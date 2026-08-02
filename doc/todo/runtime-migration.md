# Runtime Migration TODO

## Fixed ownership contract

```text
Zsh: every public command, current-shell effects, ordinary payloads,
      filesystem helpers, help, clipboard policy, tmux integration
  -> Go: one selected combo workflow process
     -> tmux: persistent session-wide ii_* state and pane transport
```

- `ii s` and interactive add/edit write tmux and update the calling shell.
- `s --from-shell` and strict, data-only `s --from-file` remain in Zsh.
- Ordinary rendering resolves shell then tmux; combo rendering uses tmux only.
- Zsh selects/classifies/validates/confirms a combo and resolves its clipboard
  backend before one `__combo-render`, `__combo-copy`, or `__combo-run` call.
- No daemon, prompt sync, Go public fallback, shell-state file, parent-shell
  operation file, or execution-file protocol.
- No external runtime or test dependency is added. Shared contracts and
  fixtures are repository-owned.

## Completed

- [x] Remove `sync`, prompt hooks, legacy dispatch, and compatibility fallback.
- [x] Move variable set/get/list/load/unset/output and interactive actions to
  focused root Zsh modules while preserving tmux and caller-shell effects.
- [x] Keep `s --from-file` strict, line-oriented, diagnostic, and free of
  `source`/`eval`.
- [x] Consolidate clipboard backend selection in Zsh and hand combo Go a closed
  backend value.
- [x] Move ordinary stored-payload selection/render/copy/output/execute and
  pasted input (`pic`, `pie`, `pice`, `p --input`) to Zsh.
- [x] Use one shared payload-token fixture for Zsh and Go render contracts.
- [x] Establish the one-process combo launch contract and tmux-only combo state.
- [x] Move public help/version/unknown handling and tmux setup/status to Zsh;
  sourcing the plugin no longer starts Go.
- [x] Remove `ii_go_command`, all three shell bridge files, superseded Go
  variable/www/public-payload/help/dispatch packages, hidden `__payload_*`,
  `__tmux_ensure`, and `__workflow_popup` entries, plus obsolete backend tests.
- [x] Narrow the Go binary to `__combo-render|copy|run` and the temporary
  `__tmux_popup`; reject public or unknown helper commands.
- [x] Old `--www`/`www` routes perform no filesystem behavior and emit a
  one-release migration diagnostic pointing to `ii p -w`.

## Remaining implementation order

1. [ ] Implement Zsh-owned web helpers:

   ```text
   ii p -w file PATH
   ii p -w ln SOURCE_PATH [LINK_NAME]
   ii p -w ls
   ii p -w search [FILTER]
   ```

   Decide and contract-test containment, traversal rejection, no-follow walk,
   no-overwrite symlinks, deterministic output, and diagnostics using existing
   Zsh/standard Unix primitives.

2. [ ] Move the tmux `:ii` pasted-input popup from `ii-go __tmux_popup` to a
   packaged Zsh helper. Preserve tmux-only rendering, origin/session identity
   revalidation, named-buffer literal paste, confirmation, and final Enter.

3. [ ] Move payload data from `ori-ii/payloads` to its final root location;
   update `II_PAYLOAD_DIR`, package/cross-package rules, install contracts, and
   release metadata.

4. [ ] Replace remaining permanent legacy-vs-current test runners with reviewed
   language-neutral fixtures for stdout, stderr, status, tmux/shell/filesystem
   effects, cancellation, and ordered pane transport. Then delete `ori-ii/` and
   stale scripts/docs.

5. [ ] Reconcile detailed usage/testing/tmux/workflow documentation after the
   above paths stop being transitional. Remove obsolete migration language.

6. [ ] Run final format/vet/unit/contracts, isolated and interactive tmux,
   package/install, Linux amd64/arm64 cross-build, and disposable real
   PowerShell/powercat validation. Confirm no generated binaries are committed.

## Open contract decisions

- [ ] Should an empty tmux value remain stored but hidden by list/load, or be
  equivalent to unset?
- [ ] Freeze current differential results as fixtures, or regenerate them from
  an explicitly reviewed public specification?
- [ ] Which exact Zsh and standard Unix filesystem primitives form the `p -w`
  safety boundary without adding a dependency?

## Completion criteria

- Every ordinary public command stays in Zsh and never starts Go.
- One selected combo starts one Go process for its complete workflow lifecycle.
- The tmux input popup no longer keeps a non-combo Go entrypoint alive.
- `p -w` correctness is implemented and the old migration diagnostic can be
  removed on schedule.
- Payload/package paths no longer depend on `ori-ii/`; the frozen runtime and
  duplicate contracts are deleted.
- Supported builds, clean installs, automated contracts, and required manual
  integration checks pass.
