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

ii_tmux_pane_snapshot() {
  local target="$1" format
  format='#{pane_id}'$'\t''#{session_id}'$'\t''#{window_id}'$'\t''#{pane_dead}'$'\t''#{pane_in_mode}'$'\t''#{pane_current_command}'
  tmux display-message -p -t "$target" "$format" 2>/dev/null
}

ii_tmux_pane_identity_valid() {
  local target="$1" session="$2" snapshot pane current_session window dead in_mode command
  snapshot="$(ii_tmux_pane_snapshot "$target")"
  [[ -n "$snapshot" ]] || {
    print -u2 -r -- "ii: target pane is no longer available: $target"
    return 1
  }
  IFS=$'\t' read -r pane current_session window dead in_mode command <<< "$snapshot"
  [[ "$pane" == "$target" && "$current_session" == "$session" && "$dead" != 1 ]] || {
    print -u2 -r -- \
      "ii: target pane identity changed: expected pane=$target session=$session; actual pane=${pane:-[missing]} session=${current_session:-[missing]} dead=${dead:-[missing]}"
    return 1
  }
}

ii_tmux_send_literal() {
  local session="$1" target="$2" text="$3" buffer
  ii_tmux_pane_identity_valid "$target" "$session" || return
  buffer="ii-send-${$}-${RANDOM}"
  if ! print -rn -- "$text" | tmux load-buffer -b "$buffer" -; then
    print -u2 "ii: failed to create tmux send buffer"
    return 1
  fi
  if ! tmux paste-buffer -b "$buffer" -t "$target" -d; then
    print -u2 -r -- "ii: failed to paste payload into target pane: $target"
    tmux delete-buffer -b "$buffer" 2>/dev/null
    return 1
  fi
  if ! tmux send-keys -t "$target" Enter; then
    print -u2 -r -- "ii: payload was pasted but final Enter failed for pane: $target"
    return 1
  fi
}
