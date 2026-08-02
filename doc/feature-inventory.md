# Feature Inventory

| Feature family | Live owner | Status / remaining work |
| --- | --- | --- |
| Bootstrap, configuration, public dispatch | Zsh | Complete; sourcing and ordinary commands do not start Go |
| Help and version | Zsh static help | Complete |
| Set/get/list/load/unset/output | Zsh + tmux state | Complete |
| Interactive variables | Zsh + fzf + tmux | Complete; add/edit also update the caller |
| Clipboard policy | Zsh | Complete; a closed backend is handed to combo Go |
| Ordinary stored payloads | Zsh | Complete |
| Pasted payload input | Zsh | Complete |
| Combo workflows | Go payload/terminal/tmux packages | Complete ownership boundary; final integration validation remains |
| Tmux alias setup/status | Zsh | Complete |
| Tmux `:ii` input popup | Go internal helper | Temporary; migrate to Zsh |
| `p -w` web helpers | Zsh target | Not implemented; old spellings diagnose migration only |
| Payload data/package | `ori-ii/payloads` temporarily | Move to root and remove frozen baseline |

Go has no public dispatcher and rejects public command names. Its accepted
runtime entries are `__combo-render`, `__combo-copy`, `__combo-run`, and the
temporary `__tmux_popup` input helper. Shell-state and parent-shell operation
protocols and their superseded tests have been removed.

Detailed ordering and unresolved decisions are tracked in
[`todo/runtime-migration.md`](todo/runtime-migration.md).
