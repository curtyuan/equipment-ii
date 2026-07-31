# Feature Inventory

This document is the live migration inventory. The frozen legacy design remains
in `ori-ii/doc/architecture.md`; the current Go design is described in
`doc/architecture.md`.

## Status Meanings

- **Go**: the public route and its behavior are implemented in Go.
- **Hybrid**: Go owns part of the route or provides a reusable foundation, but
  the compatibility bridge still owns user-visible behavior.
- **Legacy**: the Zsh compatibility bridge still owns the feature.
- **Foundation**: reusable Go support exists, but the public feature has not
  migrated yet.

## Current Inventory

| Feature family | Status | Current owner | Remaining work |
| --- | --- | --- | --- |
| Bootstrap and configuration | Hybrid | Go plus compatibility bridge | Reduce bridge-only environment setup after dependent routes migrate. |
| Route resolution and dispatch | Go | `internal/cli` | Replace remaining resolver special cases with one declarative command specification. |
| Version and top-level help | Go | `internal/cli` | Keep help registration aligned with command specifications. |
| Variable families (`s`, `g`, compact forms) | Go | `internal/variables` and `internal/cli` | Consolidate repeated CLI parsing and help wiring. |
| Clipboard | Go | `internal/clipboard` and adapters | No migration blocker; retain platform contract tests. |
| Payload catalog and stored payload actions | Hybrid | Legacy routes over Go payload foundations | Move selection, copy, execute, and related help into Go. |
| Pasted payload input | Go | `internal/payload` and `internal/cli` | Reuse the input renderer from future input-consuming routes. |
| Tmux alias installation and popup execution | Go | `internal/tmux` and `internal/cli` | Split the concrete session adapter into smaller interfaces over a shared runner. |
| `/www` publication and browsing | Hybrid | Go owns `--file`, `ls`, `search`, and `ln`; legacy owns child help | Complete help parity and semantic differential contracts. |
| Workflow helpers | Hybrid | Legacy routes plus Go environment/pane foundations | Define migration order after `/www` and payload completion. |
| Build, generated wrappers, and compatibility bridge | Hybrid | Make targets and generated shell | Remove bridge paths only after parity and shell-usage checks pass. |

## `/www` Functional Inventory

The legacy implementation exposes two route spellings for publication:
`p --www --file PATH` and `p www --file PATH`. Both must resolve to the same Go
operation.

### Publish a file

- Require a regular source file.
- Render and report the file contents using the payload input rules.
- Resolve the source to an absolute path.
- Create a symbolic link in `${II_WWW_ROOT:-/www}/p` using the source basename.
- Link the original source file; do not copy generated contents.
- Refuse to overwrite an existing destination.
- Return the body/report, link path, analysis-relative directory, absolute
  source path, and shell assignments required by the compatibility contract.

### Create a link

- Route: `www ln SOURCE [LINK_NAME]`.
- Require the configured web root to exist.
- Select a destination directory when the route requires interactive choice.
- Reject an empty name, names containing `/`, and `.` or `..`.
- Refuse to overwrite an existing destination.

### List entries

- Route: `www ls`.
- Walk entries deterministically.
- Include files, directories, and symbolic links.
- Do not follow symbolic-link targets while walking.

### Search entries

- Route: `www search [FILTER]`.
- Select an entry using the selector adapter.
- Return the relative containing directory and absolute selected path.

### Help and compatibility

- Preserve the legacy route spellings and accepted `file` / `--file` forms.
- Keep machine-readable output stable enough for the generated shell bridge.
- Add semantic contract tests before removing the legacy implementation.

## Structural Work Before `/www`

Completed in the current refactoring checkpoint:

- Replaced the positional CLI constructor with named `Dependencies`.
- Split hidden shell-bridge entrypoints from public command dispatch.
- Added a shared `Resolution` entry used by routing and public dispatch.
- Added a reusable payload `InputRenderer` for public input and tmux popup
  execution.
- Split CLI composition, dispatch, resolution, and variable-family behavior
  into responsibility-specific files.
- Added the `/www` domain service, feature-owned Store interface, filesystem
  adapter, and initial safety tests.

Still open:

- Consolidate remaining route-owner and canonical-command special cases into a
  declarative command specification.
- Separate the concrete tmux session environment into environment, pane, and
  integration adapters backed by one command runner.
- Complete `/www` child help parity and semantic differential contracts.
- Remove `/www` path policy from payload output after compatibility behavior is
  covered by contracts.
