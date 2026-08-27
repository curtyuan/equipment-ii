# Zsh-owned ordinary variable mutations.

ii_zsh_tmux_available() {
  [[ -n "${TMUX:-}" ]] || {
    print -u2 "ii: this command must run inside tmux"
    return 1
  }
  (( $+commands[tmux] )) || {
    print -u2 "ii: tmux command not found"
    return 1
  }
}

ii_zsh_normalize_name() {
  local name="${(L)${${1#export }#ii_}}"
  case "$name" in
    r) name=rhost ;;
    l) name=lhost ;;
    d) name=domain ;;
    user|username) name=usert ;;
    passwd|password) name=passt ;;
  esac
  [[ "$name" =~ '^[a-z_][a-z0-9_]*$' ]] || {
    print -u2 "ii: invalid variable name: $1"
    return 1
  }
  print -r -- "ii_${name}"
}

ii_zsh_export_value() {
  local name="${1#ii_}" value="$2"
  case "${(L)${II_EXPORT_CASE:-lower}}" in
    lower) export "$name=$value" ;;
    upper) export "${(U)name}=$value" ;;
    both)
      export "$name=$value"
      export "${(U)name}=$value"
      ;;
    *)
      print -u2 "ii: invalid II_EXPORT_CASE: ${II_EXPORT_CASE}"
      return 1
      ;;
  esac
}

ii_zsh_detect_interface_ipv4() {
  local interface="${1:-tun0}" value
  (( $+commands[ip] )) || {
    print -u2 "ii: ip command not found"
    return 1
  }
  value="$(ip -4 -o addr show dev "$interface" 2>/dev/null | awk '{print $4; exit}')"
  value="${value%%/*}"
  [[ -n "$value" ]] || {
    print -u2 "ii: no IPv4 address found for interface: $interface"
    return 1
  }
  print -r -- "$value"
}

ii_zsh_store_value() {
  local internal="$1" value="$2"
  if [[ -z "$value" ]]; then
    ii_zsh_unset_one "$internal"
    return
  fi
  tmux set-environment "$internal" "$value" || return
  ii_zsh_export_value "$internal" "$value" || return
  print -r -- "${internal#ii_}=${value}"
}

ii_zsh_maybe_detect_lhost() {
  local internal="$1"
  [[ "$internal" == (ii_rhost|ii_rhosts) ]] || return 0
  [[ "${II_AUTO_DETECT_LHOST:-1}" != 0 ]] || return 0
  local value
  value="$(ii_zsh_detect_interface_ipv4 "${II_AUTO_DETECT_LHOST_INTERFACE:-tun0}")" || return 0
  tmux set-environment ii_lhost "$value" || return
  ii_zsh_export_value ii_lhost "$value" || return
  print -r -- "lhost has automatically sets as $value"
}

ii_zsh_set_assignment() {
  local assignment="$1" raw_name value internal
  [[ "$assignment" == *=* ]] || {
    print -u2 "ii: direct values must use name=value: $assignment"
    return 2
  }
  raw_name="${assignment%%=*}"
  value="${assignment#*=}"
  internal="$(ii_zsh_normalize_name "$raw_name")" || return
  ii_zsh_store_value "$internal" "$value" || return
  if [[ -n "$value" ]]; then
    ii_zsh_maybe_detect_lhost "$internal"
  fi
}

ii_zsh_default_names() {
  print -l -- domain lhost rhost lport rport \
    user1 pass1 user2 pass2 user3 pass3 user4 pass4 user5 pass5 \
    cuser cpass tuser tpass directs
}

ii_zsh_set_from_shell() {
  local all="$1"
  shift
  local raw name upper value internal count=0 missing=0
  local -a names
  if (( all )); then
    names=("${(@f)$(ii_zsh_default_names)}")
  else
    for raw in "$@"; do
      names+=("${(@s:,:)raw}")
    done
  fi
  (( ${#names} )) || {
    print -u2 "ii: --from-shell requires at least one variable name"
    return 2
  }
  for raw in "$names[@]"; do
    internal="$(ii_zsh_normalize_name "$raw")" || return
    name="${internal#ii_}"
    upper="${(U)name}"
    if (( ${+parameters[$name]} )); then
      value="${(P)name}"
    elif (( ${+parameters[$upper]} )); then
      value="${(P)upper}"
    else
      if (( ! all )); then
        print -u2 "ii: shell variable not found: $name"
        missing=1
      fi
      continue
    fi
    if (( all )) && [[ -z "$value" ]]; then
      continue
    fi
    ii_zsh_store_value "$internal" "$value" || return
    (( ++count ))
  done
  (( ! all || count > 0 )) || print -r -- "ii: no non-empty default shell variables found"
  (( ! missing ))
}

ii_zsh_unquote_file_value() {
  local value="$1"
  if [[ ${#value} -ge 2 && "$value[1]" == "'" && "$value[-1]" == "'" ]]; then
    value="${(Q)value}"
  elif [[ ${#value} -ge 2 && "$value[1]" == '"' && "$value[-1]" == '"' ]]; then
    value="${(Q)value}"
  fi
  print -r -- "$value"
}

ii_zsh_set_from_file() {
  local file="$1" line entry name value internal
  local line_number=0 count=0 invalid=0
  [[ -f "$file" && -r "$file" ]] || {
    print -r -- "ii: variable file not found: $file"
    return 1
  }
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
      print -r -- "ii: invalid variable entry in $file at line $line_number: expected NAME=VALUE"
      invalid=1
      continue
    fi
    internal="$(ii_zsh_normalize_name "$name")" || {
      invalid=1
      continue
    }
    value="$(ii_zsh_unquote_file_value "$value")"
    ii_zsh_store_value "$internal" "$value" || return
    (( ++count ))
  done <"$file"
  (( count > 0 )) || print -r -- "ii: no variable entries found in $file"
  (( ! invalid ))
}

ii_zsh_cmd_set_explicit() {
  local command="$1"
  shift
  ii_zsh_tmux_available || return

  if [[ "$command" == sf ]]; then
    [[ $# -le 1 ]] || {
      print -u2 "ii: usage: ii sf [PATH]"
      return 2
    }
    ii_zsh_set_from_file "${1:-.env}"
    return
  fi

  if [[ "$command" == sha ]]; then
    [[ $# -eq 0 ]] || {
      print -u2 "ii: usage: ii sha"
      return 2
    }
    ii_zsh_set_from_shell 1
    return
  fi

  if [[ "$command" == ss ]]; then
    set -- "$@" --from-shell
  fi

  if [[ "$command" == sr ]]; then
    [[ $# -eq 1 ]] || {
      print -u2 "ii: usage: ii sr VALUE"
      return 2
    }
    ii_zsh_set_assignment "rhost=$1"
    return
  fi

  if [[ "$command" == s:* ]]; then
    set -- "${command#s:}" "$@"
  fi

  local from_shell=0 from_file=0 all=0 arg
  local -a remaining
  for arg in "$@"; do
    case "$arg" in
      --from-shell) from_shell=1 ;;
      --from-file) from_file=1 ;;
      -a|--all) all=1 ;;
      *) remaining+=("$arg") ;;
    esac
  done
  if (( from_shell && from_file )); then
    print -u2 "ii: --from-shell and --from-file cannot be used together"
    return 2
  fi
  if (( all && ! from_shell )); then
    print -u2 "ii: --all is only supported with --from-shell"
    return 2
  fi
  if (( from_file )); then
    [[ ${#remaining} -le 1 ]] || {
      print -u2 "ii: --from-file accepts at most one path"
      return 2
    }
    ii_zsh_set_from_file "${remaining[1]:-.env}"
    return
  fi
  if (( from_shell )); then
    if (( all && ${#remaining} )); then
      print -u2 "ii: --from-shell --all does not accept variable names"
      return 2
    fi
    ii_zsh_set_from_shell "$all" "$remaining[@]"
    return
  fi

  if [[ "${1:-}" == -d ]]; then
    set -- lhost "$@"
  fi

  if [[ $# -ge 2 && "$1" != *=* && "$2" == -d ]]; then
    local internal interface value
    internal="$(ii_zsh_normalize_name "$1")" || return
    [[ "$internal" == ii_lhost ]] || {
      print -u2 "ii: -d is only supported for lhost"
      return 2
    }
    [[ $# -le 3 ]] || {
      print -u2 "ii: -d accepts at most one interface"
      return 2
    }
    interface="${3:-tun0}"
    value="$(ii_zsh_detect_interface_ipv4 "$interface")" || return
    ii_zsh_store_value "$internal" "$value"
    return
  fi

  if [[ $# -eq 2 && "$1" != *=* ]]; then
    local internal
    internal="$(ii_zsh_normalize_name "$1")" || return
    ii_zsh_store_value "$internal" "$2" || return
    if [[ -n "$2" ]]; then
      ii_zsh_maybe_detect_lhost "$internal"
    fi
    return
  fi

  if [[ $# -eq 1 && "$1" != *=* ]]; then
    print -u2 "ii: set requires a value; use NAME=VALUE or NAME VALUE"
    return 2
  fi

  local raw assignment
  for raw in "$@"; do
    for assignment in ${(s:,:)raw}; do
      ii_zsh_set_assignment "$assignment" || return
    done
  done
}

ii_zsh_tmux_variable_lines() {
  local output
  output="$(tmux show-environment 2>&1)" || {
    print -u2 -r -- "$output"
    return 1
  }
  print -r -- "$output" | LC_ALL=C sort | while IFS= read -r line; do
    [[ "$line" =~ '^ii_[a-z0-9_]+=' ]] && print -r -- "$line"
  done
}

ii_zsh_cmd_load() {
  shift
  ii_zsh_tmux_available || return
  local line name value count=0
  while IFS= read -r line; do
    [[ "$line" == *=* ]] || continue
    name="${line%%=*}"
    value="${line#*=}"
    [[ -n "$value" ]] || continue
    ii_zsh_export_value "$name" "$value" || return
    (( ++count ))
  done < <(ii_zsh_tmux_variable_lines) || return
  print -r -- "loaded $count variable(s)"
}

ii_zsh_cmd_load_all_panes() {
  shift
  [[ $# -eq 0 || ( $# -eq 1 && "$1" == --all-pane ) ]] || {
    print -u2 'ii: usage: ii load --all-pane'
    return 2
  }
  ii_zsh_tmux_available || return
  (( $+commands[fzf] )) || {
    print -u2 'ii: required command not found: fzf'
    return 1
  }

  local identity session window current_pane line id pane_session pane_window dead in_mode command pane_path title pane_status current display
  identity="$(tmux display-message -p '#{session_id}'$'\t''#{window_id}'$'\t''#{pane_id}')" || return
  session="${identity%%$'\t'*}"
  identity="${identity#*$'\t'}"
  window="${identity%%$'\t'*}"
  current_pane="${identity#*$'\t'}"

  local -a ready other input selected
  local -A initial chosen
  while IFS=$'\t' read -r id pane_session pane_window dead in_mode command pane_path title; do
    [[ -n "$id" ]] || continue
    initial[$id]="$pane_session"$'\t'"$pane_window"$'\t'"$dead"$'\t'"$in_mode"$'\t'"$command"
    pane_status='active program'
    if [[ "$dead" == 1 ]]; then pane_status='dead pane'
    elif [[ "$in_mode" == 1 ]]; then pane_status='tmux mode'
    elif [[ "$command" == zsh ]]; then pane_status='likely ready'
    elif [[ "$command" == ssh ]]; then pane_status='remote session'
    fi
    current=''
    [[ "$id" == "$current_pane" ]] && current=current
    display="$(printf '%-5s %-8s %-14s %-18s %s' "$id" "$current" "$command" "$pane_status" "$pane_path")"
    line="$id"$'\t'"$display"
    if [[ "$pane_status" == 'likely ready' ]]; then ready+=("$line")
    else other+=("$line")
    fi
  done < <(tmux list-panes -t "$window" -F '#{pane_id}'$'\t''#{session_id}'$'\t''#{window_id}'$'\t''#{pane_dead}'$'\t''#{pane_in_mode}'$'\t''#{pane_current_command}'$'\t''#{pane_current_path}'$'\t''#{pane_title}') || return
  input=("$ready[@]" "$other[@]")

  local start_bind='' index
  for (( index=1; index <= ${#ready}; ++index )); do
    [[ -n "$start_bind" ]] && start_bind+='+'
    start_bind+="pos(${index})+select"
  done
  local -a fzf_args=(-i --multi --sync --no-sort '--height=80%' --border
    '--prompt=ii load panes> ' '--header=SPACE toggle · ENTER load · ESC cancel'
    '--bind=space:toggle,enter:accept,esc:abort,q:abort' $'--delimiter=\t' '--with-nth=2')
  [[ -n "$start_bind" ]] && fzf_args+=("--bind=start:${start_bind}")
  selected=("${(@f)$(print -rl -- "$input[@]" | fzf "$fzf_args[@]")}") || {
    print -r -- aborted
    return 1
  }
  for line in "$selected[@]"; do
    id="${line%%$'\t'*}"
    [[ -n "$id" ]] && chosen[$id]=1
  done

  local loaded=0 dispatched=0 skipped=0 failed=0 snapshot original
  local -a snapshot_fields
  print -r -- 'Load summary' ''
  for line in "$input[@]"; do
    id="${line%%$'\t'*}"
    if [[ -z "${chosen[$id]:-}" ]]; then
      printf '%-5s skipped by user\n' "$id"
      (( ++skipped ))
      continue
    fi
    snapshot="$(tmux display-message -p -t "$id" '#{session_id}'$'\t''#{window_id}'$'\t''#{pane_dead}'$'\t''#{pane_in_mode}'$'\t''#{pane_current_command}' 2>/dev/null)" || snapshot=''
    snapshot_fields=("${(@s:\t:)snapshot}")
    original="${initial[$id]}"
    if [[ -z "$snapshot" ]]; then
      printf '%-5s failed: pane disappeared\n' "$id"
      (( ++failed ))
    elif [[ "$snapshot" != "$original" ]]; then
      printf '%-5s failed: pane state changed (%s)\n' "$id" "${snapshot##*$'\t'}"
      (( ++failed ))
    elif [[ "${snapshot_fields[3]:-}" == 1 ]]; then
      printf '%-5s failed: dead pane\n' "$id"
      (( ++failed ))
    elif [[ "$id" == "$current_pane" ]]; then
      if ii_zsh_cmd_load load >/dev/null; then
        printf '%-5s loaded locally\n' "$id"
        (( ++loaded ))
      else
        printf '%-5s failed: local load failed\n' "$id"
        (( ++failed ))
      fi
    elif tmux send-keys -t "$id" -l 'ii l' && tmux send-keys -t "$id" Enter; then
      printf '%-5s dispatched\n' "$id"
      (( ++dispatched ))
    else
      printf '%-5s failed: dispatch failed\n' "$id"
      (( ++failed ))
    fi
  done
  print -r -- '' "$loaded loaded locally, $dispatched dispatched, $skipped skipped, $failed failed"
  (( failed == 0 ))
}

ii_zsh_unset_one() {
  local internal name
  internal="$(ii_zsh_normalize_name "$1")" || return
  tmux set-environment -u "$internal" || return
  name="${internal#ii_}"
  unset "$internal" "$name" "${(U)name}"
  print -r -- "unset $name"
}

ii_zsh_cmd_unset() {
  shift
  ii_zsh_tmux_available || return
  if [[ "${1:-}" == -a ]]; then
    print -n -- "unset all ii_ variables in this tmux session? [y/N] "
    local answer line name count=0
    IFS= read -r answer || true
    [[ "$answer" == y ]] || {
      print -r -- aborted
      return 1
    }
    while IFS= read -r line; do
      name="${line%%=*}"
      ii_zsh_unset_one "$name" || return
      (( ++count ))
    done < <(ii_zsh_tmux_variable_lines)
    print -r -- "unset $count variable(s)"
    return
  fi
  local raw
  for raw in "$@"; do
    ii_zsh_unset_one "$raw" || return
  done
}
