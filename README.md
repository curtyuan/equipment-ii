# ii

![ii icon](doc/asset/ii-icon2.png)

`ii` is a Zsh plugin for tmux-scoped variables, payload rendering, clipboard
work, and multi-pane combo workflows.

## Runtime ownership

- Zsh owns every public command, current-shell mutation, ordinary payload,
  help route, clipboard decision, and tmux integration setup.
- tmux is the persistent, session-wide store for `ii_*` variables.
- Go is an internal helper for opted-in `# flow: 1` combo workflows. The
  existing tmux input popup also remains in Go until its separate migration.

Sourcing the plugin and running ordinary commands do not start Go. Zsh selects
and confirms a combo before launching one `ii-go __combo-*` process. There is
no daemon, shell-state file, parent-shell operation file, or Go public-command
fallback.

## Build and test

```zsh
make build
make test
```

`make` writes a deployment package to `export/ii`. The bundled payload data is
temporarily read from `ori-ii/payloads`; moving it to the root package and
retiring the remaining frozen baseline are tracked in
[`doc/todo/runtime-migration.md`](doc/todo/runtime-migration.md).

## Source layout

- `ii.plugin.zsh`, `lib/`, and `help/`: live Zsh public runtime.
- `src/`: Go combo workflow helper and temporary tmux popup helper.
- `test/contract/`: public Zsh and combo boundary contracts.
- `ori-ii/`: frozen pre-migration reference and temporary payload source.

Do not add features to `ori-ii/`.
