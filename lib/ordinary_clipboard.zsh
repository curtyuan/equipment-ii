# Single Zsh-owned clipboard configuration, detection, copy, and diagnostics.

ii_zsh_clip_context() {
  if [[ -n "${SSH_CONNECTION:-}" || ( -n "${SSH_CLIENT:-}" && -z "${DISPLAY:-}" ) ]]; then
    print -r -- ssh
  else
    print -r -- local
  fi
}

ii_zsh_clip_config() {
  local name="$1" value="${(P)name:-}"
  if [[ -z "$value" && -n "${TMUX:-}" ]]; then
    value="$(tmux show-environment "$name" 2>/dev/null)"
    value="${value#${name}=}"
  fi
  print -r -- "$value"
}

ii_zsh_clip_detect() {
  if [[ "$(ii_zsh_clip_context)" == ssh && $+commands[base64] -eq 1 ]]; then
    print -r -- osc52
  elif [[ -n "${TMUX:-}" && -n "${DISPLAY:-}" && $+commands[xclip] -eq 1 ]]; then
    print -r -- xclip-both
  elif [[ -n "${TMUX:-}" && $+commands[base64] -eq 1 ]]; then
    print -r -- osc52
  elif (( $+commands[clip.exe] )); then print -r -- clip.exe
  elif (( $+commands[wl-copy] )); then print -r -- wl-copy
  elif (( $+commands[xclip] )); then print -r -- xclip
  elif (( $+commands[xsel] )); then print -r -- xsel
  elif (( $+commands[pbcopy] )); then print -r -- pbcopy
  elif [[ -n "${TMUX:-}" && $+commands[tmux] -eq 1 ]]; then print -r -- tmux
  else return 1
  fi
}

ii_zsh_clip_effective() {
  local backend command
  backend="$(ii_zsh_clip_config II_CLIP_BACKEND)"
  [[ -n "$backend" && "$backend" != auto ]] && { print -r -- "$backend"; return; }
  command="$(ii_zsh_clip_config II_CLIP_CMD)"
  [[ -n "$command" ]] && { print -r -- "cmd:$command"; return; }
  ii_zsh_clip_detect
}

ii_zsh_clip_copy_osc52() {
  local text="$1" encoded sequence
  if [[ -n "${TMUX:-}" ]]; then
    print -rn -- "$text" | tmux load-buffer -w - 2>/dev/null && return
    print -rn -- "$text" | tmux load-buffer - 2>/dev/null && return
  fi
  (( $+commands[base64] )) || return 1
  encoded="$(print -rn -- "$text" | base64 | tr -d '\n')" || return
  sequence=$'\e]52;c;'"${encoded}"$'\a'
  [[ -n "${TMUX:-}" ]] && sequence=$'\ePtmux;\e'"${sequence}"$'\e\\'
  if [[ -w /dev/tty ]]; then
    print -rn -- "$sequence" >/dev/tty
  else
    print -rn -- "$sequence"
  fi
}

ii_zsh_clip_copy() {
  local text="$1" backend command
  backend="$(ii_zsh_clip_config II_CLIP_BACKEND)"
  command="$(ii_zsh_clip_config II_CLIP_CMD)"
  if [[ -n "$command" && -z "$backend" ]]; then
    [[ "$command" == osc52 ]] && { ii_zsh_clip_copy_osc52 "$text"; return; }
    print -rn -- "$text" | command sh -c "$command"
    return
  fi
  [[ -n "$backend" && "$backend" != auto ]] || backend="$(ii_zsh_clip_detect)" || return
  case "$backend" in
    tmux) print -rn -- "$text" | tmux load-buffer - ;;
    wl-copy|pbcopy|clip.exe) print -rn -- "$text" | command "$backend" ;;
    xclip) print -rn -- "$text" | command xclip -selection clipboard ;;
    xclip-both) print -rn -- "$text" | xclip -i -f -selection primary | xclip -i -selection clipboard ;;
    xsel) print -rn -- "$text" | command xsel --clipboard --input ;;
    osc52) ii_zsh_clip_copy_osc52 "$text" ;;
    *) return 1 ;;
  esac
}

ii_zsh_clip_set_backend() {
  local backend="$1"
  if [[ "$backend" == auto ]]; then
    unset II_CLIP_BACKEND II_CLIP_CMD
    tmux set-environment -u II_CLIP_BACKEND 2>/dev/null || true
    tmux set-environment -u II_CLIP_CMD 2>/dev/null || true
    print -r -- 'clipboard backend: auto'
    return
  fi
  export II_CLIP_BACKEND="$backend"
  unset II_CLIP_CMD
  tmux set-environment II_CLIP_BACKEND "$backend" || return
  tmux set-environment -u II_CLIP_CMD 2>/dev/null || true
  print -r -- "clipboard backend: $backend"
}

ii_zsh_cmd_clip() {
  shift
  ii_zsh_tmux_available || return
  local action="${1:-backend}"
  shift 2>/dev/null || true
  case "$action" in
    backend)
      [[ $# -le 1 ]] || { print -u2 'ii: usage: ii clip backend [auto|BACKEND]'; return 2; }
      if [[ $# -eq 0 ]]; then
        print -r -- "context: $(ii_zsh_clip_context)"
        print -r -- "backend: $(ii_zsh_clip_effective)"
      else
        ii_zsh_clip_set_backend "$1"
      fi
      ;;
    doctor)
      local context backend token answer suggested
      context="$(ii_zsh_clip_context)"
      backend="$(ii_zsh_clip_effective 2>/dev/null)"
      token="ii-clip-test-$(date +%s)"
      print -r -- "context: $context"
      print -r -- "tmux: ${TMUX:-}"
      print -r -- "display: ${DISPLAY:-}"
      print -r -- "ssh_connection: ${SSH_CONNECTION:-}"
      print -r -- "ssh_client: ${SSH_CLIENT:-}"
      print -r -- "ssh_tty: ${SSH_TTY:-}"
      print -r -- "configured_backend: ${II_CLIP_BACKEND:-}"
      print -r -- "configured_cmd: ${II_CLIP_CMD:-}"
      print -r -- "effective_backend: $backend"
      print
      if ii_zsh_clip_copy "$token"; then print -r -- "copied test token: $token"
      else print -u2 'ii: test copy failed'; fi
      print -n -- 'Did this reach the desired clipboard? [y/N] '
      IFS= read -r answer || true
      [[ "${(L)answer}" == y ]] && return 0
      if [[ "$context" == ssh ]]; then suggested=osc52
      elif [[ -n "${DISPLAY:-}" && $+commands[xclip] -eq 1 ]]; then suggested=xclip-both
      else suggested=tmux
      fi
      print -n -- "Use $suggested for this tmux session? [y/N] "
      IFS= read -r answer || true
      [[ "${(L)answer}" == y ]] || return 1
      ii_zsh_clip_set_backend "$suggested"
      ;;
    *) print -u2 "ii: unknown clip command: $action"; return 2 ;;
  esac
}
