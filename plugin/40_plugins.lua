-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- Installation and configuration of plugins outside of MINI, mostly language specific.

local add = vim.pack.add
local now_if_args, later = Config.now_if_args, Config.later

-- Reports once a plugin that `add()` left off 'runtimepath' (failed install), so the
-- caller skips its setup. `module_name` is its `lua/<name>/` entry.
local plugin_missing = function(name, module_name)
  local module_path = 'lua/' .. module_name .. '/init.lua'
  if #vim.api.nvim_get_runtime_file(module_path, false) > 0 then return false end
  local message = name .. ' is unavailable; run :checkhealth config'
  vim.notify_once(message, vim.log.levels.ERROR)
  return true
end

-- Tree-sitter ================================================================

-- Tree-sitter (`:h treesitter`): parsers and queries from 'nvim-treesitter'.
-- NOTE: building parsers needs third party software, see README 'Requirements'.
-- Troubleshooting: `:checkhealth vim.treesitter nvim-treesitter`.
now_if_args(function()
  local ts_update = function() vim.cmd('TSUpdate') end
  Config.on_packchanged('nvim-treesitter', { 'update' }, ts_update, ':TSUpdate')

  add({
    'https://github.com/nvim-treesitter/nvim-treesitter',
    'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
  })

  -- Parsers: 'lua/config/toolchain.lua'; restart once after changing them.
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

-- Language servers (`:h vim.lsp`): 'nvim-lspconfig' supplies the configurations.
-- Troubleshooting: `:checkhealth vim.lsp`.
now_if_args(function()
  add({ 'https://github.com/neovim/nvim-lspconfig' })

  -- Servers: 'lua/config/toolchain.lua', configured in 'after/lsp/' (`:h vim.lsp.enable()`).
  -- One that is not installed fails silently; the health check reports it.
  vim.lsp.enable(require('config.toolchain').servers())

  -- NOTE: `gf` on `preload('res://...')` leaves a buffer never read from disk, so a
  -- `BufReadCmd` must exist before any is opened; 'includeexpr' can not do it because
  -- `findfile()` returns `scheme://` names unchanged. `nested` is required or the
  -- buffer gets no filetype, LSP attach or ftplugin commands (`:h autocmd-nested`).
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
end)

-- Markdown rendering =========================================================

-- 'render-markdown.nvim' (`:h render-markdown-setup`); the state machine lives in the ftplugin.
now_if_args(function()
  add({ 'https://github.com/MeanderingProgrammer/render-markdown.nvim' })

  if plugin_missing('render-markdown.nvim', 'render-markdown') then return end

  require('render-markdown').setup({
    -- Raw by default; the ftplugin enables rendering per state.
    enabled = false,
    -- Keep rendering in Visual modes so reading mode stays concealed (`:h mode()`).
    render_modes = { 'n', 'v', 'V', '\22', 'i', 'c', 't' },
    -- Table borders are drawn over the source: do not reveal them on the cursor line.
    anti_conceal = { enabled = true, ignore = { table_border = true } },
    -- NOTE: footnotes show as `(†name)` in plain letters; the dagger is in `prefix`,
    -- `icon` would land outside the parenthesis. `[[#Heading]]` gets no icon, its `§` is
    -- drawn in 'after/ftplugin/markdown.lua'.
    link = {
      custom = { same_note = { pattern = '^#', icon = '' } },
      footnote = { superscript = false, icon = '', prefix = '(†', suffix = ')' },
    },
    on = {
      -- The plugin resets `win_options` on every refresh: reapply conceal settings here.
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

-- Formatters (`:h conform-options`, `:h conform-formatters`).
later(function()
  add({ 'https://github.com/stevearc/conform.nvim' })

  require('conform').setup({
    default_format_opts = {
      lsp_format = 'fallback',
    },
    -- Declared per language in 'lua/config/toolchain.lua'
    formatters_by_ft = require('config.toolchain').formatters_by_ft(),
  })
end)

-- Snippets ===================================================================

-- Snippet collection for 'mini.snippets' (`:h MiniSnippets.gen_loader.from_lang()`).
later(function() add({ 'https://github.com/rafamadriz/friendly-snippets' }) end)

-- NOTE: see `:h terminal-debug` to enable Termdebug.

-- Color schemes: 'ayu-mirage' is active; the alternatives are in 'plugin/30_mini.lua'.
Config.now(function()
  add({
    'https://github.com/Shatur/neovim-ayu',
  })

  -- NOTE: install a scheme before selecting it by name; a name Neovim ships
  -- (`catppuccin`) silently loads the runtime copy.
  vim.cmd('color ayu-mirage')

  -- The scheme's 'WinBar' background is near black; link it to 'StatusLineNC'.
  vim.api.nvim_set_hl(0, 'WinBar', { link = 'StatusLineNC' })
  vim.api.nvim_set_hl(0, 'WinBarNC', { link = 'StatusLineNC' })

  -- Empty groups end the scheme's underline fallback for bare `[text]`;
  -- 'after/queries/markdown_inline/highlights.scm' keeps `[label](url)` underlined.
  vim.api.nvim_set_hl(0, '@markup.link.label', { underline = false })
  vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { underline = false })
  vim.api.nvim_set_hl(0, '@markup.link.underlined', { link = 'Underlined' })

  -- Straight underline instead of undercurl (`:h highlight-undercurl`).
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
