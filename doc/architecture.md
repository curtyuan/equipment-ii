# Architecture

`ii` is plugin-first. The preferred public loading entrypoint is:

```text
ii.plugin.zsh
```

Do not source files under `lib/` directly. They are implementation layers loaded
by the plugin entrypoint in dependency order.

## File Layout

```text
ii.plugin.zsh
lib/
  tmux.zsh
  clipboard.zsh
  fzf.zsh
  var_helpers.zsh
  var_interactive.zsh
  vars.zsh
  payloads.zsh
  help.zsh
  core.zsh
payloads/
  shell/
  script/
  xss/
doc/
  architecture.md
  testing.md
script/
  make
  help
export/
  ii/
```

## Load Order

`ii.plugin.zsh` loads layers in this order:

```text
1. lib/tmux.zsh
2. lib/clipboard.zsh
3. lib/fzf.zsh
4. lib/var_helpers.zsh
5. lib/var_interactive.zsh
6. lib/vars.zsh
7. lib/payloads.zsh
8. lib/help.zsh
9. lib/core.zsh
```

`core.zsh` is loaded last because it exposes the public dispatcher. The
functions it dispatches to are already defined by the earlier layers.

## Layers

### `ii.plugin.zsh`

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
ii_tmux_available
ii_tmux_session_name
ii_require_cmd
```

### `lib/fzf.zsh`

Shared fzf helpers.

Responsibilities:

- Create single-line previews for list display.
- Read free-form fzf input values.
- Print preview text with independent description and keys blocks pinned around
  the body content.

Functions:

```text
ii_one_line_preview
ii_fzf_print_preview_with_footer
ii_fzf_select_one
ii_fzf_input_value
```

### `lib/var_helpers.zsh`

Variable data helpers.

Responsibilities:

- Normalize user names like `LHOST` into `JJ_LHOST`.
- List, filter, and format `JJ_` variables.
- Export safe `NAME=VALUE` lines into the current shell.
- Enable loaded-variable prompt sync after `ii s` or `ii l`.
- Build default variable candidates for interactive commands.

### `lib/var_interactive.zsh`

Interactive variable UI.

Responsibilities:

- Open fzf flows for variable selection, add, and edit.
- Keep Enter/Ctrl-S/Ctrl-X/Ctrl-Y behavior isolated from command dispatch.
- Store interactive edits in tmux without implicitly loading shell variables.

### `lib/vars.zsh`

Tmux session variable commands.

Responsibilities:

- Set, load, print, and unset `JJ_` variables.
- Keep command help and argument validation close to command entrypoints.

Commands:

```text
ii_cmd_set
ii_cmd_load
ii_cmd_variable
ii_cmd_unset
```

Helpers:

```text
ii_var_normalize_name
ii_var_lines_from_tmux
ii_var_filter_by_name
ii_export_var_line
```

### `lib/payloads.zsh`

Payload library scanning and rendering.

Responsibilities:

- Resolve `JJ_PAYLOAD_DIR`.
- List payload files as path-style selector entries.
- Filter payloads by category or fuzzy prefilter.
- Render `${JJ_NAME}` placeholders using fresh tmux session values.
- Display first-line `# description:` metadata in preview without copying it.
- Keep description and keys independent from the payload body in fzf preview.
- Print the rendered payload and variables used.

Commands:

```text
ii_cmd_payload
```

Helpers:

```text
ii_payload_dir
ii_payload_list
ii_payload_filter
ii_payload_select_fzf
ii_payload_path_for
ii_payload_render
ii_payload_required_vars
ii_payload_print_used_vars
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
keeps cross-pane rendering correct when pane 2 has not run `ii l` yet.

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

- Prefer `JJ_CLIP_BACKEND` when configured.
- Prefer `JJ_CLIP_CMD` when configured.
- Prefer OSC52 inside tmux or SSH when base64 is available.
- Auto-detect common clipboard tools.
- Fall back to tmux buffer when available.
- Copy through stdin when possible so payload content is not passed as a tmux
  command argument.

Functions:

```text
ii_clip_copy
ii_clip_backend_detect
```

Current tmux fallback:

```zsh
print -rn -- "$text" | tmux load-buffer -
```

This is intentionally stdin-based. It is more stable for payloads containing
spaces, quotes, shell metacharacters, and HTML-like text.

Primary SSH/Kali backend:

```zsh
export JJ_CLIP_BACKEND=osc52
```

OSC52 is auto-detected inside tmux or SSH when base64 is available. Inside tmux,
the OSC52 backend first tries `tmux load-buffer -w -` so tmux handles clipboard
integration. If that fails, `ii` base64-encodes the rendered payload and emits
an OSC52 escape sequence. Inside tmux, `ii` wraps the OSC52 sequence in tmux
passthrough framing; tmux and the terminal still need to allow it.

### `lib/help.zsh`

Help routing.

Responsibilities:

- Route `ii help COMMAND` to each command's own `--help` implementation.
- Print the top-level command summary.

Functions:

```text
ii_cmd_help
```

### `lib/core.zsh`

Public command interface.

Responsibilities:

- Dispatch `ii COMMAND` to layer command functions.
- Define the `ii` dispatcher.

Public functions:

```text
ii
```

## State Model

`ii` deliberately keeps two states separate:

```text
tmux session environment = shared state across panes
current shell environment = local state for one pane
```

`ii s` writes to both tmux and the current shell.

`ii l` copies tmux `JJ_` values into the current shell without the internal
prefix. It exports both uppercase and lowercase shell variables and enables a
prompt-time sync hook so prompt integrations do not immediately overwrite loaded
lowercase values.

`ii i` copies selected variable values through the copy layer. It does not load
variables into the current shell.

`ii p` does not depend on current shell values. It reads tmux session values
directly at render time, so another pane can render immediately after `ii s`
runs elsewhere.

## Layer Boundaries

Keep these responsibilities separate:

```text
variable loading layer:
  - read tmux JJ_ values
  - validate names
  - strip JJ_ only for variable TUI display
  - export all values into current shell through ii l
  - keep loaded values synchronized after prompt hooks run

fuzzy search layer:
  - present candidate lines
  - return selected lines
  - provide bottom preview hints
  - avoid mutating state

payload render layer:
  - read selected template
  - read tmux JJ_ values fresh
  - return rendered text

copy layer:
  - receive selected variable values from ii i
  - receive rendered text
  - copy via configured or detected backend
  - avoid breaking inside tmux
```

## Deployment Boundary

`script/make` rebuilds `export/ii`, which is the deployable plugin package:

```text
export/ii/
  ii.plugin.zsh
  lib/
  payloads/
  README.md
```

`export/` is generated output. Source changes should be made in the project root
and then copied into `export/ii` by rerunning `script/make`.

## Development Helpers

`script/help` is a repo-only audit helper. It sources the local plugin entrypoint
and calls the registered `ii help` implementations for every public command.
This keeps command help as the single source of truth while making spec/help
comparison easy.
