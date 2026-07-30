# Architecture

This document describes the live Go-first runtime at repository root. The
complete pre-Go architecture is frozen separately in
[`ori-ii/doc/architecture.md`](../ori-ii/doc/architecture.md); it is a
compatibility reference, not the target layout.

## Runtime Boundary

`ii` remains a Zsh function because an executable cannot mutate its parent
shell. All command decisions and stateful behavior belong in Go; the root Zsh
file is limited to bootstrap, legacy selection during migration, filtered
shell-state capture, and application of allowlisted parent-shell operations.

```text
user
  -> ii.plugin.zsh
     -> ii-go __route ARGS
        -> Go-owned: ii-go ARGS
        -> legacy-owned: ii_legacy ARGS
```

Go-owned commands never fall back after an error. Legacy execution happens only
after the resolver explicitly returns `legacy`.

The Zsh adapter and Go runtime communicate through two per-invocation,
permission-restricted files:

- `ii-shell-state-v1`: filtered shell values required for rendering/import.
- `ii-shell-ops-v1`: `export`, `unset`, `chdir`, `sync-hook`, and
  `execute-file` records.

Both protocols are NUL-delimited and versioned. The execution file must be the
exact regular, non-symlink file pre-created for that invocation; protocol text
is never evaluated.

## Source Layout

```text
ii.plugin.zsh                    parent-shell adapter
src/
  cmd/ii/main.go                 composition root
  internal/
    cli/                         entrypoints, resolution, parsing, presentation
    variables/                   variable use cases
    payload/                     catalog, render, input render, workflow model
    terminal/                    Linux terminal input boundary
    port/                        capabilities required by use cases
    adapter/
      clipboard/                 clipboard backends
      filesystem/                payload and atomic file storage
      fzf/                       selection UI
      network/                   interface address detection
      shellops/                  parent-shell operation writer
      shellstate/                parent-shell state reader
      tmux/                      session, pane transport, alias integration
test/
  contract/                      public and isolated tmux contracts
ori-ii/                          immutable pre-Go baseline
```

Generated binaries and packages live under `build/` and `export/`; neither is
source.

## Entrypoints

`CLI.Run` has two explicit boundaries:

```text
Run
  -> runInternal   hidden adapter/runtime operations
  -> runPublic     public command handlers
```

Hidden operations currently are:

- `__route`
- `__payload_names`
- `__payload_render`
- `__payload_select`
- `__tmux_ensure`
- `__tmux_popup`

Public and hidden names must not share a handler. Hidden operations may support
the Zsh adapter or differential contracts, but they are not public API.

Every public decision starts with:

```go
resolution := Resolve(args)
```

`Resolution` contains both command ownership and the canonical handler name.
`__route` and public dispatch enter through that same resolver. Some historical
special cases still live in separate owner and canonical-command helpers;
folding them into one declarative command specification is tracked work. Until
then, aliases, nested help paths, and ownership changes require route tests
that prove both results remain aligned.

## Composition

`cmd/ii/main.go` is the only production composition root. It constructs real
adapters and passes a named `cli.Dependencies` value into the CLI. Positional
constructor injection is intentionally avoided so adding a capability does not
silently reorder unrelated dependencies.

The tmux command runner currently backs several capabilities:

- session environment
- pane enumeration and literal transport
- command-alias installation/status

They share one process runner today, but consumers depend on separate ports.
Splitting the concrete adapter into `Environment`, `PaneTransport`, and
`Integration` wrappers remains planned before workflow migration.

## Dependency Direction

The intended dependency direction is:

```text
cli -> use case/domain -> port <- adapter
```

Rules:

- Domain packages do not invoke external commands.
- Filesystem policy belongs in a domain/use case; filesystem effects belong in
  an adapter.
- CLI handlers parse arguments, call one use case, and format results.
- Parent-shell mutation is always expressed through `ShellOperations`.
- Tmux payload text is transported through a named buffer, not embedded in a
  shell or `send-keys` argument.
- Symlink/traversal decisions are explicit and tested at filesystem boundaries.

The `port` package is a migration convenience. New capabilities should remain
small and consumer-focused. Do not create one broad filesystem or tmux
interface merely to reduce constructor fields.

## Feature Packages

### Variables

`internal/variables` owns normalization-independent variable use cases:
listing, output, mutation, load, get, interactive mutation, and all-pane load.
Tmux storage, selection, clipboard, file output, and shell export are ports.

### Payload

`internal/payload` owns:

- catalog and category classification
- legacy document conversion
- placeholder parsing and rendering
- shell-over-tmux resolution
- shared input rendering
- selector orchestration
- workflow document parsing/model
- payload output-path compatibility during migration

`InputRenderer` is shared by the public pasted-input command and tmux popup so
their render precedence cannot drift.

Payload file selection and workflow execution are not fully migrated yet.

### Terminal

`internal/terminal` owns Linux terminal-mode transitions and the input key
contract: Enter, Alt-Enter, Esc, backspace, `:w`, `:q`, and streamed EOF. It
restores the original terminal mode on exit. Current release targets are Linux
amd64 and arm64.

### Tmux

The tmux adapters own process invocation and protocol details:

- session environment reads/writes
- pane snapshots and identity checks
- literal buffer transport
- native `command-alias[]` installation
- ownership markers and conflict notices

The native alias invokes `ii-go __tmux_popup execute`; it does not rebind
`Prefix + :`.

## `/www` Target Boundary

The old implementation combined `/www` command parsing, rendering, filesystem
walking, fzf selection, symlink creation, path analysis, and terminal output in
`lib/www.zsh`. That shape must not be reproduced in one Go handler.

The target split is:

```text
internal/www/
  path.go          root-relative path and analysis policy
  service.go       list, search result, and link use cases
  file.go          render-and-link orchestration

internal/port/
  web_store.go     root inspection, walk, mkdir, symlink

internal/adapter/filesystem/
  web_store.go     no-follow filesystem implementation

internal/cli/
  www.go           argument parsing and presentation only
  www_help.go      direct and nested help
```

Required policy:

- Default root is `/www`; `II_WWW_ROOT` may override it.
- All managed destinations stay beneath the configured root.
- Existing targets are never overwritten.
- Link names cannot be empty, `.`, `..`, or contain separators.
- Directory walking does not follow symlink targets.
- `--file` renders the source but links the original absolute file into `p/`.
- Search/list ordering is deterministic.
- Selection remains behind the existing selector capability or a narrower web
  selector port.

`payload.OutputPath` currently retains legacy `/www` defaults for `-o`; moving
that policy into the web/path package is a separate compatibility step and must
not change public output paths.

## Legacy Comparison

The frozen Zsh architecture organized code primarily by sourced files and load
order. The Go target instead organizes by use case and capability:

| Legacy shape | Go target |
| --- | --- |
| Source order establishes dependencies | Constructor wiring establishes dependencies |
| Global functions and dynamically scoped variables | Explicit values and interfaces |
| `lib/core.zsh` dispatch plus help registry | One resolver returning owner and canonical command |
| `lib/www.zsh` owns every layer | www domain + filesystem port + CLI presenter |
| `eval` for confirmed current-shell execution | Allowlisted execution-file operation |
| Shared global render state | `RenderResult` values |
| tmux commands called throughout libraries | tmux adapters behind focused ports |

Compatibility concerns remain authoritative even when the implementation shape
changes. The baseline determines accepted routes, aliases, output streams,
status codes, cancellation behavior, and durable side effects.

## Maintenance Rules

- Update the feature inventory and migration TODO in the same commit as an
  ownership change.
- Add a route test for every alias or nested help path.
- Add a unit test at the domain boundary and a contract test for each migrated
  effectful command family.
- Keep `ori-ii/` unchanged until every legacy route is removed.
- Do not describe legacy paths as live root architecture.
- Prefer a new focused use case or adapter over adding another responsibility
  to `CLI.Run`, `SessionEnvironment`, or `payload.Output`.

## Known Structural Work

Tracked in [`todo/runtime-migration.md`](todo/runtime-migration.md):

- move remaining command-resolution special cases into declarative specs
- split large public CLI handlers by command family
- split concrete tmux capabilities while retaining a shared runner
- move `/www` policy out of payload output
- migrate payload selection and workflow orchestration
- remove the legacy adapter and frozen runtime
