# v0.2.5 compatibility audit

This audit compares `v0.2.5` with the `0.2.10` working version. Its baseline is
observable behavior rather than documentation text alone. New interaction and
variable-output behavior is retained unless it removes an older capability.

## Runtime ownership

| Area | v0.2.5 | Current | Result |
|---|---|---|---|
| Public command dispatch | Zsh | Zsh | Compatible |
| Ordinary variable operations | Zsh | Zsh | Compatible |
| Ordinary payload select/render/copy/execute | Zsh | Zsh | Compatible |
| Clipboard and web helpers | Zsh | Zsh | Compatible |
| Tmux integration and popup input | Zsh | Zsh | Compatible |
| Combo render/copy/run | Go helper | Go helper | Compatible |

The Go entry point accepts only `__combo-render`, `__combo-copy`, and
`__combo-run`. Zsh calls the Go binary only from combo selection and launch
paths.

## Compatibility results

| Surface | Evidence | Result |
|---|---|---|
| Zsh function inventory | Function names compared across relocated libraries | No removed functions |
| Public commands and aliases | v0.2.5 command contracts run against the current package | Compatible; new `sh` alias retained |
| Variable set/load/get/unset/list/output | Old contract suite plus current extended contracts | Compatible; current output merge/cover behavior is additive |
| Shared payload renderer | Old fixture suite run against current Zsh and Go renderers | Compatible |
| Ordinary payload routes | Old route contract run against current package | Compatible |
| Clipboard and web helpers | Old contracts run against current package | Compatible |
| Tmux install/status/popup | Old contracts run against current package | Compatible |
| Combo workflow | Old render/launch contracts run against current package | Compatible |
| Release package contents | Linux-amd64 package file lists compared | Same runtime file set |
| Source layout | Root sources moved under `src/zsh` and Go under `src/go` | Expected v0.2.6 architecture change |
| Build targets | `package-linux-amd64` folded into Linux-only `package` | Expected v0.2.6 architecture change |
| Execute confirmation | Enter now confirms and prompts show `[Y/Enter]` | Intentional recent behavior |
| Selector search mode | `/` enters search and Esc returns to normal | Intentional recent behavior |
| Selector normal-mode Esc | Initially no longer aborted after search-mode work | Regression found and fixed |
| Render report styling | Resolved names green/bold; unresolved names red/bold | Recent fix; color policy retained |

The v0.2.5 documentation described colored tokens in the payload preview, but
the v0.2.5 implementation copied the source into a temporary file and previewed
it with plain `cat`. It is therefore not counted as a removed implemented
feature. Current post-selection render reports provide the resolved/unresolved
color distinction.

## Regression protection

`test/contract/fzf-modes-tmux` drives real fzf sessions inside tmux for both the
variable and payload selectors. It verifies that the first Esc returns from
search to normal mode and the next Esc aborts the selector, preserving the old
normal-mode exit behavior alongside the new search mode.

The audit also ran the complete v0.2.5 contract suite against a current packaged
runtime. All applicable contracts passed. The old payload-input test stopped at
the intentionally changed confirmation prompt; the current suite covers the new
prompt and confirmation behavior.
