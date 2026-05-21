# JJ_ variable commands and helpers.

jj_cmd_set() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: jj set NAME VALUE
       jjs NAME VALUE
       jjs

Set NAME in the current tmux session and export it into this shell.
The current shell export uses NAME without the internal JJ_ prefix.

With no arguments, open a TUI to choose a variable and type its value.
EOF
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    jj_cmd_set_interactive
    return
  fi

  if [[ $# -lt 2 ]]; then
    cat <<'EOF'
usage: jj set NAME VALUE
       jjs NAME VALUE
       jjs
EOF
    return 2
  fi

  jj_tmux_available || return

  local name value
  name="$(jj_var_normalize_name "$1")" || return
  shift
  value="$*"

  tmux set-environment "$name" "$value" || return
  jj_export_var_line "${name}=${value}" || return
  print "$(jj_var_display_line "${name}=${value}")"
}

jj_cmd_set_interactive() {
  jj_tmux_available || return
  jj_require_cmd fzf || return

  local selected value
  selected="$(jj_var_set_candidates | jj_fzf_select_one "${JJ_SET_VAR_FILTER:-}" --prompt='jj set var> ' --height=40% --border)" || return
  [[ -n "$selected" ]] || return

  value="$(jj_fzf_input_value "${JJ_SET_VALUE_FILTER:-}" --prompt="${selected} value> " --height=40% --border)"
  [[ -n "$value" ]] || return

  jj_cmd_set "$selected" "$value"
}

jj_cmd_load() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: jj load
       jjl

Load variables from the current tmux session into this shell.
The current shell exports use names without the internal JJ_ prefix.
EOF
    return 0
  fi

  jj_tmux_available || return

  local line count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    jj_export_var_line "$line" || return
    (( count++ ))
  done < <(jj_var_lines_from_tmux)

  print "loaded ${count} variable(s)"
}

jj_cmd_interactive() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: jj interactive
       jji

Select variables from the current tmux session with fzf and copy their values.
Use Tab to select multiple variables. Use jjl to load variables into this shell.
EOF
    return 0
  fi

  jj_tmux_available || return
  jj_require_cmd fzf || return

  local selected copied line value count=0
  selected="$(jj_var_lines_from_tmux | jj_var_display_lines_for_fzf | fzf --multi --prompt='jj vars> ')" || return
  [[ -n "$selected" ]] || return

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    value="${line#*=}"
    if [[ $count -eq 0 ]]; then
      copied="$value"
    else
      copied="${copied}"$'\n'"${value}"
    fi
    (( count++ ))
  done <<< "$selected"

  if jj_clip_copy "$copied"; then
    print "copied ${count} variable value(s)"
  else
    print "selected ${count} variable value(s); clipboard copy failed"
  fi

  print
  print -r -- "$copied"
}

jj_cmd_variable() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: jj variable [PATTERN]
       jjv [PATTERN]

Print variables from the current tmux session. PATTERN filters variable
names only, case-insensitively.

Special views:
  jjv host     Print configured DOMAIN/LHOST/RHOST/LPORT/RPORT as name/value pairs
  jjv cred     Print configured USER*/PASSWD*/HASH* as name/value pairs
EOF
    return 0
  fi

  jj_tmux_available || return

  case "${1:-}" in
    host) jj_var_print_named_view DOMAIN LHOST RHOST LPORT RPORT ;;
    cred) jj_var_print_cred_view ;;
    "") jj_var_lines_from_tmux | jj_var_display_lines_for_fzf ;;
    *) jj_var_lines_from_tmux | jj_var_filter_by_name "$1" | jj_var_display_lines_for_fzf ;;
  esac
}

jj_cmd_unset() {
  if [[ "${1:-}" == "--help" || $# -lt 1 ]]; then
    cat <<'EOF'
usage: jj unset NAME [NAME...]

Remove JJ_NAME from the current tmux session and unset it in this shell.
EOF
    [[ "${1:-}" == "--help" ]] && return 0
    return 2
  fi

  jj_tmux_available || return

  local raw name
  for raw in "$@"; do
    name="$(jj_var_normalize_name "$raw")" || return
    tmux set-environment -u "$name" 2>/dev/null
    unset "$name"
    unset "$(jj_var_shell_name "$name")"
    print "unset $(jj_var_shell_name "$name")"
  done
}

jj_var_normalize_name() {
  local name="$1"
  name="${name#export }"
  name="${name%%=*}"
  name="${(U)name}"
  [[ "$name" == JJ_* ]] || name="JJ_${name}"

  if [[ ! "$name" =~ '^JJ_[A-Z_][A-Z0-9_]*$' ]]; then
    print -u2 "jj: invalid variable name: $1"
    return 1
  fi

  print -r -- "$name"
}

jj_var_lines_from_tmux() {
  tmux show-environment | awk -F= '/^JJ_[A-Za-z0-9_]*=/{print}'
}

jj_var_filter_by_name() {
  local pattern="$1"
  pattern="${(L)pattern}"
  awk -F= -v pat="$pattern" 'tolower($1) ~ pat {print}'
}

jj_var_print_named_view() {
  local raw name line
  for raw in "$@"; do
    name="$(jj_var_normalize_name "$raw")" || return
    line="$(jj_var_line_by_name "$name")"
    [[ -n "$line" ]] || continue
    jj_var_print_name_value "$line"
  done
}

jj_var_print_cred_view() {
  jj_var_lines_from_tmux \
    | awk -F= '
        /^JJ_(USER|PASSWD|HASH)[0-9]*=/ {
          name = $1
          sub(/^JJ_/, "", name)
          rank = 0
          if (name ~ /^PASSWD/) rank = 1
          if (name ~ /^HASH/) rank = 2
          suffix = name
          sub(/^(USER|PASSWD|HASH)/, "", suffix)
          if (suffix == "") suffix = 0
          print suffix "\t" rank "\t" $0
        }
      ' \
    | sort -n -k1,1 -k2,2 \
    | cut -f3- \
    | while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        jj_var_print_name_value "$line"
      done
}

jj_var_line_by_name() {
  local name="$1"
  jj_var_lines_from_tmux | awk -F= -v target="$name" '$1 == target {print; exit}'
}

jj_var_print_name_value() {
  local line="$1"
  local name="${line%%=*}"
  local value="${line#*=}"
  print "$(jj_var_shell_name "$name")"
  print -r -- "$value"
}

jj_var_default_names() {
  print DOMAIN
  print LHOST
  print RHOST
  print LPORT
  print RPORT
}

jj_var_set_candidates() {
  {
    jj_var_default_names
    jj_var_lines_from_tmux | awk -F= '{sub(/^JJ_/, "", $1); print $1}'
  } | awk 'NF && !seen[$0]++'
}

jj_fzf_select_one() {
  local filter="$1"
  shift

  if [[ -n "$filter" ]]; then
    FZF_DEFAULT_OPTS="--filter=${filter}" fzf "$@" | awk 'NF {print; exit}'
  else
    fzf "$@"
  fi
}

jj_fzf_input_value() {
  local filter="$1"
  shift

  if [[ -n "$filter" ]]; then
    FZF_DEFAULT_OPTS="--filter=${filter}" fzf --print-query --phony "$@" | awk 'NR == 1 {print; exit}'
  else
    print | fzf --print-query --phony "$@" | awk 'NR == 1 {print; exit}'
  fi
}

jj_var_display_lines_for_fzf() {
  sed 's/^JJ_//'
}

jj_var_display_line() {
  local line="$1"
  print -r -- "${line#JJ_}"
}

jj_var_line_from_display() {
  local line="$1"
  [[ "$line" == JJ_* ]] || line="JJ_${line}"
  print -r -- "$line"
}

jj_var_shell_name() {
  local name="$1"
  print -r -- "${name#JJ_}"
}

jj_export_var_line() {
  local line="$1"
  local name="${line%%=*}"
  local value="${line#*=}"
  local shell_name

  if [[ ! "$name" =~ '^JJ_[A-Z_][A-Z0-9_]*$' ]]; then
    print -u2 "jj: refusing to export invalid variable line: $line"
    return 1
  fi

  shell_name="$(jj_var_shell_name "$name")"
  export "${shell_name}=${value}"
}
