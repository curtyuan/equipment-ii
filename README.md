# ii

![ii icon](doc/asset/ii-icon2.png)

`ii` is a Zsh plugin with a bundled Go helper for tmux-scoped variables,
payload rendering, clipboard work, and multi-pane combo workflows.

## Supported platform

`ii` supports Linux on amd64 only. Other operating systems and architectures
are outside the project's current support scope. The packaged `ii-go` helper is
therefore always a statically linked Linux amd64 binary; there are no native or
cross-platform package variants.

## Installation

Both installation methods download the latest release archive into this local
plugin directory:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins/ii
```

The archive has a top-level `ii/` directory, so extracting it under
`${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins` creates the path above. The same
commands install a new copy or update an existing installation.

### Direct Zsh loading

Install or update by extracting the release archive directly:

```zsh
ii_plugin_home="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins"
mkdir -p "$ii_plugin_home"
curl -fsSL \
  https://github.com/curtyuan/equipment-ii/releases/latest/download/ii-linux-amd64.tar.gz |
  tar -xz -C "$ii_plugin_home"
```

Add this line to `${ZDOTDIR:-$HOME}/.zshrc`:

```zsh
source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins/ii/ii.plugin.zsh"
```

Start a new Zsh and verify the installation:

```zsh
ii version
```

To uninstall, delete that `source` line from `${ZDOTDIR:-$HOME}/.zshrc`, then
remove the local package:

```zsh
rm -rf -- "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins/ii"
```

### Antidote

First install and configure [Antidote](https://antidote.sh/). Then download the
release into the same local plugin directory and register that directory with
Antidote:

```zsh
ii_plugin_home="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins"
ii_dir="${ii_plugin_home}/ii"
plugins_file="${ZDOTDIR:-$HOME}/.zsh_plugins.txt"

mkdir -p "$ii_plugin_home" "${plugins_file:h}"
curl -fsSL \
  https://github.com/curtyuan/equipment-ii/releases/latest/download/ii-linux-amd64.tar.gz |
  tar -xz -C "$ii_plugin_home"

touch "$plugins_file"
grep -Fqx -- "${ii_dir:A}" "$plugins_file" || \
  print -r -- "${ii_dir:A}" >> "$plugins_file"
```

Restart Zsh afterward so `antidote load` can regenerate and load its static
bundle.

To remove an Antidote-managed installation:

```zsh
ii_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins/ii"
plugins_file="${ZDOTDIR:-$HOME}/.zsh_plugins.txt"

if [[ -f "$plugins_file" ]]; then
  temporary_file="$(mktemp "${plugins_file}.XXXXXXXX")"
  grep -Fvx -- "${ii_dir:A}" "$plugins_file" >"$temporary_file" || true
  mv -- "$temporary_file" "$plugins_file"
fi
rm -rf -- "$ii_dir"
rm -f -- "${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"
```

Restart Zsh so `antidote load` can rebuild the static bundle.

## Runtime ownership

- Zsh owns every public command, current-shell mutation, ordinary payload,
  help route, clipboard decision, and tmux integration setup.
- tmux is the persistent, session-wide store for `ii_*` variables.
- Go is an internal helper only for opted-in `# flow: 1` combo workflows. The
  tmux input popup is implemented by the packaged Zsh helper.

Sourcing the plugin and running ordinary commands do not start Go. Zsh selects
and confirms a combo before launching one `ii-go __combo-*` process. There is
no daemon, shell-state file, parent-shell operation file, or Go public-command
fallback.

## Build and test

```zsh
make build
make test
```

`make` writes the sole deployment package to `export/ii`. The bundled payload
data is read from the root `payloads` directory.

See [doc/README.md](doc/README.md) for user and maintainer documentation.

## Source layout

- `src/zsh/`: live Zsh public runtime and popup helper.
- `src/go/`: Go combo workflow helper.
- `help/`: static public help text loaded by the Zsh runtime.
- `test/contract/`: public Zsh and combo boundary contracts.
- `payloads/`: bundled payload library.
