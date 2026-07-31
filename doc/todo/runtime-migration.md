# TODO: Go Runtime Migration

Status: active.

This is a living implementation plan. Update its checkboxes and decisions in
the same commits as the corresponding work. Delete this file when every
completion criterion at the end is satisfied.

The initial combo/workflow implementation and its automated regression suite
form the compatibility baseline. Pane-output advancement, branching, and other
combo-flow additions remain frozen until this migration is complete.

`ori-ii/` is the only source of truth for pre-Go code, bundled payloads,
regression scripts, and the documentation captured with that implementation.
Do not maintain a second legacy copy at repository root. All parity checks must
invoke the baseline from `ori-ii/`.

The real PowerShell/powercat end-to-end exercise remains an environment-specific
manual check. It is not represented as an automated pass and should be repeated
when a suitable disposable target is available.

## Target Architecture

Rebuild the implementation from the public entrypoint inward. New Go code lives
under `src/` throughout the migration:

```text
ori-ii/                   immutable executable legacy baseline
ii.plugin.zsh             thin parent-shell adapter
src/
  go.mod
  cmd/ii/
  internal/
    cli/                     entrypoints and presentation
    variables/               variable use cases
    payload/                 payload and input-render use cases
    www/                     web-root policy and use cases (planned)
    port/                    focused capability interfaces
    adapter/                 external process and filesystem effects
payloads/                 compatible payload data
script/                   build, test, and popup launchers
```

`ii.plugin.zsh` remains because a child executable cannot directly change its
parent Zsh process. It should contain only path/bootstrap logic and narrowly
defined handling for required shell-local effects such as exports, directory
changes, and prompt hooks.

The completed migration removes `ori-ii/`, including its legacy `lib/`. The Go
executable owns command registration, argument parsing, validation, rendering,
tmux orchestration, and all other stateful behavior.

## Non-Negotiable Compatibility

- Preserve `ii` as a natural Zsh command.
- Preserve documented public commands, aliases, shortcut syntax, exit codes,
  output streams, cancellation behavior, and color policy.
- Preserve payload and workflow file compatibility unless a separate schema
  change is approved.
- Preserve tmux session variables and shell-local behavior visible to users.
- Keep `ori-ii/` available as the differential baseline until its replacement
  passes the same contract tests.
- Do not add deferred combo-flow behavior during the migration.
- Build the runtime with `CGO_ENABLED=0` unless a reviewed dependency proves
  that CGO is necessary.

## Phase 0: Audit and Freeze the Current Contract

- [x] Move the complete legacy implementation to `ori-ii/`, remove duplicate
  root implementation files, and verify the snapshot loads as version `0.2.4`.
- [x] Inventory every dispatcher route, long command, short alias, and compact
  shortcut.
- [x] Finish the option, environment variable, configuration default, and
  external dependency inventory.
- [x] Map each feature across CLI/help, user documentation, implementation,
  automated tests, and required manual tests.
- [ ] Compare live output, exit status, stdout/stderr use, and side effects with
  the documented contract.
- [ ] Resolve every discovered implementation/documentation mismatch.
- [ ] Add regression coverage for every corrected mismatch.
- [ ] Record environment-dependent checks without claiming they are automated.
- [x] Run and commit a clean full baseline before adding the Go entrypoint
  (`4954cb7`), then verify the relocated snapshot independently.

### Initial Traceability Inventory

This table is the initial frozen audit. The live ownership and remaining-work
view is maintained in
[`../feature-inventory.md`](../feature-inventory.md).

This table records ownership and current coverage. `documented only` means the
test procedure exists in `ori-ii/doc/testing.md` but has no dedicated automatic
test executable yet.

| Feature | Public routes | Legacy owner | Primary contract docs | Automated baseline | Known gap |
| --- | --- | --- | --- | --- | --- |
| Bootstrap and config | plugin load | `ii.plugin.zsh` | README, architecture, usage | syntax and load smoke | config precedence and load failures are not isolated tests |
| Dispatcher and help | `help`, `h`, `-h`, `--help`, per-command help | `lib/core.zsh`, `lib/help*.zsh` | help, usage | `script/help` | output/exit golden files still needed |
| Version | `version`, `-v`, `--version` | `lib/version.zsh` | README, release | load smoke and help audit | build metadata contract is not defined |
| Variable set/import | `set`, `s`, `s:*`, `sr`, `sf`, `sha` | `lib/vars.zsh`, `lib/var_helpers.zsh` | usage, help | help audit | semantic tests are documented only |
| Variable get/list/output | `get`, `g`, `g:*`, `gr`, `gl`, `ls`, `list`, `variable`, `vars`, `var`, `v`, `vo`, `voc` | vars and var-output layers | usage, help | help audit | filtering, copy, and file output tests are documented only |
| Shell load and sync | `load`, `l`, `la`, `sync` | vars and var-helpers layers | usage, architecture | help audit | parent-shell exports, hooks, and multi-pane load are documented only |
| Interactive variables | `interactive`, `i` | `lib/var_interactive.zsh` | usage | help audit | modal behavior is manual |
| Unset | `unset`, `u` | `lib/vars.zsh` | usage, help | help audit | single/all removal semantics are documented only |
| Clipboard | `clip`, `clipboard` | `lib/clipboard.zsh` | clipboard, usage | help and color tests | backend matrix and doctor are documented only |
| Payload selection/render | `payload`, `p`, `pc`, `pe`, `pce` | payload command and payload layers | usage, payload-schema | workflow render tests and help audit | legacy render/selector matrix is mostly documented only |
| Pasted input | `pic`, `pie`, `pice`, payload input options | payload-input and tmux-input layers | usage, tmux-integration | `test-tmux-input`, popup test | ZLE and clipboard/execute combinations remain manual |
| Web helpers | payload `--www` file/ln/ls/search | `lib/www.zsh` | usage, help | help audit | no dedicated automatic semantic suite |
| Tmux integration | `tmux status`, native `:ii` alias | tmux and tmux-integration layers | tmux-integration | `test-tmux-integration`, popup test | terminal UI remains manual |
| Workflow | opted-in combo execution | workflow and workflow-tmux layers | workflow, payload-schema | three workflow tests and combo classification | real PowerShell/powercat remains manual |
| Build and release | build, version bump, tag release | `script/make`, `script/version`, release workflow | release | package build was previously checked manually | no branch/PR CI and no Go artifacts |

### Command Surface Inventory

The dispatcher and help registry currently expose:

| Command family | Accepted public forms |
| --- | --- |
| Set | `set`, `s`, `s:NAME...`, `sr`, `sf`, `sha`; assignments, `--from-shell`, `--from-file`, `-a`, and `-d [INTERFACE]` |
| Get | `get`, `g`, `g:FILTER`, `gr`, and `gl` |
| Clipboard | `clip` and `clipboard`; `backend [auto|BACKEND]` and `doctor` |
| Load/sync | `load`, `l`, `la`, `--all-pane`; `sync [on|off|status]` |
| Variables | `interactive`, `i`; `ls`, `list`, `variable`, `vars`, `var`; `v [PATTERN]`, `v --out`, `vo`, and `voc` |
| Payload files | `payload`, `p`, `pc`, `pe`, and `pce`; category/keywords, `--copy`, `--execute`, and `-o [PATH]` |
| Payload input | payload `--input`, `pic`, `pie`, and `pice`; copy/execute combinations and `-o [PATH]` where documented |
| Web payloads | payload `--www`/`www`; `--file`, `ln`, `ls`, and `search` |
| Tmux | `tmux status` |
| Unset | `unset`, `u`, names, and `-a` |
| Version | `version`, `-v`, and `--version` |
| Help | no arguments, `help`, `h`, `-h`, `--help`, and registered command paths |

Unknown top-level commands and unknown help topics return status 2. Individual
families also use status 2 for invalid usage; exact family-specific cases must
be captured as golden contract tests during the remaining Phase 0 work.

### Baseline Findings

- The legacy snapshot loads independently as `ii 0.2.4`.
- Syntax, plugin load, help registry audit, color policy, workflow parser,
  workflow render/state, popup input, tmux integration, and combo
  classification currently pass from `ori-ii/`.
- Dispatcher routes and registered help routes agree under the existing help
  audit.
- No confirmed legacy code/document behavior conflict has been found yet.
- The largest audit risk is coverage: many procedures in
  `ori-ii/doc/testing.md` are prose command sequences rather than repeatable
  automatic tests. They must be automated or explicitly classified as manual
  before parity can be claimed.
- Root build and release paths intentionally stop representing the legacy
  layout after the move. Phase 1 must replace them with migration-aware CI and
  build entrypoints; legacy builds remain runnable inside `ori-ii/`.
- The tag release workflow was temporarily redirected to build from `ori-ii/`
  so releases do not break before the Go package path replaces it.

### Public Configuration Inventory

The current public or user-observable configuration surface is:

| Name | Purpose | Default/source |
| --- | --- | --- |
| `II_CONFIG_FILE` | Zsh configuration file | `~/.config/ii/ii.conf` |
| `II_PLUGIN_DIR` | installed runtime root | directory containing the plugin |
| `II_PAYLOAD_DIR` | payload data root | `$II_PLUGIN_DIR/payloads` |
| `II_WWW_ROOT` | web content root | `/www` |
| `II_EXPORT_CASE` | lower/upper/both parent-shell exports | `lower` |
| `II_COLOR` | auto/always/never ANSI policy | `auto` |
| `NO_COLOR` | standard color override | unset |
| `II_AUTO_DETECT_LHOST` | rhost-triggered lhost detection | enabled |
| `II_AUTO_DETECT_LHOST_INTERFACE` | detection interface | `tun0` |
| `II_CLIP_BACKEND` | selected clipboard backend | auto detection |
| `II_CLIP_CMD` | custom clipboard command | unset |
| `II_TMUX_INTEGRATION` | automatic native `:ii` alias setup | enabled |
| `II_TMUX_INTEGRATION_FORCE` | replace a conflicting tmux alias | disabled |
| `II_SYNC_LOADED_VARS` | current-shell prompt synchronization state | disabled |

`II_INTERACTIVE_KEY`, `II_PAYLOAD_KEY`, filter variables used by test fixtures,
render-report globals, help registry globals, and workflow state arrays are
implementation/test seams rather than supported configuration. The Go protocol
must not accidentally promote them into public API.

### External Dependency Inventory

- Required for the legacy shell entry: Zsh.
- Required for session variables, pane operations, popup execution, and
  workflows: tmux.
- Required for interactive selectors: fzf.
- Required by legacy implementation paths: awk, sed, find, sort, mktemp, and
  standard core utilities.
- Required only for interface address detection: `ip`.
- Required only for OSC52 clipboard output: `base64` and `tr`.
- Optional clipboard programs: `clip.exe`, `wl-copy`, `xclip`, `xsel`, and
  `pbcopy`.
- Required only for legacy packaging/release: tar and zip.

The Go runtime should replace awk/sed/find/sort parsing where practical, but it
must continue to treat tmux, fzf, platform clipboard programs, and `ip` as
explicit capabilities with precise diagnostics.

## Phase 1: Go Skeleton, Build Interface, and CI

- [x] Create `src/go.mod`, `src/cmd/ii`, and the initial `src/internal`
  packages.
- [x] Add a minimal executable command that reports version/build information.
- [x] Add common local targets for format check, vet, unit tests, build, and
  public contracts.
- [x] Add the final architecture-specific package target.
- [x] Add pull-request and branch CI covering Go and the complete legacy
  regression baseline.
- [x] Compile statically for Linux amd64 and arm64.
- [x] Keep generated binaries and build output out of Git.
- [x] Keep the immutable legacy export under `ori-ii/export/ii` and make root
  `make` produce only the new Go deployment package under `export/ii`.
- [x] Package the temporary explicit legacy bridge beside `ii-go` while
  unmigrated routes still exist.
- [x] Make the release workflow produce architecture-specific deployment
  archives containing the correct runtime binary.

Required Go checks:

```text
gofmt
go vet ./...
go test ./...
CGO_ENABLED=0 go build ./cmd/ii
```

## Phase 2: Public Entrypoint and Dispatcher

- [ ] Define the stable protocol between `ii.plugin.zsh` and the Go executable.
- [x] Move top-level command registration, aliases, argument parsing, and the
  first help routes
  into Go before migrating feature internals.
- [x] Route every public invocation through the Go dispatcher.
- [x] Let unmigrated routes explicitly invoke a controlled legacy adapter;
  never silently guess or fall through. The adapter must invoke `ori-ii/`
  explicitly.
- [x] Preserve parent-shell mutations during the bridge by invoking the
  explicitly selected legacy function in the same Zsh process; do not evaluate
  executable output from Go.
- [x] Add initial dispatcher contract tests comparing legacy and Go exit
  status, stdout, and stderr.
- [x] Add an isolated tmux contract proving that a legacy-routed command keeps
  both parent-shell exports and tmux session state.
- [ ] Extend the contract set to every command family.
- [x] Define and contract-test the versioned, allowlisted parent-shell
  operation protocol before migrating `load`, `sync`, or shell-persistent
  behavior.

### Current Route Boundary

Every invocation first calls the hidden Go routing operation. The router returns
only the closed values `go` or `legacy`; any other value aborts.

Go-owned:

```text
no arguments
top-level help, h, -h, --help without another command topic
help version
version, -v, --version
unknown top-level commands
ls, list, variable, vars, var
v [PATTERN] without --out
v --out, vo, voc
set, s, sr, sf, sha, and compact s: forms
get, g, gr, gl, and compact g: forms
load, l, load --all-pane, and la
sync
interactive and i
clipboard and clip, including backend and doctor
tmux status diagnostics
tmux alias installation and popup execution
unset and u, including confirmed -a
help for the variable-list family
help for the set family
help for interactive variables
payload --input, pic, pie, and pice, including their help paths
```

Legacy-owned:

```text
payload file selection/copy/execute paths
payload /www paths
workflow execution
their corresponding aliases and help paths
```

An error in a Go-owned route never falls back to legacy. `ori-ii` remains
loaded only so an explicit legacy decision can preserve current-shell effects
until that command family is migrated.

### First Vertical Slice: Variable List

The read-only variable-list family is migrated as the first real feature slice:

- Domain filtering and ordering live in `internal/variables`.
- The domain depends only on the `port.EnvironmentReader` capability.
- The real adapter invokes tmux and owns tmux availability diagnostics.
- CLI formatting owns ANSI key color and stdout/stderr behavior.
- Unit tests use an in-memory fake capability.
- An isolated tmux differential contract compares every alias, filtering,
  empty values, values containing `=`, ignored extra arguments, and forced
  color with `ori-ii`.
- `v [PATTERN]` shares the Go list use case. `v --out`, `vo`, and `voc` use the
  same environment reader with an atomic filesystem writer and are also
  Go-owned.

The complete variable family is now Go-owned, including interactive selection,
add/edit/copy behavior, output, import, sync, and parent-shell semantics.

### Architecture Refactoring Work

Completed for the `/www` preparation checkpoint:

- [x] Replace positional CLI construction with named dependencies.
- [x] Split hidden shell/runtime entrypoints from public dispatch.
- [x] Route ownership and public dispatch through a shared `Resolution` entry.
- [x] Share payload input rendering between public input and tmux popup paths.
- [x] Split CLI composition, public dispatch, resolution, and variable-family
  parsing into responsibility-specific files without changing behavior.
- [x] Move variable-family list, output, unset, load, interactive, sync, and
  help behavior behind feature handlers so public dispatch only forwards.
- [x] Split variable CLI behavior by read, set/import, session, and interactive
  responsibility without adding another abstraction layer.
- [x] Add the `/www` domain policy, feature-owned Store interface, no-follow
  filesystem adapter, and unit coverage for containment and overwrite safety.
- [x] Move `/www ls`, `search`, and `ln` plus fzf selection into Go while
  keeping `--file` and child help explicitly legacy-owned.
- [x] Move `/www --file` render, report, original-file symlink, and path
  analysis into Go.
- [x] Move `/www` parent/child help into Go and add differential semantic
  coverage for list, search, link, and publish behavior.

Remaining structural work:

- [ ] Replace remaining route-owner and canonical-command special cases with a
  declarative command specification.
- [ ] Encapsulate feature dependencies in focused command-handler structs.
- [ ] Split the concrete tmux session adapter into environment, pane, and
  integration wrappers over one runner.
- [ ] Move `/www` path defaults out of payload output after compatibility
  contracts cover the transition.
- [ ] Add `/www` unit and isolated semantic contract coverage.

## Phase 3: Vertical Feature Migration

Migrate complete user-visible command paths one at a time. A route is migrated
only when implementation, tests, help, docs, and package behavior move together.

- [ ] Version, help, and diagnostics.
- [ ] Payload discovery, classification, preview, and rendering.
- [x] Tmux variable set, get, list, unset, import, and output.
- [x] `/www` output helpers.
- [x] Interactive payload input (interactive variables are complete).
- [x] Tmux command alias, popup entry, pane transport, and identity validation.
- [ ] Workflow parsing, lane assignment, memory, rendering, and orchestration.
- [x] Shell-local variable load, sync, export, and hook adapter behavior.

Payload migration foundation now present:

- Go-owned filesystem catalog with category filtering and traversal/symlink
  rejection.
- Legacy document metadata conversion and strict `# flow: 1` parsing.
- Shared renderer for `$name`, `${name}`, `${name:t}`, and `%name%`, including
  shell-over-tmux precedence and deterministic source reports.
- A filtered parent-shell state request derived only from names referenced by
  stored payload templates.
- Isolated tmux differential coverage proving legacy and workflow render output
  matches the frozen Zsh implementation. Public payload routes remain legacy
  until selector, confirmation, copy/output, and current-shell execution
  boundaries are complete.
- A per-invocation `execute-file` shell-operation channel now supports
  confirmed current-shell side effects without `eval`; exact-path validation,
  symlink rejection, cleanup, and end-to-end variable/cwd persistence are
  covered by contracts.
- Tmux command-alias discovery, ownership markers, conflict notices, forced
  replacement, idempotent installation, and legacy Prefix+: cleanup are now
  Go-owned. The native alias now opens the Go popup entrypoint, whose execute
  path owns terminal and streamed multiline input, Enter/Alt-Enter/Esc editing,
  rendering, confirmation, pane identity validation, literal buffer transport,
  and final Enter delivery.
- Public `pic`, `pie`, `pice`, and `payload --input` execution paths now share
  the Go terminal/stream reader, renderer, output writer, clipboard adapter,
  single-key confirmation, allowlisted parent-shell execution channel, and all
  direct and nested input help topics.
- Workflow lane assignment now has a Go domain model with occupied-pane swap,
  toggle, completeness, and deterministic memory serialization semantics.
- A feature-owned Go workflow runtime now provides session-wide pane discovery,
  validated memory read/write, pane snapshots, and literal stage transport
  through the tmux adapter.
- Workflow session preparation now applies the legacy-compatible initial
  assignment precedence (valid remembered binding, origin pane for Kali lanes,
  detected remote foreground command, then an unused live pane), merges
  confirmed bindings without discarding unrelated session memory, and
  revalidates distinct live pane identities before stage transport.
- The Go terminal boundary now owns the workflow spatial lane selector and pane
  map rendering, including window cycling, cursor movement, toggle/swap,
  ordinal assignment, complete-assignment confirmation, cancellation, and
  write-on-confirm session memory semantics.
- The workflow runner now presents every rendered stage with lane, live pane,
  shell, title, notes, unresolved variables, and previous-stage readiness;
  after explicit confirmation it revalidates all pinned identities, optionally
  copies, and sends through literal tmux transport in source order.
- A hidden Go workflow popup entrypoint now reparses and rerenders the selected
  relative payload path, pins the explicitly handed-off origin/session,
  composes selection and staged execution, reports copy failures without
  suppressing confirmed sends, and prints per-stage/completion status.
- The Go payload selector execution path now launches that popup through a
  quoted tmux adapter command. Still pending before public ownership:
  differential popup coverage and switching the dispatcher from the frozen
  legacy stored-payload route.

For every migrated route:

- [ ] Run old and new implementations against shared golden/contract fixtures.
- [ ] Match exit status, stdout, stderr, and durable side effects.
- [ ] Add failure-path and cancellation coverage.
- [ ] Remove the corresponding legacy route only after parity passes.

## Phase 4: Remove the Legacy Runtime

- [ ] Confirm no public route or script invokes `ori-ii/`.
- [ ] Remove all legacy fallbacks and compatibility switches used only for the
  migration.
- [ ] Delete `ori-ii/`.
- [ ] Reduce `ii.plugin.zsh` to the documented thin adapter.
- [ ] Update architecture, testing, usage, help, release, and design docs to
  describe only the completed runtime.
- [ ] Ensure deployment packages contain no stale Zsh implementation files.

## Phase 5: Final Validation and Cleanup

- [ ] Run Go format, vet, unit, integration, race-relevant, and cross-build
  checks.
- [ ] Run the complete shell, payload, tmux, workflow, build, and help
  regression suite.
- [ ] Test a clean installation from each supported release archive.
- [ ] Perform the documented interactive tmux checks.
- [ ] Perform the real PowerShell/powercat exercise when a disposable target is
  available, or explicitly carry it as a release-specific manual check.
- [ ] Confirm the working tree contains no generated binaries.

## Completion Criteria

Delete this file only when all of the following are true:

- All public commands route through the Go executable.
- `ii.plugin.zsh` contains only necessary bootstrap and parent-shell adapter
  behavior.
- `ori-ii/` and every legacy implementation file have been deleted.
- No legacy runtime fallback remains.
- Linux amd64 and arm64 builds pass in CI and ship in release archives.
- The compatibility suite and required manual checks are green or explicitly
  documented as environment-specific release checks.
- Permanent documentation describes the final architecture with no migration
  language.
