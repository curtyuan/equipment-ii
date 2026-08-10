# Clipboard Behavior

`ii i` and `ii p` both copy through `ii_zsh_clip_copy` in
`lib/ordinary_clipboard.zsh`.
The commands differ in what they copy, not in the final copy layer:

- `ii i` Enter copies the selected variable value and closes.
- `ii i` `y` copies the selected variable value without leaving the selector.
- `ii p` `y` copies the selected rendered payload text and closes the selector.

After `ii p` `y`, copy status and the selected payload's render report are
printed immediately.

## Configuration

Manual clipboard settings have priority:

```zsh
export II_CLIP_BACKEND=osc52
export II_CLIP_CMD='tmux load-buffer -'
```

If neither variable is set, `ii` auto-detects a backend.

`ii` reads these settings from the current shell first, then from the current
tmux session environment. This lets `ii clip backend BACKEND` set a backend for
the tmux session without requiring a global `.zshrc` export.

Auto-detection is runtime-only. It does not export `II_CLIP_BACKEND`, so
`env | grep BACK` only shows a value when you set one manually.

Detection order:

1. Active SSH sessions use `osc52` when `base64` is available.
2. Local tmux sessions with `DISPLAY` and `xclip` use `xclip-both`, even when
   tmux still has stale SSH environment variables.
3. Other tmux sessions use `osc52` when `base64` is available.
4. Non-tmux fallback checks common clipboard tools.
5. tmux fallback writes only to the tmux buffer.

## Backends

`osc52`

Inside tmux, this first tries:

```zsh
tmux load-buffer -w -
```

This lets tmux handle clipboard integration. If that fails, `ii` emits a raw
OSC52 sequence. OSC52 depends on the outer terminal or terminal client allowing
clipboard writes.

`tmux`

Writes only to the tmux paste buffer:

```zsh
tmux load-buffer -
```

This is useful for deterministic testing or when system clipboard integration is
not available.

`xclip`

Writes only to the X clipboard selection:

```zsh
xclip -selection clipboard
```

`xclip-both`

Matches the common tmux copy-mode command that writes both primary and clipboard
selections:

```zsh
xclip -i -f -selection primary | xclip -i -selection clipboard
```

Use this when a local Kali VM clipboard path works through tmux copy-mode but
plain `xclip -selection clipboard` does not update the desired clipboard target:

```zsh
export II_CLIP_BACKEND=xclip-both
```

See `doc/conf/tmux.conf` for the matching tmux copy-mode binding.

## VMware Kali Notes

VMware console clipboard behavior may differ from SSH terminal clipboard
behavior:

- SSH through a terminal such as Tabby can copy through OSC52 to the host
  terminal clipboard.
- Local VMware console sessions may not pass OSC52 through to the Windows host.
- tmux copy-mode may still work if it is bound to an X clipboard command such as
  `xclip -i -f -selection primary | xclip -i -selection clipboard`.

When debugging, test each layer separately:

```zsh
printf 'tmux-clip-test' | tmux load-buffer -w -
tmux show-buffer

printf 'xclip-both-test' | xclip -i -f -selection primary | xclip -i -selection clipboard
```

If `tmux show-buffer` updates but the host clipboard does not, `ii` has handed
the text to tmux successfully and the remaining issue is the tmux-to-terminal or
terminal-to-host clipboard path.

## Clipboard Commands

Show the current context and effective backend:

```zsh
ii clip backend
```

Set a backend for this shell and the current tmux session:

```zsh
ii clip backend osc52
ii clip backend xclip-both
```

Return to auto-detection:

```zsh
ii clip backend auto
```

Run an interactive diagnostic:

```zsh
ii clip doctor
```

The doctor command copies a test token, asks whether it reached the desired
clipboard, and can set a context-appropriate backend for the current tmux
session. When `SSH_CONNECTION` is empty and `DISPLAY` plus `xclip` are
available, doctor suggests `xclip-both`.
