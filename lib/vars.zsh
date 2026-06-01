# ii_ variable commands.

ii_cmd_set_usage() {
  cat <<'EOF'
usage: ii set NAME=VALUE [NAME=VALUE...]
       ii s NAME=VALUE [NAME=VALUE...]
       ii s:NAME=VALUE[,NAME=VALUE...]
       ii set NAME[,NAME...] [--from-shell]
       ii s:NAME[,NAME...] [--from-shell]
       ii s NAME -d [INTERFACE]
       ii s -d [INTERFACE]
       ii s:lhost -d [INTERFACE]
       ii set
       ii s
       ii s FILTER
       ii s:FILTER
EOF
}

ii_cmd_set_help() {
  ii_cmd_set_usage
  cat <<'EOF'

Forms:
  NAME=VALUE
    Set NAME=VALUE in the current tmux session and export it into this shell.
    Multiple assignments can be separate arguments or comma-separated shortcut
    entries, such as ii s:usert=alice,passt=secret.

  NAME[,NAME...] --from-shell
    Save existing shell variables back into the tmux session. Lowercase shell
    names are checked first, then uppercase names. Missing shell variables print
    red warnings and are skipped.

  -d [INTERFACE]
    Detect lhost from INTERFACE. The default INTERFACE is tun0. Detect is only
    supported for lhost.

  automatic lhost detect
    When rhost or rhosts is set, ii automatically detects lhost from the
    configured interface and prints the detected value. This is controlled by
    II_AUTO_DETECT_LHOST and II_AUTO_DETECT_LHOST_INTERFACE.

  [FILTER]
    Match variable names before prompting for a value. No matches prints
    "no matched"; multiple matches prompt for variable selection.

  no arguments
    Open a TUI to choose a variable and type its value.

Notes:
  User-facing names do not include the internal ii_ prefix. Single-letter
  shortcuts include r for rhost, l for lhost, and d for domain. II_EXPORT_CASE
  controls whether exported shell variables use lower, upper, or both cases.
EOF
}

ii_cmd_set() {
  local help_arg
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      ii_cmd_set_help
      return 0
    fi
  done
  if [[ $# -eq 0 ]]; then
    ii_cmd_set_interactive
    return
  fi

  local from_shell=0 arg args
  args=()
  for arg in "$@"; do
    case "$arg" in
      --from-shell) from_shell=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  set -- "$args[@]"

  if [[ $# -eq 0 ]]; then
    if (( from_shell )); then
      print -u2 "ii: --from-shell requires at least one variable name"
      return 2
    fi
    ii_cmd_set_interactive
    return
  fi

  if [[ "$1" == "-d" ]]; then
    set -- lhost "$@"
  fi

  if (( from_shell )); then
    ii_tmux_available || return
    ii_cmd_set_from_shell "$@" || return
    return
  fi

  if [[ "$*" == *"="* ]]; then
    ii_tmux_available || return
    ii_cmd_set_assignments "$@" || return
    return
  fi

  if [[ $# -eq 1 ]]; then
    ii_cmd_set_interactive "$1"
    return
  fi

  if [[ $# -lt 2 ]]; then
    ii_cmd_set_usage
    return 2
  fi

  ii_tmux_available || return

  if [[ $# -gt 1 && "${2:-}" != "-d" ]]; then
    print -u2 "ii: direct values must use name=value"
    return 2
  fi

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
  ii_var_auto_detect_lhost_for_rhost "$name"
  print "$(ii_var_display_line "${name}=${value}")"
}

ii_cmd_set_from_shell() {
  local names raw name normalized ii_name shell_name upper_name value missing=0 saw_rhost=0 saw_lhost=0
  names=()
  for raw in "$@"; do
    for name in "${(@s:,:)raw}"; do
      normalized="$(ii_cmd_set_alias_name "$name")"
      [[ -n "$normalized" ]] || continue
      names+=("$normalized")
    done
  done

  [[ $#names -gt 0 ]] || return 2
  for name in "$names[@]"; do
    ii_name="$(ii_var_normalize_name "$(ii_var_shortcut_filter "$name")")" || return
    shell_name="$(ii_var_shell_name "$ii_name")"
    upper_name="${(U)shell_name}"
    if (( ${+parameters[$shell_name]} )); then
      value="${(P)shell_name}"
    elif (( ${+parameters[$upper_name]} )); then
      value="${(P)upper_name}"
    else
      ii_color_red "ii: shell variable not found: $shell_name" >&2
      missing=1
      continue
    fi
    tmux set-environment "$ii_name" "$value" || return
    ii_export_var_line "${ii_name}=${value}" || return
    print "$(ii_var_display_line "${ii_name}=${value}")"
    ii_var_is_rhost_name "$ii_name" && saw_rhost=1
    [[ "$ii_name" == "ii_lhost" ]] && saw_lhost=1
  done

  if (( saw_rhost && ! saw_lhost )); then
    ii_var_auto_detect_lhost_for_rhost "ii_rhost"
  fi
  return "$missing"
}

ii_cmd_set_assignments() {
  local raw item name value ii_name count=0 saw_rhost=0 saw_lhost=0

  for raw in "$@"; do
    for item in "${(@s:,:)raw}"; do
      [[ -n "$item" ]] || continue
      if [[ "$item" != *=* ]]; then
        print -u2 "ii: direct values must use name=value: $item"
        return 2
      fi
      name="${item%%=*}"
      value="${item#*=}"
      name="$(ii_cmd_set_alias_name "$name")"
      ii_name="$(ii_var_normalize_name "$(ii_var_shortcut_filter "$name")")" || return
      tmux set-environment "$ii_name" "$value" || return
      ii_export_var_line "${ii_name}=${value}" || return
      print "$(ii_var_display_line "${ii_name}=${value}")"
      ii_var_is_rhost_name "$ii_name" && saw_rhost=1
      [[ "$ii_name" == "ii_lhost" ]] && saw_lhost=1
      (( count++ ))
    done
  done

  if (( count == 0 )); then
    print -u2 "ii: no assignments provided"
    return 2
  fi

  if (( saw_rhost && ! saw_lhost )); then
    ii_var_auto_detect_lhost_for_rhost "ii_rhost"
  fi
}

ii_cmd_set_alias_name() {
  local lower="${(L)1}"
  if [[ "$lower" =~ '^passwd[12]$' ]]; then
    print -r -- "pass${lower#passwd}"
    return
  fi
  if [[ "$lower" =~ '^password[12]$' ]]; then
    print -r -- "pass${lower#password}"
    return
  fi

  case "$lower" in
    user) print usert ;;
    username) print usert ;;
    passwd|password) print passt ;;
    *) print -r -- "$1" ;;
  esac
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

  print "loaded ${count} variable(s)"
}

ii_cmd_sync() {
  case "${1:-status}" in
    on)
      ii_enable_auto_sync
      print "ii auto-sync enabled"
      ;;
    off)
      ii_disable_auto_sync
      print "ii auto-sync disabled"
      ;;
    status)
      ii_auto_sync_status
      ;;
    --help|-h)
      cat <<'EOF'
usage: ii sync [on|off|status]

Control optional tmux-to-shell prompt synchronization.

Commands:
  on      Refresh exported shell variables from tmux before each prompt.
  off     Stop prompt-time refresh for this shell.
  status  Show II_SYNC_LOADED_VARS and hook state.
EOF
      ;;
    *)
      print -u2 "ii: unknown sync command: $1"
      ii_cmd_sync --help
      return 2
      ;;
  esac
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
