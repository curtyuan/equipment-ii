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
| Tmux `:ii` input popup | Zsh packaged helper | Complete |
| `p -w` web helpers | Zsh | Complete; removed `--www`/`www` options are rejected |
| Payload data/package | root `payloads` | Complete |

Go has no public dispatcher and rejects public command names. Its accepted
runtime entries are `__combo-render`, `__combo-copy`, and `__combo-run`. The
popup input helper is Zsh-owned. Shell-state and parent-shell operation
protocols and their superseded tests have been removed.

The runtime ownership migration is complete. Payload-specific field validation
continues as normal operator testing and is not a runtime migration dependency.
