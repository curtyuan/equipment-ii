# Default tmux command-prompt dispatcher and popup input execution.

typeset -gr II_TMUX_INTEGRATION_SCHEMA=1
typeset -gr II_TMUX_INTEGRATION_MARKER_OPTION='@ii_integration_marker'
typeset -gr II_TMUX_INTEGRATION_NOTICE_OPTION='@ii_integration_conflict_notice'

ii_cmd_tmux() {
  local help_arg
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      set -- --help
      break
    fi
  done

  case "${1:-status}" in
    status) shift; [[ $# -eq 0 ]] || { print -u2 "ii: usage: ii tmux status"; return 2; }; ii_tmux_dispatch_status ;;
    --help|-h)
      cat <<'EOF'
usage: ii tmux status

Aliases:
  none

Help:
  ii help tmux

The integration is installed automatically when the plugin loads inside tmux.
Set II_TMUX_INTEGRATION=0 before loading the plugin to disable automatic setup.
If Prefix+: has a custom binding, ii leaves it unchanged; set
II_TMUX_INTEGRATION_FORCE=1 to replace it. Status is read-only and reports the
configuration, binding state, and popup helper path.

Entering `ii pice` through Prefix+: opens a popup for pasted payload input.
Enter finishes input, Alt+Enter inserts a newline, and Esc cancels. The popup
renders current-session ii variables, shows the destination pane, and asks for
confirmation before copying and sending the rendered command there.

Missing variables remain visible and require explicit confirmation. Clipboard
failure does not prevent a confirmed command from being sent.
EOF
      ;;
    *) print -u2 "ii: usage: ii tmux status"; return 2 ;;
  esac
}

ii_tmux_dispatch_helper() {
  print -r -- "${II_PLUGIN_DIR}/script/ii-tmux-pice"
}

ii_tmux_dispatch_marker() {
  print -r -- "version=${II_TMUX_INTEGRATION_SCHEMA} helper=$(ii_tmux_dispatch_helper)"
}

ii_tmux_dispatch_binding() {
  local helper="$(ii_tmux_dispatch_helper)"
  print -r -- "if-shell -F \"##{==:%1,ii pice}\" \"display-popup -EE -T 'ii pice' -w 90% -h 90% -d '#{pane_current_path}' '${helper}' '#{pane_id}' '#{session_id}'\" \"%1\""
}

ii_tmux_dispatch_current_binding() {
  tmux list-keys -T prefix : 2>/dev/null
}

ii_tmux_dispatch_is_standard_binding() {
  local binding="$1"
  [[ "$binding" =~ '^bind-key[[:space:]]+(-r[[:space:]]+)?-T[[:space:]]+prefix[[:space:]]+:[[:space:]]+command-prompt[[:space:]]*$' ]]
}

ii_tmux_dispatch_is_legacy_binding() {
  local binding="$1"
  [[ "$binding" == *'@ii_dispatch_enabled'* && "$binding" == *'ii pice'* && "$binding" == *'ii-tmux-pice'* ]]
}

ii_tmux_dispatch_is_owned_binding() {
  local binding="$1"
  [[ "$binding" == *'ii pice'* && "$binding" == *'ii-tmux-pice'* ]]
}

ii_tmux_dispatch_is_current_binding() {
  local binding="$1" marker="$2" expected
  expected="$(ii_tmux_dispatch_marker)"
  [[ "$marker" == "$expected" && "$binding" == *'ii pice'* && "$binding" == *"$(ii_tmux_dispatch_helper)"* && "$binding" != *'@ii_dispatch_enabled'* ]]
}

ii_tmux_dispatch_clear_legacy_state() {
  local session
  tmux set-option -gu @ii_colon_binding 2>/dev/null
  tmux set-option -gu @ii_colon_binding_saved 2>/dev/null
  for session in ${(f)"$(tmux list-sessions -F '#{session_id}' 2>/dev/null)"}; do
    tmux set-option -qu -t "$session" @ii_dispatch_enabled 2>/dev/null
  done
  return 0
}

ii_tmux_dispatch_install() {
  local binding marker
  binding="$(ii_tmux_dispatch_binding)" || return
  marker="$(ii_tmux_dispatch_marker)" || return
  tmux bind-key -T prefix : command-prompt -F -p : "$binding" || return
  tmux set-option -gq "$II_TMUX_INTEGRATION_MARKER_OPTION" "$marker" || return
  tmux set-option -gu "$II_TMUX_INTEGRATION_NOTICE_OPTION" 2>/dev/null || true
  ii_tmux_dispatch_clear_legacy_state
  return 0
}

ii_tmux_dispatch_ensure() {
  [[ -n "${TMUX:-}" ]] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  [[ "${II_TMUX_INTEGRATION:-1}" != 0 ]] || return 0

  local helper binding marker notice expected force=0
  helper="$(ii_tmux_dispatch_helper)"
  if [[ ! -r "$helper" ]]; then
    print -u2 "ii: tmux popup helper is not readable: $helper"
    return 1
  fi

  binding="$(ii_tmux_dispatch_current_binding)"
  marker="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_MARKER_OPTION" 2>/dev/null)"
  ii_tmux_dispatch_is_current_binding "$binding" "$marker" && return 0
  [[ "${II_TMUX_INTEGRATION_FORCE:-0}" == 1 ]] && force=1

  if [[ -z "$binding" ]] || ii_tmux_dispatch_is_standard_binding "$binding" || ii_tmux_dispatch_is_owned_binding "$binding" || (( force )); then
    ii_tmux_dispatch_install
    return $?
  fi

  expected="$(ii_tmux_dispatch_marker)"
  notice="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_NOTICE_OPTION" 2>/dev/null)"
  if [[ "$notice" != "$expected" ]]; then
    print -u2 "ii: Prefix+: has a custom tmux binding; ii popup integration was not installed"
    print -u2 "ii: set II_TMUX_INTEGRATION_FORCE=1 to replace it, or II_TMUX_INTEGRATION=0 to silence this notice"
    tmux set-option -gq "$II_TMUX_INTEGRATION_NOTICE_OPTION" "$expected" 2>/dev/null
  fi
  return 0
}

ii_tmux_dispatch_binding_state() {
  local binding="$1" marker="$2"
  if ii_tmux_dispatch_is_current_binding "$binding" "$marker"; then
    print installed
  elif ii_tmux_dispatch_is_owned_binding "$binding"; then
    print stale
  elif [[ -z "$binding" ]]; then
    print missing
  elif ii_tmux_dispatch_is_standard_binding "$binding"; then
    [[ -n "$marker" ]] && print stale || print standard
  else
    print custom
  fi
}

ii_tmux_dispatch_status() {
  ii_tmux_available || return
  local configured=default binding marker helper server
  if [[ "${II_TMUX_INTEGRATION:-1}" == 0 ]]; then
    configured=disabled
  elif [[ "${II_TMUX_INTEGRATION_FORCE:-0}" == 1 ]]; then
    configured=force
  fi
  binding="$(ii_tmux_dispatch_current_binding)"
  marker="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_MARKER_OPTION" 2>/dev/null)"
  helper="$(ii_tmux_dispatch_helper)"
  server="$(tmux display-message -p '#{socket_path}' 2>/dev/null)"
  [[ -n "$server" ]] || server="${TMUX%%,*}"
  print "server: $server"
  print "configured: $configured"
  print "binding: $(ii_tmux_dispatch_binding_state "$binding" "$marker")"
  print "helper: $helper"
  print "Prefix+: command: ii pice"
}

ii_tmux_pice_popup() {
  ii_tmux_available || return
  local target="${1:-${TMUX_PANE:-}}" session="${2:-}" input rendered report missing answer copy_rc=0
  [[ -n "$target" ]] || { print -u2 "ii: cannot determine originating pane"; return 1; }
  [[ -n "$session" ]] || session="$(tmux display-message -p -t "$target" '#{session_id}')"
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
  if [[ -n "$missing" ]]; then
    print -u2 "Unresolved variables: ${(j:, :)${(f)missing}}"
    printf 'Unresolved variables may make this payload ineffective. Copy, send and execute anyway? [y/N] '
  else
    printf 'Copy, send and execute? [y/N] '
  fi
  read -r -k 1 answer
  print
  [[ "${(L)answer}" == y ]] || { print "cancelled"; return 1; }

  ii_clip_copy "$rendered" || copy_rc=1
  if ! ii_tmux_send_literal "$session" "$target" "$rendered"; then
    (( copy_rc )) && print -u2 "ii: clipboard copy also failed"
    return 1
  fi
  (( copy_rc )) && print -u2 "ii: clipboard copy failed; payload sent and executed anyway" || print "payload copied, sent, and executed"
}

ii_help_register tmux ii_cmd_tmux
