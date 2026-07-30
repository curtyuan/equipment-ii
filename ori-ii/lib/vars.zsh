# ii_ variable commands.

ii_cmd_set_usage() {
  cat <<'EOF'
usage: ii set NAME=VALUE [NAME=VALUE...]
       ii s NAME=VALUE [NAME=VALUE...]
       ii set NAME VALUE
       ii s NAME VALUE
       ii sr VALUE
       ii s:NAME=VALUE[,NAME=VALUE...]
       ii set NAME[,NAME...] [--from-shell]
       ii s:NAME[,NAME...] [--from-shell]
       ii set --from-shell -a
       ii s --from-shell -a
       ii sha
       ii set --from-file [PATH]
       ii s --from-file [PATH]
       ii sf [PATH]
       ii s NAME -d [INTERFACE]
       ii s -d [INTERFACE]
       ii s:lhost -d [INTERFACE]
EOF
}

ii_cmd_set_help() {
  ii_cmd_set_usage
  cat <<'EOF'

Aliases:
  s
  sr
  sf
  sha

Help:
  ii help set

Forms:
  NAME=VALUE
    Set NAME=VALUE in the current tmux session and export it into this shell.
    Multiple assignments can be separate arguments or comma-separated shortcut
    entries, such as ii s:usert=alice,passt=secret.

  NAME VALUE
    Set one variable from explicit command-line arguments. Use NAME=VALUE for
    batches or when the value could otherwise be confused with an option.

  NAME[,NAME...] --from-shell
    Save existing shell variables back into the tmux session. Lowercase shell
    names are checked first, then uppercase names. Missing shell variables print
    red warnings and are skipped.

  --from-shell -a
    Check every default ii variable name against non-empty lowercase, then
    uppercase shell variables. Save and print each value found; silently skip
    unset or empty defaults.

  --from-file [PATH]
    Read NAME=VALUE entries from PATH, defaulting to .env in the current
    directory. Blank lines, comments, an optional export prefix, and the
    quoting written by ii v --out are supported. Each imported value is saved
    to tmux, exported into this shell, and printed.

  -d [INTERFACE]
    Detect lhost from INTERFACE. The default INTERFACE is tun0. Detect is only
    supported for lhost.

  automatic lhost detect
    When rhost or rhosts is set, ii automatically detects lhost from the
    configured interface and prints the detected value. This is controlled by
    II_AUTO_DETECT_LHOST and II_AUTO_DETECT_LHOST_INTERFACE.

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
    ii_cmd_set_usage
    return 2
  fi

  local from_shell=0 from_shell_all=0 from_file=0 arg args
  args=()
  for arg in "$@"; do
    case "$arg" in
      --from-shell) from_shell=1 ;;
      --from-file) from_file=1 ;;
      -a) from_shell_all=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  set -- "$args[@]"

  if (( from_shell && from_file )); then
    print -u2 "ii: --from-shell and --from-file cannot be used together"
    return 2
  fi

  if (( from_file )); then
    if (( from_shell_all )); then
      print -u2 "ii: -a is only supported with --from-shell"
      return 2
    fi
    if [[ $# -gt 1 ]]; then
      print -u2 "ii: --from-file accepts at most one path"
      return 2
    fi
    ii_cmd_set_from_file "${1:-.env}"
    return
  fi

  if (( from_shell_all && ! from_shell )); then
    print -u2 "ii: -a is only supported with --from-shell"
    return 2
  fi

  if (( from_shell_all )); then
    if [[ $# -ne 0 ]]; then
      print -u2 "ii: --from-shell -a does not accept variable names"
      return 2
    fi
    ii_tmux_available || return
    ii_cmd_set_from_shell_all
    return
  fi

  if [[ $# -eq 0 ]]; then
    if (( from_shell )); then
      print -u2 "ii: --from-shell requires at least one variable name"
      return 2
    fi
    ii_cmd_set_usage
    return 2
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
    print -u2 "ii: set requires a value; use NAME=VALUE or NAME VALUE"
    return 2
  fi

  if [[ $# -lt 2 ]]; then
    ii_cmd_set_usage
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
  ii_var_auto_detect_lhost_for_rhost "$name"
  print "$(ii_var_display_line "${name}=${value}")"
}

ii_cmd_set_from_shell_all() {
  local name ii_name upper_name value count=0 saw_rhost=0 saw_lhost=0

  for name in ${(f)"$(ii_var_default_names)"}; do
    upper_name="${(U)name}"
    if (( ${+parameters[$name]} )) && [[ -n "${(P)name}" ]]; then
      value="${(P)name}"
    elif (( ${+parameters[$upper_name]} )) && [[ -n "${(P)upper_name}" ]]; then
      value="${(P)upper_name}"
    else
      continue
    fi
    ii_name="$(ii_var_normalize_name "$name")" || return
    tmux set-environment "$ii_name" "$value" || return
    ii_export_var_line "${ii_name}=${value}" || return
    print "$(ii_var_display_line "${ii_name}=${value}")"
    ii_var_is_rhost_name "$ii_name" && saw_rhost=1
    [[ "$ii_name" == "ii_lhost" ]] && saw_lhost=1
    (( count++ ))
  done

  if (( saw_rhost && ! saw_lhost )); then
    ii_var_auto_detect_lhost_for_rhost "ii_rhost"
  fi
  (( count > 0 )) || print "ii: no non-empty default shell variables found"
}

ii_cmd_set_from_file() {
  local file="$1" line entry name value ii_name
  local line_number=0 count=0 invalid=0 saw_rhost=0 saw_lhost=0

  if [[ ! -f "$file" ]]; then
    print -r -- "ii: variable file not found: $file"
    return 1
  fi
  if [[ ! -r "$file" ]]; then
    print -r -- "ii: variable file is not readable: $file"
    return 1
  fi
  ii_tmux_available || return

  while IFS= read -r line || [[ -n "$line" ]]; do
    (( ++line_number ))
    line="${line%$'\r'}"
    entry="${line#${line%%[![:space:]]*}}"
    [[ -n "$entry" && "$entry" != \#* ]] || continue
    if [[ "$entry" == export[[:space:]]* ]]; then
      entry="${entry#export}"
      entry="${entry#${entry%%[![:space:]]*}}"
    fi

    if [[ "$entry" != *=* ]]; then
      print -r -- "ii: invalid variable entry in $file at line $line_number: expected NAME=VALUE"
      invalid=1
      continue
    fi

    name="${entry%%=*}"
    value="${entry#*=}"
    if [[ -z "$name" || "$name" == *[[:space:]]* ]]; then
      print -r -- "ii: invalid variable name in $file at line $line_number: $name"
      invalid=1
      continue
    fi

    case "$value" in
      \'*)
        if [[ "$value" != *\' ]]; then
          print -r -- "ii: invalid quoted value in $file at line $line_number"
          invalid=1
          continue
        fi
        value="${(Q)value}"
        ;;
      \"*)
        if [[ "$value" != *\" ]]; then
          print -r -- "ii: invalid quoted value in $file at line $line_number"
          invalid=1
          continue
        fi
        value="${(Q)value}"
        ;;
    esac
    name="$(ii_cmd_set_alias_name "$name")"
    if ! ii_name="$(ii_var_normalize_name "$(ii_var_shortcut_filter "$name")" 2>/dev/null)"; then
      print -r -- "ii: invalid variable name in $file at line $line_number: $name"
      invalid=1
      continue
    fi

    tmux set-environment "$ii_name" "$value" || return
    ii_export_var_line "${ii_name}=${value}" || return
    print "$(ii_var_display_line "${ii_name}=${value}")"
    ii_var_is_rhost_name "$ii_name" && saw_rhost=1
    [[ "$ii_name" == "ii_lhost" ]] && saw_lhost=1
    (( ++count ))
  done < "$file"

  if (( saw_rhost && ! saw_lhost )); then
    ii_var_auto_detect_lhost_for_rhost "ii_rhost"
  fi
  (( count > 0 )) || print -r -- "ii: no variable entries found in $file"
  return "$invalid"
}

ii_cmd_set_rhost() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    ii_cmd_set --help
    return
  fi
  if [[ $# -ne 1 ]]; then
    print -u2 "ii: usage: ii sr VALUE"
    return 2
  fi

  ii_cmd_set "rhost=$1"
}

ii_cmd_set_from_file_alias() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    ii_cmd_set --help
    return
  fi
  if [[ $# -gt 1 ]]; then
    print -u2 "ii: usage: ii sf [PATH]"
    return 2
  fi
  ii_cmd_set --from-file "$@"
}

ii_cmd_set_from_shell_all_alias() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    ii_cmd_set --help
    return
  fi
  if [[ $# -ne 0 ]]; then
    print -u2 "ii: usage: ii sha"
    return 2
  fi
  ii_cmd_set --from-shell -a
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
  local help_arg
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      cat <<'EOF'
usage: ii get FILTER
       ii g FILTER
       ii g:FILTER
       ii gr
       ii gl

Aliases:
  g
  gr (ii g r)
  gl (ii g l)

Help:
  ii help get
  ii help g

Get a variable value from the current tmux session, copy it, and print it.
FILTER matches variable names case-insensitively, with the same shortcut
handling as ii set. No matches prints "no matched". One match copies the value.
Multiple matches open a prompt; Enter or Space selects one value. q, Esc, or
Ctrl-C aborts without changing variables or copying anything.
EOF
      return 0
    fi
  done

  ii_tmux_available || return
  ii_require_cmd fzf || return

  if [[ $# -lt 1 || -z "${1:-}" ]]; then
    cat <<'EOF'
usage: ii get FILTER
       ii g FILTER
       ii g:FILTER
       ii gr
       ii gl
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
  local help_arg
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      set -- --help
      break
    fi
  done

  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii load
       ii l
       ii load --all-pane
       ii la

Aliases:
  l
  la    ii load --all-pane

Help:
  ii help load
  ii help load --all-pane

Load non-empty variables from the current tmux session into this shell.
The current shell exports use names without the internal ii_ prefix.
II_EXPORT_CASE controls exported shell names: lower, upper, or both.
The default is lower.

With --all-pane or la, show every pane in the current tmux window in a
multi-select prompt. Panes that appear to be idle zsh shells are preselected
as "likely ready". Review the selection with Space, then press Enter to load
the current shell directly and dispatch `ii l` to the other selected panes.
Other panes must already have ii loaded. "dispatched" means the command was
sent successfully; it does not confirm that the destination shell ran it.
EOF
    return 0
  fi

  if [[ "${1:-}" == "--all-pane" ]]; then
    if [[ $# -gt 1 ]]; then
      print -u2 "ii: --all-pane does not accept arguments"
      return 2
    fi
    ii_cmd_load_all_panes
    return
  fi

  if [[ $# -gt 0 ]]; then
    print -u2 "ii: unknown load option: $1"
    ii_cmd_load --help
    return 2
  fi

  ii_load_current_shell
}

ii_load_current_shell() {
  local quiet="${1:-0}"
  ii_tmux_available || return
  local line count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ -n "${line#*=}" ]] || continue
    ii_export_var_line "$line" || return
    (( count++ ))
  done < <(ii_var_lines_from_tmux)

  (( quiet )) || print "loaded ${count} variable(s)"
}

ii_load_pane_snapshot() {
  ii_tmux_pane_snapshot "$1"
}

ii_load_pane_entries() {
  local window_id="$1" format line pane dead in_mode command pane_path title pane_status current display
  local -a ready_entries other_entries

  format='#{pane_id}'$'\t''#{pane_dead}'$'\t''#{pane_in_mode}'$'\t''#{pane_current_command}'$'\t''#{pane_current_path}'$'\t''#{pane_title}'
  while IFS= read -r line; do
    IFS=$'\t' read -r pane dead in_mode command pane_path title <<< "$line"
    [[ -n "$pane" ]] || continue

    current=""
    [[ "$pane" == "${TMUX_PANE:-}" ]] && current="current"
    if [[ "$dead" == "1" ]]; then
      pane_status="dead pane"
    elif [[ "$in_mode" == "1" ]]; then
      pane_status="tmux mode"
    elif [[ "$command" == "zsh" ]]; then
      pane_status="likely ready"
    elif [[ "$command" == "ssh" ]]; then
      pane_status="remote session"
    else
      pane_status="active program"
    fi

    display="$(printf '%-5s %-8s %-14s %-18s %s' "$pane" "$current" "$command" "$pane_status" "$pane_path")"
    [[ -n "$title" && "$title" != "$command" ]] && display+="  ${title}"
    line="$pane"$'\t'"$dead"$'\t'"$in_mode"$'\t'"$command"$'\t'"$display"
    if [[ "$pane_status" == "likely ready" ]]; then
      ready_entries+=("$line")
    else
      other_entries+=("$line")
    fi
  done < <(tmux list-panes -t "$window_id" -F "$format")

  print -rl -- "$ready_entries[@]" "$other_entries[@]"
}

ii_load_pane_select() {
  local likely_count="$1" bind="" index

  if (( likely_count > 0 )); then
    bind='start:pos(1)+select'
    for (( index = 2; index <= likely_count; index++ )); do
      bind+="+pos(${index})+select"
    done
  fi

  local -a args
  args=(
    -i --ansi --multi --sync --no-sort --height=80% --border
    --prompt='ii load panes> '
    --header='SPACE toggle · ENTER load · ESC cancel · preselected panes are likely ready'
    --bind='space:toggle,enter:accept,esc:abort,q:abort'
    --marker='☑' --pointer='  '
    --delimiter=$'\t' --with-nth=5
  )
  [[ -n "$bind" ]] && args+=(--bind="$bind")
  FZF_DEFAULT_OPTS='' fzf "$args[@]"
}

ii_cmd_load_all_panes() {
  ii_tmux_available || return
  ii_require_cmd fzf || return

  local session_id window_id entries selected line pane dead in_mode command display snapshot
  local selected_dead selected_mode selected_command
  local current_session current_window current_dead current_mode current_command
  local likely_count=0 loaded=0 dispatched=0 skipped=0 failed=0
  local -A chosen
  local -a all_panes

  session_id="$(tmux display-message -p '#{session_id}')" || return
  window_id="$(tmux display-message -p '#{window_id}')" || return
  entries="$(ii_load_pane_entries "$window_id")" || return
  [[ -n "$entries" ]] || { print -u2 "ii: no panes found in current tmux window"; return 1; }

  while IFS= read -r line; do
    IFS=$'\t' read -r pane dead in_mode command display <<< "$line"
    all_panes+=("$pane")
    [[ "$dead" == "0" && "$in_mode" == "0" && "$command" == "zsh" ]] && (( likely_count++ ))
  done <<< "$entries"

  selected="$(print -r -- "$entries" | ii_load_pane_select "$likely_count")" || {
    print "aborted"
    return 1
  }

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS=$'\t' read -r pane selected_dead selected_mode selected_command display <<< "$line"
    chosen[$pane]="$selected_dead"$'\t'"$selected_mode"$'\t'"$selected_command"
  done <<< "$selected"

  print "Load summary"
  print
  for pane in "$all_panes[@]"; do
    if [[ -z "${chosen[$pane]-}" ]]; then
      printf '%-5s skipped by user\n' "$pane"
      (( skipped++ ))
      continue
    fi

    IFS=$'\t' read -r selected_dead selected_mode selected_command <<< "${chosen[$pane]}"
    snapshot="$(ii_load_pane_snapshot "$pane")"
    if [[ -z "$snapshot" ]]; then
      printf '%-5s failed: pane disappeared\n' "$pane"
      (( failed++ ))
      continue
    fi
    IFS=$'\t' read -r pane current_session current_window current_dead current_mode current_command <<< "$snapshot"
    if [[ "$current_session" != "$session_id" ]]; then
      printf '%-5s failed: pane changed session\n' "$pane"
      (( failed++ ))
      continue
    fi
    if [[ "$current_window" != "$window_id" ]]; then
      printf '%-5s failed: pane changed window\n' "$pane"
      (( failed++ ))
      continue
    fi
    if [[ "$current_dead" != "$selected_dead" || "$current_mode" != "$selected_mode" || "$current_command" != "$selected_command" ]]; then
      printf '%-5s failed: pane state changed (%s)\n' "$pane" "$current_command"
      (( failed++ ))
      continue
    fi
    if [[ "$current_dead" == "1" ]]; then
      printf '%-5s failed: dead pane\n' "$pane"
      (( failed++ ))
      continue
    fi

    if [[ "$pane" == "${TMUX_PANE:-}" ]]; then
      if ii_load_current_shell 1; then
        printf '%-5s loaded locally\n' "$pane"
        (( loaded++ ))
      else
        printf '%-5s failed: local load failed\n' "$pane"
        (( failed++ ))
      fi
    elif tmux send-keys -t "$pane" -l 'ii l' && tmux send-keys -t "$pane" Enter; then
      printf '%-5s dispatched\n' "$pane"
      (( dispatched++ ))
    else
      printf '%-5s failed: dispatch failed\n' "$pane"
      (( failed++ ))
    fi
  done

  print
  print "${loaded} loaded locally, ${dispatched} dispatched, ${skipped} skipped, ${failed} failed"
  (( failed == 0 ))
}

ii_cmd_sync() {
  local help_arg
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      set -- --help
      break
    fi
  done

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

Aliases:
  none

Help:
  ii help sync

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
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
usage: ii ls [PATTERN]

Aliases:
  list, variable, vars, var

Help:
  ii help ls

Print non-empty variables from the current tmux session.
PATTERN filters variable names only, case-insensitively.
Output format is blue key, then value, without blank lines between entries.
ii v [PATTERN] uses this same listing behavior; see ii v --help for its --out
file-output mode.
EOF
    return 0
  fi

  ii_tmux_available || return

  local pattern="${1:-}"
  ii_var_print_list "$pattern"
}

ii_cmd_unset() {
  local help_arg help_requested=0
  for help_arg in "$@"; do
    if [[ "$help_arg" == "--help" || "$help_arg" == "-h" ]]; then
      help_requested=1
      break
    fi
  done
  if (( help_requested )) || [[ $# -lt 1 ]]; then
    cat <<'EOF'
usage: ii unset NAME [NAME...]
       ii unset -a

Aliases:
  u

Help:
  ii help unset
  ii help u

Remove ii_name from the current tmux session and unset it in this shell.
With -a, remove all ii_ variables after confirmation.
EOF
    (( help_requested )) && return 0
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

ii_help_register set ii_cmd_set s sr sf sha
ii_help_register get ii_cmd_get g gr gl
ii_help_register load ii_cmd_load l la "load --all-pane" "l --all-pane"
ii_help_register sync ii_cmd_sync
ii_help_register ls ii_cmd_list list variable vars var
ii_help_register unset ii_cmd_unset u
