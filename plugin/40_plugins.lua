-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file installs and configures plugins outside MINI, mostly for specific languages.

local add = vim.pack.add
local now_if_args, later = Config.now_if_args, Config.later

-- Report once when `add()` leaves a plugin off 'runtimepath' after a failed install.
-- The caller then skips setup.
-- `module_name` identifies its `lua/<name>/` entry.
local plugin_missing = function(name, module_name)
  local module_path = 'lua/' .. module_name .. '/init.lua'
  if #vim.api.nvim_get_runtime_file(module_path, false) > 0 then return false end
  local message = name .. ' is unavailable; run :checkhealth config'
  vim.notify_once(message, vim.log.levels.ERROR)
  return true
end

-- Tree-sitter ================================================================

-- Use parsers and queries from 'nvim-treesitter' (`:h treesitter`).
-- NOTE: Building parsers needs third-party software; see README 'Requirements'.
-- Use `:checkhealth vim.treesitter nvim-treesitter` to find problems.
now_if_args(function()
  local ts_update = function() vim.cmd('TSUpdate') end
  Config.on_packchanged('nvim-treesitter', { 'update' }, ts_update, ':TSUpdate')

  add({
    'https://github.com/nvim-treesitter/nvim-treesitter',
    'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
  })

  -- 'lua/config/toolchain.lua' defines parsers. Restart once after changing them.
  local languages = require('config.toolchain').parsers()
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install) end

  local filetypes = {}
  for _, lang in ipairs(languages) do
    vim.list_extend(filetypes, vim.treesitter.language.get_filetypes(lang))
  end
  local ts_start = function(ev) vim.treesitter.start(ev.buf) end
  Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter')
end)

-- Language servers ===========================================================

-- 'nvim-lspconfig' supplies language server configurations (`:h vim.lsp`).
-- Use `:checkhealth vim.lsp` to find problems.
now_if_args(function()
  add({ 'https://github.com/neovim/nvim-lspconfig' })

  -- 'lua/config/toolchain.lua' lists servers; 'after/lsp/' configures them (`:h vim.lsp.enable()`).
  -- A missing server fails without a warning; the health check reports it.
  vim.lsp.enable(require('config.toolchain').servers())

  -- NOTE: `gf` on `preload('res://...')` opens a buffer that Neovim never reads from disk.
  -- Register `BufReadCmd` before any such buffer opens.
  -- 'includeexpr' cannot help because `findfile()` returns `scheme://` names unchanged.
  -- The handler needs `nested` for filetype detection, LSP attachment and ftplugin commands (`:h autocmd-nested`).
  vim.api.nvim_create_autocmd('BufReadCmd', {
    pattern = 'res://*',
    group = vim.api.nvim_create_augroup('config-godot-res', { clear = true }),
    desc = 'Resolve a res:// reference to the real file of its Godot project',
    nested = true,
    callback = function(args)
      local ghost = args.buf
      local previous = vim.fn.bufname('#')
      local root = (previous ~= '' and vim.fs.root(previous, { 'project.godot' }))
        or vim.fs.root(vim.fn.getcwd(), { 'project.godot' })
      if root == nil then
        return vim.notify(
          'res:// reference outside a Godot project: ' .. args.match,
          vim.log.levels.WARN
        )
      end
      vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. args.match:sub(#'res://' + 1)))
      if
        ghost ~= vim.api.nvim_get_current_buf() and vim.api.nvim_buf_is_valid(ghost)
      then
        vim.api.nvim_buf_delete(ghost, { force = true })
      end
    end,
  })

  -- NOTE: Go to definition on a JDK or jar class returns a `jdt://` URI.
  -- Neovim opens an empty buffer for this URI.
  -- The handler requests its text from jdtls and attaches jdtls to the buffer for hover and further navigation.
  -- Register the handler before opening the buffer, as with `res://` above.
  vim.api.nvim_create_autocmd('BufReadCmd', {
    pattern = 'jdt://*',
    group = vim.api.nvim_create_augroup('config-jdt-class', { clear = true }),
    desc = 'Read a jdt:// class file from jdtls',
    nested = true,
    callback = function(args)
      local client = vim.lsp.get_clients({ name = 'jdtls' })[1]
      local lines = client
        and require('config.lsp').class_file_lines(client, args.match)
      if lines == nil then
        return vim.notify(
          'jdtls has no source for ' .. args.match,
          vim.log.levels.WARN
        )
      end
      vim.bo[args.buf].buftype = 'nofile'
      vim.bo[args.buf].swapfile = false
      vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
      vim.bo[args.buf].modifiable = false
      vim.bo[args.buf].filetype = 'java'
      vim.lsp.buf_attach_client(args.buf, client.id)
    end,
  })
end)

-- Markdown rendering =========================================================

-- Set up 'render-markdown.nvim' (`:h render-markdown-setup`).
-- The ftplugin holds the state machine.
now_if_args(function()
  add({ 'https://github.com/MeanderingProgrammer/render-markdown.nvim' })

  if plugin_missing('render-markdown.nvim', 'render-markdown') then return end

  require('render-markdown').setup({
    -- Keep raw text by default; the ftplugin enables rendering for each state.
    enabled = false,
    -- Keep rendering in Visual modes so reading mode continues to conceal text (`:h mode()`).
    render_modes = { 'n', 'v', 'V', '\22', 'i', 'c', 't' },
    -- Do not reveal table borders on the cursor line because they cover the source.
    anti_conceal = { enabled = true, ignore = { table_border = true } },
    -- NOTE: Footnotes show as `(†name)` in plain letters.
    -- `prefix` keeps the dagger inside the parentheses; `icon` would put it outside.
    -- `[[#Heading]]` has no icon; 'after/ftplugin/markdown.lua' draws its `§`.
    link = {
      custom = { same_note = { pattern = '^#', icon = '' } },
      footnote = { superscript = false, icon = '', prefix = '(†', suffix = ')' },
    },
    on = {
      -- Apply conceal settings again here because the plugin resets `win_options` on every refresh.
      render = function(args)
        require('config.mdlink').anchor_footnotes(args.buf)
        local state = vim.b[args.buf].markdown_om
        if state and state ~= 'source' then
          for _, win in ipairs(vim.fn.getbufinfo(args.buf)[1].windows or {}) do
            vim.wo[win][0].conceallevel = 3
            vim.wo[win][0].concealcursor = state == 'reading' and 'nv' or ''
          end
        end
      end,
      clear = function(args)
        require('config.mdlink').clear_footnotes(args.buf)
        if vim.b[args.buf].markdown_om == 'source' then
          local original = vim.b[args.buf].markdown_om_original
          if original then
            for key, options in pairs(original.windows) do
              local win = tonumber(key)
              if vim.api.nvim_win_is_valid(win) then
                vim.wo[win][0].conceallevel = options.conceallevel
                vim.wo[win][0].concealcursor = options.concealcursor
              end
            end
          end
        end
      end,
    },
  })
end)

-- Obsidian vaults ============================================================

now_if_args(
  function()
    require('config.obsidian').setup({
      src = 'https://github.com/pyroMain404/obsidian.nvim',
      version = 'feat/frontmatter-sync-title',
    })
  end
)

-- Formatting =================================================================

-- Set formatters (`:h conform-options`, `:h conform-formatters`).
later(function()
  add({ 'https://github.com/stevearc/conform.nvim' })

  require('conform').setup({
    default_format_opts = {
      lsp_format = 'fallback',
    },
    -- 'lua/config/toolchain.lua' declares formatters for each language.
    formatters_by_ft = require('config.toolchain').formatters_by_ft(),
  })
end)

-- Snippets ===================================================================

-- Load the snippet collection for 'mini.snippets' (`:h MiniSnippets.gen_loader.from_lang()`).
later(function() add({ 'https://github.com/rafamadriz/friendly-snippets' }) end)

-- NOTE: See `:h terminal-debug` to enable Termdebug.

-- 'ayu-mirage' is active; 'plugin/30_mini.lua' contains alternative color schemes.
Config.now(function()
  add({
    'https://github.com/Shatur/neovim-ayu',
  })

  -- NOTE: Install a scheme before selecting it by name.
  -- A name that Neovim ships (`catppuccin`) loads the runtime copy without a warning.
  vim.cmd('color ayu-mirage')

  -- Link 'WinBar' to 'StatusLineNC' because the scheme makes its background almost black.
  vim.api.nvim_set_hl(0, 'WinBar', { link = 'StatusLineNC' })
  vim.api.nvim_set_hl(0, 'WinBarNC', { link = 'StatusLineNC' })

  -- Empty groups stop the scheme's fallback underline for bare `[text]`.
  -- 'after/queries/markdown_inline/highlights.scm' keeps `[label](url)` underlined.
  vim.api.nvim_set_hl(0, '@markup.link.label', { underline = false })
  vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { underline = false })
  vim.api.nvim_set_hl(0, '@markup.link.underlined', { link = 'Underlined' })

  -- Use a straight underline instead of undercurl (`:h highlight-undercurl`).
  for _, name in ipairs({
    'SpellBad',
    'SpellCap',
    'SpellLocal',
    'SpellRare',
    'DiagnosticUnderlineError',
    'DiagnosticUnderlineWarn',
    'DiagnosticUnderlineInfo',
    'DiagnosticUnderlineHint',
    'MiniJump',
  }) do
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    vim.api.nvim_set_hl(0, name, { underline = true, sp = hl.sp })
  end
end)
