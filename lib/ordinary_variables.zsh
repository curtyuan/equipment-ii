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

ii_zsh_cmd_set_explicit() {
  local command="$1"
  shift
  ii_zsh_tmux_available || return

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
