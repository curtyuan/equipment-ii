# Documentation

The docs are split by audience and maintenance task.
Deployment instructions live in the root [README.md](../README.md).

## User Docs

| File | Purpose |
| --- | --- |
| [usage.md](usage.md) | Command behavior, variable state, interactive variables, payload rendering, and web-root helpers. |
| [clipboard.md](clipboard.md) | Clipboard backend behavior, configuration, diagnostics, and VMware/Kali notes. |
| [tmux-integration.md](tmux-integration.md) | Default Prefix+: popup integration, custom-binding policy, configuration, and status diagnostics. |
| [payload-schema.md](payload-schema.md) | Payload file format, metadata, combo conventions, and renderable variables. |
| [conf/ii.conf](conf/ii.conf) | Example `ii` shell configuration. |
| [conf/tmux.conf](conf/tmux.conf) | Minimal tmux clipboard configuration. |

## Maintainer Docs

| File | Purpose |
| --- | --- |
| [architecture.md](architecture.md) | Load order, layer ownership, state model, and deployment boundary. |
| [help.md](help.md) | Help output contract, per-feature registration, routing, and maintenance workflow. |
| [testing.md](testing.md) | Syntax checks, smoke tests, and regression scenarios. |
| [release.md](release.md) | Version bumping, package build output, and release tagging. |
| [design.html](design.html) | Navigable design map for command behavior, docs ownership, and maintenance checks. |

## Pending Designs

Files under `pending/` describe proposals that are not implemented and are not
part of the live command contract.

| File | Purpose |
| --- | --- |
| [pending/combo-function.md](pending/combo-function.md) | Proposed parser and tmux orchestration model for executable named-lane combo workflows. |
