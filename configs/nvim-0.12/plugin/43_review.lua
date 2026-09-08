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
-- origin: a source is anything that produces paths and hands them over.
-- `Config.review.git()` is the first one, and the reason this file exists.
--
-- Everything this file offers is reachable through `Config.review`, and nothing
-- else of it is global:
--
-- - `Config.review.max_files` - how many files are opened without asking first.
-- - `Config.review.open(paths, label)` - open these files as the argument list
--   of a new tabpage. `label` names the review in every message it prints, and
--   is written so that it reads after the word "Review".
-- - `Config.review.close()` - close the review of the current tabpage and drop
--   the buffers it opened.
-- - `Config.review.git(rev, pathspec)` - files changed since a revision, opened
--   as a review.
--
-- Mappings carry no logic of their own: 'plugin/20_keymaps.lua' binds
-- `<Leader>rg` and `<Leader>rc` to the last two, under the `<Leader>r` group.
-- Read that file for what a review looks like from the keyboard; read this one
-- for how it is implemented.
--
-- It pairs with `<Leader>gr`: referencing the same revision turns every buffer
-- of the review into the change it received, hunk by hunk.

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
local open_arglist = function(paths, label)
  local existing = {}
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    existing[buf_id] = true
  end

  vim.cmd('tabnew')
  local escaped = vim.tbl_map(vim.fn.fnameescape, paths)
  vim.cmd('arglocal! ' .. table.concat(escaped, ' '))

  local opened, unloaded = {}, 0
  for _, path in ipairs(paths) do
    local buf_id = vim.fn.bufadd(path)
    vim.bo[buf_id].buflisted = true
    if not pcall(vim.fn.bufload, buf_id) then unloaded = unloaded + 1 end
    if not existing[buf_id] then table.insert(opened, buf_id) end
  end
  vim.t.review_bufs = opened

  local msg = 'Review ' .. label .. ': ' .. #paths .. ' file(s)'
  if unloaded == 0 then return vim.notify(msg) end
  msg = msg .. ', ' .. unloaded .. ' not loaded (open elsewhere?)'
  vim.notify(msg, vim.log.levels.WARN)
end

-- Open `paths` as the review, asking first when it is a big one. The question
-- is asked with `:h vim.ui.input()`, as in `Config.git.update_config()`. This
-- is the whole contract a source has to meet: a list of paths and a label.
-- Example usage:
-- - `:lua Config.review.open({ 'init.lua', 'plugin/10_options.lua' }, 'by hand')`
Config.review.open = function(paths, label)
  paths = readable_paths(paths)
  if #paths == 0 then
    return vim.notify('No file to review ' .. label, vim.log.levels.WARN)
  end
  if #paths <= Config.review.max_files then return open_arglist(paths, label) end

  local prompt = #paths .. ' files to review. Open them all? (y/n) '
  vim.ui.input({ prompt = prompt }, function(answer)
    if (answer or ''):lower() ~= 'y' then return end
    open_arglist(paths, label)
  end)
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
-- left behind is a tabline nobody can read. Example usage:
-- - `:lua Config.review.close()` - what `<Leader>rc` does
-- NOTE: a buffer with unsaved changes refuses to be deleted (`:h E89`), and is
-- reported rather than forced: the review is over, that edit is not.
Config.review.close = function()
  local bufs = vim.t.review_bufs
  if bufs == nil then
    return vim.notify('Not in a review tabpage', vim.log.levels.WARN)
  end
  if #vim.api.nvim_list_tabpages() == 1 then
    local msg = 'Review is the only tabpage: nothing left to return to'
    return vim.notify(msg, vim.log.levels.WARN)
  end

  vim.cmd('tabclose')
  local kept = 0
  for _, buf_id in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      if not pcall(vim.api.nvim_buf_delete, buf_id, {}) then kept = kept + 1 end
    end
  end

  local msg = 'Review closed: ' .. (#bufs - kept) .. ' buffer(s) dropped'
  if kept == 0 then return vim.notify(msg) end
  msg = msg .. ', ' .. kept .. ' kept (unsaved changes)'
  vim.notify(msg, vim.log.levels.WARN)
end

-- Git ========================================================================

-- Which files the review holds is decided by `rev`: the command is always
-- `git diff --name-only <rev>`, and `rev` is handed over as it is. That is
-- enough for every shape a review takes, because the range syntax of Git is
-- itself the expressive part. Example usage:
-- - `:lua Config.review.git()` - what `<Leader>rg` does: pick a commit from the
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

-- Ask Git which files changed and hand them over. It runs asynchronously
-- (`:h vim.system()`) both because a diff over a long range takes its time and
-- because the callback then runs once the picker has closed, which is what
-- makes a window openable from it.
-- NOTE: with the default `core.quotePath`, Git writes a path holding anything
-- outside ASCII quoted and escaped ("caff\303\250.lua"), which matches no file
-- on disk and would drop it from the review without a word. Turning the setting
-- off for this one call is what keeps such a file in.
-- NOTE: a single pathspec is taken as a string, as that is how one is written
-- in the command line, and every message names the arguments Git was given
-- rather than the revision alone: a review limited to a directory which finds
-- nothing has to say which directory it looked in.
local git_changed = function(rev, root, pathspec)
  local cmd = { 'git', '-c', 'core.quotePath=false', 'diff', '--name-only', rev }
  local args = rev
  if pathspec ~= nil then
    local specs = type(pathspec) == 'string' and { pathspec } or pathspec
    vim.list_extend(cmd, { '--' })
    vim.list_extend(cmd, specs)
    args = rev .. ' -- ' .. table.concat(specs, ' ')
  end

  local on_done = function(out)
    if out.code ~= 0 then
      local msg = vim.trim(out.stderr)
      if msg == '' then msg = 'exited with code ' .. out.code end
      return vim.notify('git diff ' .. args .. ': ' .. msg, vim.log.levels.ERROR)
    end
    local dir, paths = vim.fs.normalize(root), {}
    for _, line in ipairs(vim.split(out.stdout, '\n')) do
      table.insert(paths, dir .. '/' .. vim.trim(line))
    end
    Config.review.open(paths, 'since ' .. args)
  end
  vim.system(cmd, { cwd = root, text = true }, vim.schedule_wrap(on_done))
end

-- Review the files changed since `rev`, or since a commit picked from the Git
-- log when it is not given - the same way `Config.git.diff_commit()` picks the
-- commit to diff against. `pathspec` narrows the review to a part of the tree,
-- and holds whether the revision is given or picked. Example usage:
-- - `:lua Config.review.git()` - what `<Leader>rg` does
-- - `:lua Config.review.git('HEAD~3')` - skip the picker
-- - `:lua Config.review.git(nil, 'configs/')` - pick, then keep that directory
-- NOTE: the root is resolved before the picker starts, so that a call from
-- outside a repository is refused right away instead of after a picker with
-- nothing to pick from.
Config.review.git = function(rev, pathspec)
  local root = Config.git.root()
  if root == nil then
    return vim.notify('Not inside a Git repository', vim.log.levels.WARN)
  end
  if rev ~= nil then return git_changed(rev, root, pathspec) end

  local choose = function(item) git_changed(item:match('^%S+'), root, pathspec) end
  MiniExtra.pickers.git_commits({}, { source = { choose = choose } })
end
