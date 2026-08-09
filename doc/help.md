# Help System

Public help is Zsh-owned. `lib/ordinary_help.zsh` maps public aliases and nested
forms to static files under `help/`; `lib/ordinary_runtime.zsh` sends all help
and version forms there without starting Go.

Each help file follows this order:

```text
usage: command forms

Aliases:
  true alternatives, or none

Help:
  representative ways to open this help
```

Alias names are cyan only when the shared Zsh color policy enables ANSI.
Unknown commands and help topics return status 2. The public contract checks
status, stdout, stderr, alias coloring, version, and that help does not invoke
the Go helper.

When a route changes, update its `help/*.txt` file, the Zsh help resolver,
`doc/usage.md`, and the public routing contract together. Removed options have
explicit status and stderr contracts and must not silently become search terms.
