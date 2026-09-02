-- ┌─────────────────┐
-- │ Git integration │
-- └─────────────────┘
--
-- This file contains the Git part of the config: the 'mini.diff' and 'mini.git'
-- modules, and what is built on top of them - the revision used as diff
-- reference, the navigation inside the output of `:Git`, and the blame of the
-- line under the cursor.
--
-- It is kept apart from 'plugin/30_mini.lua', where every other MINI module is
-- configured, because it is the one area that outgrew a module setup: two
-- modules answering the same question - what changed, when, and by whom - plus
-- the code that makes them work together. Anything else about a MINI module
-- still belongs there. The mappings that drive this file are in
-- 'plugin/20_keymaps.lua', under the `<Leader>g` group.
--
-- Both modules are enabled with `later()`, as neither is needed for the first
-- screen draw. See 'plugin/30_mini.lua' for what the loading steps are.
local later = Config.later

-- The state and the functions of this file live together under `Config.git`,
-- so that what belongs to the Git integration is told apart from the rest of
-- the config at a glance, both while reading it here and while typing
-- `:lua Config.git.` in the command line. It is created now because both
-- `later()` blocks below fill it in, each with the part it configures.
Config.git = {}

-- Hunks ======================================================================

-- Work with diff hunks that represent the difference between the buffer text and
-- some reference text set by a source. Default source uses text from Git index.
-- Also provides summary info used in developer section of 'mini.statusline'.
-- Example usage:
-- - `ghip` - apply hunks (`gh`) within *i*nside *p*aragraph
-- - `gHG` - reset hunks (`gH`) from cursor until end of buffer (`G`)
-- - `ghgh` - apply (`gh`) hunk at cursor (`gh`)
-- - `gHgh` - reset (`gH`) hunk at cursor (`gh`)
-- - `<Leader>go` - toggle overlay
--
-- See also:
-- - `:h MiniDiff-overview` - overview of how module works
-- - `:h MiniDiff-diff-summary` - available summary information
-- - `:h MiniDiff.gen_source` - available built-in sources
--
-- Beside the default source, this config can use the file content at some
-- revision as reference text, which is what makes the latest commits readable
-- as if they were not committed yet. That source and the state telling which
-- revision is referenced are set up below, and mapped to `<Leader>gr` and
-- `<Leader>gR` in 'plugin/20_keymaps.lua'.
later(function()
  require('mini.diff').setup()

  -- 'mini.diff' source using file content at `rev` as reference text.
  -- Every field is set because a buffer-local config is merged field by field
  -- into the global one (`:h mini.nvim-buffer-local-config`): a field left out
  -- would be silently taken from the source this one replaces. `apply_hunks` is
  -- the one that matters, as staging happens against the index and not `rev`.
  -- The Git source is kept as a fallback for files absent from that revision,
  -- and reused across calls because it watches '.git/index' on its own.
  local diff_source_git = nil
  local diff_sources_at = function(rev)
    local attach = function(buf_id)
      local path = vim.api.nvim_buf_get_name(buf_id)
      if vim.fn.filereadable(path) ~= 1 then return false end
      local cmd = { 'git', 'show', rev .. ':./' .. vim.fn.fnamemodify(path, ':t') }
      local out = vim.system(cmd, { cwd = vim.fn.fnamemodify(path, ':h') }):wait()
      if out.code ~= 0 then return false end
      -- Account for possible 'crlf' end of line in Git object
      MiniDiff.set_ref_text(buf_id, (out.stdout:gsub('\r\n', '\n')))
    end
    local apply_hunks = function()
      error('Hunks are shown against ' .. rev .. '. Restore the index to apply.')
    end

    diff_source_git = diff_source_git or MiniDiff.gen_source.git()
    local source = {
      name = 'git-' .. rev,
      attach = attach,
      detach = function(_) end,
      apply_hunks = apply_hunks,
    }
    return { source, diff_source_git }
  end

  -- Revision used as 'mini.diff' reference text, `nil` for the Git index: in
  -- `Config.git.diff_ref` for every buffer, in `vim.b.diff_ref` for a single one.
  -- Change it through this function, as the source has to be attached anew:
  -- - `:lua Config.git.set_diff_ref('v0.15.0')` - reference a tag everywhere
  -- - `:lua Config.git.set_diff_ref(nil, 0)` - restore the index in current buffer
  Config.git.diff_ref = nil
  Config.git.set_diff_ref = function(rev, buf_id)
    local source = rev ~= nil and diff_sources_at(rev) or nil
    local bufs = vim.api.nvim_list_bufs()
    if buf_id == nil then
      Config.git.diff_ref, MiniDiff.config.source = rev, source
    else
      buf_id = buf_id == 0 and vim.api.nvim_get_current_buf() or buf_id
      vim.b[buf_id].diff_ref = rev
      vim.b[buf_id].minidiff_config = source ~= nil and { source = source } or nil
      bufs = { buf_id }
    end

    -- Reference text is set while the source attaches, so reattach to apply it.
    -- Show the overlay wherever a revision is referenced, as reading the old text
    -- in place is the point of it. Reattaching resets it back to the config value.
    for _, id in ipairs(bufs) do
      if MiniDiff.get_buf_data(id) ~= nil then
        MiniDiff.disable(id)
        MiniDiff.enable(id)
        local data = MiniDiff.get_buf_data(id)
        local has_rev = (vim.b[id].diff_ref or Config.git.diff_ref) ~= nil
        local show_overlay = has_rev and data ~= nil and not data.overlay
        if show_overlay then MiniDiff.toggle_overlay(id) end
      end
    end

    local scope = buf_id ~= nil and ' (buffer)' or ''
    vim.notify('Diff reference' .. scope .. ': ' .. (rev or 'Git index'))
  end
end)

-- Repository =================================================================

-- Git integration for more straightforward Git actions based on Neovim's state.
-- It is not meant as a fully featured Git client, only to provide helpers that
-- integrate better with Neovim. Example usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
-- - `<Leader>gb` - toggle who last changed the line under the cursor
-- - `:Git help git` - show output of `git help git` inside Neovim
--
-- Output of `:Git` is shown in a scratch buffer with "git" or "diff" filetype.
-- Those are set up below to be navigable instead of being a wall of text:
-- - `zm` / `zr` fold and unfold by hunk, then by file, then by log entry.
--   Nothing is folded initially, as 'foldlevel' starts at the deepest level.
-- - `gf` and friends (`<C-w>f`, `[f`, ...) open the file under cursor, ignoring
--   the "a/" and "b/" prefixes which Git adds to paths inside a patch.
-- - `gF` opens the file of the patch entry at cursor in the state it had at
--   that commit, with cursor on the corresponding line.
-- - `<CR>` shows data at cursor: full commit if it is a hash (like in the
--   output of `:Git log`), the file of the patch entry if it is inside a patch,
--   evolution of the line otherwise. Unlike `gF`, it opens the file itself when
--   the patch is against the working tree (like in `<Leader>gd`/`<Leader>gh`).
-- - `q` closes the output window.
-- Both `gF` and `<CR>` open in a vertical split, next to the patch they start
-- from, instead of in a new tabpage.
--
-- See also:
-- - `:h MiniGit-examples` - examples of common setups
-- - `:h :Git` - more details about `:Git` user command
-- - `:h MiniGit.show_at_cursor()` - what information at cursor is shown
-- - `:h MiniGit.diff_foldexpr()` - how folds inside a patch are computed
later(function()
  require('mini.git').setup()

  -- HACK: paths inside a patch are relative to the root of the repository, while
  -- 'mini.git' resolves them against the current directory, as the notes of
  -- `:h MiniGit.show_diff_source()` state. The two differ whenever Neovim runs
  -- below the root, which is the normal case here as `setup_auto_root()` above
  -- stops at the config directory: showing an entry of a patch against the working
  -- tree then fails with `:h E484`. Run those calls from the root instead and
  -- restore the directory after, as `setup_auto_root()` sets it anew (on the next
  -- event loop tick) for the buffer that gets opened.
  -- Remove once 'mini.git' resolves the paths itself (still needed in 0.18.0).
  local repo_root = function() return vim.fs.root(vim.fn.getcwd(), '.git') end
  local at_repo_root = function(f, opts)
    local root = repo_root()
    if root == nil then return f(opts) end
    local cwd = vim.fn.getcwd()
    vim.fn.chdir(root)
    local ok, err = pcall(f, opts)
    vim.fn.chdir(cwd)
    if not ok then error(err, 0) end
  end

  -- The output of Git is read next to the code, so its column is given a fixed
  -- width and everything left goes to the file. It is the width the config
  -- files themselves are written to, which a commit subject and a patch are
  -- meant to fit in. Never take more than half of the screen: a fixed width is
  -- a bad deal on a narrow terminal.
  -- NOTE: `textoff` is what the line numbers and the signs take, so that the
  -- text gets the full width and not the window.
  local git_column_width = 85
  local fit_git_column = function(win_id)
    if not vim.api.nvim_win_is_valid(win_id) then return end
    local width = math.min(git_column_width, math.floor(0.5 * vim.o.columns))
    vim.api.nvim_win_set_width(win_id, width + vim.fn.getwininfo(win_id)[1].textoff)
  end

  -- `<CR>` shows either a commit or a file, and the two are read differently:
  -- a commit is detail of the log it was opened from, so it goes full width
  -- below it, while a file is the thing being read, so it gets a full height
  -- column at the far right, pushing the files opened before it to the left.
  -- Ask for the matching direction and not for the "auto" default of
  -- 'mini.git', which switches to a new tabpage as soon as a window of the
  -- current one holds a normal buffer, the case as soon as the first file has
  -- been opened this way.
  -- NOTE: which of the two is shown is decided by 'mini.git' from the word at
  -- cursor (`:h MiniGit.show_at_cursor()`), while the direction has to be known
  -- before the call, hence the same test repeated here.
  local is_commit_at_cursor = function()
    local cword = vim.fn.expand('<cword>')
    return cword:find('^%x%x%x%x%x%x%x+$') ~= nil and cword == cword:lower()
  end

  -- `MiniGit.show_diff_source()` always shows a scratch buffer with a copy of
  -- the file, also for the "after" state of a patch against the working tree.
  -- Reuse it to resolve path and line number of the entry at cursor, but then
  -- edit the file itself to get a fully functional buffer ('mini.diff', LSP).
  local show_at_cursor = function()
    local win_init = vim.api.nvim_get_current_win()
    local is_commit = is_commit_at_cursor()
    local split = is_commit and 'horizontal' or 'vertical'
    at_repo_root(MiniGit.show_at_cursor, { target = 'after', split = split })
    if vim.api.nvim_get_current_win() == win_init then
      -- There is no "after" state if the file was deleted: show "before" one
      at_repo_root(MiniGit.show_at_cursor, { split = split })
    end
    if vim.api.nvim_get_current_win() == win_init then return end
    vim.cmd(is_commit and 'wincmd J' or 'wincmd L')
    if not is_commit then fit_git_column(win_init) end

    -- Only the working tree state is shown as `edit`. A state at some commit
    -- (`show <commit>:<path>`) has no file on disk, so it is left as it is.
    -- NOTE: 'mini.git' stores the path already escaped for a command, and
    -- relative to the repository root, hence the same resolution as above.
    local path = vim.api.nvim_buf_get_name(0):match('^minigit://%d+/edit (.*)$')
    if path == nil then return end
    local root = repo_root()
    if root ~= nil then
      path = vim.fn.fnameescape(vim.fs.normalize(root)) .. '/' .. path
    end
    local lnum = vim.api.nvim_win_get_cursor(0)[1]

    -- Keep the patch as alternate file and drop the fold options which the new
    -- window inherited from it, as they only make sense inside a patch
    vim.cmd('keepalt edit ' .. path)
    vim.cmd('setlocal foldmethod< foldexpr< foldlevel<')
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    vim.cmd('normal! zv')
  end

  -- A state at some commit is always shown as a copy, in the same column
  local show_diff_source = function()
    local win_init = vim.api.nvim_get_current_win()
    at_repo_root(MiniGit.show_diff_source, { split = 'vertical' })
    if vim.api.nvim_get_current_win() == win_init then return end
    vim.cmd('wincmd L')
    fit_git_column(win_init)
  end

  local setup_patch_buf = function()
    -- Resolve "a/path" and "b/path" of a patch to a real file for `:h gf`.
    -- Add repository root to `:h 'path'` for patches shown from a subdirectory,
    -- escaped because space and comma separate the entries of 'path'.
    vim.bo.includeexpr = [[substitute(v:fname, '^[abciwo]/', '', '')]]
    local root = repo_root()
    if root ~= nil then
      root = vim.fn.escape(vim.fs.normalize(root), ' ,')
      vim.bo.path = root .. ',' .. vim.bo.path
    end

    -- Fold by file entry (level 1), hunk (2), and hunk body (3). Start at the
    -- deepest level, as with the global 'foldlevel' of 10 the first several
    -- `zm` would do nothing at all (see 'plugin/10_options.lua').
    vim.wo.foldmethod, vim.wo.foldexpr = 'expr', 'v:lua.MiniGit.diff_foldexpr()'
    vim.wo.foldlevel = 3

    -- Navigation is mapped only in scratch buffers of 'mini.nvim' itself (both
    -- "minigit://" of `:Git` and "miniextra://" of `:Pick git_commits`), as it
    -- would shadow useful defaults inside a regular patch or commit file
    if not vim.api.nvim_buf_get_name(0):find('^mini%a+://') then return end
    local bmap = function(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = 0, desc = desc })
    end
    bmap('<CR>', show_at_cursor, 'Show at cursor')
    bmap('gF', show_diff_source, 'Show diff source')
    bmap('q', '<Cmd>silent! close<CR>', 'Close output')
  end
  local ft_patch = { 'git', 'diff' }
  Config.new_autocmd('FileType', ft_patch, setup_patch_buf, 'Navigable Git output')

  -- Who last changed the line under the cursor, written at the end of the line
  -- itself instead of in a window: this is the reading wanted while writing
  -- code, and a window for one line costs the code half of the screen.
  -- `<Leader>gb` turns it on and off, `:vertical Git blame -- %:p` still
  -- blames the whole file. What is shown, in the layout `<Leader>gl` uses:
  -- `Gaetano Esposito │ 2026-09-02 │ fix(mini): patch fails below the root`
  --
  -- NOTE: `git blame` reads the file from disk, so nothing is shown while the
  -- buffer is modified: past the first unsaved edit the line numbers are no
  -- longer the ones on disk and lines would be credited to the wrong commit.
  local blame_ns = vim.api.nvim_create_namespace('custom-config-blame')
  local blame_timer = vim.uv.new_timer()
  local blame_last = {}

  local blame_clear = function(buf_id)
    if not vim.api.nvim_buf_is_valid(buf_id) then return end
    vim.api.nvim_buf_clear_namespace(buf_id, blame_ns, 0, -1)
  end

  local blame_show = function(buf_id, lnum)
    local root = (MiniGit.get_buf_data(buf_id) or {}).root
    if root == nil or vim.bo[buf_id].modified then return end

    local range = lnum .. ',' .. lnum
    local path = vim.api.nvim_buf_get_name(buf_id)
    local cmd = { 'git', 'blame', '--porcelain', '-L', range, '--', path }
    local on_done = function(out)
      -- An answer for a line the cursor has left is of no interest anymore
      local is_current = blame_last.buf_id == buf_id and blame_last.lnum == lnum
      if out.code ~= 0 or not is_current then return end

      -- A line not committed yet is reported with a hash of only zeros
      local text = 'Not committed yet'
      if out.stdout:find('^0+ ') == nil then
        local author = out.stdout:match('\nauthor ([^\n]*)') or '?'
        local summary = out.stdout:match('\nsummary ([^\n]*)') or '?'
        local time = tonumber(out.stdout:match('\nauthor%-time (%d+)'))
        local date = time ~= nil and os.date('%Y-%m-%d', time) or '?'
        text = author .. ' │ ' .. date .. ' │ ' .. summary
      end
      -- NOTE: `hl_mode` defaults to "replace", which would keep the annotation
      -- on the background of 'Normal' while the line it belongs to is
      -- highlighted by `:h 'cursorline'`, making it look cut out of the line.
      -- "combine" keeps the foreground of 'Comment' over whichever background
      -- the line has.
      -- The leading space is one column more than `virt_text_pos` leaves, so
      -- that the annotation does not read as part of the line it follows.
      -- `virt_text_win_col` would pin it to a fixed window column instead,
      -- landing inside the code on every line longer than that column.
      local opts = {
        virt_text = { { ' ' .. text, 'Comment' } },
        virt_text_pos = 'eol',
        hl_mode = 'combine',
      }
      pcall(vim.api.nvim_buf_set_extmark, buf_id, blame_ns, lnum - 1, 0, opts)
    end
    vim.system(cmd, { cwd = root, text = true }, vim.schedule_wrap(on_done))
  end

  -- Blame a line only once the cursor rests on it, as holding `j` would
  -- otherwise start a `git` process for every line passed through
  local blame_track = function()
    local buf_id, lnum = vim.api.nvim_get_current_buf(), vim.fn.line('.')
    local tick = vim.b[buf_id].changedtick
    local is_same = blame_last.buf_id == buf_id and blame_last.lnum == lnum
    if is_same and blame_last.tick == tick then return end
    -- Left as it is, the annotation of the previous buffer stays readable in
    -- whatever split still shows it, as if the cursor had never left
    if blame_last.buf_id ~= nil then blame_clear(blame_last.buf_id) end
    blame_last = { buf_id = buf_id, lnum = lnum, tick = tick }

    blame_clear(buf_id)
    blame_timer:stop()
    if not Config.git.blame then return end
    local show = function() blame_show(buf_id, lnum) end
    blame_timer:start(150, 0, vim.schedule_wrap(show))
  end
  local blame_events = { 'CursorMoved', 'CursorMovedI', 'BufEnter' }
  Config.new_autocmd(blame_events, nil, blame_track, 'Blame current line')

  -- Whether that annotation is shown at all. It starts off: who wrote a line
  -- is asked for at some point while reading, not at every one of them, and
  -- until it is asked there is no reason to run `git` on every pause of the
  -- cursor. Example usage:
  -- - `:lua Config.git.toggle_blame()` - what `<Leader>gb` does
  Config.git.blame = false
  Config.git.toggle_blame = function()
    Config.git.blame = not Config.git.blame
    if not Config.git.blame then
      vim.tbl_map(blame_clear, vim.api.nvim_list_bufs())
    end
    blame_last = {}
    blame_track()
    vim.notify('Blame line: ' .. (Config.git.blame and 'on' or 'off'))
  end

  -- Align output of `<Leader>gb` with the window it was called from and make
  -- both windows scroll together. See `:h MiniGit-examples`.
  local align_blame = function(au_data)
    if au_data.data.git_subcommand ~= 'blame' then return end
    local win_src = au_data.data.win_source
    vim.wo.wrap = false
    vim.fn.winrestview({ topline = vim.fn.line('w0', win_src) })
    vim.api.nvim_win_set_cursor(0, { vim.fn.line('.', win_src), 0 })
    vim.wo[win_src].scrollbind, vim.wo.scrollbind = true, true
  end
  Config.new_autocmd('User', 'MiniGitCommandSplit', align_blame, 'Align Git blame')
end)
