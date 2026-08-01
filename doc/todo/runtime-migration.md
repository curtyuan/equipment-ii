# TODO: Zsh and Go Runtime Ownership Migration

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

The migration target is now a deliberately split runtime rather than a full Go
replacement. Zsh owns ordinary shell-native behavior, Go owns only combo flow,
and tmux remains the persistent session-wide state store:

```text
ori-ii/                   immutable executable legacy baseline
ii.plugin.zsh             public command runtime and shell integration
src/
  go.mod
  cmd/ii/
  internal/
    workflow/                combo parsing, lanes, memory, rendering, runner
    terminal/                combo selector terminal boundary
    adapter/tmux/            combo pane discovery and literal transport
payloads/                 compatible payload data
test/                     one repository-owned public contract suite
```

`ii.plugin.zsh` remains because a child executable cannot directly change its
parent Zsh process. It should contain only path/bootstrap logic and narrowly
defined handling for required shell-local effects such as exports, directory
changes, and prompt hooks.

The completed migration removes `ori-ii/` as a frozen duplicate, but restores
the retained ordinary-command Zsh implementation at the repository root. The
Go executable is invoked once only for a selected combo flow and owns its full
parse/render/select/confirm/transport lifecycle. It does not store shared
variables, implement ordinary payloads, or mutate the parent shell.

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
| Shell load | `load`, `l`, `la` | vars and var-helpers layers | usage, architecture | help audit | parent-shell exports and multi-pane load are documented only; legacy `sync` is intentionally not part of the target |
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
| Load | `load`, `l`, `la`, and `--all-pane` |
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

- [ ] Define the stable one-process combo launch protocol between
  `ii.plugin.zsh` and the Go executable.
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
  operation protocol before migrating `load` or shell-persistent
  behavior.

### Current Route Boundary

Every public invocation now enters the Go dispatcher directly. The Zsh adapter
does not load or dispatch to the frozen runtime. This records the current
implementation checkpoint, not the approved final ownership boundary below.

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
interactive and i
clipboard and clip, including backend and doctor
tmux status diagnostics
tmux alias installation and popup execution
unset and u, including confirmed -a
help for the variable-list family
help for the set family
help for interactive variables
payload --input, pic, pie, and pice, including their help paths
payload, p, pc, pe, and pce stored-payload selection/copy/execute paths
payload --www list/search/link/file paths
workflow popup parsing, lane assignment, confirmation, and execution
```

Legacy-owned:

```text
none
```

An error in a Go-owned route never falls back to legacy. The root adapter no
longer loads or dispatches to the frozen implementation; `ori-ii` remains only
as the differential contract baseline and temporary payload-data source.

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

The complete retained variable family is Go-owned, including interactive
selection, add/edit/copy behavior, output, import, load, and parent-shell
semantics. Prompt-time `sync` remains implemented temporarily and is scheduled
for removal below.

### Architecture Refactoring Work

Completed for the `/www` preparation checkpoint:

- [x] Replace positional CLI construction with named dependencies.
- [x] Split hidden shell/runtime entrypoints from public dispatch.
- [x] Route ownership and public dispatch through a shared `Resolution` entry.
- [x] Share payload input rendering between public input and tmux popup paths.
- [x] Split CLI composition, public dispatch, resolution, and variable-family
  parsing into responsibility-specific files without changing behavior.
- [x] Move variable-family list, output, unset, load, and interactive
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

- [ ] Replace remaining canonical-command special cases with a
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
- [x] Payload discovery, classification, preview, and rendering.
- [x] Tmux variable set, get, list, unset, import, and output.
- [x] `/www` output helpers.
- [x] Interactive payload input (interactive variables are complete).
- [x] Tmux command alias, popup entry, pane transport, and identity validation.
- [x] Workflow parsing, lane assignment, memory, rendering, and orchestration.
- [x] Shell-local variable load and export adapter behavior.

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
- The Go payload selector execution path launches that popup through a quoted
  tmux adapter command. Public payload selection, copy, current-shell execute,
  workflow copy/execute, aliases, and aggregate help now route through Go;
  route, CLI composition, popup quoting, and tmux selector contracts cover the
  handoff while the frozen legacy implementation remains the differential
  contract baseline.

For every migrated route:

- [ ] Run old and new implementations against shared golden/contract fixtures.
- [ ] Match exit status, stdout, stderr, and durable side effects.
- [ ] Add failure-path and cancellation coverage.
- [ ] Remove the corresponding legacy route only after parity passes.

## Approved Runtime Boundary: Implementation Gap

The target ownership chain is now fixed:

```text
Zsh: public commands, variables, ordinary payloads, filesystem helpers
  -> Go: combo flow only
     -> tmux: persistent session-wide ii_* variables and pane transport
```

Tmux continues as the canonical cross-pane variable store. Go starts once only
after an ordinary Zsh selector identifies an opted-in `# flow: 1` document; do
not introduce an ii daemon, duplicate tmux state in Go memory, or split one
combo session across multiple Go processes. Ordinary commands do not invoke
Go and require no Zsh/Go state or parent-shell operation protocol.

Approved ownership decisions:

- `ii s` retains its existing behavior: write tmux and update the calling
  shell.
- Interactive add/edit follows `ii s`: write tmux and update the calling shell.
- `s --from-shell` and `s --from-file` remain Zsh-owned. File input is parsed as
  data and is never sourced or evaluated.
- `s`, `g`, `load`, `unset`, clipboard behavior, ordinary payload selection,
  rendering, copy/current-shell execution, and help/version are Zsh-owned.
- Go owns combo document parsing, workflow rendering from tmux state, lane
  assignment and memory, terminal selection, confirmation, pane identity
  validation, and literal tmux transport.
- Replace the public `/www` spelling with `ii p -w ...`; its behavior and
  filesystem correctness are Zsh-owned.
- The public contract suite has one repository-owned set of expectations and
  fixtures. It may have thin Zsh/current/temporary-legacy runners, but it must
  not duplicate expected behavior by implementation language.
- Add no external runtime or test dependency. Contract manifests, fixtures,
  and runners use repository scripts, existing Zsh/Bash, tmux/fzf capabilities,
  standard Unix tools already required by the project, and the Go standard
  library.

Current implementation gaps, in intended implementation order:

- [x] Remove the public `sync` command, registry/resolution/dispatch branches,
  CLI help and session handlers, prompt hook,
  `II_SYNC_LOADED_VARS`, `II_SYNC_HOOK_PRESENT`, `sync-hook` operation, and
  interactive sync branches.
- [x] Remove or rewrite sync-only unit and contract expectations in
  `shellops/file_test.go`, `test/contract/shell-operations`,
  `test/contract/interactive-tmux`, `test/contract/variable-mutations-tmux`,
  and `test/contract/run`; add an unknown-command contract for `sync`.
- [ ] Define one Zsh command specification table for ordinary aliases, help
  paths, and handlers. Combo classification is the closed `# flow: 1` marker;
  do not invoke Go merely to classify an ordinary payload.
- [ ] Restore/move variable set/get/list/load/unset/output and interactive
  behavior to the root Zsh runtime, retaining `ii_` normalization and tmux
  semantics. Remove the replaced Go variable handlers only after public
  contracts pass.
- [ ] Keep `s --from-file` in Zsh with strict line-oriented data parsing,
  diagnostics with source line numbers, and no `source`/`eval` behavior.
- [ ] Restore/move ordinary payload catalog, selection, shell-aware rendering,
  copy, output, and confirmed current-shell execution to Zsh. Go must not be
  started for an ordinary payload.
- [ ] Narrow the Go composition root and packages to combo-only parsing,
  rendering, lane selection/memory, runner, and tmux transport. Delete the
  shell-state and parent-shell operation protocols once no Go-owned route uses
  them.
- [ ] Change `/www` public routing and help to `ii p -w ...`; implement its
  containment, traversal rejection, symlink policy, deterministic list/search,
  no-overwrite linking, file publication, and diagnostics in Zsh.
- [ ] Decide compatibility behavior for the old `payload --www`/`www` forms
  before implementing `-w` (hard removal, diagnostic redirect, or temporary
  alias), then encode only the chosen public result in contracts.
- [ ] Preserve tmux as the uncached source of truth: `set-environment` for
  writes, `show-environment` for reads, explicit `ii l` for pane-local
  hydration, and `ii la` for reviewed cross-pane dispatch.
- [ ] Replace permanent legacy-vs-current diffs with one language-neutral
  contract fixture set covering stdout, stderr, status, tmux state, shell
  state, filesystem effects, cancellation, and ordered pane transport.
- [ ] Add architecture contracts proving ordinary commands never start Go and
  one selected combo starts exactly one Go process.
- [ ] Remove Go packages and tests superseded by Zsh only after their public
  expectations exist in the shared contract suite; large deletion volume is
  not a blocker or a reason to retain split ownership.
- [ ] Update package/install tests after root payload data no longer depends on
  the temporary `ori-ii/payloads` path.

Current ownership-reversal checkpoint:

- [x] Choose a clean Zsh ordinary runtime (option B): use `ori-ii` as behavior
  reference, but do not restore its 21-module global load order, Zsh workflow,
  or removed sync implementation wholesale.
- [x] Add the first closed Zsh command specification and public dispatcher
  seam while retaining Go fallback only for not-yet-migrated ordinary forms.
- [x] Move explicit `set`/`s`, compact `s:`, and `sr` mutations to Zsh,
  including tmux storage, calling-shell export, export-case policy, explicit
  interface detection, and optional rhost-triggered lhost detection.
- [x] Add an isolated architecture contract proving migrated explicit-set
  forms preserve tmux and shell effects without starting Go.
- [x] Move `s --from-shell`, `sha`, `s --from-file`, and `sf` into the same Zsh
  variable module before removing their Go handlers.
- [x] Move current-pane `load`/`l` and `unset`/`u` (including confirmed `-a`)
  to Zsh and preserve tmux plus parent-shell effects without starting Go.
- [x] Move `load --all-pane`/`la` with its pane selection and reviewed dispatch
  behavior to Zsh.
- [x] Move `ls`/list aliases, `v [PATTERN]`, `v --out`, `vo`, and `voc` to Zsh,
  retaining color policy, deterministic filtering, atomic replacement, and
  shell-sourceable quoting without starting Go.
- [x] Move `g`/`g:`/`gr`/`gl` selection and clipboard behavior to Zsh,
  retaining shortcut matching, fzf selection, configured clipboard copy, and
  current output/status behavior without starting Go.
- [x] Move `clip`/`clipboard backend|doctor` to Zsh and consolidate its backend
  resolution with the compact copy helper now used by `g`; do not retain two
  divergent clipboard detection/configuration policies.
- [x] Choose one clipboard-policy owner for combo handoff: Zsh resolves the
  configured/effective backend and passes that closed choice when launching
  combo; Go must not independently auto-detect a backend.
- [x] Move interactive variable selection, add, edit, and copy to Zsh; add/edit
  share the `ii s` mutation path and therefore update both tmux and the calling
  shell, while copy shares the single Zsh clipboard policy.

### Next-Stage Discussion Queue

Resolve these together before implementing the ownership reversal:

- [x] Which existing root/legacy Zsh modules should be restored as the starting
  point, and which should be rewritten to avoid reintroducing obsolete global
  load-order coupling? Decision: clean ordinary modules; frozen modules are
  reference/fixtures only and combo is never restored to Zsh.
- [ ] Should ordinary and combo rendering intentionally share identical token
  syntax while using different state precedence (ordinary: shell then tmux;
  combo: tmux only), and how will one fixture corpus express both contexts?
- [ ] What exact argv/environment contract launches one combo Go process from
  Zsh without shell-state or operation channels?
- [ ] Should the old `--www` forms fail as unknown immediately or print a
  migration diagnostic pointing to `ii p -w` for one release?
- [ ] What exact `ii p -w` child grammar replaces `--www --file`, `ln`, `ls`,
  and `search`, including short forms and help paths?
- [ ] Which Zsh filesystem primitives and checks are sufficient to retain the
  current `/www` containment and no-follow correctness without adding a new
  dependency?
- [ ] Should variable/output and ordinary-payload contract fixtures be copied
  from current differential results before their Go owners are removed, or be
  regenerated from an explicitly reviewed public specification?
- [ ] Should empty tmux values remain stored but hidden by list/load, or should
  setting an empty value become equivalent to unset in the final contract?

## Phase 4: Remove the Legacy Runtime

- [ ] Confirm no public route or script invokes `ori-ii/`.
- [x] Remove all legacy fallbacks and compatibility switches used only for the
  migration.
- [ ] Delete `ori-ii/`.
- [ ] Replace the transitional adapter with the documented Zsh public-command
  runtime and one-process combo launcher.
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

- Ordinary public commands execute in the Zsh runtime without starting Go.
- One selected combo flow starts exactly one Go process for its complete
  parse/render/select/confirm/transport lifecycle.
- `ii.plugin.zsh` owns documented shell-native commands and parent-shell
  behavior without a Zsh/Go state or operation protocol.
- `ori-ii/` and every legacy implementation file have been deleted.
- No frozen-runtime fallback remains.
- Linux amd64 and arm64 builds pass in CI and ship in release archives.
- The compatibility suite and required manual checks are green or explicitly
  documented as environment-specific release checks.
- Permanent documentation describes the final architecture with no migration
  language.
