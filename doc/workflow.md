# Executable Combo Workflows

Status: implemented.

This document defines the file format and execution model for sending ordered
payload stages through as many as three named `kali-*` or `remote-*` lanes,
each pinned to a distinct tmux pane. Existing combo payloads remain ordinary
render/copy payloads unless they explicitly opt into the workflow schema.

## Decisions Reached

- Workflow parsing is opt-in through `# flow: 1`; legacy combo files never gain
  execution behavior by inference.
- A stage is recognized only from the exact structured `# stage: SHELL | TITLE`
  header followed immediately by `# lane: LANE`. The parser never guesses a
  lane from prose, command content, or a legacy label.
- Lanes are created implicitly by the distinct lane names encountered in stage
  execution order. There is no separate lane declaration in the file. The
  first new name is `lane1`, the next is `lane2`, and the next is `lane3` in the
  popup. The first version accepts at most three distinct lane names.
- A lane name has the form `kali-NAME` or `remote-NAME`. The prefix is the
  explicit role and the suffix is the payload author's descriptive identifier.
  Stages share a lane only by repeating exactly the same complete lane name.
- Every lane is assigned to one distinct tmux pane before execution. Two lanes
  cannot share a pane; stages intended for the same pane must use the same lane
  name in the combo file. Each resolved pane ID is pinned for the complete run.
- Pane selection is shown as a spatial tmux-layout view inside the workflow
  popup. Pane rectangles preserve their relative size and position so the
  operator recognizes the layout visually instead of inferring it from a list.
- The selector assigns one checked pane to each lane. Selection order follows
  lane first-appearance order, not stage count. A workflow may contain many
  stages distributed across its maximum of three lanes.
- Remote-shell detection is advisory only. ii may label a pane `likely remote`,
  but it must not claim to identify the remote operating system reliably or
  execute based on that classification alone.
- The orchestrator runs in a tmux popup so both destination panes are idle and
  able to receive literal-pasted input.
- Every stage must declare `# advance: confirm`. Its confirmation authorizes
  sending that stage; for every stage after the first, the same confirmation
  also means the operator considers the preceding stage ready. There is no
  second post-send advancement prompt. Submitted input is not treated as
  process completion.
- Workflow popup rendering uses tmux-session variables only, matching the
  existing isolated ii popup boundary.
- Workflow execution is entered through the existing payload selector rather
  than a new public `workflow` command. Selecting an opted-in combo and pressing
  `e`, or selecting it through `ii pe KEYWORD...`, routes to the workflow popup.
- The selected file, not a guessed keyword match outside the selector, decides
  what runs. Non-workflow payloads retain their existing execute behavior.
- Ordinary preview and copy still parse an opted-in workflow into distinct
  stages. Copy proceeds one stage at a time in file order and never flattens a
  mixed-lane workflow into one clipboard body.
- Once a file declares `# flow: 1`, every preview, render, copy, and execute
  path requires a complete successful parse. Any parse error reports its source
  line and aborts without output, copying, execution, or legacy fallback.
- Every payload-file action without `--input`, including `pc` and `p --copy`,
  opens the payload selector and preview. Keywords initialize its query; they
  never choose and copy a best match without showing the selector.
- Lane assignment may search every pane in the current tmux session. The popup
  selects a window and shows that window's spatial pane layout; it never crosses
  into another session.
- The selector initially assigns lanes in first-appearance order from detected
  and remembered candidates. These are editable suggestions and never bypass
  the final confirmation.
- Each assigned pane has an extra status line immediately above its rectangle.
  The line shows the lane ordinal, complete lane name, and suggestion source,
  for example `[1/lane1] kali-sender · detected`. Remembered and manually
  adjusted assignments use `remembered` and `manual` respectively. The active
  lane also has a non-color-only marker such as `>` in addition to highlighting.
- Space toggles the active lane on the pane under the cursor. Number keys `1`,
  `2`, and `3` directly assign that lane ordinal to the pane under the cursor.
  Assigning a lane to a pane already occupied by another lane swaps the two
  assignments; assigning it to an empty pane moves it and clears its old pane.
- Enter confirms the complete lane assignment only when every lane has one
  distinct pane. Escape or `q` aborts without sending anything.
- A manually confirmed assignment is remembered within the current tmux
  session by complete lane name and concrete pane ID. A valid remembered pane
  is preferred over fresh detection but remains an editable suggestion. Missing,
  cross-session, or conflicting remembered panes are ignored and cleared.
- During execution, a workflow aborts only when a pinned destination identity
  is no longer safe: the pane disappears, leaves the pinned session, aliases
  another lane unexpectedly, or literal buffer transport cannot complete.
  Foreground command, title, visible content, window placement, and layout size
  changes do not abort a workflow.

## Goals

- Send one rendered command block to an explicitly selected tmux pane.
- Execute ordered host and remote stages from one combo file.
- Reuse the current payload renderer and literal tmux buffer transport.
- Keep workflow files readable as plain text and valid comments in zsh, Bash,
  PowerShell, and common target shells.
- Never infer executable routing from existing free-form stage labels.
- Preview and confirm targets and rendered commands before sending them.

## Non-goals for the First Version

- Parse Markdown or execute fenced code blocks.
- Automatically identify a pane as a reverse shell from its foreground command.
- Treat a submitted command as completed without an explicit advancement rule.
- Embed tmux pane IDs in portable payload files.
- Rewrite commands based on their declared shell.

## Proposed File Format

The format extends the current combo convention with a required workflow marker
and structured stages:

```text
# description: Kali sends a file to Windows TEMP
# flow: 1
# note: Windows target must already have powercat

# stage: powershell | Start receiver on Windows
# lane: remote-receiver
# advance: confirm

$PORT = $rport
$RFILE = "${file:t}"
$OUTFILE = Join-Path $env:TEMP $RFILE
Remove-Item $OUTFILE -Force -ErrorAction SilentlyContinue

powercat -l -p $PORT -of $OUTFILE
Write-Output $OUTFILE

# stage: zsh | Send file from Kali
# lane: kali-sender
# advance: confirm

nc -q 1 "$rhost" "$rport" < "$file"
```

Executable workflow files should remain under `payloads/script/combo/`. The
existing path convention may continue to describe direction and connection
roles, for example `trans/powercat-K2T-TLKC`.

Do not include Markdown headings, numbered prose, or fenced code blocks in an
executable workflow. Operator-facing explanation belongs in `description` and
repeatable `note` metadata.

## File Metadata

### `# description:`

Optional first-line summary. This retains the current payload metadata rule and
is omitted from rendered command bodies.

### `# flow: 1`

Required opt-in marker for executable workflow parsing. A combo file without
this exact marker remains a display/render/copy payload even when it contains
legacy `# stage:` lines.

### `# note:`

Optional repeatable prerequisite or operator instruction. Notes are displayed
in preview but are never sent to a pane.

## Stage Metadata

Each executable stage starts with:

```text
# stage: SHELL | TITLE
# lane: LANE
```

`LANE` is a complete named lane in one of these forms:

```text
kali-NAME
remote-NAME
```

`kali` and `remote` are the only accepted role prefixes. `NAME` is a lowercase
descriptive identifier made from letters, digits, `_`, and `-`, beginning with
a letter or digit. Examples include `kali-launch`, `remote-revshell`, and
`kali-http-server`.

`# lane:` is a required property of each stage, not a separate global lane
declaration. It must appear immediately after the stage header. The parser
creates lanes from their first appearance in stage order:

```text
# stage: zsh | Start handler
# lane: kali-launch
# stage: powershell | Fetch payload
# lane: remote-revshell
# stage: zsh | Verify callback
# lane: kali-launch
```

This produces `lane1: kali-launch` and `lane2: remote-revshell`. The first and
third stages share lane1 because their complete lane names match exactly. A
different name creates a different lane even when it has the same role prefix.
More than three distinct lane names is a parse error.

Pane IDs are runtime bindings and must not be stored in the payload file.

`SHELL` is descriptive metadata used in previews and validation. Initial known
values may include `zsh`, `bash`, `sh`, `powershell`, and `cmd`. Declaring a
shell does not authorize the parser to rewrite or quote the stage body.

`TITLE` is free operator-facing text. The required `# advance: confirm` line
must immediately follow the required `# lane:` line before body content. A
stage ends at the next structured `# stage:` line or at end of file.

The recognition rule is intentionally narrow. After optional surrounding
spaces are trimmed, both stage fields must be present, the required lane must
be valid, and the title must be non-empty. For example:

```text
# stage: powershell | Start receiver
# lane: remote-receiver
```

is executable workflow metadata, while these remain ordinary comments or
legacy presentation metadata:

```text
# Windows target
# Run this on Kali
# stage: Target PowerShell: receive file
```

### `# advance:`

This directive is mandatory for every stage. It must immediately follow the
required lane line and precede the first command line.

The first implementation accepts only:

```text
# advance: confirm
```

The prompt for a stage authorizes sending that stage. Starting with stage 2,
the same confirmation also states that the preceding stage is ready for the
workflow to advance. There is no separate prompt immediately after a send.
This avoids deadlock in listener workflows, where the listener may remain in
the foreground until a following connector stage runs.

Possible later modes, reserved but not initially accepted:

- `delay SECONDS`: advance after a fixed delay; simple but unreliable.
- `output PATTERN`: use `tmux capture-pane` until output matches or times out.
- `done`: wrap a compatible command with a completion marker and exit status.

Unsupported advancement modes must be rejected. They must not silently fall
back to confirmation or delay behavior.

## Multi-stage and Process Semantics

A stage is a command block sent to one pane, not necessarily one command or one
operating-system process. Variable setup and related commands for the same pane
belong in one stage. Split stages when the destination pane changes or when the
operator must decide whether the next block may be sent.

Listener workflows normally alternate panes:

```text
remote listener -> confirm ready -> host connector -> confirm complete
```

or:

```text
host listener -> confirm ready -> remote connector -> confirm complete
```

This allows the listener and connector to overlap even though the workflow
itself advances in file order. A later stage aimed at the listener pane is safe
only after the blocking listener has returned control to that pane. In the
first version, determining that readiness remains the operator's responsibility.

The lane model is not a process manager. ii sends each stage body to its lane's
pinned pane in file order and relies on explicit operator advancement. It does
not supervise, background, terminate, or determine completion of processes in
that pane. A workflow that wants later stages to reuse a pane repeats the same
lane name; shell-level concurrency remains the payload author's responsibility.

## Parser Model

The parser should be strict and line-oriented:

1. Normalize CRLF by removing a trailing carriage return from each input line.
2. Recognize `description` only on the first line, matching the current schema.
3. Require exactly one supported `flow` marker before the first stage.
4. Collect repeatable `note` metadata before the first stage.
5. Start a stage only from a structured header with two pipe-separated fields:
   shell and title.
6. Require one valid `lane` line immediately after every stage header.
7. Require exactly one `advance: confirm` line immediately after `lane`.
8. Preserve blank lines and ordinary comments inside the stage body.
9. Reject executable text before the first stage.
10. Reject unknown workflow metadata, invalid lanes, missing titles, duplicate
   singleton metadata, and empty stage bodies with source line numbers.
11. Parse and validate the complete file before rendering or sending anything.
12. Render each stage independently with the existing payload renderer.
13. Record and display unresolved variables per stage; do not send unresolved
    content without explicit confirmation.

The logical parsed object is:

```text
workflow
  version
  description
  notes[]
  lanes[]
    ordinal
    name
    role
    pane_id
  stages[]
    lane_name
    shell
    title
    advance
    source_body
    rendered_body
    variables[]
    unresolved[]
    source_line
```

Workflow metadata is not part of `source_body` or `rendered_body`. Ordinary
comments that are not recognized metadata remain part of the stage body.

## Rendering Rules

Rendering must reuse the current lowercase placeholder rules:

- Render `%name%`, `$name`, `${name}`, and `${name:t}`.
- For workflow execution in a popup, resolve from the selected tmux session's
  `ii_` variables only, matching the current isolated popup boundary. The
  popup cannot reliably inherit pane-local shell overrides.
- Leave uppercase variables and legacy `II_NAME` forms unchanged.
- Leave PowerShell scope expressions such as `$env:TEMP` unchanged.

The same file rendered through ordinary `ii p` remains subject to the existing
shell-first, tmux-fallback rule. The workflow preview must state that execution
is using tmux-only values so the difference is visible before sending.

In the example, ii resolves `$rport`, `$rhost`, `$file`, and `${file:t}`. It
leaves `$PORT`, `$RFILE`, `$OUTFILE`, and `$env:TEMP` for PowerShell runtime.

## Tmux Execution Model

The current `ii pice` transport already provides the required primitive:

```text
rendered text -> tmux load-buffer -> paste-buffer to pane -> final Enter
```

The popup command adapter is available by default according to
[tmux-integration.md](tmux-integration.md). Workflow support reuses that
popup boundary and does not reintroduce per-session enable/disable state.

Workflow execution should extract this into a shared literal-send helper. It
must not pass payload text directly as a `tmux send-keys` command argument.

The first-version orchestrator should run in a tmux popup. A separate controller
pane may be considered later. It must not remain as the foreground process in
the host pane while also pasting a host stage into that pane, because the pasted
input could be consumed by the orchestrator instead of the shell.

### Entry from the payload selector

Workflow execution reuses the existing execution actions rather than adding a
new top-level command:

```text
ii p KEYWORD...        select a payload, then press e
ii pe KEYWORD...       select a payload; Enter requests execution
```

Both forms still enter the payload TUI and act on the payload the operator
actually selects. If that file has `# flow: 1` and valid structured stages, the
execute action opens the workflow popup and returns control of the originating
pane to its shell. The popup receives the selected payload path, originating
pane ID, and session ID, then performs complete validation before sending any
stage.

If the selected file is not an opted-in workflow, the existing payload execute
path remains unchanged. A legacy combo must not acquire cross-pane execution
merely because it is stored under `payloads/script/combo/` or contains a
free-form `# stage:` label. `ii pice` remains the pasted-input execution path;
without a selected workflow file it does not infer workflow structure.

Before every stage, the runner must:

1. Revalidate the target pane and its original tmux session.
2. Display lane, pane identity, foreground command, shell metadata, title, and
   rendered body.
3. Show unresolved variables and workflow notes.
4. Require confirmation to send every stage; from stage 2 onward it also
   confirms that the preceding stage is ready.
5. Abort rather than fall back to another pane when the target is unavailable.

## Pane Resolution and Fast Interaction

The user should not need to remember or repeatedly type a pane ID. Internally,
tmux pane IDs such as `%7` remain the stable identity, but the normal workflow
uses automatic capture and session-scoped binding.

### Lane pane assignment

The popup assigns lanes in first-appearance order. The originating `$TMUX_PANE`
is the initial suggestion for the first `kali-*` lane. Other `kali-*` lanes and
all `remote-*` lanes are assigned through the spatial selector, with remembered
or advisory candidates shown only as suggestions.

Each assignment consumes a distinct pane. A pane already assigned to one lane
cannot be checked for another. If multiple stages should return to the same
pane, those stages must repeat the same lane name and therefore reuse its one
assignment.

Every assignment is resolved once to a concrete pane ID and original session.
A stale suggestion is cleared and selected again rather than redirected.

After resolution, the popup should present one compact plan summary before the
first send:

```text
lane1 kali-launch: %3 zsh
lane2 remote-revshell: %7 nc
lane3 kali-http-server: %9 python3
stages: 5
```

Per-stage pauses then come only from `advance: confirm` or unresolved-variable
confirmation, avoiding repeated pane selection and unnecessary prompts.

## Compatibility

Existing combo files use free-form labels such as:

```text
# stage: Target PowerShell: receive file to TEMP
```

These remain presentation-only metadata. They must not be interpreted as pane
routing. A workflow becomes executable only when both conditions hold:

- the file contains `# flow: 1`; and
- every executable stage uses structured `SHELL | TITLE` plus its required
  `# lane: LANE` line.

This preserves legacy combo selection while allowing individual files to
migrate to workflow execution. Execute routing is based on the parsed opt-in
marker and structured stages, not merely on the combo directory.

For ordinary preview and copy, recognized non-code metadata is omitted from
each individual stage body:

- `# description:`
- `# flow:`
- `# note:`
- structured or legacy `# stage:` labels
- `# lane:`
- `# advance:`

Stage bodies remain separate. After the operator presses `y`, ii copies the
first rendered stage and prompts before each following stage, for example:

```text
Stage 2/3 ready for copy
lane2: remote-receiver | powershell | Start receiver
Press y to copy, n/Esc to abort.
```

Each accepted stage replaces the clipboard with that stage body. Copy does not
send to a pane or execute; the operator decides where and whether to paste it.
Blank lines and ordinary comments belonging to a stage remain unchanged.
Rendering follows the normal variable-source rules for `ii p`; it does not use
the popup's tmux-only rule.

## Open Decisions

- Whether a separate public command is needed later for direct one-pane send;
  workflow execution itself uses the existing payload selector actions.
- Whether completion-marker wrapping is useful enough to justify shell-specific
  behavior in a later schema version.
- Whether control-key stages such as sending Ctrl-C should ever share the same
  workflow schema or remain a separate, more privileged action.

### Pending: pane-output advancement and branching

Discuss before implementation:

- Add a bounded `output PATTERN timeout SECONDS` advancement mode before
  introducing general branching.
- Capture a pane baseline before sending the stage and match only output
  observed afterward, so text already in pane history cannot satisfy the rule.
- Treat patterns as data, never shell code; define whether the first version
  uses literal matching or a restricted regular-expression syntax.
- On timeout, provide explicit retry, continue, and abort choices. A missing or
  replaced pinned pane still aborts immediately.
- Show the matched output and rule before advancing so the operator can audit
  the decision.
- Defer `case` branching until stages have stable, unique IDs. Branch targets
  should use those IDs rather than positional stage numbers.
- Before enabling branches, define validation for missing targets, duplicate
  IDs, match priority, default behavior, cycles, and a maximum transition
  count.

None of these decisions blocks the first implementation. The concrete tmux
session-option encoding for remembered assignments is an implementation detail;
its semantic key is the complete lane name and its value is the concrete pane
ID.

## Implemented Interaction Contract

The first-version behavior below is implemented. Later advancement modes,
completion wrapping, control-key stages, and a separate one-pane public command
remain deferred.

### Selector notation

The spatial pane map displays one status line above every assigned pane. Its
minimum content is the ordinal, generated label, complete lane name, and source:

```text
> [1/lane1] kali-sender · detected
┌──────────────────────────┐
│ %3  zsh                  │
└──────────────────────────┘
```

`>` marks the active lane without relying on color. Space toggles the active
lane at the cursor. Number keys assign a specific ordinal; a conflict swaps
assignments. Enter confirms all assignments, while Escape and `q` abort.

#### Remembered lane suggestions

The required behavior is:

- Only an assignment included in a completed Enter confirmation is remembered.
- The complete lane name is the lookup key and the concrete pane ID is its
  session-scoped value.
- A valid remembered pane is preselected next time, but still requires operator
  confirmation and cannot already belong to another lane. It takes precedence
  over a newly detected suggestion.
- A missing pane, a pane outside the pinned session, or a conflicting binding
  clears the invalid binding and falls back to detection or manual selection.
- A confirmed manual change replaces the remembered value. Merely opening or
  aborting the selector never writes remembered state.
- The first version does not need `--remember`.

### Safety requirements

#### Never downgrade a malformed opted-in workflow

Once a file declares a supported workflow opt-in such as `# flow: 1`, an
invalid stage, lane, advancement directive, or other workflow parse error must
show source line information and abort. It must never fall back to ordinary
payload `eval`, because that could execute mixed host and remote bodies in the
originating shell.

Duplicate markers and unsupported workflow versions should also be rejected
rather than treated as legacy payloads.

#### Parse before ordinary render and copy

For an opted-in workflow, ordinary render and copy should also require a
successful complete parse before producing output. This prevents misspelled or
misplaced workflow metadata from leaking into copied content as if it were an
ordinary comment. Legacy combo files without the opt-in marker retain their
legacy parsing behavior.

#### Shell metadata remains advisory

The declared stage shell is displayed in preview and may produce a warning, but
it does not prove the shell behind a reverse connection. It must not rewrite
commands, automatically switch shells, or block a confirmed send merely because
the local pane foreground command cannot verify it.

#### Workflow execution requires tmux

If a workflow is selected for execution outside tmux, or if the popup cannot be
created with a valid originating pane and session, execution should abort with
a clear message. It must not fall back to local `eval`. Ordinary render/copy
remains available outside tmux, and non-workflow payloads keep their existing
behavior.

## Implementation Boundaries

Workflow support integrates with the existing payload selector only at the
execute-routing boundary and remains internally separable from ordinary payload
rendering and `ii load --all-pane`. The implementation boundary is:

```text
workflow parser       parse and validate metadata and stage bodies
workflow tmux         resolve, select, pin, revalidate, and send to panes
workflow command      preview, confirm, and orchestrate stages
```

Only narrow primitives should be shared with existing features:

- Reuse `ii_payload_render_text` to render each already-parsed stage.
- Extract pane discovery and pane snapshot helpers from the concepts currently
  used by `ii la`; keep `ii la` bulk selection and workflow lane assignment as
  separate interaction policies.
- Extract the literal tmux buffer transport from `ii pice` into a helper that
  accepts only a pinned pane ID and rendered text. It must not parse workflows
  or choose a target.

The workflow parser should not access tmux, the renderer should not understand
lanes, and the send helper should not understand stages. Existing ordinary
payload paths should not acquire execution behavior from the workflow parser.

## Pane Selection Assistance

### Spatial target selection

The popup draws pane rectangles from tmux layout geometry (`pane_left`,
`pane_top`, `pane_width`, and `pane_height`). This resembles tmux's visual pane
presentation: the operator sees panes above, below, and beside one another at a
glance and checks the rectangles directly. It is not a linear fzf list with
direction labels.

Every lane target is resolved at workflow startup to a distinct concrete tmux
pane ID and pinned. Later layout changes must not cause the runner to
recalculate the destination.

The originating pane may preselect the first `kali-*` lane. Selection
assistance for the remaining lanes can use:

- A remembered concrete lane binding for the session.
- Spatial proximity visible directly in the pane map.
- Advisory foreground-command and pane-content signals for `remote-*` lanes.

Before every stage, the runner verifies that its pinned pane still exists in
the original session. If a pane disappears during execution, the workflow
aborts immediately and the popup reports the missing pane and pending stage. It
must prompt the operator and must not substitute another pane or recompute the
layout.

### Assisted remote-shell candidate selection

ii ranks or preselects a likely remote-shell pane, followed by explicit human
confirmation. This is advisory only: tmux normally exposes the local foreground
process (`nc`, `socat`, `ssh`, `python3`, and similar), not authoritative facts
about the operating system attached to that process. It therefore cannot
reliably prove that a pane is "non-Kali" or that it contains a usable remote
shell.

Weak signals may include:

- The pane is not the originating Kali pane.
- Its foreground command commonly carries an interactive connection, such as
  `nc`, `ncat`, `socat`, or `ssh`.
- Pane title or recent visible output resembles a PowerShell, cmd, Windows, or
  other remote prompt.
- A previous session-scoped lane suggestion still points to the pane.
- The pane occupies a nearby position visible in the spatial pane map.

These signals assign labels such as `likely remote` and may preselect a pane
while assigning a `remote-*` lane. They must not automatically execute a stage,
override an explicit target, or treat captured pane output as trusted data. The
preview must always show the resolved concrete pane, foreground command, and
the reason for the suggestion before the operator confirms it.

## Implementation Record

Implementation was divided so parsing and ordinary render/copy safety could be
verified without tmux before interactive workflow execution was introduced.

### Phase 1: Parser and data contract

- Add `lib/workflow.zsh` and source it before `lib/payloads.zsh`.
- Implement an exact, line-oriented parser for `# flow: 1`, file metadata,
  structured stage/lane/advance headers, bodies, and source line numbers.
- Store ordered stages and first-appearance lane order in workflow-owned global
  arrays/maps. Reject duplicate or unsupported flow markers, malformed header
  adjacency, empty bodies, invalid lane names, unsupported
  advancement modes, and more than three distinct lanes.
- Provide a cheap classification entrypoint that distinguishes legacy payloads,
  valid workflows, and malformed opted-in workflows without invoking tmux.
- Add shell-level parser fixtures covering valid one/two/three-lane workflows,
  repeated lanes, CRLF input, metadata placement, every required parse failure,
  and proof that legacy `# stage:` comments remain legacy.

Exit criterion: parser tests assert stage text, lane ordering, metadata, line
numbers, and nonzero diagnostics for every invalid opted-in file.

### Phase 2: Render, preview, and staged copy integration

- Route `ii_payload_preview_text`, `ii_payload_render`, and selector copy through
  the workflow classifier before legacy `ii_payload_body` processing.
- Render each parsed stage independently with `ii_payload_render_text`; preserve
  blank lines and ordinary stage comments and aggregate variable reports without
  merging stage bodies.
- Format workflow previews with description, notes, ordinal, complete lane name,
  shell, title, advancement mode, and separately rendered bodies.
- Implement sequential copy confirmation. Each accepted stage replaces the
  clipboard; cancellation never copies a later stage.
- Change `ii pc` and `ii p --copy` without `--input` to open the normal selector
  with keywords as the initial query, matching the decided payload-file action
  behavior. Keep `--input` behavior independent.
- Ensure every malformed opted-in workflow aborts preview, render, copy, output,
  and execute paths with no legacy fallback.

Exit criterion: non-tmux tests prove legacy output is unchanged, workflow stages
stay separate, copy order is deterministic, and malformed workflow content
cannot reach output, clipboard, or `eval`.

### Phase 3: Shared tmux primitives

- Extract general pane/session snapshot and discovery helpers from the narrow
  concepts in `ii_load_pane_snapshot` and `ii_load_pane_entries`; keep `ii la`
  selection policy and its current-window restriction unchanged.
- Extract the literal buffer send sequence from the popup input path into a
  helper accepting only pinned session ID, pane ID, and rendered text. It owns
  unique buffer creation, paste, final Enter, cleanup, and precise failures.
- Reuse that helper from the generic tmux input popup first to prove no behavior
  regression.
- Make workflow revalidation identity-based: same pane ID, same session,
  distinct lane targets, and successful transport. Do not reject command,
  title, content, window, position, or size changes.

Exit criterion: existing pice smoke behavior passes through the extracted
transport, including pane disappearance and buffer/paste/Enter failures.

### Phase 4: Spatial selector and session memory

- Add a workflow-specific popup selector rather than extending the linear fzf
  policy used by `ii la`.
- Enumerate windows in the pinned session, select one window at a time, and draw
  pane rectangles from `pane_left`, `pane_top`, `pane_width`, and `pane_height`.
- Build initial assignments in lane order: valid remembered complete-lane
  binding first, then role-based detection, then the best remaining candidate.
- Render the extra assignment line above each assigned pane, including ordinal,
  generated label, complete lane name, source, and a non-color active marker.
- Implement cursor movement, Space toggle, direct `1`/`2`/`3` assignment,
  occupied-pane swap, empty-pane move, window navigation, Enter validation, and
  Escape/`q` abort.
- Store confirmed complete-lane-to-pane bindings in one session-scoped tmux user
  option with an encoding that round-trips valid lane names safely. Clear stale,
  cross-session, duplicate, and conflicting values while loading suggestions.

Exit criterion: deterministic selector-state tests cover initialization,
toggle/move/swap, incomplete confirmation, abort-without-write, confirmed memory
updates, stale cleanup, and layouts with one through three lanes.

### Phase 5: Workflow orchestrator and execute routing

- Add a workflow popup entrypoint that receives the selected absolute file,
  originating pane, and session ID. The selected file is reparsed inside the
  popup and is the sole authority for workflow routing.
- At the existing selector execute boundary, route a valid opted-in combo to the
  popup; continue executing legacy payloads in the current shell. Never route
  from a guessed keyword or free-form popup command.
- Pin all confirmed pane IDs before stage 1. For each stage, render using
  tmux-session variables only, show target and command preview, obtain its
  `confirm` authorization, revalidate every pinned destination, and literal-send
  the stage.
- Starting at stage 2, word the confirmation so it also records that the
  preceding stage is ready. Do not add a post-send completion prompt.
- Abort on any rejected confirmation or identity/transport failure, report the
  failed and pending stage, and never substitute or recalculate a target.
- Keep workflow execution unavailable outside tmux with a clear error and no
  local-eval fallback.

Exit criterion: isolated tmux smoke tests exercise alternating lanes, repeated
lane reuse, user abort before every stage, pane disappearance, harmless command
and layout changes, unresolved variables, and exact ordered pane input.

### Phase 6: Documentation and regression completion

- Update payload schema, usage, help, architecture, tmux integration, and testing
  documentation together with representative executable combo payloads.
- Extend `script/help` expectations for the changed selector-copy semantics
  without adding a public workflow command.
- Run syntax checks, plugin-load and help audits, legacy payload render/copy
  checks, pice regression tests, parser tests, and isolated multi-pane tmux smoke
  tests.
- Move or rename this pending document only after all first-version exit
  criteria pass; retain deferred decisions in the permanent workflow design
  documentation.
