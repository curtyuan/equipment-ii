# Variable command routing and shell-sourceable file output.

ii_cmd_variable() {
  if [[ "${1:-}" == "--out" ]]; then
    shift
    ii_cmd_vars_output "$@"
    return
  fi
  ii_cmd_list "$@"
}

ii_cmd_vars_output() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
usage: ii v --out [PATH]
       ii voc [PATH]

Aliases:
  voc

Help:
  ii help v --out
  ii help variables-output
  ii help voc

Write all non-empty ii variables to PATH in shell-sourceable name='value'
format. User-facing names are lowercase without the internal ii_ prefix.
PATH defaults to .env in the current directory. Existing files are replaced.
EOF
    return 0
  fi
  if [[ $# -gt 1 ]]; then
    print -u2 "ii: usage: ii v --out [PATH]"
    return 2
  fi

  ii_tmux_available || return
  ii_require_cmd mktemp || return

  local output="${1:-.env}"
  local output_abs parent temp="" line name value count=0 serialize_rc=0
  output_abs="${output:a}"
  parent="${output_abs:h}"
  if [[ ! -d "$parent" ]]; then
    print -u2 "ii: output directory not found: $parent"
    return 1
  fi
  if [[ -d "$output_abs" ]]; then
    print -u2 "ii: output path is a directory: $output_abs"
    return 1
  fi

  {
    temp="$(mktemp "${output_abs}.tmp.XXXXXX")" || {
      print -u2 "ii: failed to create temporary output beside: $output_abs"
      return 1
    }

    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      value="${line#*=}"
      [[ -n "$value" ]] || continue
      if ! name="$(ii_var_shell_name "${line%%=*}")"; then
        serialize_rc=1
        break
      fi
      print -r -- "${name}=${(qq)value}"
      (( ++count ))
    done < <(ii_var_lines_from_tmux) >| "$temp"
    if (( serialize_rc )); then
      print -u2 "ii: failed to serialize variable output: $output_abs"
      return 1
    fi
    if ! command mv -f -- "$temp" "$output_abs"; then
      print -u2 "ii: failed to replace variable output: $output_abs"
      return 1
    fi
    temp=""
  } always {
    [[ -n "$temp" ]] && command rm -f -- "$temp"
  }

  print "wrote ${count} variable(s) to ${output_abs}"
}

ii_help_register variables-output ii_cmd_vars_output voc "v --out"
