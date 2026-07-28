# Pending: Compiled Runtime Migration

Status: initial combo/workflow functionality is complete and its automated
regression suite passes. Begin the compiled-runtime refactor before continuing
with pane-output advancement, branching, or further combo-flow changes.

The real PowerShell/powercat end-to-end exercise remains an environment-specific
manual check. It is not represented as an automated pass and should be repeated
when a suitable disposable target is available.

## Direction

Keep Zsh as the thin shell-facing integration layer and evaluate moving
increasingly stateful runtime components into a compiled executable. Do not
begin with a full rewrite.

Language candidates:

1. Go — first candidate because it provides a single deployable binary, fast
   startup, straightforward tmux/PTY/subprocess control, simple cross-compiling,
   and comparatively low maintenance cost.
2. Rust — secondary candidate when stricter type and lifetime guarantees justify
   the higher implementation cost.

Python and Node.js are not preferred for the runtime because they add deployment
and dependency variability without solving the startup-boundary problem as
cleanly as a compiled binary.

## Possible Migration Order

1. Tmux popup input executable.
2. Pane transport and identity validation.
3. Payload parsing and variable rendering.
4. Combo/workflow parsing and orchestration.
5. Reassess whether the public Zsh dispatcher should remain.

## Constraints

- Preserve `ii` as a natural Zsh command and retain shell-local integration.
- Preserve payload and combo file compatibility unless a separately approved
  schema change requires otherwise.
- Migrate incrementally behind existing commands and tests.
- Keep the passing Zsh behavior as the compatibility baseline during migration.
- Do not add deferred combo-flow behavior while the runtime boundary is being
  refactored.
