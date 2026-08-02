# Documentation

The docs are split by audience and maintenance task.
Deployment instructions live in the root [README.md](../README.md).

During the runtime ownership migration, root documentation is the working target contract.
The documentation captured with the executable legacy baseline under
[`../ori-ii/`](../ori-ii/) is the only source of truth for pre-Go behavior.
Paths that still describe root-level `lib/`, `payloads/`, or `script/` belong
to the contract audit and must be reconciled as their features migrate.

## User Docs

| File | Purpose |
| --- | --- |
| [usage.md](usage.md) | Command behavior, variable state, interactive variables, payload rendering, and web-root helpers. |
| [clipboard.md](clipboard.md) | Clipboard backend behavior, configuration, diagnostics, and VMware/Kali notes. |
| [tmux-integration.md](tmux-integration.md) | Native `:ii` tmux command alias, popup execution, conflict policy, and status diagnostics. |
| [payload-schema.md](payload-schema.md) | Payload file format, metadata, combo conventions, and renderable variables. |
| [workflow.md](workflow.md) | Executable combo parser, lane selector, memory, safety, and tmux execution model. |
| [conf/ii.conf](conf/ii.conf) | Example `ii` shell configuration. |
| [conf/tmux.conf](conf/tmux.conf) | Minimal tmux clipboard configuration. |

## Maintainer Docs

| File | Purpose |
| --- | --- |
| [architecture.md](architecture.md) | Current Zsh/tmux/Go ownership and invocation boundaries. |
| [feature-inventory.md](feature-inventory.md) | Live feature ownership, migration status, and the `/www` compatibility inventory. |
| [help.md](help.md) | Help output contract, per-feature registration, routing, and maintenance workflow. |
| [testing.md](testing.md) | Syntax checks, smoke tests, and regression scenarios. |
| [release.md](release.md) | Version bumping, package build output, and release tagging. |

## Active TODOs

Files under `todo/`, when present, track active implementation work. Update
them together with the code and delete each file when its completion criteria
are satisfied.

- [Runtime migration](todo/runtime-migration.md) — finish `p -w`, move the tmux
  popup and payload data, validate packaging, and remove the frozen baseline.
