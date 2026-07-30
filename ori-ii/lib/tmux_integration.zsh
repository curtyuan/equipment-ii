# Default tmux command alias and popup input execution.

# Keep these reloadable: plugin managers and interactive config commonly source
# a zsh plugin more than once in the same shell.
typeset -g II_TMUX_INTEGRATION_SCHEMA=2
typeset -g II_TMUX_INTEGRATION_MARKER_OPTION='@ii_integration_marker'
typeset -g II_TMUX_INTEGRATION_NOTICE_OPTION='@ii_integration_conflict_notice'

ii_cmd_tmux() {
  local help_arg
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      set -- --help
      break
    fi
  done

  case "${1:-status}" in
    status) shift; [[ $# -eq 0 ]] || { print -u2 "ii: usage: ii tmux status"; return 2; }; ii_tmux_alias_status ;;
    --help|-h)
      cat <<'EOF'
usage: ii tmux status

Aliases:
  none

Help:
  ii help tmux

The tmux command alias is installed automatically when the plugin loads inside
tmux. It adds `ii` to tmux's native `Prefix + :` command prompt without
replacing that key binding. Enter `ii` at the prompt to open an isolated popup
equivalent to `ii pie`: render, confirm, send, and execute without copying.

Set II_TMUX_INTEGRATION=0 before loading the plugin to disable automatic setup.
If another tmux command alias already owns the name `ii`, ii leaves it unchanged;
set II_TMUX_INTEGRATION_FORCE=1 to replace that conflicting alias. Status is
read-only and reports the command alias, native Prefix+: binding, and helper.
EOF
      ;;
    *) print -u2 "ii: usage: ii tmux status"; return 2 ;;
  esac
}

ii_tmux_input_helper() {
  print -r -- "${II_PLUGIN_DIR}/script/ii-tmux-input"
}

ii_tmux_input_version() {
  local version_file="${II_PLUGIN_DIR}/VERSION"
  if [[ -r "$version_file" ]]; then
    command cat "$version_file"
  else
    print "unknown"
  fi
}

ii_tmux_alias_command() {
  local helper version
  helper="$(ii_tmux_input_helper)"
  version="$(ii_tmux_input_version)"
  print -r -- "ii=display-popup -EE -T 'ii pie ${version}' -w 90% -h 90% -d '#{pane_current_path}' zsh ${(q)helper} execute"
}

ii_tmux_alias_marker() {
  local index="$1"
  print -r -- "version=${II_TMUX_INTEGRATION_SCHEMA} index=${index} helper=$(ii_tmux_input_helper)"
}

ii_tmux_alias_scan() {
  local line option value index name
  typeset -gA II_TMUX_ALIAS_VALUE=()
  typeset -gA II_TMUX_ALIAS_NAME_INDEX=()
  while IFS= read -r line; do
    [[ "$line" == command-alias\[*\]\ * ]] || continue
    option="${line%% *}"
    value="${(Q)${line#* }}"
    index="${option#command-alias\[}"
    index="${index%\]}"
    name="${value%%=*}"
    II_TMUX_ALIAS_VALUE[$index]="$value"
    [[ -n "$name" && -z "${II_TMUX_ALIAS_NAME_INDEX[$name]-}" ]] &&
      II_TMUX_ALIAS_NAME_INDEX[$name]="$index"
  done < <(tmux show-options -s command-alias 2>/dev/null)
}

ii_tmux_alias_marker_index() {
  local marker="$1" field
  for field in ${(z)marker}; do
    [[ "$field" == index=* ]] && { print -r -- "${field#index=}"; return 0; }
  done
  return 1
}

ii_tmux_alias_free_index() {
  local index=100
  while [[ -n "${II_TMUX_ALIAS_VALUE[$index]-}" ]]; do
    (( index++ ))
  done
  print -r -- "$index"
}

ii_tmux_alias_is_current() {
  local marker="$1" index expected
  index="$(ii_tmux_alias_marker_index "$marker" 2>/dev/null)" || return 1
  expected="$(ii_tmux_alias_command)"
  [[ "$marker" == "$(ii_tmux_alias_marker "$index")" &&
     "${II_TMUX_ALIAS_VALUE[$index]-}" == "$expected" ]]
}

ii_tmux_alias_value_is_owned() {
  local value="$1"
  [[ "$value" == ii=display-popup* &&
     ( "$value" == *'ii-tmux-pice'* || "$value" == *'ii-tmux-input'* ) ]]
}

ii_tmux_legacy_binding() {
  tmux list-keys -T prefix : 2>/dev/null
}

ii_tmux_legacy_binding_is_owned() {
  local binding="$1" helper="${II_PLUGIN_DIR}/script/ii-tmux-pice"
  [[ "$binding" == bind-key\ -T\ prefix\ :\ command-prompt\ -F\ -p\ :\ * &&
     "$binding" == *'if-shell -F \"##{==:%1,ii pice}\"'* &&
     "$binding" == *"display-popup -EE"*"'${helper}'"*"'#{pane_id}' '#{session_id}'"* &&
     "$binding" == *'\"%1\""' ]]
}

ii_tmux_restore_native_colon() {
  local binding
  binding="$(ii_tmux_legacy_binding)"
  if ii_tmux_legacy_binding_is_owned "$binding"; then
    tmux bind-key -T prefix : command-prompt || return
  fi
}

ii_tmux_alias_clear_legacy_state() {
  local session
  tmux set-option -gu @ii_colon_binding 2>/dev/null
  tmux set-option -gu @ii_colon_binding_saved 2>/dev/null
  for session in ${(f)"$(tmux list-sessions -F '#{session_id}' 2>/dev/null)"}; do
    tmux set-option -qu -t "$session" @ii_dispatch_enabled 2>/dev/null
  done
  return 0
}

ii_tmux_alias_install() {
  local index="$1" command marker
  command="$(ii_tmux_alias_command)" || return
  marker="$(ii_tmux_alias_marker "$index")" || return
  tmux set-option -s "command-alias[$index]" "$command" || return
  tmux set-option -gq "$II_TMUX_INTEGRATION_MARKER_OPTION" "$marker" || return
  tmux set-option -gu "$II_TMUX_INTEGRATION_NOTICE_OPTION" 2>/dev/null || true
  ii_tmux_restore_native_colon || return
  ii_tmux_alias_clear_legacy_state
}

ii_tmux_alias_ensure() {
  [[ -n "${TMUX:-}" ]] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  [[ "${II_TMUX_INTEGRATION:-1}" != 0 ]] || return 0

  local helper marker marker_index name_index notice expected force=0
  helper="$(ii_tmux_input_helper)"
  if [[ ! -r "$helper" ]]; then
    print -u2 "ii: tmux popup helper is not readable: $helper"
    return 1
  fi

  ii_tmux_alias_scan
  marker="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_MARKER_OPTION" 2>/dev/null)"
  ii_tmux_alias_is_current "$marker" && {
    ii_tmux_restore_native_colon || return
    ii_tmux_alias_clear_legacy_state
    return 0
  }
  [[ "${II_TMUX_INTEGRATION_FORCE:-0}" == 1 ]] && force=1
  name_index="${II_TMUX_ALIAS_NAME_INDEX[ii]-}"
  marker_index="$(ii_tmux_alias_marker_index "$marker" 2>/dev/null)"

  if [[ -n "$name_index" ]]; then
    if { [[ -n "$marker_index" && "$name_index" == "$marker_index" ]] &&
         ii_tmux_alias_value_is_owned "${II_TMUX_ALIAS_VALUE[$name_index]}"; } ||
       (( force )); then
      ii_tmux_alias_install "$name_index"
      return $?
    fi
    expected="version=${II_TMUX_INTEGRATION_SCHEMA} helper=$helper"
    notice="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_NOTICE_OPTION" 2>/dev/null)"
    if [[ "$notice" != "$expected" ]]; then
      print -u2 "ii: tmux command alias 'ii' is already defined; ii popup alias was not installed"
      print -u2 "ii: set II_TMUX_INTEGRATION_FORCE=1 to replace it, or II_TMUX_INTEGRATION=0 to silence this notice"
      tmux set-option -gq "$II_TMUX_INTEGRATION_NOTICE_OPTION" "$expected" 2>/dev/null
    fi
    return 0
  fi

  ii_tmux_alias_install "$(ii_tmux_alias_free_index)"
}

ii_tmux_alias_state() {
  local marker="$1" marker_index name_index
  ii_tmux_alias_scan
  ii_tmux_alias_is_current "$marker" && { print installed; return; }
  name_index="${II_TMUX_ALIAS_NAME_INDEX[ii]-}"
  marker_index="$(ii_tmux_alias_marker_index "$marker" 2>/dev/null)"
  if [[ -n "$name_index" ]]; then
    if [[ -n "$marker_index" && "$name_index" == "$marker_index" ]] &&
       ii_tmux_alias_value_is_owned "${II_TMUX_ALIAS_VALUE[$name_index]}"; then
      print stale
    else
      print conflict
    fi
  elif [[ -n "$marker_index" ]]; then
    print stale
  else
    print missing
  fi
}

ii_tmux_alias_status() {
  ii_tmux_available || return
  local configured=default marker helper server binding
  if [[ "${II_TMUX_INTEGRATION:-1}" == 0 ]]; then
    configured=disabled
  elif [[ "${II_TMUX_INTEGRATION_FORCE:-0}" == 1 ]]; then
    configured=force
  fi
  marker="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_MARKER_OPTION" 2>/dev/null)"
  helper="$(ii_tmux_input_helper)"
  server="$(tmux display-message -p '#{socket_path}' 2>/dev/null)"
  [[ -n "$server" ]] || server="${TMUX%%,*}"
  binding="$(ii_tmux_legacy_binding)"
  print "server: $server"
  print "configured: $configured"
  print "command alias: $(ii_tmux_alias_state "$marker")"
  print "command: ii"
  print "helper: $helper"
  if ii_tmux_legacy_binding_is_owned "$binding"; then
    print "Prefix+: legacy ii adapter"
  else
    print "Prefix+: native or user-defined"
  fi
}

ii_help_register tmux ii_cmd_tmux
