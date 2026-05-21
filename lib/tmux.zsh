# tmux and external command helpers.

jj_tmux_available() {
  if [[ -z "${TMUX:-}" ]]; then
    print -u2 "jj: this command must run inside tmux"
    return 1
  fi
  if ! command -v tmux >/dev/null 2>&1; then
    print -u2 "jj: tmux command not found"
    return 1
  fi
}

jj_tmux_session_name() {
  jj_tmux_available || return
  tmux display-message -p '#S'
}

jj_require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    print -u2 "jj: required command not found: $1"
    return 1
  fi
}
