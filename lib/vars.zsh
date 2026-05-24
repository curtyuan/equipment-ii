# ii_ variable commands.

ii_cmd_set() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii set NAME VALUE
       ii s NAME VALUE
       ii s NAME -d [INTERFACE]
       ii s -d [INTERFACE]
       ii s:lhost -d [INTERFACE]
       ii set
       ii s
       ii s FILTER
       ii s:FILTER

Set NAME in the current tmux session and export it into this shell.
The current shell export uses NAME without the internal ii_ prefix.

With no arguments, open a TUI to choose a variable and type its value.
With one FILTER argument, match variable names before prompting for a value.
No matches prints "no matched"; multiple matches prompt for variable selection.
Single-letter shortcuts include r for rhost, l for lhost, and d for domain.

-d means detect. It is only supported for lhost and detects the IPv4 address
from INTERFACE. The default INTERFACE is tun0. II_EXPORT_CASE controls whether
exported shell variables use lower, upper, or both cases.
EOF
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    ii_cmd_set_interactive
    return
  fi

  if [[ "$1" == "-d" ]]; then
    set -- lhost "$@"
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
       ii s -d [INTERFACE]
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
    if [[ "$name" != "ii_lhost" ]]; then
      print -u2 "ii: -d is only supported for lhost"
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
  ii_enable_loaded_var_sync
  print "$(ii_var_display_line "${name}=${value}")"
}

ii_cmd_get() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii get FILTER
       ii g FILTER
       ii g:FILTER

Get a variable value from the current tmux session, copy it, and print it.
FILTER matches variable names case-insensitively, with the same shortcut
handling as ii set. No matches prints "no matched". One match copies the value.
Multiple matches open a prompt; Enter or Space selects one value. q, Esc, or
Ctrl-C aborts without changing variables or copying anything.
EOF
    return 0
  fi

  ii_tmux_available || return
  ii_require_cmd fzf || return

  if [[ $# -lt 1 || -z "${1:-}" ]]; then
    cat <<'EOF'
usage: ii get FILTER
       ii g FILTER
       ii g:FILTER
EOF
    return 2
  fi

  local filter matches count selected line value
  filter="$(ii_var_shortcut_filter "$1")"
  matches="$(ii_var_get_matches "$filter")"
  count="$(print -r -- "$matches" | awk 'NF {count++} END {print count + 0}')"

  case "$count" in
    0)
      print -u2 "no matched"
      return 1
      ;;
    1)
      line="$(print -r -- "$matches" | awk 'NF {print; exit}')"
      ;;
    *)
      selected="$(print -r -- "$matches" | ii_var_get_entries_for_fzf | ii_var_get_select_fzf)" || return
      [[ -n "$selected" ]] || return
      line="${selected##*$'\t'}"
      ;;
  esac

  [[ -n "$line" ]] || return
  value="${line#*=}"

  if ii_clip_copy "$value"; then
    print "value copied successfully"
  else
    print "value selected; clipboard copy failed"
  fi

  print
  print -r -- "$value"
}

ii_cmd_load() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii load
       ii l

Load non-empty variables from the current tmux session into this shell.
The current shell exports use names without the internal ii_ prefix.
II_EXPORT_CASE controls exported shell names: lower, upper, or both.
The default is lower.
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

  ii_enable_loaded_var_sync
  print "loaded ${count} variable(s)"
}

ii_cmd_list() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii ls [PATTERN]

Print non-empty variables from the current tmux session.
PATTERN filters variable names only, case-insensitively.
Output format is blue key, then value, without blank lines between entries.
EOF
    return 0
  fi

  ii_tmux_available || return

  local pattern="${1:-}"
  ii_var_print_list "$pattern"
}

ii_cmd_unset() {
  if [[ "${1:-}" == "--help" || $# -lt 1 ]]; then
    cat <<'EOF'
usage: ii unset NAME [NAME...]
       ii unset -a

Remove ii_name from the current tmux session and unset it in this shell.
With -a, remove all ii_ variables after confirmation.
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
    unset "${(U)shell_name}"
    print "unset $shell_name"
  done
}

ii_cmd_unset_all() {
  local answer line name shell_name count=0

  printf 'unset all ii_ variables in this tmux session? [y/N] '
  read -r answer
  [[ "$answer" == "y" ]] || { print "aborted"; return 1; }

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="${line%%=*}"
    shell_name="$(ii_var_shell_name "$name")"
    tmux set-environment -u "$name" 2>/dev/null
    unset "$name"
    unset "$shell_name"
    unset "${(U)shell_name}"
    print "unset $shell_name"
    (( count++ ))
  done < <(ii_var_lines_from_tmux)

  print "unset ${count} variable(s)"
}
