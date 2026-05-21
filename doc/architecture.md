# Architecture

`jj` is plugin-first. The only public loading entrypoint is:

```text
jj.plugin.zsh
```

Do not source files under `lib/` directly. They are implementation layers loaded
by the plugin entrypoint in dependency order.

## File Layout

```text
jj.plugin.zsh
lib/
  tmux.zsh
  clipboard.zsh
  vars.zsh
  payloads.zsh
  help.zsh
  core.zsh
payloads/
  shell/
  xss/
doc/
  architecture.md
  testing.md
```

## Load Order

`jj.plugin.zsh` loads layers in this order:

```text
1. lib/tmux.zsh
2. lib/clipboard.zsh
3. lib/vars.zsh
4. lib/payloads.zsh
5. lib/help.zsh
6. lib/core.zsh
```

`core.zsh` is loaded last because it exposes the public dispatcher and wrapper
functions. The functions it dispatches to are already defined by the earlier
layers.

## Layers

### `jj.plugin.zsh`

Plugin entrypoint.

Responsibilities:

- Resolve the plugin root path.
- Set `JJ_PLUGIN_DIR` to the plugin root when unset.
- Set `JJ_PAYLOAD_DIR` to `${JJ_PLUGIN_DIR}/payloads` when unset.
- Source each implementation layer.
- Avoid exposing path setup variables after loading.

This lets Kali deployments use bundled payloads without adding a separate
`export JJ_PAYLOAD_DIR=...` line to `~/.zshrc`.

### `lib/tmux.zsh`

External environment helpers.

Responsibilities:

- Check whether the current shell is inside tmux.
- Check whether required external commands exist.
- Read tmux session identity when needed.

Functions:

```text
jj_tmux_available
jj_tmux_session_name
jj_require_cmd
```

### `lib/vars.zsh`

Tmux session variable management.

Responsibilities:

- Normalize user names like `LHOST` into `JJ_LHOST`.
- Set, load, list, filter, and unset `JJ_` variables.
- Export safe `NAME=VALUE` lines into the current shell.

Commands:

```text
jj_cmd_set
jj_cmd_load
jj_cmd_interactive
jj_cmd_variable
jj_cmd_unset
```

Helpers:

```text
jj_var_normalize_name
jj_var_lines_from_tmux
jj_var_filter_by_name
jj_export_var_line
```

### `lib/payloads.zsh`

Payload library scanning and rendering.

Responsibilities:

- Resolve `JJ_PAYLOAD_DIR`.
- List payload files as path-style selector entries.
- Filter payloads by category or fuzzy prefilter.
- Render `${JJ_NAME}` placeholders using fresh tmux session values.
- Print the rendered payload and variables used.

Commands:

```text
jj_cmd_payload
```

Helpers:

```text
jj_payload_dir
jj_payload_list
jj_payload_filter
jj_payload_select_fzf
jj_payload_path_for
jj_payload_render
jj_payload_required_vars
jj_payload_print_used_vars
```

Render boundary:

```text
Input:
  - selected payload file
  - tmux session JJ_ variables

Output:
  - rendered payload text
  - used-variable report
```

The render layer must not depend on the current pane's shell environment. This
keeps cross-pane rendering correct when pane 2 has not run `jjl` yet.

Fuzzy boundary:

```text
Input:
  - path-style payload entries
  - optional category filter

Output:
  - exactly one selected payload entry
```

In non-interactive `fzf --filter` mode, multiple matches can be returned. The
payload layer intentionally keeps the first non-empty line so test mode remains
deterministic.

### `lib/clipboard.zsh`

Clipboard backend handling.

Responsibilities:

- Prefer `JJ_CLIP_CMD` when configured.
- Auto-detect common clipboard tools.
- Fall back to tmux buffer when available.
- Copy through stdin when possible so payload content is not passed as a tmux
  command argument.

Functions:

```text
jj_clip_copy
jj_clip_backend_detect
```

Current tmux fallback:

```zsh
print -rn -- "$text" | tmux load-buffer -
```

This is intentionally stdin-based. It is more stable for payloads containing
spaces, quotes, shell metacharacters, and HTML-like text.

### `lib/help.zsh`

Help routing.

Responsibilities:

- Route `jj help COMMAND` to each command's own `--help` implementation.
- Print the top-level command summary.

Functions:

```text
jj_cmd_help
```

### `lib/core.zsh`

Public command interface.

Responsibilities:

- Dispatch `jj COMMAND` to layer command functions.
- Define wrapper functions.

Public functions:

```text
jj
jjs
jjl
jji
jjv
jjp
jjh
```

## State Model

`jj` deliberately keeps two states separate:

```text
tmux session environment = shared state across panes
current shell environment = local state for one pane
```

`jjs` writes to both tmux and the current shell.

`jjl` copies tmux `JJ_` values into the current shell.

`jjp` does not depend on current shell values. It reads tmux session values
directly at render time, so another pane can render immediately after `jjs`
runs elsewhere.

## Layer Boundaries

Keep these responsibilities separate:

```text
variable loading layer:
  - read tmux JJ_ values
  - validate names
  - strip JJ_ only for variable TUI display
  - map selected display lines back to JJ_ before export
  - export selected values into current shell

fuzzy search layer:
  - present candidate lines
  - return selected lines
  - avoid mutating state

payload render layer:
  - read selected template
  - read tmux JJ_ values fresh
  - return rendered text

copy layer:
  - receive rendered text
  - copy via configured or detected backend
  - avoid breaking inside tmux
```
