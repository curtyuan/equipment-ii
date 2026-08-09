# Tmux Integration

Status: implemented.

Tmux popup input execution is available by default after `ii.plugin.zsh` is
loaded inside tmux. Integration adds `ii` to tmux's native command language
through the server-level `command-alias[]` option. It does not replace or wrap
the `Prefix + :` key binding.

## Behavior

- Loading `ii.plugin.zsh` inside tmux idempotently installs the tmux command
  alias `ii`.
- `Prefix + :` remains tmux's native command prompt, or whatever custom binding
  the user configured.
- Entering `ii` in that prompt opens an isolated popup equivalent to shell
  command `ii pie`: input, tmux-only render, confirmation, literal send to the
  originating pane, and one final Enter. It does not copy to the clipboard.
- `ii pice` remains the shell alias for input, copy, and execute. Its legacy
  popup helper delegates to the same generic helper in copy mode.
- There is no per-session enable/disable state. `ii tmux status` is read-only.
- The alias belongs to the tmux server containing the shell that loaded the
  plugin; integration never crosses servers.

Static configuration controls automatic setup:

```zsh
II_TMUX_INTEGRATION=1        # default
II_TMUX_INTEGRATION=0        # do not install or update the alias
II_TMUX_INTEGRATION_FORCE=1  # replace a conflicting alias named ii
```

## Default Load Behavior

After configuration and plugin functions are loaded:

```text
not inside tmux
  -> do nothing

II_TMUX_INTEGRATION=0
  -> do nothing

current ii alias has the same version, index, and helper
  -> leave it unchanged

no command alias named ii
  -> choose an unused command-alias[] index and install it

another command alias named ii
  -> force=1: replace that alias at its existing index
  -> otherwise: preserve it and report one conflict notice
```

Repeated plugin loads are silent. The installer must not occupy an existing
array index. It scans the server's complete `command-alias[]` array and chooses
an unused index starting at 100.

## Native Tmux Command

The installed array value is conceptually:

```tmux
set-option -s command-alias[INDEX] \
  "ii=display-popup -EE -T 'ii pie VERSION' -w 90% -h 90% \
  -d '#{pane_current_path}' /absolute/path/to/script/ii-tmux-popup \
  execute '#{pane_id}' '#{session_id}'"
```

`command-alias[]` is a native tmux server option. When tmux parses the unknown
command `ii`, it expands the alias to `display-popup`. No command-prompt input
is intercepted and no fallback dispatcher is involved. The installer verifies
that the packaged Zsh helper is executable before publishing
the alias.

The intended interaction is:

```text
Prefix + :
  -> native tmux command prompt
  -> enter ii
  -> isolated ii pie popup
```

Arguments are not part of the public contract; use exactly `ii`.

## Popup Entrypoint

The native alias enters the packaged Zsh popup helper directly:

```text
tmux command alias
  -> display-popup
  -> script/ii-tmux-popup execute ORIGIN SESSION
  -> render and confirm
  -> validate and send to the originating pane
```

The native `:ii` alias therefore renders, confirms, sends, and executes without
copying.

The Zsh ZLE reader preserves the popup editing contract: Enter finishes,
Alt-Enter inserts a newline, Esc cancels, and `:q`/`:q!` cancel a complete
buffer. Streamed input supports EOF and the standalone `:w` finish line.

The alias captures `#{pane_id}` and `#{session_id}` when opening the popup. The
helper snapshots the pane and uses both values for the final pre-send identity
check.

The popup process cannot rely on the originating pane's functions or startup
state. Running the controller in a popup also leaves the originating pane at
its shell so pasted input cannot be consumed by the controller.

Popup rendering uses tmux-session `ii_` variables only. It previews the target,
foreground command, render report, unresolved variables, and rendered body
before confirmation.

Confirmed text is transported literally:

```text
rendered text
  -> tmux load-buffer
  -> tmux paste-buffer to the pinned pane
  -> tmux send-keys Enter
```

Payload text is never passed as a `tmux send-keys` command argument.

## Installation Marker

The global user option `@ii_integration_marker` identifies ii's installed
alias. Its value contains:

```text
version=2 index=INDEX helper=/absolute/path/to/ii-go
```

The marker lets ii refresh its own alias without treating an unrelated array
entry as owned. A marker whose index is missing or no longer contains the
expected ii command is stale and does not authorize overwriting another alias.

`@ii_integration_conflict_notice` suppresses repeated conflict messages for the
same integration version and helper.

## Same-name Conflict

If a user already has a tmux command alias named `ii`, automatic installation
leaves it unchanged and reports once:

```text
ii: tmux command alias 'ii' is already defined; ii popup alias was not installed
ii: set II_TMUX_INTEGRATION_FORCE=1 to replace it, or II_TMUX_INTEGRATION=0 to silence this notice
```

Force mode replaces only the conflicting `ii` array entry. It does not modify
other aliases or the `Prefix + :` binding.

## Migration from the Prefix Adapter

Versions before schema 2 replaced `Prefix + :` with an ii-owned dispatcher that
intercepted the exact text `ii pice`. During automatic installation, schema 2
recognizes that old binding and restores:

```tmux
bind-key -T prefix : command-prompt
```

Only a binding positively recognized as the old ii adapter is restored.
Unrelated custom bindings remain untouched.

Legacy options `@ii_colon_binding`, `@ii_colon_binding_saved`, and per-session
`@ii_dispatch_enabled` are cleared after successful installation.

## Status Command

`ii tmux status` is read-only:

```text
server: /tmp/tmux-1000/default
configured: default | disabled | force
command alias: installed | missing | stale | conflict
command: ii
helper: /absolute/path/to/ii-go
Prefix+: native or user-defined | legacy ii adapter
```

Status never installs, repairs, enables, disables, or migrates anything.
Automatic repair occurs only while loading the plugin with integration enabled.

## Failure Behavior

- Failure to inspect or install the alias does not abort the rest of plugin
  loading.
- A missing or non-executable Go runtime leaves the alias uninstalled.
- A same-name conflict is preserved unless force mode is explicitly configured.
- A disappeared target pane, buffer creation failure, paste failure, or final
  Enter failure is reported in the popup.
- The `-EE` popup remains visible when the helper exits unsuccessfully.

## Regression Coverage

`script/test-tmux-integration` uses an isolated tmux server and verifies:

- native binding preservation;
- unused-index installation;
- repeated idempotent loads;
- read-only status;
- same-name conflict preservation;
- force replacement;
- migration from the legacy Prefix adapter.

Popup transport and pane identity are covered by `script/test-workflow-tmux`.
