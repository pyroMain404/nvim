-- ┌───────────────────────┐
-- │ LSP client behaviour  │
-- └───────────────────────┘
--
-- Client side fixes and switches that belong to no single server. Which servers
-- run is declared in 'plugin/40_plugins.lua'; per-server settings are in
-- 'after/lsp/'. Switched on by `setup()` from 'plugin/50_features.lua'.

local M = {}

-- HACK: on Windows `vim.lsp.util.rename()` (LSP file renames, 'obsidian.nvim',
-- `:Obsidian rename`) looks for the buffers of the renamed file by splitting the
-- `fs_realpath()` result, which has backslashes, on `/`; no buffer matches, so it
-- keeps the old name and is written back at the old path. After the move, give
-- such a buffer the new name the way upstream does (`:saveas!`), without
-- autocommands: the write would run the front matter hook of 'obsidian.nvim' in
-- the middle of its rename. Files only. Still present in Neovim 0.12.5.
local patch_rename = function()
  local lsp_rename = vim.lsp.util.rename
  vim.lsp.util.rename = function(old_fname, new_fname, opts)
    lsp_rename(old_fname, new_fname, opts)
    if vim.uv.fs_stat(old_fname) or not vim.uv.fs_stat(new_fname) then return end
    local old_norm = vim.fs.normalize(old_fname)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if
        vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buftype == ''
        and vim.fs.normalize(name) == old_norm
      then
        vim.api.nvim_buf_call(
          buf,
          function()
            vim.cmd('noautocmd keepalt saveas! ' .. vim.fn.fnameescape(new_fname))
          end
        )
        vim.cmd('bdelete! ' .. vim.fn.bufnr(name))
      end
    end
  end
end

-- HACK: 'nvim-lspconfig' announces `rust-analyzer.showReferences` among the
-- commands the client implements and then registers only `runSingle`, so every
-- "N implementations" / "N references" lens ends in "Language server
-- `rust_analyzer` does not support command". The command is client-side by
-- design: the server hands over the locations, the editor decides how to show
-- them. Still missing in 'nvim-lspconfig' ac9d2f7 (2026-09-10).
local add_show_references = function()
  vim.lsp.commands['rust-analyzer.showReferences'] = function(command, ctx)
    -- Arguments are `{ uri, position, locations }`; only the third is needed.
    local locations = command.arguments and command.arguments[3] or {}
    local encoding = vim.lsp.get_client_by_id(ctx.client_id).offset_encoding
    if #locations == 0 then
      vim.notify(command.title, vim.log.levels.INFO)
    elseif #locations == 1 then
      vim.lsp.util.show_document(locations[1], encoding, { reuse_win = true })
    else
      local items = vim.lsp.util.locations_to_items(locations, encoding)
      vim.fn.setqflist({}, ' ', { title = command.title, items = items })
      vim.cmd('copen')
    end
  end
end

M.setup = function()
  patch_rename()
  add_show_references()
  -- Servers announce code lens at a precise place ("run this test"); Neovim asks
  -- for them only when told to. No filter covers every server and later buffer
  -- (`:h vim.lsp.codelens.enable()`).
  vim.lsp.codelens.enable(true)
end

return M
