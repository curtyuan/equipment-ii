# Documentation

The docs are split by audience and maintenance task.
Deployment instructions live in the root [README.md](../README.md).

Root documentation describes the current runtime contract. Reviewed public
results are stored in `help/` and `test/fixtures/` rather than generated from
an older executable implementation.

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

Files under `todo/`, when present, track active implementation work. There are
currently no active runtime migration TODOs.
