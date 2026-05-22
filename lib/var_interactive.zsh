# Interactive variable selection and editing.

ii_cmd_set_interactive() {
  ii_tmux_available || return
  ii_require_cmd fzf || return

  local filter selected value
  filter="${1:-${JJ_SET_VAR_FILTER:-}}"
  filter="$(ii_var_shortcut_filter "$filter")"

  if [[ -n "$filter" ]]; then
    selected="$(ii_var_match_candidate "$filter")" || return
  else
    selected="$(ii_var_set_candidates | fzf -i --prompt='ii set var> ' --height=40% --border)" || return
  fi
  [[ -n "$selected" ]] || return

  value="$(ii_fzf_input_value "${JJ_SET_VALUE_FILTER:-}" --prompt="${selected} value> " --height=40% --border)"
  [[ -n "$value" ]] || return

  ii_cmd_set "$selected" "$value"
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
