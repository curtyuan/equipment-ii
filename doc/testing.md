# Testing

All commands run from the repository root. Automated tests are the maintained
baseline; operator-specific remote-shell and clipboard checks are outside this
document.

## Test Layers

```text
src/**/*_test.go    Go combo-domain, terminal, and adapter tests
test/contract/      Zsh public behavior and isolated tmux contracts
test/fixtures/      reviewed public output and shared render fixtures
```

Go tests cover only the internal combo helper. Zsh contracts cover public
commands, ordinary payloads, current-shell mutation, packaging boundaries, and
tmux integration. Tests never execute an older runtime to generate expected
output.

## Primary Test

```zsh
make test
```

This runs formatting checks, `go vet`, Go tests, shared rendering, payload
routing, web helpers, the single-process combo launch boundary, a static Go
build, and public help/command contracts.

The primary target requires `go`, `zsh`, `tmux`, and `fzf`. Tmux contracts
create isolated Unix sockets under a temporary directory.

## Tmux Contracts

Run the complete maintained tmux matrix with:

```zsh
make test-entry-tmux
make test-variables-tmux
make test-variable-output-tmux
make test-variable-mutations-tmux
make test-set-tmux
make test-unset-all-tmux
make test-load-all-tmux
make test-get-tmux
make test-clipboard-tmux
make test-tmux-install
make test-tmux-popup
make test-tmux-popup-interactive
make test-tmux-status
make test-payload-input-usage-tmux
```

These targets verify tmux-scoped variables, shell mutation, clipboard policy,
native alias installation, popup transport, interactive cancellation, and
`ii pic`/`ii pie`/`ii pice` input and execution behavior.

## Focused Targets

```zsh
make fmt-check
make vet
make test-go
make test-contract
make test-payload-render-shared
make test-payload-routing
make test-web-helpers
make test-combo-launch
```

`test-payload-routing` proves ordinary payloads remain in Zsh while opted-in
combo payloads enter an internal `ii-go` command. `test-combo-launch` proves a
confirmed combo starts one Go process rather than a daemon or per-stage helper.

## Syntax and Load Checks

```zsh
zsh -n ii.plugin.zsh
zsh -n lib/*.zsh
zsh -fc 'II_CONFIG_FILE=/dev/null; source ./ii.plugin.zsh; type ii; ii version'
```

Sourcing the plugin and running public help, version, ordinary variables, or
ordinary payload commands must not start Go.

## Packaging Checks

```zsh
make clean
make
make package-linux-amd64
```

`make` creates the local deployment unit under `export/ii`. The amd64 target
creates `export/linux-amd64/ii` with a statically linked Linux `ii-go` helper.
Both packages must contain the plugin, helper, libraries, help, payloads,
popup script, `VERSION`, and `RELEASE`.

Generated `build/` and `export/` trees are ignored and are never test sources.
