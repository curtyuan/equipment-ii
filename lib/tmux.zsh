# tmux and external command helpers.

ii_tmux_available() {
  if [[ -z "${TMUX:-}" ]]; then
    print -u2 "ii: this command must run inside tmux"
    return 1
  fi
  if ! command -v tmux >/dev/null 2>&1; then
    print -u2 "ii: tmux command not found"
    return 1
  fi
}

ii_tmux_session_name() {
  ii_tmux_available || return
  tmux display-message -p '#S'
}

ii_require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    print -u2 "ii: required command not found: $1"
    return 1
  fi
}
