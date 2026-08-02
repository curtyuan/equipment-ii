# Zsh-owned tmux command alias installation and status.

typeset -g II_TMUX_INTEGRATION_SCHEMA=2
typeset -g II_TMUX_INTEGRATION_MARKER='@ii_integration_marker'
typeset -g II_TMUX_INTEGRATION_NOTICE='@ii_integration_conflict_notice'

ii_zsh_tmux_alias_command() {
  local version=unknown
  [[ -r "${II_GO_ROOT}/VERSION" ]] && version="$(<"${II_GO_ROOT}/VERSION")"
  print -r -- "ii=display-popup -EE -T 'ii pie ${version}' -w 90% -h 90% -d '#{pane_current_path}' ${(q)II_GO_BIN} __tmux_popup execute"
}

ii_zsh_tmux_scan_aliases() {
  local alias_line option alias_value alias_index alias_name
  typeset -gA II_TMUX_ALIAS_VALUES=()
  typeset -gA II_TMUX_ALIAS_INDEX=()
  while IFS= read -r alias_line; do
    [[ "$alias_line" == command-alias\[*\]\ * ]] || continue
    option="${alias_line%% *}"
    alias_value="${(Q)${alias_line#* }}"
    alias_index="${${option#command-alias\[}%\]}"
    alias_name="${alias_value%%=*}"
    II_TMUX_ALIAS_VALUES[$alias_index]="$alias_value"
    [[ -n "$alias_name" && -z "${II_TMUX_ALIAS_INDEX[$alias_name]:-}" ]] && II_TMUX_ALIAS_INDEX[$alias_name]="$alias_index"
  done < <(tmux show-options -s command-alias 2>/dev/null)
}

ii_zsh_tmux_marker_field() {
  local marker="$1" wanted="$2" field
  for field in ${(z)marker}; do
    [[ "$field" == "$wanted"=* ]] && { print -r -- "${field#*=}"; return; }
  done
  return 1
}

ii_zsh_tmux_owned_alias() {
  [[ "$1" == ii=display-popup* && "$1" == *(__tmux_popup|ii-tmux-input|ii-tmux-pice)* ]]
}

ii_zsh_tmux_free_alias_index() {
  local -i alias_index=100
  while [[ -n "${II_TMUX_ALIAS_VALUES[$alias_index]:-}" ]]; do (( ++alias_index )); done
  print -r -- "$alias_index"
}

ii_zsh_tmux_finish_install() {
  local binding session
  binding="$(tmux list-keys -T prefix : 2>/dev/null)"
  if [[ "$binding" == *'if-shell -F "##{==:%1,ii pice}"'* && "$binding" == *ii-tmux-pice* ]]; then
    tmux bind-key -T prefix : command-prompt || return
  fi
  tmux set-option -gu @ii_colon_binding 2>/dev/null || true
  tmux set-option -gu @ii_colon_binding_saved 2>/dev/null || true
  for session in ${(f)"$(tmux list-sessions -F '#{session_id}' 2>/dev/null)"}; do
    tmux set-option -qu -t "$session" @ii_dispatch_enabled 2>/dev/null || true
  done
}

ii_zsh_tmux_install_alias() {
  local alias_index="$1" alias_command marker
  alias_command="$(ii_zsh_tmux_alias_command)"
  marker="version=${II_TMUX_INTEGRATION_SCHEMA} index=${alias_index} helper=${II_GO_BIN}"
  tmux set-option -s "command-alias[$alias_index]" "$alias_command" || return
  tmux set-option -gq "$II_TMUX_INTEGRATION_MARKER" "$marker" || return
  tmux set-option -gu "$II_TMUX_INTEGRATION_NOTICE" 2>/dev/null || true
  ii_zsh_tmux_finish_install
}

ii_zsh_tmux_ensure() {
  [[ -n "${TMUX:-}" && "${II_TMUX_INTEGRATION:-1}" != 0 && $+commands[tmux] -eq 1 ]] || return 0
  [[ -x "$II_GO_BIN" ]] || { print -u2 -- "ii: Go runtime is not executable: $II_GO_BIN"; return 1; }
  local marker marker_index alias_index expected_marker expected_command notice force=0
  ii_zsh_tmux_scan_aliases
  marker="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_MARKER" 2>/dev/null)"
  marker_index="$(ii_zsh_tmux_marker_field "$marker" index 2>/dev/null)"
  expected_command="$(ii_zsh_tmux_alias_command)"
  expected_marker="version=${II_TMUX_INTEGRATION_SCHEMA} index=${marker_index} helper=${II_GO_BIN}"
  if [[ -n "$marker_index" && "$marker" == "$expected_marker" && "${II_TMUX_ALIAS_VALUES[$marker_index]:-}" == "$expected_command" ]]; then
    ii_zsh_tmux_finish_install
    return
  fi
  alias_index="${II_TMUX_ALIAS_INDEX[ii]:-}"
  [[ "${II_TMUX_INTEGRATION_FORCE:-0}" == 1 ]] && force=1
  if [[ -n "$alias_index" ]]; then
    if { [[ "$alias_index" == "$marker_index" ]] && ii_zsh_tmux_owned_alias "${II_TMUX_ALIAS_VALUES[$alias_index]}"; } || (( force )); then
      ii_zsh_tmux_install_alias "$alias_index"
      return
    fi
    notice="version=${II_TMUX_INTEGRATION_SCHEMA} helper=${II_GO_BIN}"
    if [[ "$(tmux show-option -gqv "$II_TMUX_INTEGRATION_NOTICE" 2>/dev/null)" != "$notice" ]]; then
      print -u2 -- "ii: tmux command alias 'ii' is already defined; ii popup alias was not installed"
      print -u2 -- 'ii: set II_TMUX_INTEGRATION_FORCE=1 to replace it, or II_TMUX_INTEGRATION=0 to silence this notice'
      tmux set-option -gq "$II_TMUX_INTEGRATION_NOTICE" "$notice" 2>/dev/null || true
    fi
    return 0
  fi
  ii_zsh_tmux_install_alias "$(ii_zsh_tmux_free_alias_index)"
}

ii_zsh_tmux_alias_state() {
  local marker="$1" marker_index alias_index expected
  ii_zsh_tmux_scan_aliases
  marker_index="$(ii_zsh_tmux_marker_field "$marker" index 2>/dev/null)"
  alias_index="${II_TMUX_ALIAS_INDEX[ii]:-}"
  expected="version=${II_TMUX_INTEGRATION_SCHEMA} index=${marker_index} helper=${II_GO_BIN}"
  if [[ -n "$marker_index" && "$marker" == "$expected" && "${II_TMUX_ALIAS_VALUES[$marker_index]:-}" == "$(ii_zsh_tmux_alias_command)" ]]; then print installed
  elif [[ -n "$alias_index" ]]; then
    if [[ "$alias_index" == "$marker_index" ]] && ii_zsh_tmux_owned_alias "${II_TMUX_ALIAS_VALUES[$alias_index]}"; then print stale
    else print conflict
    fi
  elif [[ -n "$marker_index" ]]; then print stale
  else print missing
  fi
}

ii_zsh_cmd_tmux() {
  shift
  [[ $# -le 1 && "${1:-status}" == status ]] || { print -u2 -- 'ii: usage: ii tmux status'; return 2; }
  ii_zsh_tmux_available || return
  local configured=default marker server binding
  [[ "${II_TMUX_INTEGRATION:-1}" == 0 ]] && configured=disabled
  [[ "${II_TMUX_INTEGRATION_FORCE:-0}" == 1 ]] && configured=force
  marker="$(tmux show-option -gqv "$II_TMUX_INTEGRATION_MARKER" 2>/dev/null)"
  server="$(tmux display-message -p '#{socket_path}' 2>/dev/null)"
  [[ -n "$server" ]] || server="${TMUX%%,*}"
  binding="$(tmux list-keys -T prefix : 2>/dev/null)"
  print -rl -- "server: $server" "configured: $configured" "command alias: $(ii_zsh_tmux_alias_state "$marker")" \
    'command: ii' "helper: $II_GO_BIN"
  if [[ "$binding" == *'if-shell -F "##{==:%1,ii pice}"'* && "$binding" == *ii-tmux-pice* ]]; then
    print -r -- 'Prefix+: legacy ii adapter'
  else
    print -r -- 'Prefix+: native or user-defined'
  fi
}
