# Markdown

Markdown is already recognized by Neovim as the `markdown` filetype. This config
keeps ordinary editing in the runtime ftplugin and adds an opt-in rendered view;
opening a Markdown file remains source view.

## 1. Runtime and existing support

| Capability | Provider | Detail |
|---|---|---|
| Filetype and editing defaults | Neovim runtime | The Markdown ftplugin supplies the ordinary editing behavior. |
| Syntax structure and folds | Tree-sitter | `markdown` is in `languages` in `plugin/40_plugins.lua`. |
| Markdown surroundings | `mini.surround` | `after/ftplugin/markdown.lua` adds the `L` link surrounding. |

Neither Neovim nor MINI renders Markdown as a document while retaining the source
buffer. `render-markdown.nvim` supplies the conceal and extmark rendering layer.

## 2. Renderer dependency

`MeanderingProgrammer/render-markdown.nvim` is declared in
`plugin/40_plugins.lua` through `vim.pack.add()`. It has no executable to install:
`vim.pack` fetches it and maintains `nvim-pack-lock.json`. In this config,
`vim.pack.add()` and the renderer setup run from `now_if_args()`: with a file
argument, setup completes before that file's ftplugins run; with no file argument,
setup remains deferred. A Markdown ftplugin therefore sees the managed directory
when opening a file from the command line, while startup without a file keeps the
deferred loading behavior.

`:checkhealth config` has a `config: Markdown` section. It reports a missing
renderer and also checks that the Markdown tree-sitter parser is installed.

## 3. Render modes

`<Leader>om` exists only in Markdown buffers and cycles:

| Mode | Renderer | Editing | Conceal behavior |
|---|---|---|---|
| `source` | Disabled for the current buffer | Original `modifiable` and `readonly` values restored | Original window conceal options restored |
| `live` | Enabled for the current buffer | Modifiable | Markup remains rendered except on the cursor line and Visual selection |
| `reading` | Enabled for the current buffer | `modifiable=false`, `readonly=true` | Markup stays concealed in Normal and Visual mode |

The renderer reapplies its window options during every refresh. Its documented
`on.render` hook reapplies the current buffer mode to every window showing that
buffer, which keeps split windows consistent after cursor movement. The ftplugin
captures each affected window's `conceallevel` and `concealcursor`, plus the
buffer's original editability, and restores them both on return to `source` and
through `b:undo_ftplugin`.

In `reading`, buffer-local `j` and `k` skip concealed non-table source lines,
including fenced-code delimiters, but visit every pipe-table source row. Other
modes preserve their ordinary motions.

## 4. Manual verification

Open any `.md` file and press `<Leader>om` three times. Confirm in order:

1. `live` renders headings, lists and other Markdown while source markup appears at
the cursor and over a Visual selection; insert text on that line.
2. `reading` rejects edits, keeps source markup concealed when moving the cursor
or making a Visual selection, makes `j`/`k` skip concealed non-table lines, and
visits every pipe-table source row.
3. The following `source` press restores the original unrendered view and the
buffer's original editability.

Repeat the live/reading transitions with the Markdown buffer visible in two splits;
both windows must retain the active mode after cursor movement.
