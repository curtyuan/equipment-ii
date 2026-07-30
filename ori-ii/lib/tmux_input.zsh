# Tmux popup controller for payload input, rendering, and pane delivery.

ii_tmux_input_target_pane() {
  tmux display-message -p '#{pane_id}' 2>/dev/null
}

ii_tmux_input_target_session() {
  local target="$1"
  tmux display-message -p -t "$target" '#{session_id}' 2>/dev/null
}

ii_tmux_input_popup() {
  ii_tmux_available || return
  local mode="$1" target="${2:-}" session="${3:-}"
  local input rendered report missing answer copy=0 copy_rc=0
  case "$mode" in
    execute) ;;
    copy-execute) copy=1 ;;
    *) print -u2 "ii: unsupported tmux input popup mode: $mode"; return 2 ;;
  esac
  [[ -n "$target" ]] || target="$(ii_tmux_input_target_pane)"
  [[ -n "$target" && "$target" == %<-> ]] || {
    print -u2 -r -- "ii: cannot determine originating pane: ${target:-[missing]}"
    return 1
  }
  [[ -n "$session" ]] || session="$(ii_tmux_input_target_session "$target")"
  [[ -n "$session" ]] || {
    print -u2 -r -- "ii: cannot determine session for target pane: $target"
    return 1
  }
  local II_PAYLOAD_TMUX_ONLY=1

  print "Paste payload input below. Enter renders; Alt-Enter adds a line; Esc cancels."
  print
  ii_payload_read_input
  local input_rc=$?
  if (( input_rc == 130 )); then
    print "cancelled"
    return 0
  fi
  (( input_rc == 0 )) || return "$input_rc"
  input="$II_PAYLOAD_INPUT_TEXT"
  [[ -n "$input" ]] || { print -u2 "ii: input is empty"; return 1; }
  ii_payload_render_text "$input" >/dev/null || return
  rendered="$II_PAYLOAD_RENDERED_TEXT"
  report="$(ii_payload_render_report)"
  missing="$(ii_payload_missing_names)"

  print "Target: $(tmux display-message -p -t "$target" '#S:#I.#P (#{pane_id})')"
  print "Command: $(tmux display-message -p -t "$target" '#{pane_current_command}')"
  [[ -n "$report" ]] && { print; print -r -- "$report"; }
  print
  ii_payload_print_separator
  print -r -- "$rendered"
  print
  [[ -n "$missing" ]] && print -u2 "Unresolved variables: ${(j:, :)${(f)missing}}"
  if (( copy )); then
    [[ -n "$missing" ]] &&
      printf 'Unresolved variables may make this payload ineffective. Copy, send and execute anyway? [y/N] ' ||
      printf 'Copy, send and execute? [y/N] '
  else
    [[ -n "$missing" ]] &&
      printf 'Unresolved variables may make this payload ineffective. Send and execute anyway? [y/N] ' ||
      printf 'Send and execute? [y/N] '
  fi
  if [[ -n "${II_INTERACTIVE_KEY:-}" ]]; then
    answer="$II_INTERACTIVE_KEY"
    print -r -- "$answer"
  else
    read -r -k 1 answer
    print
  fi
  [[ "${(L)answer}" == y ]] || { print "cancelled"; return 1; }

  (( copy )) && { ii_clip_copy "$rendered" || copy_rc=1; }
  if ! ii_tmux_send_literal "$session" "$target" "$rendered"; then
    (( copy_rc )) && print -u2 "ii: clipboard copy also failed"
    return 1
  fi
  if (( copy )); then
    (( copy_rc )) &&
      print -u2 "ii: clipboard copy failed; payload sent and executed anyway" ||
      print "payload copied, sent, and executed"
  else
    print "payload sent and executed"
  fi
}
