# Tmux Integration

Status: implemented.

Tmux popup input execution is available by default after `ii.plugin.zsh` is
loaded inside tmux, while avoiding silent replacement of a custom
`Prefix + :` binding. This replaces the former per-session
`ii tmux enable` / `disable` state.

## Behavior

- Tmux integration is enabled by default. Loading `ii.plugin.zsh` from a shell
  inside tmux idempotently ensures that the server-wide adapter is installed.
- There is no per-session enable/disable state and no
  `@ii_dispatch_enabled` option.
- `ii tmux enable` and `ii tmux disable` are removed. `ii tmux status` remains
  as a read-only diagnostic command.
- The adapter intercepts only the exact command `ii pice`. All other input is
  executed as an ordinary tmux command, preserving the standard `Prefix + :`
  command-prompt workflow.
- Repeated plugin loads are silent and do not reinstall an identical binding.
  A changed helper path or integration version causes an idempotent binding
  refresh.
- Automatic integration never crosses tmux servers. The binding and its marker
  belong to the server containing the shell that loaded the plugin.
- Static configuration replaces runtime enable/disable state:

  ```zsh
  II_TMUX_INTEGRATION=1        # default
  II_TMUX_INTEGRATION=0        # do not install or update the adapter
  II_TMUX_INTEGRATION_FORCE=1  # replace a detected custom Prefix + : binding
  ```

- A standard tmux `Prefix + :` command-prompt binding may be replaced
  automatically because the adapter preserves its normal command-entry
  behavior.
- A non-standard custom `Prefix + :` binding is never overwritten silently.
  ii reports the conflict once and leaves the custom binding unchanged unless
  `II_TMUX_INTEGRATION_FORCE=1` is set.
- Force mode replaces the custom binding but does not attempt to emulate its
  behavior. This consequence must be stated in the conflict message and user
  documentation.

## Default Load Behavior

After configuration is read and the tmux integration functions are available,
plugin loading follows this decision flow:

```text
not inside tmux
  -> do nothing

II_TMUX_INTEGRATION=0
  -> do nothing

ii adapter already installed with the same version and helper path
  -> do nothing

Prefix + : is the standard command-prompt binding
  -> install or refresh the adapter

Prefix + : is a non-standard custom binding
  -> force=1: replace it
  -> otherwise: leave it unchanged and report one conflict notice
```

The automatic check must be safe to run from every interactive pane. It must
not print success messages during ordinary shell startup.

## Adapter Behavior

The installed adapter opens the normal tmux command prompt. After submission:

```text
exactly "ii pice"
  -> open the isolated ii pice popup

anything else
  -> execute it as the entered tmux command
```

Matching is exact. Leading or trailing whitespace, arguments, aliases, and
other `ii` commands are not accepted by this dispatcher. The popup continues
to receive the originating pane ID and session ID, render from tmux-session
variables only, confirm, literal-paste through an ii-owned tmux buffer, and send
one final Enter.

The same popup boundary is used by executable combo workflows selected through
`ii p`; workflow routing does not broaden the exact free-form dispatcher input.

## Installation Marker and Refresh

The implementation uses the server-wide `@ii_integration_marker` tmux user
option containing the adapter schema version and resolved popup helper path.
This is an installation marker, not an enable/disable state. Its value has the
form:

```text
version=1 helper=/absolute/path/to/script/ii-tmux-pice
```

The separate `@ii_integration_conflict_notice` option suppresses duplicate
conflict notices for the same schema version and helper path. These markers
allow ii to distinguish:

- its current adapter;
- an older ii adapter that needs refreshing;
- the standard tmux command-prompt binding;
- an unrelated custom binding.

A stale marker without the matching installed binding is repaired. A matching
marker must not authorize overwriting a binding that has since been customized
by the user.

## Custom Binding Conflict

Conflict detection must inspect the effective `prefix` key-table binding for
`:`, not assume tmux defaults from the presence or absence of an ii option.

Without force, a conflict produces one concise notice per tmux server or plugin
version, not once per pane:

```text
ii: Prefix+: has a custom tmux binding; ii popup integration was not installed
ii: set II_TMUX_INTEGRATION_FORCE=1 to replace it, or II_TMUX_INTEGRATION=0 to silence this notice
```

The conflict path must not modify the binding or store a marker claiming that
the adapter is installed.

With force enabled, ii installs its adapter. Because runtime disable is being
removed, force mode is an explicit configuration choice rather than a temporary
override. Users who later want their old custom binding must restore it through
their tmux configuration.

## Status Command

`ii tmux status` remains read-only and reports enough information to diagnose
default installation:

```text
server: /tmp/tmux-1000/default
configured: default | disabled | force
binding: installed | standard | custom | missing | stale
helper: /absolute/path/to/script/ii-tmux-pice
Prefix+: command: ii pice
```

Status must not install, repair, enable, disable, or otherwise mutate tmux.
Automatic repair occurs only during normal plugin load when integration is not
disabled.

## Failure Behavior

- Failure to inspect or install the binding must not abort loading the rest of
  the plugin.
- A missing or unreadable popup helper leaves the adapter uninstalled and
  produces a clear diagnostic.
- A stale helper path is refreshed only when the current binding is still
  recognized as ii-owned or is the standard binding.
- A custom binding discovered after ii previously installed its adapter is
  treated as user-owned and is not overwritten without force.
- Popup execution retains its existing failure behavior: target disappearance,
  buffer creation failure, paste failure, or final Enter failure is reported in
  the popup.

## Implementation Boundary

The default-install check belongs to `lib/tmux_integration.zsh` and is invoked
from `ii.plugin.zsh` only after configuration and required functions have been
loaded. It should remain separate from the popup runner:

```text
binding inspection/install  -> tmux integration setup
dispatcher adapter          -> exact command routing
popup runner                -> input, render, confirm, copy, and literal send
```

The combo workflow pane selector and orchestrator reuse the popup boundary, but
do not own or duplicate adapter installation.

## Regression Coverage

Regression coverage includes default installation, repeated silent loads,
disabled configuration, forced installation, standard binding passthrough,
custom binding preservation, one-time conflict reporting, stale helper refresh,
read-only status, and exact `ii pice` matching.
