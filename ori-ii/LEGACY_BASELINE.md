# Legacy Zsh Baseline

This directory is the executable pre-Go implementation captured immediately
before the runtime contract audit. It is the only source of truth for legacy
code and behavior; no duplicate legacy implementation is kept at repository
root.

It exists only for differential testing during the migration. Do not implement
new features here. When a baseline defect is confirmed, first record the
expected behavior in the root documentation and shared contract tests, then
decide explicitly whether the snapshot must be corrected to keep the comparison
meaningful.

The snapshot includes:

- `ii.plugin.zsh` and `lib/`
- bundled payloads
- runtime and regression scripts
- the version and build files
- permanent user and maintainer documentation as it existed at capture time

Load it independently with:

```zsh
II_CONFIG_FILE=/dev/null source ./ori-ii/ii.plugin.zsh
```

Remove this directory together with the final legacy fallback after the Go
runtime satisfies every completion criterion in
`../doc/todo/runtime-migration.md`.
