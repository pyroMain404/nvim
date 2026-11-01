-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local add = vim.pack.add
local now_if_args, later = Config.now_if_args, Config.later

-- Whether a plugin that `add()` was just asked for is missing from
-- 'runtimepath' anyway - an install that failed leaves it off disk, and
-- `require()` would then abort the rest of this file. Report once and let the
-- caller skip that plugin's setup. `module_name` is its `lua/<name>/` entry.
local plugin_missing = function(name, module_name)
  local module_path = 'lua/' .. module_name .. '/init.lua'
  if #vim.api.nvim_get_runtime_file(module_path, false) > 0 then return false end
  local message = name .. ' is unavailable; run :checkhealth config'
  vim.notify_once(message, vim.log.levels.ERROR)
  return true
end

-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
--   NOTE: It requires third party software to build and install parsers.
--   See the link for more info in "Requirements" section of this repo's README.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.treesitter nvim-treesitter` to see potential issues.
-- - In case of errors related to queries for Neovim bundled parsers (like `lua`,
--   `vimdoc`, `markdown`, etc.), manually install them via 'nvim-treesitter'
--   with `:TSInstall <language>`. Be sure to have necessary system dependencies
--   (see README's "Requirements" section for software dependencies).
now_if_args(function()
  -- Define hook to update tree-sitter parsers after plugin is updated
  local ts_update = function() vim.cmd('TSUpdate') end
  Config.on_packchanged('nvim-treesitter', { 'update' }, ts_update, ':TSUpdate')

  add({
    'https://github.com/nvim-treesitter/nvim-treesitter',
    'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
  })

  -- Parsers are declared in 'lua/config/toolchain.lua'. After changing them,
  -- restart Neovim once and wait for the install before opening such a file.
  local languages = require('config.toolchain').parsers()
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install) end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    vim.list_extend(filetypes, vim.treesitter.language.get_filetypes(lang))
  end
  local ts_start = function(ev) vim.treesitter.start(ev.buf) end
  Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter')
end)

-- Language servers ===========================================================

-- Language Server Protocol (LSP) is a set of conventions that power creation of
-- language specific tools. It requires two parts:
-- - Server - program that performs language specific computations.
-- - Client - program that asks server for computations and shows results.
--
-- Here Neovim itself is a client (see `:h vim.lsp`). Language servers need to
-- be installed separately based on your OS, CLI tools, and preferences.
-- See note about 'mason.nvim' at the bottom of the file.
--
-- Neovim's team collects commonly used configurations for most language servers
-- inside 'neovim/nvim-lspconfig' plugin.
--
-- Add it now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.lsp` to see potential issues.
now_if_args(function()
  add({ 'https://github.com/neovim/nvim-lspconfig' })

  -- Servers are declared in 'lua/config/toolchain.lua' and configured in 'after/lsp/'.
  -- Enabling one that is not installed fails silently: the health check reports it.
  -- See `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
  vim.lsp.enable(require('config.toolchain').servers())

  -- `res://` is Godot's own scheme for "relative to this project", and it is
  -- exactly what `gf` on a `preload('res://...')` leaves as a buffer name: a
  -- buffer named "res://scripts/x.gd" that was never read from disk. This is
  -- the same shape as `jdt://` for a Java class without source
  -- (`capabilities.md` "Navigazione della codebase"), and the fix is the same one: a `BufReadCmd` on
  -- the scheme, registered here because it has to exist before ANY such
  -- buffer is opened - a `.gd` ftplugin would always be one file late.
  --
  -- NOTE: 'includeexpr' does NOT do this job, and the reason is Vim's own,
  -- not GDScript's: `findfile('res://x')` returns the string UNCHANGED, as
  -- if found, instead of empty (measured against a name with no possible
  -- match, which correctly returns ''). Vim treats anything containing
  -- "://" as URL-like and never asks the filesystem, so 'includeexpr' -
  -- which `:h 'includeexpr'` documents as firing for `gf` only when the
  -- name "can't be found" - is never reached. Any `scheme://` reference in
  -- any language hits this same wall; see 'after/ftplugin/gdscript.lua' for
  -- where 'isfname' and 'include' still pull their own weight around it.
  -- NOTE: `nested` is what makes the redirect produce an ordinary buffer, and
  -- without it the failure is silent. Autocommands do not trigger each other
  -- by default (`:h autocmd-nested`), so the `:edit` below would run with
  -- autocommands blocked: the resolved buffer gets its text and nothing else.
  -- Measured in an isolated Neovim: `filetype` stays empty, and neither
  -- `BufReadPost` nor `FileType` fires - which costs the highlighting, the
  -- LSP attach and every `.gd` ftplugin command (`:make`, `:Run`, `:GodotDoc`)
  -- at once, leaving a buffer that looks like a file and acts like a scratch.
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

-- 'render-markdown.nvim' supplies the rendered Markdown view that MINI does
-- not provide. It is configured here, while the state machine belongs in the
-- filetype plugin (`:h ftplugin-overview`, `:h b:undo_ftplugin`).
now_if_args(function()
  add({ 'https://github.com/MeanderingProgrammer/render-markdown.nvim' })

  if plugin_missing('render-markdown.nvim', 'render-markdown') then return end

  require('render-markdown').setup({
    -- Keep the raw state as the buffer-local starting point; the ftplugin
    -- enables rendering explicitly for the live and reading states.
    enabled = false,
    -- Render in Normal, Visual, Insert, command-line and terminal modes
    -- (`:h mode()`).
    -- Keep rendering active in Visual modes so reading mode remains concealed
    -- while a selection is made (`:h visual-mode`, `:h mode()`).
    render_modes = { 'n', 'v', 'V', '\22', 'i', 'c', 't' },
    -- Table pipes and the delimiter row are drawn over the source, so hiding
    -- them on the cursor line would show the raw row (`:h render-markdown-setup`).
    anti_conceal = { enabled = true, ignore = { table_border = true } },
    -- A footnote `[^name]` is drawn as `(†name)` in plain letters. A superscript
    -- name is made of tiny Unicode glyphs that the terminal draws in a whole
    -- cell each, which looks small and widely spaced; plain letters also work
    -- for every name. The dagger is in `prefix`, not `icon`, because the plugin
    -- puts the icon before the prefix and it would land outside the
    -- parenthesis (`:h render-markdown-setup`, `link.footnote`).
    -- A link to a heading of the same note, `[[#Heading]]`, names no note, so it
    -- gets no icon and reads `§Heading`: the `§` over its `#` is drawn by a
    -- 'mini.hipatterns' highlighter in 'after/ftplugin/markdown.lua'. `custom`
    -- picks the icon from the destination (`link.custom`).
    link = {
      custom = { same_note = { pattern = '^#', icon = '' } },
      footnote = { superscript = false, icon = '', prefix = '(†', suffix = ')' },
    },
    on = {
      -- The plugin reapplies `win_options` on every refresh. Reapply the
      -- state-specific conceal settings from this documented post-render hook
      -- (`:h render-markdown-setup`) rather than relying on a one-time change.
      render = function(args)
        require('config.mdlink').anchor_footnotes(args.buf)
        local state = vim.b[args.buf].markdown_om
        if state and state ~= 'source' then
          for _, win in ipairs(vim.fn.getbufinfo(args.buf)[1].windows or {}) do
            -- Both rendered modes keep syntax concealed; live relies on an
            -- empty `concealcursor` to reveal source only at cursor/selection.
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

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
later(function()
  add({ 'https://github.com/stevearc/conform.nvim' })

  -- See also:
  -- - `:h Conform`
  -- - `:h conform-options`
  -- - `:h conform-formatters`
  require('conform').setup({
    default_format_opts = {
      -- Allow formatting from LSP server if no dedicated formatter is available
      lsp_format = 'fallback',
    },
    -- Declared per language in 'lua/config/toolchain.lua'
    formatters_by_ft = require('config.toolchain').formatters_by_ft(),
  })
end)

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
later(function() add({ 'https://github.com/rafamadriz/friendly-snippets' }) end)

-- Honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:
-- now_if_args(function()
--   add({ 'https://github.com/mason-org/mason.nvim' })
--   require('mason').setup()
-- end)

-- NOTE: see `:h terminal-debug` to enable Termdebug.

-- Beautiful, usable, well maintained color schemes outside of 'mini.nvim' and
-- have full support of its highlight groups. Use if you don't like the
-- disabled 'miniwinter' alternative in 'plugin/30_mini.lua' or other
-- suggested 'mini.hues' based ones.
Config.now(function()
  -- Install only those that you need
  add({
    'https://github.com/Shatur/neovim-ayu',
    -- 'https://github.com/catppuccin/nvim'
    -- 'https://github.com/sainnhe/everforest',
  })

  -- Enable only one. 'ayu-mirage' is the active scheme - one of the three
  -- variants 'Shatur/neovim-ayu' registers under `colors/` (the others are
  -- `ayu-dark`/`ayu-light`; `ayu` alone follows `:h 'background'` instead of
  -- naming one). The names above are alternatives that must be installed
  -- first: picking a scheme by a name Neovim happens to ship - `catppuccin`
  -- is one - silently loads the runtime copy instead.
  vim.cmd('color ayu-mirage')

  -- ayu-mirage's own 'WinBar'/'WinBarNC' background is nearly black
  -- (`#07080d`), almost indistinguishable from an empty bar. 'Title' (tried
  -- first) gave a bright, saturated foreground with no background of its
  -- own - too close in tone to the syntax highlighting of the code below it
  -- and too strong for a line that is only ever chrome. 'StatusLineNC' gives
  -- the breadcrumb its own muted background, distinct from 'Normal' without
  -- competing with it (`:h highlight-groups`).
  vim.api.nvim_set_hl(0, 'WinBar', { link = 'StatusLineNC' })
  vim.api.nvim_set_hl(0, 'WinBarNC', { link = 'StatusLineNC' })

  -- The scheme underlines every `@markup.link*` through 'Underlined', so a bare
  -- `[text]` too. Empty groups end that fallback (Markdown-only, so help
  -- `|tags|` and URLs stay underlined); 'after/queries/markdown_inline/
  -- highlights.scm' gives `[label](url)` and `[[note]]` a group linked to
  -- 'Underlined', as `@markup.underline` lacks its `sp`.
  vim.api.nvim_set_hl(0, '@markup.link.label', { underline = false })
  vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { underline = false })
  vim.api.nvim_set_hl(0, '@markup.link.underlined', { link = 'Underlined' })

  -- The scheme draws spelling, diagnostics and 'mini.jump' targets with
  -- `undercurl`, which looks broken up on one word; keep each group's `sp` and
  -- underline straight (`:h highlight-undercurl`).
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
