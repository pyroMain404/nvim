-- ┌───────────────────────┐
-- │ LSP client behaviour  │
-- └───────────────────────┘
--
-- Client-side fixes for no single server; switched on by `setup()` in 'plugin/50_features.lua'.

local M = {}

-- HACK: on Windows `vim.lsp.util.rename()` splits the backslashed `fs_realpath()`
-- on `/`, so the renamed buffer keeps its old name and is written back at the old
-- path. Rename it with `:saveas!` without autocommands (the write would run the
-- 'obsidian.nvim' front matter hook mid-rename). Still present in Neovim 0.12.5.
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

-- HACK: 'nvim-lspconfig' announces `rust-analyzer.showReferences` but registers
-- only `runSingle`, so reference lenses end in "does not support command". Show
-- the locations client-side. Still missing in 'nvim-lspconfig' ac9d2f7 (2026-09-10).
local add_show_references = function()
  vim.lsp.commands['rust-analyzer.showReferences'] = function(command, ctx)
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
  vim.lsp.codelens.enable(true)
end

return M
