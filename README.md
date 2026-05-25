# ii

`ii` is a zsh plugin for tmux-scoped workflow variables and payload rendering.
It stores shared variables in the current tmux session with an internal `ii_`
prefix, lets each pane load values when needed, and renders payload templates
from the current shell first, then tmux.

```text
tmux session environment = shared source across panes
current shell environment = values directly usable in one pane
payload renderer = reads current shell first, then tmux session values
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

## Install

Build the deployable plugin package:

```zsh
./script/make
```

This creates `export/ii`, which is the deployment unit:

```text
export/ii/
  ii.plugin.zsh
  lib/
  payloads/
  README.md
  VERSION
  RELEASE
```

Copy it into your zsh plugin directory:

```zsh
mkdir -p "$HOME/.config/zsh/plugin"
rm -rf "$HOME/.config/zsh/plugin/ii"
cp -r ./export/ii "$HOME/.config/zsh/plugin/ii"
```

Load it from `.zshrc` or your plugin manager. Manual `.zshrc` loading:

```zsh
source "$HOME/.config/zsh/plugin/ii/ii.plugin.zsh"
```

Reload and verify:

```zsh
source ~/.zshrc
type ii
ii version
echo $II_PAYLOAD_DIR
```

## Versioning

`VERSION` is the source of truth for releases and follows SemVer:

```text
MAJOR.MINOR.PATCH
```

Update the version with the dedicated version script:

```zsh
./script/version patch  # 0.1.0 -> 0.1.1
./script/version minor  # 0.1.0 -> 0.2.0
./script/version major  # 0.1.0 -> 1.0.0
```

Create a release by committing `VERSION` and pushing a matching tag:

```zsh
./script/version minor
git add VERSION
git commit -m "Release v0.2.0"
git tag v0.2.0
git push origin master --tags
```

The release workflow checks that the tag matches `VERSION`, builds `export/ii`,
and publishes `ii-VERSION.tar.gz` plus `ii-VERSION.zip`.

## Quick Start

Run inside tmux:

```zsh
ii s lhost 192.168.45.192
ii s lport 443
ii s domain example.test

ii ls
ii i
ii p linux
```

## Commands

| Command | Short form | Purpose |
| --- | --- | --- |
| `ii set NAME=VALUE` | `ii s NAME=VALUE` | Set a tmux variable and export it into this shell |
| `ii set NAME=VALUE NAME=VALUE` | `ii s:NAME=VALUE,NAME=VALUE` | Set multiple variables with `=` |
| `ii set NAME[,NAME...] --from-shell` | `ii s:NAME[,NAME...] --from-shell` | Save current shell variables back into tmux |
| `ii set -d [INTERFACE]` | `ii s -d`, `ii s:lhost -d [INTERFACE]` | Detect lhost from an interface |
| `ii set [FILTER]` | `ii s [FILTER]`, `ii s:FILTER` | Select or match a variable before setting it |
| `ii get FILTER` | `ii g FILTER`, `ii g:FILTER` | Copy and print one tmux variable value |
| `ii load` | `ii l` | Load non-empty tmux variables into this shell |
| `ii clip backend` | | Show or set clipboard backend |
| `ii clip doctor` | | Diagnose clipboard behavior and suggest a backend |
| `ii interactive` | `ii i` | Select, edit, add, and copy variables |
| `ii ls [PATTERN]` | | List non-empty tmux variables as compact key/value blocks |
| `ii payload [CATEGORY]` | `ii p [CATEGORY]` | Select, render, print, and optionally write a payload |
| `ii p --input [--copy] [-o [PATH]]` | | Render pasted input; optionally copy or write the result |
| `ii p -www ls/search/ln` | | List, search, or symlink files under the configured web root |
| `ii unset NAME [...]` | `ii u NAME [...]` | Remove variables from tmux and this shell |
| `ii unset -a` | `ii u -a` | Prompt, then remove all `ii_` variables |
| `ii version` | `ii -v`, `ii --version` | Show installed version |
| `ii help [COMMAND]` | `ii h [COMMAND]` | Show help |

`ii p` shows path entries separated from template previews by a solid block.
Use `j`/`k` to move, `l` to unfold the selected script preview, `h` to return
to filtering, `y` to copy the selected rendered payload, Enter to
render/output, and `q` to abort.
Copy reports are printed when the selector exits; aborting without Enter or
`y` prints nothing.

## Common Configuration

`ii` reads this config file automatically when it exists:

```text
~/.config/ii/ii.conf
```

To use another path, set it in `.zshrc` before sourcing `ii.plugin.zsh`:

```zsh
export II_CONFIG_FILE="$HOME/.config/ii/work.conf"
source "$HOME/.config/zsh/plugin/ii/ii.plugin.zsh"
```

Bundled payloads work without extra configuration. Override the payload
directory only if you keep payloads somewhere else:

```zsh
export II_PAYLOAD_DIR="$HOME/.config/ii/payloads"
```

`ii p -www ...` defaults to `/www`. Override it from `~/.config/ii/ii.conf`
when your web root lives somewhere else:

```zsh
export II_WWW_ROOT="$HOME/www"
```

Shell export case for `ii set` and `ii load` defaults to lowercase:

```zsh
export II_EXPORT_CASE=lower
export II_EXPORT_CASE=upper
export II_EXPORT_CASE=both
```

Clipboard overrides:

```zsh
export II_CLIP_BACKEND=osc52
export II_CLIP_CMD='tmux load-buffer -'
export II_CLIP_BACKEND=xclip-both
```

Without an override, active SSH sessions prefer OSC52. Local tmux sessions with
`DISPLAY` and `xclip` prefer `xclip-both`, even when tmux still has stale SSH
environment variables. This mirrors a tmux copy-mode binding that writes both X
primary and clipboard selections. Auto-detection is runtime-only and does not
export `II_CLIP_BACKEND`.

## Documentation

| Topic | File | Covers |
| --- | --- | --- |
| Usage guide | [doc/usage.md](doc/usage.md) | Command behavior, variables, `ii i`, payload files, pasted input rendering, and payload categories |
| Payload schema | [doc/payload-schema.md](doc/payload-schema.md) | Plain-text payload format, metadata, combo naming, and renderable variables |
| Clipboard behavior | [doc/clipboard.md](doc/clipboard.md) | OSC52, tmux buffer copy, `xclip-both`, VMware/Kali notes, and troubleshooting |
| ii config example | [doc/conf/ii.conf](doc/conf/ii.conf) | Shell export case values and optional `/www` root |
| tmux clipboard example | [doc/conf/tmux.conf](doc/conf/tmux.conf) | Minimal tmux settings related to `ii` clipboard behavior |
| Architecture | [doc/architecture.md](doc/architecture.md) | Entrypoint, layer responsibilities, state model, and development boundaries |
| Testing | [doc/testing.md](doc/testing.md) | Syntax checks, tmux smoke tests, cross-pane tests, and regression scenarios |

## Help

```zsh
ii help
ii help set
ii help get
ii help clip
ii help load
ii help interactive
ii help ls
ii help payload
ii help payload input
ii help input
ii help unset
ii help version
```
