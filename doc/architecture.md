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
  help_registry.zsh
  tmux_integration.zsh
  clipboard.zsh
  fzf.zsh
  interact.zsh
  var_helpers.zsh
  var_interactive.zsh
  vars.zsh
  var_output.zsh
  www.zsh
  payloads.zsh
  payload_input.zsh
  payload_command.zsh
  help.zsh
  version.zsh
  core.zsh
payloads/
  shell/
  script/
  xss/
doc/
  README.md
  architecture.md
  clipboard.md
  design.html
  help.md
  payload-schema.md
  release.md
  usage.md
  testing.md
  conf/
    tmux.conf
script/
  make
  help
  ii-tmux-pice
export/
  ii/
```

## Load Order

`ii.plugin.zsh` loads layers in this order:

```text
1. lib/tmux.zsh
2. lib/help_registry.zsh
3. lib/tmux_integration.zsh
4. lib/clipboard.zsh
5. lib/fzf.zsh
6. lib/interact.zsh
7. lib/var_helpers.zsh
8. lib/var_interactive.zsh
9. lib/vars.zsh
10. lib/var_output.zsh
11. lib/payloads.zsh
12. lib/payload_input.zsh
13. lib/www.zsh
14. lib/payload_command.zsh
15. lib/help.zsh
16. lib/version.zsh
17. lib/core.zsh
```

`core.zsh` is loaded last because it exposes the public dispatcher. The
functions it dispatches to are already defined by the earlier layers.

## Layers

### `ii.plugin.zsh`

Plugin entrypoint.

Responsibilities:

- Resolve the plugin root path.
- Set `II_PLUGIN_DIR` to the plugin root when unset.
- Set `II_PAYLOAD_DIR` to `${II_PLUGIN_DIR}/payloads` when unset.
- Set `II_WWW_ROOT` to `/www` when unset.
- Set `II_CONFIG_FILE` to `~/.config/ii/ii.conf` when unset, and source it
  when readable.
- Source each implementation layer.
- Avoid exposing path setup variables after loading.

This lets Kali deployments use bundled payloads without adding a separate
`export II_PAYLOAD_DIR=...` line to `~/.zshrc`.

Configuration belongs in `II_CONFIG_FILE`, not tmux. Tmux session environment is
reserved for `ii_` workflow variables used by payload rendering across panes.
Optional settings such as `II_PAYLOAD_DIR`, `II_WWW_ROOT`,
`II_AUTO_DETECT_LHOST`, `II_AUTO_DETECT_LHOST_INTERFACE`, and clipboard backend
selection are shell/config state.

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

### `lib/tmux_integration.zsh`

Optional tmux command-prompt adapter.

Responsibilities:

- Install one server-wide `Prefix + :` binding while enabling it per session.
- Preserve non-ii tmux commands and restore the previous binding after the last
  enabled session is disabled.
- Whitelist only the exact `ii pice` dispatcher command.
- Open an isolated popup for pasted input, render only from tmux `ii_` values,
  report unresolved lowercase placeholders, and confirm before sending.
- Copy best-effort, literal-paste to the originating pane, and send one final
  Enter while treating pane readiness as the user's responsibility.

Public commands:

```text
ii tmux enable
ii tmux status
ii tmux disable
```

The popup process enters through `script/ii-tmux-pice`; it does not read an
existing tmux buffer as payload input. An ii-owned named buffer is only the
internal literal-paste transport after confirmation.

### `lib/help_registry.zsh`

Thin help registration and routing infrastructure. The detailed output contract
and registration workflow live in [help.md](help.md).

Responsibilities:

- Let each command layer register its canonical help topic, handler, aliases,
  and nested help paths beside the implementation.
- Resolve `ii help ...` with longest-path matching.
- Expose the canonical topic list used by `script/help`.
- Keep live help text in the feature layer rather than the registry.

Functions:

```text
ii_help_register
ii_help_dispatch
ii_help_topics
```

### `lib/fzf.zsh`

Shared fzf helpers.

Responsibilities:

- Create single-line previews for list display.
- Read free-form fzf input values.
- Print preview text with an independent description block pinned around the
  body content.
- Trim leading empty lines from fzf output before selector key parsing.

Functions:

```text
ii_one_line_preview
ii_fzf_print_preview_blocks
ii_fzf_print_preview_with_footer
ii_fzf_trim_leading_empty_lines
ii_fzf_select_one
ii_fzf_input_value
```

### `lib/interact.zsh`

Shared interaction helpers.

Responsibilities:

- Build selector preview footers with an optional status line.
- Keep width-aware normal/search selector key text shared for `ii i` and
  `ii p`; wrap only between complete key prompt units.
- Keep selector footers compact: no footer border, no outer padding, and only
  two spaces between action units.
- Build reusable fzf modal start actions.
- Keep copy-success and copy-failure wording shared across selector commands.
- Leave domain actions in the variable and payload command layers.

Functions:

```text
ii_interact_footer
ii_interact_hint_line
ii_interact_status_line
ii_interact_copy_status
ii_interact_keys_vars_normal
ii_interact_keys_vars_search
ii_interact_keys_payload_normal
ii_interact_keys_payload_expanded
ii_interact_keys_payload_search
ii_fzf_modal_start_actions
```

### `lib/var_helpers.zsh`

Variable data helpers.

Responsibilities:

- Normalize user names like `LHOST` into `ii_lhost`.
- List, filter, and format `ii_` variables.
- Apply shared terminal colors for variable display keys.
- Export safe `NAME=VALUE` lines into the current shell.
- Detect and export lhost automatically after rhost/rhosts is set, when enabled.
- Control optional loaded-variable prompt auto-sync for `ii sync`.
- Build default variable candidates for interactive commands.

Helpers:

```text
ii_color_wrap
ii_color_blue
ii_color_red
ii_color_green
ii_var_normalize_name
ii_var_lines_from_tmux
ii_var_filter_by_name
ii_var_print_name_value
ii_var_print_list
ii_export_var_line
```

### `lib/var_interactive.zsh`

Interactive variable UI.

Responsibilities:

- Open fzf flows for variable selection, add, and edit.
- Keep `ii set` CLI-only; interactive variable management belongs to `ii i`.
- Keep populated variables before empty default names in the selector.
- Keep vim-style selector keys isolated from command dispatch.
- Store interactive edits in tmux without implicitly loading shell variables.

### `lib/vars.zsh`

Tmux session variable commands.

Responsibilities:

- Set, load, print, and unset `ii_` variables.
- Get one tmux variable value through the copy layer without shell loading.
- Print `ii ls` as dense key/value blocks with blue keys and no blank separator
  lines.
- Keep command help and argument validation close to command entrypoints.

Commands:

```text
ii_cmd_set
ii_cmd_get
ii_cmd_load
ii_cmd_list
ii_cmd_unset
```

### `lib/var_output.zsh`

Variable command routing and shell-sourceable file output.

Responsibilities:

- Keep `ii v` compatible with variable listing while routing `ii v --out` to
  file output.
- Implement the fixed `ii voc` alias.
- Serialize non-empty variables with shell-safe quoting.
- Atomically replace the destination through a securely created temporary file
  and clean it on every function exit.
- Own the `variables-output` help registration.

Commands:

```text
ii_cmd_variable
ii_cmd_vars_output
```

### `lib/www.zsh`

`/www` helper commands used from `ii p --www ...`.

Responsibilities:

- Resolve `II_WWW_ROOT`, defaulting to `/www`.
- Print a tree of files and directories under the configured web root without
  showing symlink targets.
- Read a file, render it through the payload renderer, report render sources,
  and symlink the file under the web root's `p` directory.
- Fuzzy-select web-root entries and report the containing directory relative to
  `/www`, then the selected entry's absolute filesystem path.
- Fuzzy-select a destination directory under the web root and create symlinks
  without overwriting existing files.
- Keep `/www` helper state local to the command instead of storing it in tmux.

Commands:

```text
ii_cmd_payload_www
ii_cmd_payload_www_file
ii_cmd_payload_www_ls
ii_cmd_payload_www_ln
ii_cmd_payload_www_search
```

Config:

```text
II_WWW_ROOT=/www
```

### `lib/payloads.zsh`

Payload library scanning and rendering.

Responsibilities:

- Resolve `II_PAYLOAD_DIR`.
- List payload files as path-style selector entries.
- Filter payloads by category or fuzzy prefilter.
- Render payload files and pasted `--input` text through the same parser and
  resolver.
- Write rendered payload text to a requested output path.
- Display first-line `# description:` metadata in preview without copying it.
- Emit `# stage:` metadata as paste-safe `# --- ... ---` comment delimiters
  for combo payloads.
- Keep description independent from the payload body in fzf preview and show
  selector controls/status at the bottom of the preview. Reserve the
  description block when space allows, but preserve controls/status first.
- Print the rendered payload and variables used.

Commands:

```text
ii_cmd_payload_select
```

Helpers:

```text
ii_payload_dir
ii_payload_list
ii_payload_filter
ii_payload_select_fzf
ii_payload_path_for
ii_payload_render
ii_payload_render_text
ii_payload_render_report
ii_payload_output_path
ii_payload_write_output
ii_payload_body
```

### `lib/payload_input.zsh`

Pasted payload input command and input UI.

Responsibilities:

- Implement `ii p --input` and the fixed `ii pic` alias behavior.
- Keep interactive ZLE editing, Enter submit, Ctrl-J newline insertion, and the
  persistent bottom key hint together.
- Preserve the `:w`, `:q`, and `:q!` stream protocol for pipelines.
- Pass collected text to the renderer and output helpers owned by
  `payloads.zsh`.
- Own the `payload-input` help registration.

Commands:

```text
ii_cmd_payload_input
```

Helpers:

```text
ii_payload_read_input
ii_payload_read_input_interactive
ii_payload_read_input_stream
ii_payload_input_zle_setup
ii_payload_input_newline
ii_payload_input_zle_init
ii_payload_input_strip_finish_line
ii_payload_input_is_finish_line
ii_payload_input_is_cancel_line
```

### `lib/payload_command.zsh`

Public payload command facade.

Responsibilities:

- Own the public `ii payload` / `ii p` entrypoint.
- Route normal category selection to `payloads.zsh`, `--input` to
  `payload_input.zsh`, and `--www` to `www.zsh`.
- Route `--execute` and `pe` to confirmed current-shell execution after
  selection, and route `--copy --execute` and `pce` to copy-before-execute.
- Route `--input --copy --execute` and `pice` to confirmed input execution.
- Route `--copy` and `pc` to non-interactive best-match rendering and copy.
- Join multiple positional keywords into the selector's initial fzf query.
- Print aggregate payload help without moving feature-specific help away from
  its owning layer.
- Own the canonical `payload` help registration.

Commands:

```text
ii_cmd_payload
ii_cmd_payload_execute
ii_cmd_payload_copy_best
```

Render boundary:

```text
Input:
  - selected payload file or pasted input text
  - current lowercase shell variables
  - tmux session `ii_` variables

Output:
  - rendered payload text
  - render-variable report
```

The render layer checks the current shell first, then falls back to tmux session
`ii_` variables. This keeps one-command shell overrides useful while preserving
tmux as the shared fallback when a pane has not run `ii l`. It renders lowercase
`%name%`, `$name`, `${name}`, and `${name:t}`; leaves uppercase, legacy
`II_NAME`, and PowerShell scope forms unchanged; and reports missing variables
in red while keeping the original token in rendered output.

Payload previews use the same shell-then-tmux availability check for color only:
tokens with values are green, missing tokens are red. The preview color check
does not change render output or render reports.

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

- Prefer `II_CLIP_BACKEND` when configured.
- Prefer `II_CLIP_CMD` when configured.
- Read clipboard settings from the shell first, then the tmux session
  environment.
- Prefer OSC52 in active SSH sessions when base64 is available.
- Prefer `xclip-both` in local tmux sessions with `DISPLAY` and `xclip`, even
  when tmux still has stale SSH environment variables.
- Prefer OSC52 in other tmux sessions when base64 is available.
- Auto-detect common clipboard tools.
- Fall back to tmux buffer when available.
- Copy through stdin when possible so payload content is not passed as a tmux
  command argument.
- Provide `xclip-both` for environments where tmux copy-mode succeeds by
  writing both X primary and clipboard selections.

Functions:

```text
ii_clip_copy
ii_clip_backend_detect
ii_cmd_clip
```

Current tmux fallback:

```zsh
print -rn -- "$text" | tmux load-buffer -
```

This is intentionally stdin-based. It is more stable for payloads containing
spaces, quotes, shell metacharacters, and HTML-like text.

Primary SSH/Kali backend:

```zsh
export II_CLIP_BACKEND=osc52
```

OSC52 is auto-detected inside tmux or SSH when base64 is available. Inside tmux,
the OSC52 backend first tries `tmux load-buffer -w -` so tmux handles clipboard
integration. If that fails, `ii` base64-encodes the rendered payload and emits
an OSC52 escape sequence. Inside tmux, `ii` wraps the OSC52 sequence in tmux
passthrough framing; tmux and the terminal still need to allow it.

VMware/Kali X clipboard backend:

```zsh
export II_CLIP_BACKEND=xclip-both
```

This uses:

```zsh
xclip -i -f -selection primary | xclip -i -selection clipboard
```

It intentionally mirrors tmux copy-mode configurations that copy through both X
selections.

### `lib/help.zsh`

Top-level help command.

Responsibilities:

- Print the top-level command summary.
- Register the `help` topic with the shared registry.

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

`ii l` copies tmux `ii_` values into the current shell without the internal
prefix. `II_EXPORT_CASE` controls whether exported shell variables are lower,
upper, or both; the default is lower. This is a one-time load. `ii sync on`,
`ii sync off`, and `ii sync status` explicitly control the optional prompt-time
sync hook.

`ii i` copies selected variable values through the copy layer. It does not load
variables into the current shell.

`ii p` and `ii p --input` share the same render resolver. A non-empty lowercase
shell variable in the current command context wins first, then the matching tmux
`ii_` variable is used. This keeps one-command overrides ergonomic while still
letting another pane render immediately after `ii s` runs elsewhere.

## Layer Boundaries

Keep these responsibilities separate:

```text
variable loading layer:
  - read tmux ii_ values
  - validate names
  - strip ii_ only for variable TUI display
  - export all values into current shell through ii l
  - keep loaded values synchronized after prompt hooks run only when `ii sync on` is active

fuzzy search layer:
  - present candidate lines
  - keep active variable entries near the initial cursor position
  - return selected lines
  - provide bottom preview hints
  - avoid mutating state

payload render layer:
  - read selected template
  - read lowercase shell values first
  - read tmux ii_ values as the shared fallback
  - render lowercase %name%, $name, ${name}, and ${name:t} placeholders without
    touching uppercase $NAME
  - turn # stage: metadata into paste-safe comment delimiters
  - return rendered text

payload output layer:
  - resolve optional -o paths
  - write rendered text without changing terminal output
  - report the absolute output path as the final line

www helper layer:
  - read II_WWW_ROOT from shell/config state
  - render an explicit file and symlink it under /www/p
  - list and search web-root files without using tmux
  - create symlinks under selected web-root directories

copy layer:
  - receive selected variable values from ii i
  - receive selected variable values from ii g
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
  script/ii-tmux-pice
  README.md
```

`export/` is generated output. Source changes should be made in the project root
and then copied into `export/ii` by rerunning `script/make`.

## Development Helpers

`script/help` is a repo-only audit helper. It sources the local plugin entrypoint
and asks `ii_help_topics` for the canonical topics collected from command-layer
registrations before calling the matching `ii help` implementations. Command
dispatch remains independent in `lib/core.zsh`.
This keeps command help as the single source of truth while making spec/help
comparison easy. See [help.md](help.md) for the help ownership and formatting
contract, and [testing.md](testing.md) for executable checks.
