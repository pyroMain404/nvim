-- Some Sass rimpiazza cssls anche per il CSS puro: il default nvim-lspconfig
-- registra solo { "scss", "sass" }, qui aggiungiamo "css" così i file .css
-- ottengono completion/hover/diagnostica/colori (feature set allineato a
-- vscode-css-language-server) più la navigazione workspace-wide di Some Sass.
-- less resta scoperto: Some Sass non lo gestisce (vedi lsp_servers.lua).
return {
  filetypes = { "scss", "sass", "css" },
}
