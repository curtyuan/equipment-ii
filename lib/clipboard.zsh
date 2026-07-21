# Clipboard backend detection and copy.

ii_clip_copy() {
  local text="$1"
  local backend clip_cmd

  backend="$(ii_clip_config_backend)"
  if [[ -n "$backend" ]]; then
    ii_clip_copy_with_backend "$backend" "$text"
    return $?
  fi

  clip_cmd="$(ii_clip_config_cmd)"
  if [[ -n "$clip_cmd" ]]; then
    if [[ "$clip_cmd" == "osc52" ]]; then
      ii_clip_copy_osc52 "$text"
      return $?
    fi
    print -rn -- "$text" | eval "$clip_cmd"
    return $?
  fi

  backend="$(ii_clip_backend_detect)"
  ii_clip_copy_with_backend "$backend" "$text"
}

ii_clip_config_backend() {
  if [[ -n "${II_CLIP_BACKEND:-}" ]]; then
    print -r -- "$II_CLIP_BACKEND"
    return
  fi

  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux show-environment II_CLIP_BACKEND 2>/dev/null | awk -F= 'NR == 1 {print $2; exit}'
  fi
}

ii_clip_config_cmd() {
  if [[ -n "${II_CLIP_CMD:-}" ]]; then
    print -r -- "$II_CLIP_CMD"
    return
  fi

  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux show-environment II_CLIP_CMD 2>/dev/null | awk -F= 'NR == 1 {print substr($0, index($0, "=") + 1); exit}'
  fi
}

ii_clip_copy_with_backend() {
  local backend="$1"
  local text="$2"

  case "$backend" in
    clip.exe) { print -rn -- "$text" | clip.exe } 2>/dev/null ;;
    wl-copy) { print -rn -- "$text" | wl-copy } 2>/dev/null ;;
    xclip) { print -rn -- "$text" | xclip -selection clipboard } 2>/dev/null ;;
    xclip-both) { print -rn -- "$text" | xclip -i -f -selection primary | xclip -i -selection clipboard } 2>/dev/null ;;
    xsel) { print -rn -- "$text" | xsel --clipboard --input } 2>/dev/null ;;
    pbcopy) { print -rn -- "$text" | pbcopy } 2>/dev/null ;;
    osc52) ii_clip_copy_osc52 "$text" ;;
    tmux) { print -rn -- "$text" | tmux load-buffer - } 2>/dev/null ;;
    *) return 1 ;;
  esac
}

ii_clip_backend_detect() {
  local cmd
  if ii_clip_ssh_active && command -v base64 >/dev/null 2>&1; then
    print -r -- osc52
    return
  fi

  if [[ -n "${TMUX:-}" && -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
    print -r -- xclip-both
    return
  fi

  if [[ -n "${TMUX:-}" ]] && command -v base64 >/dev/null 2>&1; then
    print -r -- osc52
    return
  fi

  if [[ -n "${SSH_TTY:-}" ]] && command -v base64 >/dev/null 2>&1; then
    print -r -- osc52
    return
  fi

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

ii_clip_backend_effective() {
  local backend clip_cmd

  backend="$(ii_clip_config_backend)"
  if [[ -n "$backend" ]]; then
    print -r -- "$backend"
    return
  fi

  clip_cmd="$(ii_clip_config_cmd)"
  if [[ -n "$clip_cmd" ]]; then
    print -r -- "cmd:$clip_cmd"
    return
  fi

  ii_clip_backend_detect
}

ii_clip_ssh_active() {
  [[ -n "${SSH_CONNECTION:-}" || ( -n "${SSH_CLIENT:-}" && -z "${DISPLAY:-}" ) ]]
}

ii_clip_context() {
  if ii_clip_ssh_active; then
    print -r -- ssh
  else
    print -r -- local
  fi
}

ii_cmd_clip() {
  local help_arg
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      set -- --help
      break
    fi
  done

  case "${1:-backend}" in
    --help|-h|help)
      cat <<'EOF'
usage: ii clip backend
       ii clip backend auto
       ii clip backend BACKEND
       ii clip doctor

Aliases:
  clipboard

Help:
  ii help clip

Inspect or change clipboard backend settings for this shell and tmux session.

backend prints the effective backend. backend auto clears II_CLIP_BACKEND and
II_CLIP_CMD from this shell and the current tmux session. backend BACKEND sets
II_CLIP_BACKEND in this shell and the current tmux session.

doctor prints clipboard context, copies a test token, asks whether it reached
the desired clipboard, and can set a context-appropriate backend.
EOF
      ;;
    backend)
      shift
      ii_cmd_clip_backend "$@"
      ;;
    doctor)
      shift
      ii_cmd_clip_doctor "$@"
      ;;
    *)
      print -u2 "ii: unknown clip command: $1"
      return 2
      ;;
  esac
}

ii_cmd_clip_backend() {
  ii_tmux_available || return

  case "${1:-}" in
    "")
      print "context: $(ii_clip_context)"
      print "backend: $(ii_clip_backend_effective)"
      ;;
    auto)
      unset II_CLIP_BACKEND
      unset II_CLIP_CMD
      tmux set-environment -u II_CLIP_BACKEND 2>/dev/null
      tmux set-environment -u II_CLIP_CMD 2>/dev/null
      print "clipboard backend: auto"
      ;;
    *)
      export II_CLIP_BACKEND="$1"
      unset II_CLIP_CMD
      tmux set-environment II_CLIP_BACKEND "$1" || return
      tmux set-environment -u II_CLIP_CMD 2>/dev/null
      print "clipboard backend: $1"
      ;;
  esac
}

ii_cmd_clip_doctor() {
  ii_tmux_available || return

  local context backend suggested token answer
  context="$(ii_clip_context)"
  backend="$(ii_clip_backend_effective)"
  token="ii-clip-test-$(date +%s)"

  print "context: $context"
  print "tmux: ${TMUX:-}"
  print "display: ${DISPLAY:-}"
  print "ssh_connection: ${SSH_CONNECTION:-}"
  print "ssh_client: ${SSH_CLIENT:-}"
  print "ssh_tty: ${SSH_TTY:-}"
  print "configured_backend: ${II_CLIP_BACKEND:-}"
  print "configured_cmd: ${II_CLIP_CMD:-}"
  print "effective_backend: $backend"
  print

  if ! ii_clip_copy "$token"; then
    print -u2 "ii: test copy failed"
  else
    print "copied test token: $token"
  fi

  printf 'Did this reach the desired clipboard? [y/N] '
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] && return 0

  if [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1 && ! ii_clip_ssh_active; then
    suggested="xclip-both"
  elif [[ "$context" == "ssh" ]]; then
    suggested="osc52"
  else
    suggested="tmux"
  fi

  printf 'Use %s for this tmux session? [y/N] ' "$suggested"
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || return 1
  ii_cmd_clip_backend "$suggested"
}

ii_clip_copy_osc52() {
  local text="$1"
  local sequence

  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    if { print -rn -- "$text" | tmux load-buffer -w - } 2>/dev/null; then
      return 0
    fi
    if { print -rn -- "$text" | tmux load-buffer - } 2>/dev/null; then
      return 0
    fi
  fi

  sequence="$(ii_clip_osc52_sequence "$text")" || return

  if [[ -w /dev/tty ]]; then
    { print -rn -- "$sequence" > /dev/tty } 2>/dev/null
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

ii_help_register clip ii_cmd_clip clipboard
