# Clipboard backend detection and copy.

ii_clip_copy() {
  local text="$1"

  if [[ -n "${JJ_CLIP_BACKEND:-}" ]]; then
    ii_clip_copy_with_backend "$JJ_CLIP_BACKEND" "$text"
    return $?
  fi

  if [[ -n "${JJ_CLIP_CMD:-}" ]]; then
    if [[ "$JJ_CLIP_CMD" == "osc52" ]]; then
      ii_clip_copy_osc52 "$text"
      return $?
    fi
    print -rn -- "$text" | eval "$JJ_CLIP_CMD"
    return $?
  fi

  local backend
  backend="$(ii_clip_backend_detect)"
  ii_clip_copy_with_backend "$backend" "$text"
}

ii_clip_copy_with_backend() {
  local backend="$1"
  local text="$2"

  case "$backend" in
    clip.exe) print -rn -- "$text" | clip.exe ;;
    wl-copy) print -rn -- "$text" | wl-copy ;;
    xclip) print -rn -- "$text" | xclip -selection clipboard ;;
    xsel) print -rn -- "$text" | xsel --clipboard --input ;;
    pbcopy) print -rn -- "$text" | pbcopy ;;
    osc52) ii_clip_copy_osc52 "$text" ;;
    tmux) print -rn -- "$text" | tmux load-buffer - ;;
    *) return 1 ;;
  esac
}

ii_clip_backend_detect() {
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

ii_clip_copy_osc52() {
  local text="$1"
  local sequence
  sequence="$(ii_clip_osc52_sequence "$text")" || return

  if [[ -w /dev/tty ]]; then
    print -rn -- "$sequence" > /dev/tty
  else
    print -rn -- "$sequence"
  fi
}

ii_clip_osc52_sequence() {
  local text="$1"
  local encoded sequence esc bel

  if ! command -v base64 >/dev/null 2>&1; then
    print -u2 "ii: required command not found: base64"
    return 1
  fi

  encoded="$(print -rn -- "$text" | base64 | tr -d '\n')" || return
  esc=$'\033'
  bel=$'\a'
  sequence="${esc}]52;c;${encoded}${bel}"

  if [[ -n "${TMUX:-}" ]]; then
    sequence="${esc}Ptmux;${esc}${sequence}${esc}\\"
  fi

  print -rn -- "$sequence"
}
