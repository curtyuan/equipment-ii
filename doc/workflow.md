# Executable Combo Workflows

Combo workflows are stored payloads that opt into Go-owned multi-pane execution
with `# flow: 1`. Files without that marker remain ordinary Zsh payloads.

## Ownership

- Zsh selects the payload, renders ordinary payloads, asks for combo execution
  confirmation, and launches one internal `ii-go` command.
- Go parses opted-in workflows, resolves lanes, presents pane assignment,
  renders stages from tmux-session variables, and sends confirmed stages.
- Tmux supplies session variables, pane identity, assignment memory, and literal
  buffer transport.

The Go helper exposes only `__combo-render`, `__combo-copy`, and `__combo-run`.
There is no public workflow command or background process.

## File Format

```text
# description: Kali sends a file to a target
# flow: 1
# note: The target must already have powercat.

# stage: powershell | Receive file
# lane: remote-transfer
# advance: confirm
powercat -l -p $rport -of "${file:t}"

# stage: zsh | Send file
# lane: kali-transfer
# advance: confirm
nc -q 0 $rhost $rport < $file
```

Rules:

- `# flow: 1` appears exactly once before the first stage.
- A stage begins with `# stage: SHELL | TITLE`.
- `# lane: kali-NAME|remote-NAME` immediately follows the stage header.
- `# advance: confirm` immediately follows the lane.
- Every stage has a non-empty body.
- At most three distinct complete lane names are accepted.
- Repeated complete lane names reuse the same pane.
- Invalid opted-in files fail with source-line information and never fall back
  to ordinary execution.

`# description:` is optional first-line display metadata. Repeated `# note:`
lines before the first stage are optional operator notes. Payload command text
remains plain text; Markdown fences are not supported.

## Rendering

Each stage is rendered independently. Lowercase `%name%`, `$name`, `${name}`,
and `${name:t}` placeholders use tmux-session `ii_` variables. Uppercase and
legacy `II_NAME` tokens remain unchanged. Missing lowercase values remain
visible and are reported before confirmation.

Ordinary payload rendering may use current-shell values first. Combo execution
does not inherit the originating shell's local values because it runs in an
isolated popup.

## Entry and Actions

The stored-payload selector determines the selected file. Keywords only seed
the selector query.

- Enter renders a selected workflow.
- `ii pc` or copy mode copies confirmed stages in file order.
- `e`, `ii pe`, or execute mode asks for workflow confirmation and opens the
  Go-owned popup.
- `ii pce` enables copy during confirmed workflow execution.

Non-workflow payload execution remains current-shell Zsh `eval` behavior.

## Lane Assignment

Every distinct lane is assigned to one distinct pane in the current tmux
session. The selector displays one window's spatial pane layout at a time.

- Arrow/navigation keys move through panes.
- Space assigns or clears the active lane.
- `1`, `2`, and `3` assign the corresponding lane ordinal.
- Assigning an occupied pane swaps assignments.
- Enter accepts only a complete, distinct assignment.
- Escape or `q` aborts without sending input.

Initial suggestions prefer valid remembered assignments, then role-based pane
hints, then remaining panes. Detection is advisory and never authorizes
execution. Confirmed complete-lane bindings are remembered in the current tmux
session and remain editable on later runs.

## Execution Safety

All pane IDs are pinned before stage execution. Before every send, Go verifies
that the pane still exists in the pinned session and does not alias another
lane. Pane title, foreground command, layout, and visible content may change
without invalidating the identity.

Each `# advance: confirm` prompt authorizes one stage. Confirmation for a later
stage also records that the operator considers the previous stage ready; it
does not prove process completion.

Stage text is transported literally through a temporary tmux buffer, followed
by one Enter. It is never interpolated into a `tmux send-keys` command. A pane
identity change, buffer failure, rejected confirmation, or unavailable tmux
session aborts pending stages without choosing a replacement pane.

## Implementation Map

```text
src/zsh/lib/ordinary_payload.zsh          Zsh selection and combo handoff
src/zsh/lib/ordinary_payload_render.zsh   shared rendering contract
src/go/internal/payload/             parser, assignments, runner
src/go/internal/terminal/            pane selector and confirmation UI
src/go/internal/adapter/tmux/         panes, memory, literal transport
src/go/internal/adapter/clipboard/    combo copy transport
src/go/internal/cli/                  internal ii-go entrypoints
```

Automated coverage is described in [testing.md](testing.md). The exact stored
payload schema is described in [payload-schema.md](payload-schema.md).

## Deferred Ideas

Automatic completion detection, conditional branching, rollback, retries,
parallel stages, and control-key stages are not implemented. Adding any of
them requires a new explicit payload schema rather than inference from command
text or captured pane output.
