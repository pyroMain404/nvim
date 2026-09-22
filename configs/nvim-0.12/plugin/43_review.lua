-- ┌─────────────┐
-- │ File review │
-- └─────────────┘
--
-- A patch says what changed, and the `<Leader>g` group is how it is read. What
-- it never shows is the code that stayed: whether the new function belongs
-- where it was put, whether something next to it should have moved with it.
-- That reading happens in the files themselves, and its unit is the set of
-- files a change touched.
--
-- This file turns such a set into the argument list (`:h argument-list`) of
-- a new tabpage, which is what Neovim already has for "the files I am working
-- through": `:h :next` and `:h :previous` walk it, `:h :argdo` runs a command
-- over all of it, `:h :args` prints it with the current file in brackets,
-- `:h :first` starts it over. None of that is written here - only the filling
-- of the list.
--
-- Where the set comes from is deliberately not part of it. Opening files in
-- order to read them is the same work whether Git named them, a grep did, or
-- they were typed by hand, so `Config.review.open()` asks nothing about their
-- origin: a source is anything that produces paths and hands them over. Git is
-- the first one, and the reason this file exists.
--
-- Everything this file offers is reachable through `Config.review`, and nothing
-- else of it is global:
--
-- - `Config.review.max_files` - how many files are opened without asking first.
-- - `Config.review.open(paths, label, on_open)` - open these files as the
--   argument list of a new tabpage. `label` names the review in every message
--   it prints, and is written so that it reads after the word "Review".
--   `on_open` is optional, and is what the source does once it is there.
-- - `Config.review.close()` - close the review of the current tabpage, drop the
--   buffers it opened and restore the diff reference it found.
-- - `Config.review.git(rev, pathspec)` - files changed since a revision, opened
--   as a review.
-- - `Config.review.commit_only(rev, pathspec)` - files a commit changed by
--   itself.
-- - `Config.review.unstaged(pathspec)` - files changed and not staged yet.
-- - `Config.review.staged(pathspec)` - files changed and already staged.
--
-- Mappings carry no logic of their own: 'plugin/20_keymaps.lua' binds
-- `<Leader>rc`, `<Leader>rs`, `<Leader>rp`, `<Leader>rd` and `<Leader>ra` to
-- the last five, under the `<Leader>r` group. Read that file for what a review
-- looks like from the keyboard; read this one for how it is implemented.
--
-- A review since a revision references it on its own - what `<Leader>gr` does
-- by hand - so every buffer holds the change it received since then, hunk by
-- hunk. Closing the review puts back whatever was referenced before it.

Config.review = {}

-- Reading ====================================================================

-- More files than one session of reading holds. Past this many the review is
-- opened only after a confirmation: a commit picked far enough back names half
-- the repository, and loading that is an editor frozen for as long as it takes.
Config.review.max_files = 50

-- Paths naming a file there is something to read in, normalized. A path the
-- change deleted, or the name it was renamed away from, is a line of the answer
-- with nothing to open behind it; every source produces some of them, so they
-- are dropped here instead of in each one.
local readable_paths = function(paths)
  local res = {}
  for _, path in ipairs(paths) do
    if vim.fn.filereadable(path) == 1 then
      table.insert(res, vim.fs.normalize(path))
    end
  end
  return res
end

-- Argument list of a new tabpage, holding the files to review. It is local to
-- the window `:h :tabnew` opens (`:h :arglocal`) and defined in a single
-- command, so it starts empty by construction and the global list - the files
-- Neovim was started with - is left as it is. Every split made from that window
-- inherits it, so the review survives being read in two columns.
--
-- The files are loaded and listed right away instead of when `:next` first
-- reaches them: the whole set is then one `:h :bnext` away, and is in the buffer
-- picker (`<Leader>fb`) and in the tabline as the thing being read.
-- NOTE: `:h bufadd()` creates a buffer neither listed nor loaded, which is what
-- the two calls after it are for.
-- NOTE: loading throws on a file another Neovim is editing, which is what the
-- swap file question of `:h E325` is - and a review is read exactly while the
-- code is being written elsewhere. Without the `pcall` the first such file ends
-- the loop, and the review silently holds files nobody opened; with it the file
-- stays in the list and `:next` asks the same question when it gets there.
-- NOTE: which buffers the review created is written down here, in a tabpage
-- variable that lives exactly as long as the review does, because afterwards it
-- cannot be worked out: a file already open before the review is indis-
-- tinguishable from one it opened, and closing the review must not close it.
-- NOTE: `on_open` runs after the tabpage is there and before the files are
-- loaded, so that whatever it sets - a diff reference, an option - is what they
-- are loaded against, and is written down in the tabpage the review lives in.
local open_arglist = function(paths, label, on_open)
  local existing = {}
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    existing[buf_id] = true
  end

  vim.cmd('tabnew')
  local escaped = vim.tbl_map(vim.fn.fnameescape, paths)
  vim.cmd('arglocal! ' .. table.concat(escaped, ' '))
  if on_open ~= nil then on_open() end

  local opened, unloaded = {}, 0
  for _, path in ipairs(paths) do
    local buf_id = vim.fn.bufadd(path)
    vim.bo[buf_id].buflisted = true
    if not pcall(vim.fn.bufload, buf_id) then unloaded = unloaded + 1 end
    if not existing[buf_id] then table.insert(opened, buf_id) end
  end
  vim.t.review_bufs = opened

  Config.report(
    'Review ' .. label,
    #paths,
    unloaded,
    'file(s)',
    'not loaded (open elsewhere?)'
  )
end

-- Open `paths` as the review, asking first when it is a big one. The question
-- is asked through `Config.confirm()`, as in `Config.git.update_config()`. This
-- is the whole contract a source has to meet: a list of paths and a label, plus
-- an `on_open` when producing them is not all it does - the Git source
-- references the revision there, and a source with nothing to add passes
-- nothing. Example usage:
-- - `:lua Config.review.open({ 'init.lua', 'plugin/10_options.lua' }, 'by hand')`
Config.review.open = function(paths, label, on_open)
  paths = readable_paths(paths)
  if #paths == 0 then
    return vim.notify('No file to review ' .. label, vim.log.levels.WARN)
  end
  if #paths <= Config.review.max_files then
    return open_arglist(paths, label, on_open)
  end

  Config.confirm(
    #paths .. ' files to review. Open them all?',
    function() open_arglist(paths, label, on_open) end
  )
end

-- Close the review of the current tabpage. The tabpage goes, and the argument
-- list with it, being local to it; what outlives both are the buffers, and they
-- are the reason this exists: 'mini.tabline' shows every listed buffer, so
-- a review read and done leaves its files in the line at the top. Only the ones
-- it opened are dropped - a file already open before it belongs to whatever was
-- being done before, and stays.
--
-- Under a handful of files this is `<Leader>bd` pressed a few times, which is
-- what 'plugin/30_mini.lua' says about buffers taking up space. It is worth
-- a key of its own at the size `Config.review.max_files` allows, where what is
-- left behind is a tabline nobody can read.
--
-- The diff reference goes with them, back to what it was before the review:
-- a review since a revision references it (`Config.review.git()`), and what is
-- read against what ends with the tabpage that held it. A reference changed by
-- hand while the review was open is left alone - that is a decision about what
-- to read against, and closing a tabpage does not undo it. Example usage:
-- - `:lua Config.review.close()` - what `<Leader>rc` does
-- NOTE: a buffer with unsaved changes refuses to be deleted (`:h E89`), and is
-- reported rather than forced: the review is over, that edit is not.
-- NOTE: both tabpage variables are read before `:h :tabclose`, after which they
-- are those of whatever tabpage the closing lands in.
Config.review.close = function()
  local bufs, diff_ref = vim.t.review_bufs, vim.t.review_diff_ref
  if bufs == nil then
    return vim.notify('Not in a review tabpage', vim.log.levels.ERROR)
  end
  if #vim.api.nvim_list_tabpages() == 1 then
    local msg = 'Review is the only tabpage: nothing left to return to'
    return vim.notify(msg, vim.log.levels.WARN)
  end

  -- `:h :tabclose` refuses on a modified buffer with `'hidden'` unset - not
  -- the case here (`plugin/10_options.lua` sets it), but reported rather
  -- than left to raise if that ever changes.
  if not pcall(vim.cmd, 'tabclose') then
    return vim.notify('Could not close the review tabpage', vim.log.levels.ERROR)
  end

  -- Scheduled: 'mini.git' updates its own status asynchronously
  -- (`vim.schedule_wrap`), and deleting a buffer synchronously right after
  -- `:tabclose` can run ahead of that update and raise on an id it still
  -- expects to be valid. Scheduling this loop lets that update land first.
  vim.schedule(function()
    local kept = 0
    for _, buf_id in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf_id) then
        if not pcall(vim.api.nvim_buf_delete, buf_id, {}) then kept = kept + 1 end
      end
    end
    if diff_ref ~= nil and Config.git.diff_ref == diff_ref.set then
      Config.git.set_diff_ref(nil, diff_ref.prev)
    end

    Config.report(
      'Review closed',
      #bufs - kept,
      kept,
      'buffer(s) dropped',
      'kept (unsaved changes)'
    )
  end)
end

-- Git ========================================================================

-- Git names four sets of files worth reading as a whole, and each is a review:
-- what changed since some revision (`Config.review.git()`), what one commit
-- changed by itself (`Config.review.commit_only()`), what is changed and not
-- staged yet (`Config.review.unstaged()`), and what is staged and about to be
-- committed (`Config.review.staged()`). They are the same command with
-- different arguments - `git diff --name-only`, the revision or `<rev>^!` or
-- `--cached` or neither - and the same four sets `<Leader>gs`, `<Leader>gp`,
-- `<Leader>gd` and `<Leader>ga` show as a patch: the group answers "what
-- changed", this file opens it, and the mapping of each keeps the second key of
-- the patch it answers.
--
-- NOTE: a file Git does not track yet is in none of them, `git diff` being
-- about what Git already knows. It is the same blind spot the patches have, so
-- a review holds exactly what the patch of the same name holds.

-- Which files the review holds is decided by `rev`: the command is always
-- `git diff --name-only <rev>`, and `rev` is handed over as it is. That is
-- enough for every shape a review takes, because the range syntax of Git is
-- itself the expressive part. Example usage:
-- - `:lua Config.review.git()` - what `<Leader>rs` does: pick a commit from the
--   Git log and review everything changed since it
-- - `:lua Config.review.git('HEAD')` - the working tree, staged or not
-- - `:lua Config.review.git('main')` - every file this branch differs in
-- - `:lua Config.review.git('main...')` - only what this branch changed, from
--   where it left `main`, ignoring what happened on `main` since
-- - `:lua Config.review.git('abc1234~..abc1234')` - one commit alone
--
-- `pathspec` narrows that set to a part of the tree, and is what Git calls one:
-- a directory, a file, a glob, or a list of them, added after `--`. It answers
-- the review which spans three areas and is read one area at a time, and it is
-- the one thing `rev` cannot say, being about where in the tree rather than
-- since when. No mapping passes it - it is reached from the command line:
-- - `:lua Config.review.git('main', 'configs/')` - only that directory
-- - `:lua Config.review.git('main', { 'configs/', '*.md' })` - either of them
--
-- A pathspec is read from the root of the repository, which is where Git is run
-- and the root every path it reports is relative to: it says the same thing no
-- matter which directory Neovim was started in.

-- Ask Git which files changed and hand them over. `diff_args` is what selects
-- them - a revision, `--cached`, or nothing at all - and `label` says the same
-- thing in words, for the messages. `on_open` reaches `Config.review.open()`
-- untouched, and is where a revision gets referenced when there is one.
--
-- It runs asynchronously (`:h vim.system()`) both because a diff over a long
-- range takes its time and because the callback then runs once the picker has
-- closed, which is what makes a window openable from it.
-- NOTE: with the default `core.quotePath`, Git writes a path holding anything
-- outside ASCII quoted and escaped ("caff\303\250.lua"), which matches no file
-- on disk and would drop it from the review without a word. Turning the setting
-- off for this one call is what keeps such a file in.
-- NOTE: a single pathspec is taken as a string, as that is how one is written
-- in the command line, and both messages name it: a review limited to a
-- directory which finds nothing has to say which directory it looked in. The
-- error names the command as it was run, the review names itself as it reads.
local git_changed = function(diff_args, root, pathspec, label, on_open)
  local cmd = { 'git', '-c', 'core.quotePath=false', 'diff', '--name-only' }
  vim.list_extend(cmd, diff_args)
  local args = table.concat(diff_args, ' ')
  if pathspec ~= nil then
    local specs = type(pathspec) == 'string' and { pathspec } or pathspec
    vim.list_extend(cmd, { '--' })
    vim.list_extend(cmd, specs)
    local shown = '-- ' .. table.concat(specs, ' ')
    args, label = vim.trim(args .. ' ' .. shown), label .. ' ' .. shown
  end

  local on_done = function(out)
    if out.code ~= 0 then
      local msg = vim.trim(out.stderr)
      if msg == '' then msg = 'exited with code ' .. out.code end
      local run = vim.trim('git diff ' .. args)
      return vim.notify(run .. ': ' .. msg, vim.log.levels.ERROR)
    end
    local dir, paths = vim.fs.normalize(root), {}
    for _, line in
      ipairs(vim.split(out.stdout, '\n', { plain = true, trimempty = true }))
    do
      table.insert(paths, dir .. '/' .. vim.trim(line))
    end
    Config.review.open(paths, label, on_open)
  end
  vim.system(cmd, { cwd = root, text = true }, vim.schedule_wrap(on_done))
end

-- Root of the repository to review, `nil` outside one - `Config.git`'s own
-- resolver and warning, reused instead of repeated across all four sources.
local review_root = Config.git.require_root

-- Reference `rev` in every buffer, which is what `<Leader>gr` does by hand, and
-- write down in the review tabpage both it and the reference it replaces.
-- `Config.review.close()` reads the two: the revision to recognise a reference
-- still standing from the review, the previous one to put back in its place.
-- NOTE: the reference is global rather than a property of the tabpage, being
-- the one 'mini.diff' has, so a second review opened over the first takes it
-- over. Closing that one restores the revision of the first; closing the first
-- afterwards finds a reference it did not set, and leaves it alone.
-- NOTE: a revision `git show <rev>:<path>` cannot resolve - a range such as
-- `main...`, which names a set of commits and not a state - leaves every file
-- on the Git index fallback of the source. The review then holds the right
-- files and the reference shows what is not staged, neither of them saying
-- anything is off: a range is reviewed with the reference set on its merge base
-- (`<Leader>gr`, or `:lua Config.git.set_diff_ref(nil, 'main')`).
local reference_rev = function(rev)
  vim.t.review_diff_ref = { set = rev, prev = Config.git.diff_ref }
  Config.git.set_diff_ref(nil, rev)
end

-- Review the files changed since `rev`, or since a commit picked from the Git
-- log when it is not given - the same way `Config.git.diff_commit()` picks the
-- commit to diff against. `pathspec` narrows the review to a part of the tree,
-- and holds whether the revision is given or picked.
--
-- That revision is also what the review is read against: it becomes the
-- 'mini.diff' reference text, so every file opened shows the change it received
-- since then - hunk navigation, hunk textobject and overlay included - without
-- picking the same commit a second time under `<Leader>gr`. Example usage:
-- - `:lua Config.review.git()` - what `<Leader>rs` does
-- - `:lua Config.review.git('HEAD~3')` - skip the picker
-- - `:lua Config.review.git(nil, 'configs/')` - pick, then keep that directory
-- NOTE: the root is resolved before the picker starts, so that a call from
-- outside a repository is refused right away instead of after a picker with
-- nothing to pick from.
Config.review.git = function(rev, pathspec)
  local root = review_root()
  if root == nil then return end
  local since = function(commit)
    local reference = function() reference_rev(commit) end
    git_changed({ commit }, root, pathspec, 'since ' .. commit, reference)
  end
  if rev ~= nil then return since(rev) end

  local choose = function(item) since(item:match('^%S+')) end
  MiniExtra.pickers.git_commits({}, { source = { choose = choose } })
end

-- Review the files a commit changed by itself - what `<Leader>gp` shows as a
-- patch - picking it from the Git log when `rev` is not given. What
-- the files are read against is the commit before the picked one, so each of
-- them shows exactly the change that commit made and nothing of what came
-- after. Example usage:
-- - `:lua Config.review.commit_only()` - what `<Leader>rp` does
-- - `:lua Config.review.commit_only('HEAD~3')` - skip the picker
-- - `:lua Config.review.commit_only(nil, 'configs/')` - pick, then keep that
--   directory
-- NOTE: `<rev>^!` names the commit excluding its parents (`:h gitrevisions`),
-- which is what makes the first commit of a repository readable too - the range
-- `<rev>~..<rev>` has no parent to name there and Git refuses it. The reference
-- is still written `<rev>~`, being a state a file is shown at rather than a set
-- of commits: on that first commit there is none, and every file falls back on
-- the Git index the way a range does.
Config.review.commit_only = function(rev, pathspec)
  local root = review_root()
  if root == nil then return end
  local only = function(commit)
    local reference = function() reference_rev(Config.git.parent(commit)) end
    git_changed(
      { Config.git.only(commit) },
      root,
      pathspec,
      'in ' .. commit,
      reference
    )
  end
  if rev ~= nil then return only(rev) end

  local choose = function(item) only(item:match('^%S+')) end
  MiniExtra.pickers.git_commits({}, { source = { choose = choose } })
end

-- The two sets which need no revision to name them, and the ones read most
-- often: what is changed and not staged yet, and what is staged and about to be
-- committed. They are read while the change is being written rather than after
-- it, so neither has anything to pick and both open right away. `pathspec`
-- narrows them the same way it narrows `Config.review.git()`. Example usage:
-- - `:lua Config.review.unstaged()` - what `<Leader>rd` does
-- - `:lua Config.review.staged()` - what `<Leader>ra` does
-- - `:lua Config.review.unstaged('configs/')` - only that directory
-- NOTE: neither touches the diff reference, which stays the Git index and so
-- shows what is not staged yet. Naming the state before a staged change is
-- `HEAD`, and referencing it is `<Leader>gr` away.
Config.review.unstaged = function(pathspec)
  local root = review_root()
  if root == nil then return end
  git_changed({}, root, pathspec, 'not staged')
end

Config.review.staged = function(pathspec)
  local root = review_root()
  if root == nil then return end
  git_changed({ '--cached' }, root, pathspec, 'staged')
end
