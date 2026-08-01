# Zsh-owned read-only variable presentation and file output.

ii_zsh_color_enabled() {
  [[ -z "${NO_COLOR:-}" ]] || return 1
  case "${(L)${II_COLOR:-auto}}" in
    always) return 0 ;;
    never) return 1 ;;
    auto) [[ -t 1 ]] ;;
    *) [[ -t 1 ]] ;;
  esac
}

ii_zsh_print_key() {
  if ii_zsh_color_enabled; then
    print -r -- $'\e[34m'"$1"$'\e[0m'
  else
    print -r -- "$1"
  fi
}

ii_zsh_cmd_list() {
  shift
  ii_zsh_tmux_available || return
  local pattern="${(L)${1:-}}" line name value
  while IFS= read -r line; do
    [[ "$line" == *=* ]] || continue
    name="${line%%=*}"
    value="${line#*=}"
    [[ -n "$value" ]] || continue
    name="${name#ii_}"
    [[ -z "$pattern" || "${(L)name}" == *"$pattern"* ]] || continue
    ii_zsh_print_key "$name"
    print -r -- "$value"
  done < <(ii_zsh_tmux_variable_lines)
}

ii_zsh_cmd_output() {
  local command="$1"
  shift
  [[ "$command" == v && "${1:-}" == --out ]] && shift
  [[ $# -le 1 ]] || {
    print -u2 "ii: usage: ii v --out [PATH] | ii vo [PATH]"
    return 2
  }
  ii_zsh_tmux_available || return
  local output="${1:-.env}" output_abs parent temp line name value count=0
  output_abs="${output:A}"
  parent="${output_abs:h}"
  [[ -d "$parent" ]] || {
    print -u2 "ii: output directory not found: $parent"
    return 1
  }
  [[ ! -d "$output_abs" ]] || {
    print -u2 "ii: output path is a directory: $output_abs"
    return 1
  }
  temp="$(mktemp "${output_abs}.tmp.XXXXXX")" || {
    print -u2 "ii: failed to create temporary output beside: $output_abs"
    return 1
  }
  {
    while IFS= read -r line; do
      [[ "$line" == *=* ]] || continue
      name="${line%%=*}"
      value="${line#*=}"
      [[ -n "$value" ]] || continue
      print -r -- "${name#ii_}=${(qq)value}"
      (( ++count ))
    done < <(ii_zsh_tmux_variable_lines) >|"$temp"
    command mv -f -- "$temp" "$output_abs" || {
      print -u2 "ii: failed to replace variable output: $output_abs"
      return 1
    }
    temp=""
  } always {
    [[ -n "$temp" ]] && command rm -f -- "$temp"
  }
  print -r -- "wrote $count variable(s) to $output_abs"
}
