# Optional tmux command-prompt dispatcher and popup input execution.

ii_cmd_tmux() {
  case "${1:-status}" in
    enable) shift; [[ $# -eq 0 ]] || { print -u2 "ii: usage: ii tmux enable"; return 2; }; ii_tmux_dispatch_enable ;;
    status) shift; [[ $# -eq 0 ]] || { print -u2 "ii: usage: ii tmux status"; return 2; }; ii_tmux_dispatch_status ;;
    disable) shift; [[ $# -eq 0 ]] || { print -u2 "ii: usage: ii tmux disable"; return 2; }; ii_tmux_dispatch_disable ;;
    --help|-h)
      cat <<'EOF'
usage: ii tmux enable
       ii tmux status
       ii tmux disable

Aliases:
  none

Help:
  ii help tmux

Enable installs a server-wide Prefix+: dispatcher and enables it for the
current session. Only the exact command `ii pice` enters ii; every other input
continues through tmux's normal command prompt path.

The tmux ii pice path is:
  popup input -> tmux-variable render -> popup confirmation -> clipboard copy
  -> literal paste to the originating pane -> one final Enter

The popup accepts pasted input. Ctrl-D finishes input and starts rendering;
Ctrl-C cancels. It does not read an existing tmux buffer as payload input.
Rendering uses only ii_ values stored in the current tmux session and ignores
shell-local overrides. The preview shows the originating pane and its current
foreground command.

The shell ii pice path is:
  stdin/input -> render -> confirmation -> clipboard copy -> current shell

Missing lowercase render variables are preserved and require explicit
confirmation. Clipboard failure does not prevent confirmed execution.
EOF
      ;;
    *) print -u2 "ii: usage: ii tmux enable|status|disable"; return 2 ;;
  esac
}

ii_tmux_dispatch_binding() {
  local helper="${II_PLUGIN_DIR}/script/ii-tmux-pice"
  print -r -- "if-shell -F \"##{&&:##{==:##{@ii_dispatch_enabled},1},##{==:%1,ii pice}}\" \"display-popup -E -T 'ii pice' -w 90% -h 90% -d '#{pane_current_path}' '${helper}' '#{pane_id}' '#{session_id}'\" \"%1\""
}

ii_tmux_dispatch_enable() {
  ii_tmux_available || return
  local saved saved_flag binding
  saved_flag="$(tmux show-option -gqv @ii_colon_binding_saved)"
  if [[ "$saved_flag" != 1 ]]; then
    saved="$(tmux list-keys -T prefix : 2>/dev/null)"
    tmux set-option -gq @ii_colon_binding "$saved" || return
    tmux set-option -gq @ii_colon_binding_saved 1 || return
  fi
  binding="$(ii_tmux_dispatch_binding)" || return
  tmux bind-key -T prefix : command-prompt -F -p : "$binding" || return
  tmux set-option -q @ii_dispatch_enabled 1 || return
  print "ii tmux dispatcher enabled for session $(ii_tmux_session_name)"
}

ii_tmux_dispatch_status() {
  ii_tmux_available || return
  local enabled saved
  enabled="$(tmux show-option -qv @ii_dispatch_enabled)"
  saved="$(tmux show-option -gqv @ii_colon_binding_saved)"
  print "session: $(ii_tmux_session_name)"
  print "enabled: ${enabled:-0}"
  print "server binding installed: $([[ "$saved" == 1 ]] && print yes || print no)"
  print "supported dispatcher command: ii pice"
}

ii_tmux_dispatch_disable() {
  ii_tmux_available || return
  tmux set-option -qu @ii_dispatch_enabled 2>/dev/null
  local session any=0 value saved temp
  for session in ${(f)"$(tmux list-sessions -F '#{session_id}' 2>/dev/null)"}; do
    value="$(tmux show-option -qv -t "$session" @ii_dispatch_enabled 2>/dev/null)"
    [[ "$value" == 1 ]] && { any=1; break; }
  done
  if (( ! any )); then
    saved="$(tmux show-option -gqv @ii_colon_binding)"
    tmux unbind-key -T prefix : 2>/dev/null
    if [[ -n "$saved" ]]; then
      temp="$(mktemp "${TMPDIR:-/tmp}/ii-tmux-binding.XXXXXX")" || return
      print -r -- "$saved" >| "$temp"
      tmux source-file "$temp"
      command rm -f -- "$temp"
    fi
    tmux set-option -gu @ii_colon_binding 2>/dev/null
    tmux set-option -gu @ii_colon_binding_saved 2>/dev/null
  fi
  print "ii tmux dispatcher disabled for session $(ii_tmux_session_name)"
}

ii_tmux_pice_popup() {
  ii_tmux_available || return
  local target="${1:-${TMUX_PANE:-}}" session="${2:-}" input rendered report missing answer buffer copy_rc=0
  [[ -n "$target" ]] || { print -u2 "ii: cannot determine originating pane"; return 1; }
  [[ -n "$session" ]] || session="$(tmux display-message -p -t "$target" '#{session_id}')"
  local II_PAYLOAD_TMUX_ONLY=1

  print "Paste payload input below. Press Ctrl-D to render; Ctrl-C cancels."
  print
  input="$(command cat; print -rn -- x)" || { print -u2 "ii: input cancelled"; return 1; }
  input="${input%x}"
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
  if [[ "$(tmux display-message -p -t "$target" '#{session_id}' 2>/dev/null)" != "$session" ]]; then
    print -u2 "ii: target pane is no longer available"
    (( copy_rc )) && print -u2 "ii: clipboard copy also failed"
    return 1
  fi
  buffer="ii-pice-${$}-${RANDOM}"
  print -rn -- "$rendered" | tmux load-buffer -b "$buffer" - || return
  tmux paste-buffer -b "$buffer" -t "$target" -d || return
  tmux send-keys -t "$target" Enter || return
  (( copy_rc )) && print -u2 "ii: clipboard copy failed; payload sent and executed anyway" || print "payload copied, sent, and executed"
}

ii_help_register tmux ii_cmd_tmux
