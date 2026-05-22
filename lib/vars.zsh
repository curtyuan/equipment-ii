# JJ_ variable commands and helpers.

ii_cmd_set() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii set NAME VALUE
       ii s NAME VALUE
       ii set
       ii s
       ii s FILTER
       ii s:FILTER

Set NAME in the current tmux session and export it into this shell.
The current shell export uses NAME without the internal JJ_ prefix.

With no arguments, open a TUI to choose a variable and type its value.
With one FILTER argument, open the same TUI filtered to matching variable names.
Single-letter shortcuts include r for RHOST.
EOF
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    ii_cmd_set_interactive
    return
  fi

  if [[ $# -eq 1 ]]; then
    ii_cmd_set_interactive "$1"
    return
  fi

  if [[ $# -lt 2 ]]; then
    cat <<'EOF'
usage: ii set NAME VALUE
       ii s NAME VALUE
       ii set
       ii s
       ii s FILTER
       ii s:FILTER
EOF
    return 2
  fi

  ii_tmux_available || return

  local name value
  name="$(ii_var_normalize_name "$(ii_var_shortcut_filter "$1")")" || return
  shift
  value="$*"

  tmux set-environment "$name" "$value" || return
  ii_export_var_line "${name}=${value}" || return
  print "$(ii_var_display_line "${name}=${value}")"
}

ii_cmd_set_interactive() {
  ii_tmux_available || return
  ii_require_cmd fzf || return

  local filter selected value
  filter="${1:-${JJ_SET_VAR_FILTER:-}}"
  filter="$(ii_var_shortcut_filter "$filter")"

  selected="$(ii_var_set_candidates | ii_fzf_select_one "$filter" --prompt='ii set var> ' --height=40% --border)" || return
  if [[ -z "$selected" && -n "$filter" ]]; then
    ii_cmd_interactive_add_variable
    return
  fi
  [[ -n "$selected" ]] || return

  value="$(ii_fzf_input_value "${JJ_SET_VALUE_FILTER:-}" --prompt="${selected} value> " --height=40% --border)"
  [[ -n "$value" ]] || return

  ii_cmd_set "$selected" "$value"
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

ii_cmd_interactive() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii interactive
       ii i

Select variables with fzf, edit values, and copy values.
Default variable names are shown even before they have values.
Select "add new variable" to create or update a variable.
Enter edits the selected variable. Ctrl-A adds a new variable.
Ctrl-Y copies selected existing values. Esc or Ctrl-C aborts.
Use Tab to select multiple variables. Use ii load to load variables into this shell.
EOF
    return 0
  fi

  ii_tmux_available || return
  ii_require_cmd fzf || return

  local key selected copied line name value count=0
  selected="$(
    ii_var_entries_for_fzf \
      | fzf -i --multi --expect=ctrl-a,ctrl-y --prompt='ii vars> ' --delimiter=$'\t' --with-nth=1 \
          --preview='printf "%s" {2..}' --preview-window='down:3:wrap'
  )" || return
  [[ -n "$selected" ]] || return

  key="${selected%%$'\n'*}"
  if [[ "$key" == "ctrl-a" || "$key" == "ctrl-y" ]]; then
    selected="${selected#*$'\n'}"
  else
    key="enter"
  fi
  [[ -n "${JJ_INTERACTIVE_KEY:-}" ]] && key="$JJ_INTERACTIVE_KEY"

  case "$key" in
    ctrl-a)
      ii_cmd_interactive_add_variable
      return
      ;;
    enter)
      line="${selected%%$'\n'*}"
      [[ -n "$line" ]] || return
      name="${line%%$'\t'*}"
      if [[ "$name" == "add new variable" ]]; then
        ii_cmd_interactive_add_variable
      else
        ii_cmd_interactive_edit_variable "$name"
      fi
      return
      ;;
  esac

  [[ "$key" == "ctrl-y" ]] || return

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="${line%%$'\t'*}"
    if [[ "$name" == "add new variable" ]]; then
      ii_cmd_interactive_add_variable || return
      continue
    fi
    value="${line#*$'\t'}"
    if [[ $count -eq 0 ]]; then
      copied="$value"
    else
      copied="${copied}"$'\n'"${value}"
    fi
    (( count++ ))
  done <<< "$selected"

  [[ $count -gt 0 ]] || return

  if ii_clip_copy "$copied"; then
    print "copied ${count} variable value(s)"
  else
    print "selected ${count} variable value(s); clipboard copy failed"
  fi

  print
  print -r -- "$copied"
}

ii_cmd_interactive_add_variable() {
  local raw name value

  if [[ -n "${1:-}" ]]; then
    raw="$1"
  elif [[ -v JJ_ADD_VAR_FILTER ]]; then
    raw="$JJ_ADD_VAR_FILTER"
  else
    raw="$(ii_fzf_input_value "" --prompt='ii add name> ' --height=40% --border)" || return
  fi
  [[ -n "$raw" ]] || return

  name="$(ii_var_normalize_name "$raw")" || return
  if [[ -v JJ_ADD_VALUE_FILTER ]]; then
    value="$JJ_ADD_VALUE_FILTER"
  else
    value="$(ii_fzf_input_value "" --prompt="${name#JJ_} value> " --height=40% --border)" || return
  fi

  ii_var_set_tmux_only "$name" "$value" || return
}

ii_cmd_interactive_edit_variable() {
  local raw name value current

  raw="$1"
  name="$(ii_var_normalize_name "$raw")" || return
  current="$(ii_var_value_by_name "$name")"

  if [[ -v JJ_EDIT_VALUE_FILTER ]]; then
    value="$JJ_EDIT_VALUE_FILTER"
  else
    value="$(print -r -- "$current" | fzf -i --print-query --phony --query="$current" --prompt="${name#JJ_} value> " --height=40% --border | awk 'NR == 1 {print; exit}')" || return
  fi

  ii_var_set_tmux_only "$name" "$value" || return
}

ii_var_set_tmux_only() {
  local name="$1"
  local value="$2"
  tmux set-environment "$name" "$value" || return
  print "$(ii_var_display_line "${name}=${value}")"
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

ii_var_normalize_name() {
  local name="$1"
  name="${name#export }"
  name="${name%%=*}"
  name="${(U)name}"
  [[ "$name" == JJ_* ]] || name="JJ_${name}"

  if [[ ! "$name" =~ '^JJ_[A-Z_][A-Z0-9_]*$' ]]; then
    print -u2 "ii: invalid variable name: $1"
    return 1
  fi

  print -r -- "$name"
}

ii_var_lines_from_tmux() {
  tmux show-environment | awk -F= '/^JJ_[A-Za-z0-9_]*=/{print}'
}

ii_var_filter_by_name() {
  local pattern="$1"
  pattern="${(L)pattern}"
  awk -F= -v pat="$pattern" 'tolower($1) ~ pat {print}'
}

ii_var_print_named_view() {
  local raw name line
  for raw in "$@"; do
    name="$(ii_var_normalize_name "$raw")" || return
    line="$(ii_var_line_by_name "$name")"
    [[ -n "$line" ]] || continue
    ii_var_print_name_value "$line"
  done
}

ii_var_print_cred_view() {
  ii_var_lines_from_tmux \
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
        ii_var_print_name_value "$line"
      done
}

ii_var_line_by_name() {
  local name="$1"
  ii_var_lines_from_tmux | awk -F= -v target="$name" '$1 == target {print; exit}'
}

ii_var_value_by_name() {
  local name="$1"
  local line
  line="$(ii_var_line_by_name "$name")"
  [[ -n "$line" ]] && print -r -- "${line#*=}"
}

ii_var_print_name_value() {
  local line="$1"
  local name="${line%%=*}"
  local value="${line#*=}"
  print "$(ii_var_shell_name "$name")"
  print -r -- "$value"
}

ii_var_default_names() {
  print DOMAIN
  print LHOST
  print RHOST
  print LPORT
  print RPORT
  print USER1
  print PASSWD1
  print HASH1
  print USER2
  print PASSWD2
  print HASH2
}

ii_var_set_candidates() {
  {
    ii_var_default_names
    ii_var_lines_from_tmux | awk -F= '{sub(/^JJ_/, "", $1); print toupper($1)}'
  } | awk 'NF && !seen[toupper($0)]++ {print toupper($0)}'
}

ii_var_shortcut_filter() {
  case "${(L)1}" in
    r) print RHOST ;;
    l) print LHOST ;;
    d) print DOMAIN ;;
    *) print -r -- "$1" ;;
  esac
}

ii_var_entries_for_fzf() {
  local name line value
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    line="$(ii_var_line_by_name "JJ_${name}")"
    value=""
    [[ -n "$line" ]] && value="${line#*=}"
    print -r -- "${name}"$'\t'"${value}"
  done < <(ii_var_set_candidates)
  print -r -- "add new variable"$'\t'"Create or update a variable. Empty values are stored but skipped by ii load."
}

ii_fzf_select_one() {
  local filter="$1"
  shift

  if [[ -n "$filter" ]]; then
    FZF_DEFAULT_OPTS="--filter=${filter}" fzf -i "$@" | awk 'NF {print; exit}'
  else
    fzf -i "$@"
  fi
}

ii_fzf_input_value() {
  local filter="$1"
  shift

  if [[ -n "$filter" ]]; then
    FZF_DEFAULT_OPTS="--filter=${filter}" fzf -i --print-query --phony "$@" | awk 'NR == 1 {print; exit}'
  else
    print | fzf -i --print-query --phony "$@" | awk 'NR == 1 {print; exit}'
  fi
}

ii_var_display_lines_for_fzf() {
  sed 's/^JJ_//'
}

ii_var_display_line() {
  local line="$1"
  print -r -- "${line#JJ_}"
}

ii_var_line_from_display() {
  local line="$1"
  [[ "$line" == JJ_* ]] || line="JJ_${line}"
  print -r -- "$line"
}

ii_var_shell_name() {
  local name="$1"
  print -r -- "${name#JJ_}"
}

ii_export_var_line() {
  local line="$1"
  local name="${line%%=*}"
  local value="${line#*=}"
  local shell_name

  if [[ ! "$name" =~ '^JJ_[A-Z_][A-Z0-9_]*$' ]]; then
    print -u2 "ii: refusing to export invalid variable line: $line"
    return 1
  fi

  shell_name="$(ii_var_shell_name "$name")"
  export "${shell_name}=${value}"
  export "${(L)shell_name}=${value}"
}
