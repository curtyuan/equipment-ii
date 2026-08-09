# Architecture

## Ownership chain

```text
user
  -> Zsh `ii` function
     -> public commands and ordinary payloads in the current shell
     -> tmux `ii_*` environment for shared session state
     -> one Go process only for a selected combo workflow
```

Zsh owns public parsing, help/version, variables, clipboard policy, ordinary
payload selection/render/copy/execute, and tmux alias setup/status. It can
directly update the caller's variables, cwd, and functions, so no child-process
state transport or returned operation plan is required.

Tmux is the uncached source of truth shared by panes. `ii s` writes tmux and the
calling shell; interactive add/edit uses the same path. `ii g` reads tmux,
`ii l` explicitly hydrates one shell, and `ii la` reviews and dispatches loads
to selected panes. There is no prompt sync or daemon.

Go owns combo document validation/rendering, lane selection and remembered
assignment, ordered stage confirmation, pane identity validation, and literal
tmux transport. Combo rendering reads tmux state only. Zsh resolves the
clipboard backend and passes a closed value to Go.

The tmux `:ii` input popup invokes the packaged Zsh popup helper and does not
start the Go binary.

## Invocation contracts

Ordinary commands remain in the sourcing Zsh process and never invoke Go. A
stored payload enters Go only after Zsh selects it and verifies the exact
`# flow: 1` marker:

```text
render combo -> ii-go __combo-render PATH
copy combo   -> ii-go __combo-copy PATH CLIPBOARD
run combo    -> ii-go __combo-run PATH ORIGIN SESSION COPY CLIPBOARD
```

For execution, Zsh validates the relative path, asks for confirmation, resolves
the clipboard backend, snapshots the tmux session/pane identity, and opens one
popup. Go revalidates the catalog path and workflow marker before acting. No
shell-state, parent-shell operations, or execution-file protocol exists.

The Go binary rejects public commands and unknown internal commands.

## Source layout

```text
ii.plugin.zsh                   Zsh composition and configuration
lib/ordinary_runtime.zsh       public command specification and dispatch
lib/ordinary_variables.zsh     set/import/load/unset mutations
lib/ordinary_read.zsh          list and output
lib/ordinary_get.zsh           get and copy
lib/ordinary_interactive.zsh   interactive variable actions
lib/ordinary_clipboard.zsh     one clipboard policy
lib/ordinary_payload*.zsh      catalog, rendering, input, combo handoff
lib/ordinary_tmux.zsh          alias installation and status
lib/ordinary_help.zsh          static help routing
help/                           public help contracts
src/cmd/ii/main.go             Go helper composition root
src/internal/payload/          renderer and combo workflow domain
src/internal/terminal/         popup input and workflow interaction
src/internal/adapter/tmux/     tmux state, panes, memory, literal transport
src/internal/adapter/clipboard combo stage copy transport
src/internal/adapter/filesystem combo payload catalog boundary
test/contract/                 public/runtime architecture contracts
payloads/                      bundled payload data
```

Generated binaries and packages live under `build/` and `export/`.

## State and rendering

Ordinary rendering resolves a lowercase token from the current shell first,
then tmux. Combo rendering intentionally resolves from tmux only so a workflow
has one reproducible session-wide state view. Both implementations consume the
same repository-owned token fixture.

Payload text sent to panes is loaded through a tmux buffer and pasted
literally; it is not embedded in a shell command or `send-keys` argument. Pane
and session identity are checked again immediately before transport.

## Maintained boundaries

- `ii p -w file|ln|ls|search` and the `:ii` popup are Zsh-owned.
- Payload data and packaging use the root `payloads` directory.
- Public command results are checked against reviewed repository fixtures;
  tests never execute an older runtime to generate expected output.
- Go remains strictly scoped to selected combo workflows.
