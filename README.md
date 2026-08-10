# ii

![ii icon](doc/asset/ii-icon2.png)

`ii` is a Zsh plugin for tmux-scoped variables, payload rendering, clipboard
work, and multi-pane combo workflows.

## Runtime ownership

- Zsh owns every public command, current-shell mutation, ordinary payload,
  help route, clipboard decision, and tmux integration setup.
- tmux is the persistent, session-wide store for `ii_*` variables.
- Go is an internal helper only for opted-in `# flow: 1` combo workflows. The
  tmux input popup is implemented by the packaged Zsh helper.

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
read from the root `payloads` directory.

## Source layout

- `ii.plugin.zsh`, `lib/`, and `help/`: live Zsh public runtime.
- `src/`: Go combo workflow helper.
- `test/contract/`: public Zsh and combo boundary contracts.
- `payloads/`: bundled payload library.
