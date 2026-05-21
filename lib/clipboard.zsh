# Clipboard backend detection and copy.

jj_clip_copy() {
  local text="$1"

  if [[ -n "${JJ_CLIP_CMD:-}" ]]; then
    print -rn -- "$text" | eval "$JJ_CLIP_CMD"
    return $?
  fi

  local backend
  backend="$(jj_clip_backend_detect)"
  case "$backend" in
    clip.exe) print -rn -- "$text" | clip.exe ;;
    wl-copy) print -rn -- "$text" | wl-copy ;;
    xclip) print -rn -- "$text" | xclip -selection clipboard ;;
    xsel) print -rn -- "$text" | xsel --clipboard --input ;;
    pbcopy) print -rn -- "$text" | pbcopy ;;
    tmux) print -rn -- "$text" | tmux load-buffer - ;;
    *) return 1 ;;
  esac
}

jj_clip_backend_detect() {
  local cmd
  for cmd in clip.exe wl-copy xclip xsel pbcopy; do
    if command -v "$cmd" >/dev/null 2>&1; then
      print -r -- "$cmd"
      return
    fi
  done

  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    print -r -- tmux
    return
  fi

  return 1
}
