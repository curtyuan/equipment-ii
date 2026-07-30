# ii

![ii icon](doc/asset/ii-icon2.png)

`ii` is being rebuilt from its public entrypoint inward as a Go runtime with a
thin Zsh parent-shell adapter.

## Repository State

- [`ori-ii/`](ori-ii/) is the only source of truth for the complete pre-Go Zsh
  implementation, payload set, scripts, tests, and matching documentation.
- `src/` will contain the new Go implementation.
- [`doc/todo/runtime-migration.md`](doc/todo/runtime-migration.md) is the living
  audit and migration plan.
- Root documentation is the working target contract and must be reconciled
  against `ori-ii/` before implementation behavior changes.

Do not add features to `ori-ii/`. Use it to reproduce legacy behavior and run
differential contract tests while migrating one public route at a time.

## First Go Runtime

Build and test the current entrypoint-first runtime:

```zsh
make build
make test
```

The migration bridge sends every invocation through `ii-go`. Migrated routes
run in Go; explicitly unmigrated routes run in the same parent shell through
the `ori-ii` adapter. There is no fallback after a Go-owned route fails.

Current Go-owned routes are top-level help, version, unknown-command handling,
the read-only `ls`/`list`/`variable`/`vars`/`var` family, `v [PATTERN]`, and
the `v --out`/`vo`/`voc` file-output family. The complete `set` family,
`load/l/la`, `sync`, and `unset/u` are also Go-owned, including all-pane load
and confirmed unset-all modes. `get/g/gr/gl/g:*` selection and clipboard copy
are Go-owned as well. Public pasted-input execution through `pic`, `pie`,
`pice`, and `payload --input` is Go-owned; its help text remains on the
temporary legacy bridge until the help migration is complete.

`make` writes the current Go deployment package to `export/ii`. The immutable
legacy package is built separately under `ori-ii/export/ii`:

```zsh
./ori-ii/script/make
make
```

## Legacy Baseline

Load the original implementation independently:

```zsh
II_CONFIG_FILE=/dev/null source ./ori-ii/ii.plugin.zsh
ii version
```

Run its automated baseline from `ori-ii/`:

```zsh
cd ori-ii
zsh -n ii.plugin.zsh lib/*.zsh script/ii-tmux-*
./script/help
./script/test-color
./script/test-workflow-parser
./script/test-workflow
./script/test-workflow-tmux
./script/test-tmux-input
./script/test-tmux-popup-input
./script/test-tmux-integration
```

Deployment instructions for the legacy version remain in
[`ori-ii/README.md`](ori-ii/README.md).
