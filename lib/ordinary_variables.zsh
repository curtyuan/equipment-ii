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
  ii_zsh_maybe_detect_lhost "$internal"
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
    value="${value[2,-2]//\'\\\'\'/\'}"
  elif [[ ${#value} -ge 2 && "$value[1]" == '"' && "$value[-1]" == '"' ]]; then
    value="${value[2,-2]//\\\"/\"}"
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
      -a) all=1 ;;
      *) remaining+=("$arg") ;;
    esac
  done
  if (( from_shell && from_file )); then
    print -u2 "ii: --from-shell and --from-file cannot be used together"
    return 2
  fi
  if (( all && ! from_shell )); then
    print -u2 "ii: -a is only supported with --from-shell"
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
      print -u2 "ii: --from-shell -a does not accept variable names"
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
    ii_zsh_maybe_detect_lhost "$internal"
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
