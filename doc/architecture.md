# Architecture

`ii` is distributed as a Zsh plugin with a bundled Go helper. The public
product entrypoint is `ii.plugin.zsh`; `ii-go` is an internal implementation
detail for opted-in combo workflows and is not a standalone public CLI.

## Platform boundary

The runtime and release package support Linux amd64 only. `make build` always
cross-builds a static Linux amd64 `ii-go`, even when invoked from another host.
No runtime fallback or package variant is maintained for another operating
system or architecture.

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

## Source-language boundary

Both runtime implementations live below `src/`, separated as `src/zsh/` and
`src/go/`. This is a source-layout boundary, not a change in runtime ownership:
moving Zsh parsing into the Go process would change when tmux state is read,
validated, and updated, and a child process cannot directly mutate the calling
shell's variables, working directory, or functions. Keeping the public parser
and ordinary command sequence in Zsh preserves those ordering and
current-shell guarantees. Go remains an isolated helper entered only after Zsh
has selected and validated an opted-in combo workflow.

`II_ROOT` continues to identify the project or installed package root, where
`help/`, `payloads/`, and `ii-go` live. In the repository, `II_ZSH_ROOT`
identifies `src/zsh/`; the packaged layout is flattened, so both roots identify
the package root. The distinction lets the source tree stay language-oriented
without exposing that development layout in the deployment package.

## Source layout

```text
src/zsh/ii.plugin.zsh                 Zsh composition and configuration
src/zsh/lib/ordinary_runtime.zsh      public command specification and dispatch
src/zsh/lib/ordinary_variables.zsh    set/import/load/unset mutations
src/zsh/lib/ordinary_read.zsh         list and output
src/zsh/lib/ordinary_get.zsh          get and copy
src/zsh/lib/ordinary_interactive.zsh  interactive variable actions
src/zsh/lib/ordinary_clipboard.zsh    one clipboard policy
src/zsh/lib/ordinary_payload*.zsh     catalog, rendering, input, combo handoff
src/zsh/lib/ordinary_tmux.zsh         alias installation and status
src/zsh/lib/ordinary_help.zsh         static help routing
src/zsh/script/ii-tmux-popup          tmux popup entrypoint
src/go/cmd/ii/main.go                 Go helper composition root
src/go/internal/payload/              renderer and combo workflow domain
src/go/internal/terminal/             popup input and workflow interaction
src/go/internal/adapter/tmux/         tmux state, panes, memory, literal transport
src/go/internal/adapter/clipboard combo stage copy transport
src/go/internal/adapter/filesystem combo payload catalog boundary
help/                                  public help contracts
test/contract/                         public/runtime architecture contracts
payloads/                              bundled payload data
```

Generated binaries and packages live under `build/` and `export/`. The single
deployment unit is `export/ii`; architecture-specific export trees are not
maintained.

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
- Linux amd64 is the sole supported deployment platform.
