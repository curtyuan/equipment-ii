# JJ_ variable commands.

ii_cmd_set() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii set NAME VALUE
       ii s NAME VALUE
       ii s NAME -d [INTERFACE]
       ii s:lhost -d [INTERFACE]
       ii set
       ii s
       ii s FILTER
       ii s:FILTER

Set NAME in the current tmux session and export it into this shell.
The current shell export uses NAME without the internal JJ_ prefix.

With no arguments, open a TUI to choose a variable and type its value.
With one FILTER argument, match variable names before prompting for a value.
No matches prints "no matched"; multiple matches prompt for variable selection.
Single-letter shortcuts include r for RHOST, l for LHOST, and d for DOMAIN.

-d means detect. It is only supported for LHOST and detects the IPv4 address
from INTERFACE. The default INTERFACE is tun0.
EOF
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    ii_cmd_set_interactive
    return
  fi

  if [[ "$1" == "-d" ]]; then
    set -- LHOST "$@"
  fi

  if [[ $# -eq 1 ]]; then
    ii_cmd_set_interactive "$1"
    return
  fi

  if [[ $# -lt 2 ]]; then
    cat <<'EOF'
usage: ii set NAME VALUE
       ii s NAME VALUE
       ii s NAME -d [INTERFACE]
       ii s:lhost -d [INTERFACE]
       ii set
       ii s
       ii s FILTER
       ii s:FILTER
EOF
    return 2
  fi

  ii_tmux_available || return

  local name value interface
  name="$(ii_var_normalize_name "$(ii_var_shortcut_filter "$1")")" || return
  shift
  if [[ "${1:-}" == "-d" ]]; then
    if [[ "$name" != "JJ_LHOST" ]]; then
      print -u2 "ii: -d is only supported for LHOST"
      return 2
    fi
    shift
    interface="${1:-tun0}"
    value="$(ii_var_detect_interface_ipv4 "$interface")" || return
  else
    value="$*"
  fi

  tmux set-environment "$name" "$value" || return
  ii_export_var_line "${name}=${value}" || return
  print "$(ii_var_display_line "${name}=${value}")"
}

ii_cmd_load() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii load
       ii l

Load non-empty variables from the current tmux session into this shell.
The current shell exports use names without the internal JJ_ prefix.
EOF
    return 0
  fi

  ii_tmux_available || return

  local line count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ -n "${line#*=}" ]] || continue
    ii_export_var_line "$line" || return
    (( count++ ))
  done < <(ii_var_lines_from_tmux)

  print "loaded ${count} variable(s)"
}

ii_cmd_variable() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii variable [PATTERN]
       ii v [PATTERN]

Print variables from the current tmux session. PATTERN filters variable
names only, case-insensitively.

Special views:
  ii v host    Print configured DOMAIN/LHOST/RHOST/LPORT/RPORT as name/value pairs
  ii v cred    Print configured USER*/PASSWD*/HASH* as name/value pairs
EOF
    return 0
  fi

  ii_tmux_available || return

  case "${1:-}" in
    host) ii_var_print_named_view DOMAIN LHOST RHOST LPORT RPORT ;;
    cred) ii_var_print_cred_view ;;
    "") ii_var_lines_from_tmux | ii_var_display_lines_for_fzf ;;
    *) ii_var_lines_from_tmux | ii_var_filter_by_name "$1" | ii_var_display_lines_for_fzf ;;
  esac
}

ii_cmd_unset() {
  if [[ "${1:-}" == "--help" || $# -lt 1 ]]; then
    cat <<'EOF'
usage: ii unset NAME [NAME...]
       ii unset -a

Remove JJ_NAME from the current tmux session and unset it in this shell.
With -a, remove all JJ_ variables after confirmation.
EOF
    [[ "${1:-}" == "--help" ]] && return 0
    return 2
  fi

  ii_tmux_available || return

  if [[ "$1" == "-a" ]]; then
    ii_cmd_unset_all
    return
  fi

  local raw name shell_name
  for raw in "$@"; do
    name="$(ii_var_normalize_name "$raw")" || return
    shell_name="$(ii_var_shell_name "$name")"
    tmux set-environment -u "$name" 2>/dev/null
    unset "$name"
    unset "$shell_name"
    unset "${(L)shell_name}"
    print "unset $shell_name"
  done
}

ii_cmd_unset_all() {
  local answer line name shell_name count=0

  printf 'unset all JJ_ variables in this tmux session? [y/N] '
  read -r answer
  [[ "$answer" == "y" ]] || { print "aborted"; return 1; }

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="${line%%=*}"
    shell_name="$(ii_var_shell_name "$name")"
    tmux set-environment -u "$name" 2>/dev/null
    unset "$name"
    unset "$shell_name"
    unset "${(L)shell_name}"
    print "unset $shell_name"
    (( count++ ))
  done < <(ii_var_lines_from_tmux)

  print "unset ${count} variable(s)"
}
