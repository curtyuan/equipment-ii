# ii

![ii icon](doc/asset/ii-icon2.png)

`ii` is a zsh plugin for tmux-scoped variables, payload rendering, and confirmed
multi-pane combo workflows.

## Requirements

- zsh
- tmux
- fzf
- coreutils

Kali:

```zsh
sudo apt update
sudo apt install -y zsh tmux fzf coreutils
```

## Deploy

Build the deployable plugin package:

```zsh
./script/make
```

Install it under the zsh plugin directory:

```zsh
mkdir -p "$HOME/.config/zsh/plugin"
rm -rf "$HOME/.config/zsh/plugin/ii"
cp -r ./export/ii "$HOME/.config/zsh/plugin/ii"
```

## Load With Antidote

Add the local plugin path to your antidote plugin list, for example
`~/.zsh_plugins.txt`:

```text
~/.config/zsh/plugin/ii
```

Load that file from `.zshrc` with your antidote setup:

```zsh
antidote load "$HOME/.zsh_plugins.txt"
```

## Load Manually

Source the plugin directly from `.zshrc`:

```zsh
source "$HOME/.config/zsh/plugin/ii/ii.plugin.zsh"
```

## Verify

Reload zsh and check the command:

```zsh
source ~/.zshrc
type ii
ii version
```

## Documentation

See [doc/README.md](doc/README.md) for usage, configuration, payloads, testing,
architecture, and release notes.
