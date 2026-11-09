-- ┌────────────────────┐
-- │ MINI configuration │
-- └────────────────────┘
--
-- One `setup()` per 'mini.nvim' module (`:h mini.xxx`); step one runs before first draw.

local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

-- Step one ===================================================================
-- Disabled alternatives to 'ayu' (plugin/40_plugins.lua), `:h mini.nvim-color-schemes`:
-- now(function() vim.cmd('colorscheme miniwinter') end)
-- now(function() vim.cmd('colorscheme minispring') end)
-- now(function() vim.cmd('colorscheme minisummer') end)
-- now(function() vim.cmd('colorscheme miniautumn') end)
-- now(function() vim.cmd('colorscheme randomhue') end)

-- Common options, mappings and autocommands: `:h MiniBasics.config`.
now(
  function()
    require('mini.basics').setup({
      mappings = {
        windows = true,
        move_with_alt = true,
      },
    })
  end
)

-- Icon provider (`:h MiniIcons`).
now(function()
  local blocklist = { scm = true, txt = true, yml = true, json = true, yaml = true }
  require('mini.icons').setup({
    use_file_extension = function(ext, _)
      return not blocklist[ext:sub(-3)] and not blocklist[ext:sub(-4)]
    end,
  })

  later(MiniIcons.tweak_lsp_kind)
end)

-- `content.sort` hides the progress reports jdtls sends on every keystroke
now(function()
  require('mini.notify').setup({
    content = {
      sort = function(notifications)
        return require('config.lsp').notify_sort(notifications)
      end,
    },
  })
end)

now(function() require('mini.sessions').setup() end)

-- Start screen (`:h MiniStarter-example-config`).
now(function() require('mini.starter').setup() end)

-- Statusline (`:h MiniStatusline-example-content`); 'lua/config/git/diffref.lua' labels the diff section.
-- NOTE: a custom `config.content.active` that does not call `section_diff()` silently loses the label.
now(function()
  require('mini.statusline').setup()

  local default = MiniStatusline.section_diff
  MiniStatusline.section_diff = function(args)
    local diff = default(args)
    local diffref = package.loaded['config.git.diffref']
    local label = diffref and diffref.label(vim.api.nvim_get_current_buf())
    if not label then return diff end
    return diff == '' and label or (label .. ' ' .. diff)
  end
end)

now(function() require('mini.tabline').setup() end)

-- Step one or two ============================================================

-- Completion and signature help (`:h MiniCompletion`).
now_if_args(function()
  local process_items_opts = { kind_priority = { Text = -1, Snippet = 99 } }
  local process_items = function(items, base)
    return MiniCompletion.default_process_items(items, base, process_items_opts)
  end
  require('mini.completion').setup({
    lsp_completion = {
      source_func = 'omnifunc',
      auto_setup = false,
      process_items = process_items,
    },
  })

  local on_attach = function(ev)
    vim.bo[ev.buf].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'
  end
  Config.new_autocmd('LspAttach', nil, on_attach, "Set 'omnifunc'")

  vim.lsp.config('*', { capabilities = MiniCompletion.get_lsp_capabilities() })
end)

-- File explorer (`:h MiniFiles-navigation`).
now_if_args(function()
  local filter_show = function(fs_entry)
    return not vim.endswith(fs_entry.name, '.gd.uid')
  end
  require('mini.files').setup({
    content = { filter = filter_show },
    windows = { preview = true },
  })

  -- NOTE: bookmark the resolved path: a file opened through the startup junction has no
  -- root marker above it, so `lua_ls` starts rootless in single file mode and publishes
  -- no diagnostics (see `config_file()` in 'plugin/20_keymaps.lua').
  local add_marks = function()
    local config_dir = vim.fn.resolve(vim.fn.stdpath('config'))
    MiniFiles.set_bookmark('c', config_dir, { desc = 'Config' })
    local vimpack_plugins = vim.fn.stdpath('data') .. '/site/pack/core/opt'
    MiniFiles.set_bookmark('p', vimpack_plugins, { desc = 'Plugins' })
    MiniFiles.set_bookmark('w', vim.fn.getcwd, { desc = 'Working directory' })
  end
  Config.new_autocmd('User', 'MiniFilesExplorerOpen', add_marks, 'Add bookmarks')
end)

-- Miscellaneous helpers (`:h MiniMisc`).
now_if_args(function()
  require('mini.misc').setup()

  -- NOTE: 'nvim-pack-lock.json' comes first so this config is its own project; the nearest
  -- '.git' is the whole fork's. 'init.lua' can not serve as marker, many plugins have one.
  MiniMisc.setup_auto_root({ 'nvim-pack-lock.json', '.git', 'Makefile' })

  MiniMisc.setup_restore_cursor()

  -- HACK: ConPTY never relays the OSC 11 background query, so `setup_termbg_sync()` waits
  -- a second and warns. Delete the guard once ConPTY forwards OSC queries (still absent
  -- in Windows 11 26200, Windows Terminal 1.24).
  if vim.fn.has('win32') == 0 then MiniMisc.setup_termbg_sync() end
end)

-- Step two ===================================================================

-- Extra pickers, textobjects and highlighters (`:h MiniExtra.pickers`).
later(function() require('mini.extra').setup() end)

-- Extended a/i textobjects (`:h MiniAi-builtin-textobjects`).
later(function()
  local ai = require('mini.ai')
  ai.setup({
    custom_textobjects = {
      B = MiniExtra.gen_ai_spec.buffer(),
      F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
    },

    search_method = 'cover',
  })
end)

-- Align text (`:h MiniAlign-example`).
later(function() require('mini.align').setup() end)

-- Square-bracket motions (`:h MiniBracketed`).
-- NOTE: the `indent` target is disabled: 'mini.indentscope' takes `[i` and Neovim's
-- defaults take `[d` (`:h lsp-defaults`).
later(
  function()
    require('mini.bracketed').setup({
      indent = { suffix = '' },
    })
  end
)

-- Remove buffers (`:h MiniBufremove`).
later(function() require('mini.bufremove').setup() end)

-- Next-key clues (`:h MiniClue-examples`); not active in special buffers.
later(function()
  local miniclue = require('mini.clue')
  -- stylua: ignore
  miniclue.setup({
    clues = {
      Config.leader_group_clues,
      miniclue.gen_clues.builtin_completion(),
      miniclue.gen_clues.g(),
      miniclue.gen_clues.marks(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.square_brackets(),
      miniclue.gen_clues.windows({ submode_resize = true }),
      miniclue.gen_clues.z(),
    },
    triggers = {
      { mode = { 'n', 'x' }, keys = '<Leader>' }, -- Leader triggers
      { mode =   'n',        keys = '\\' },       -- mini.basics
      { mode = { 'n', 'x' }, keys = '[' },        -- mini.bracketed
      { mode = { 'n', 'x' }, keys = ']' },
      { mode =   'i',        keys = '<C-x>' },    -- Built-in completion
      { mode = { 'n', 'x' }, keys = 'g' },        -- `g` key
      { mode = { 'n', 'x' }, keys = "'" },        -- Marks
      { mode = { 'n', 'x' }, keys = '`' },
      { mode = { 'n', 'x' }, keys = '"' },        -- Registers
      { mode = { 'i', 'c' }, keys = '<C-r>' },
      { mode =   'n',        keys = '<C-w>' },    -- Window commands
      { mode = { 'n', 'x' }, keys = 's' },        -- `s` key (mini.surround, etc.)
      { mode = { 'n', 'x' }, keys = 'z' },        -- `z` key
    },
  })
end)

-- Command line tweaks (`:h MiniCmdline`).
later(function() require('mini.cmdline').setup() end)

-- Comment lines (`:h MiniComment`).
later(function() require('mini.comment').setup() end)

-- `gq` reflows nested comments (`:h MiniMisc.use_nested_comments()`).
later(function()
  Config.new_autocmd(
    'BufEnter',
    nil,
    function(ev) require('mini.misc').use_nested_comments(ev.buf) end,
    'Reflow nested comments with gq'
  )
end)

-- Diff hunks (`:h MiniDiff-overview`); 'lua/config/git/diffref.lua' attaches its own source.
later(function() require('mini.diff').setup() end)

-- Git integration (`:h MiniGit-examples`).
later(function() require('mini.git').setup() end)

-- Highlight patterns (`:h MiniHipatterns-examples`); markers in 'lua/config/markers.lua'.
later(function()
  local hipatterns = require('mini.hipatterns')
  local hi_words = MiniExtra.gen_highlighter.words
  local words = require('config.markers').words
  hipatterns.setup({
    highlighters = {
      fixme = hi_words(words.fixme, 'MiniHipatternsFixme'),
      hack = hi_words(words.hack, 'MiniHipatternsHack'),
      todo = hi_words(words.todo, 'MiniHipatternsTodo'),
      note = hi_words(words.note, 'MiniHipatternsNote'),

      hex_color = hipatterns.gen_highlighter.hex_color(),
    },
  })
end)

-- Indent scope (`:h MiniIndentscope`).
later(function() require('mini.indentscope').setup() end)

-- Input prompts (`:h MiniInput-examples`).
later(function() require('mini.input').setup() end)

-- Smarter `fFtT` (`:h MiniJump`).
later(function() require('mini.jump').setup() end)

-- Jump to labelled spots (`:h MiniJump2d`).
later(function() require('mini.jump2d').setup() end)

-- Multistep and combo mappings (`:h MiniKeymap-examples`).
later(function()
  require('mini.keymap').setup()
  -- NOTE: in a snippet session <Tab> jumps instead of inserting a tab; <C-v><Tab> still does.
  MiniKeymap.map_multistep('i', '<Tab>', { 'minisnippets_next', 'pmenu_next' })
  MiniKeymap.map_multistep('i', '<S-Tab>', { 'minisnippets_prev', 'pmenu_prev' })
  MiniKeymap.map_multistep('i', '<CR>', { 'pmenu_accept', 'minipairs_cr' })
end)

-- Text overview window (`:h MiniMap`).
later(function()
  local map = require('mini.map')
  map.setup({
    symbols = { encode = map.gen_encode_symbols.dot('4x2') },
    integrations = {
      map.gen_integration.builtin_search(),
      map.gen_integration.diff(),
      map.gen_integration.diagnostic(),
    },
  })
end)

-- Move lines and selections (`:h MiniMove`).
later(function() require('mini.move').setup() end)

-- Text edit operators (`:h MiniOperators-overview`).
later(function()
  require('mini.operators').setup()

  -- Replace with the system clipboard: `gr`, `grr` (its `gr_` goes through the new `gr`) and
  -- Visual `gr`. The register is read when the operator starts, so `"+` goes before it.
  vim.keymap.set(
    'n',
    '<Plug>(ClipboardReplace)',
    'v:lua.MiniOperators.replace()',
    { expr = true, replace_keycodes = false }
  )
  vim.keymap.set(
    'n',
    'gr',
    '"+<Plug>(ClipboardReplace)',
    { remap = true, desc = 'Replace with clipboard' }
  )
  vim.keymap.set(
    'x',
    'gr',
    '"+<Cmd>lua MiniOperators.replace("visual")<CR>',
    { desc = 'Replace selection with clipboard' }
  )
end)

-- Autopairs (`:h MiniPairs`); Insert mode only, prose is skipped in 'after/ftplugin/markdown.lua'.
later(function() require('mini.pairs').setup() end)

-- Picker (`:h MiniPick-overview`); mappings in 'plugin/20_keymaps.lua'.
later(
  function()
    require('mini.pick').setup({ source = { show = require('config.pick').show } })
  end
)

-- Snippets (`:h MiniSnippets-overview`); sources: 'snippets/', 'after/snippets/', 'friendly-snippets'.
later(function()
  local latex_patterns = { 'latex/**/*.json', '**/latex.json' }
  local lang_patterns = {
    tex = latex_patterns,
    plaintex = latex_patterns,
    markdown_inline = { 'markdown.json' },
  }

  local snippets = require('mini.snippets')
  local config_path = vim.fn.stdpath('config')
  snippets.setup({
    snippets = {
      snippets.gen_loader.from_file(config_path .. '/snippets/global.json'),
      snippets.gen_loader.from_lang({ lang_patterns = lang_patterns }),
    },
  })
end)

-- Split and join arguments (`:h MiniSplitjoin`).
later(function() require('mini.splitjoin').setup() end)

-- Surround actions (`:h MiniSurround-builtin-surroundings`).
later(function() require('mini.surround').setup() end)

-- Trailing whitespace (`:h MiniTrailspace`).
later(function() require('mini.trailspace').setup() end)

-- File visits and labels (`:h MiniVisits-overview`).
later(function() require('mini.visits').setup() end)
