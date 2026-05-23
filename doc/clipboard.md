# Clipboard Behavior

`ii i` and `ii p` both copy through `ii_clip_copy` in `lib/clipboard.zsh`.
The commands differ in what they copy, not in the final copy layer:

- `ii i` copies selected variable values.
- `ii p` copies the rendered payload text.

## Configuration

Manual clipboard settings have priority:

```zsh
export II_CLIP_BACKEND=osc52
export II_CLIP_CMD='tmux load-buffer -'
```

If neither variable is set, `ii` auto-detects a backend.

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
