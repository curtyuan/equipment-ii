# Interactive variable selection and editing.

ii_cmd_set_interactive() {
  ii_tmux_available || return
  ii_require_cmd fzf || return

  local filter selected value
  filter="${1:-${II_SET_VAR_FILTER:-}}"
  filter="$(ii_var_shortcut_filter "$filter")"

  if [[ -n "$filter" ]]; then
    selected="$(ii_var_match_candidate "$filter")" || return
  else
    selected="$(ii_var_set_candidates | fzf -i --prompt='ii set var> ' --height=40% --border)" || return
  fi
  [[ -n "$selected" ]] || return

  value="$(ii_fzf_input_value "${II_SET_VALUE_FILTER:-}" --prompt="${selected} value> " --height=40% --border)"
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
Variables with values are listed before empty default names.
Select "add new variable" to create or update a variable.
Enter edits the selected variable, copies the value, and closes.
i edits the selected variable. y copies the selected value without closing.
q, Esc, or Ctrl-C aborts. Use ii load to load variables into this shell.
EOF
    return 0
  fi

  ii_tmux_available || return
  ii_require_cmd fzf || return

  local key selected line name value plugin_file footer footer_status copy_rc
  plugin_file="${II_PLUGIN_DIR%/}/ii.plugin.zsh"
  footer="$(ii_interact_footer "j/k Move    i Edit    Enter Edit+Copy+Quit    y Copy    q Quit" "")"
  footer_status=""
  [[ -t 0 ]] && stty -ixon 2>/dev/null
  while true; do
    selected="$(
      ii_var_entries_for_fzf \
        | fzf -i --ansi --expect=enter,i,y,q --prompt='ii vars> ' --delimiter=$'\t' --with-nth=1,2,3 \
            --bind='j:down,k:up' \
            --preview="zsh -fc 'source \"\$1\"; printf \"%s\" \"\$2\" | ii_fzf_print_preview_with_footer \"\$3\"' -- ${(q)plugin_file} {4..} ${(q)footer}" \
            --preview-window='down,5,wrap,noinfo'
    )" || return
    [[ -n "$selected" ]] || return

    key="${selected%%$'\n'*}"
    if [[ "$key" == "enter" || "$key" == "i" || "$key" == "y" || "$key" == "q" ]]; then
      selected="${selected#*$'\n'}"
    else
      key="enter"
    fi
    [[ -n "${II_INTERACTIVE_KEY:-}" ]] && key="$II_INTERACTIVE_KEY"

    case "$key" in
      q)
        return
        ;;
      i)
        line="${selected%%$'\n'*}"
        [[ -n "$line" ]] || return
        name="${line%%$'\t'*}"
        if [[ "$name" == "add new variable" ]]; then
          ii_cmd_interactive_add_variable
        else
          ii_cmd_interactive_edit_variable "$name"
        fi
        [[ -n "${II_INTERACTIVE_KEY:-}" ]] && return
        continue
        ;;
      enter)
        line="${selected%%$'\n'*}"
        [[ -n "$line" ]] || return
        name="${line%%$'\t'*}"
        if [[ "$name" == "add new variable" ]]; then
          ii_cmd_interactive_add_variable
          return
        else
          ii_cmd_interactive_edit_variable "$name" || return
          value="$(ii_var_value_by_name "ii_${name}")"
          if ii_clip_copy "$value"; then
            print "copied ${name}"
          else
            print "selected ${name}; clipboard copy failed"
          fi
        fi
        return
        ;;
    esac

    [[ "$key" == "y" ]] || return

    line="${selected%%$'\n'*}"
    [[ -n "$line" ]] || return
    name="${line%%$'\t'*}"
    if [[ "$name" == "add new variable" ]]; then
      ii_cmd_interactive_add_variable || return
      footer_status="variable saved"
    else
      value="${line##*$'\t'}"
      ii_clip_copy "$value"
      copy_rc="$?"
      footer_status="$(ii_interact_copy_status "$copy_rc" "copied ${name}" "selected ${name}; clipboard copy failed")"
    fi
    footer="$(ii_interact_footer "j/k Move    i Edit    Enter Edit+Copy+Quit    y Copy    q Quit" "$footer_status")"
    [[ -n "${II_INTERACTIVE_KEY:-}" ]] && print -r -- "$footer_status" && return
  done
}

ii_cmd_interactive_add_variable() {
  local raw name value

  if [[ -n "${1:-}" ]]; then
    raw="$1"
  elif [[ -v II_ADD_VAR_FILTER ]]; then
    raw="$II_ADD_VAR_FILTER"
  else
    raw="$(ii_fzf_input_value "" --prompt='ii add name> ' --height=40% --border)" || return
  fi
  [[ -n "$raw" ]] || return

  name="$(ii_var_normalize_name "$raw")" || return
  if [[ -v II_ADD_VALUE_FILTER ]]; then
    value="$II_ADD_VALUE_FILTER"
  else
    value="$(ii_fzf_input_value "" --prompt="${name#ii_} value> " --height=40% --border)" || return
  fi

  ii_var_set_tmux_only "$name" "$value" || return
}

ii_cmd_interactive_edit_variable() {
  local raw name value current edited

  raw="$1"
  name="$(ii_var_normalize_name "$raw")" || return
  current="$(ii_var_value_by_name "$name")"

  if [[ -v II_EDIT_VALUE_FILTER ]]; then
    value="$II_EDIT_VALUE_FILTER"
  else
    edited="$(print -r -- "$current" | fzf -i --print-query --phony --query="$current" --prompt="${name#ii_} value> " --height=40% --border)" || return
    value="$(print -r -- "$edited" | awk 'NR == 1 {print; exit}')"
  fi

  ii_var_set_tmux_only "$name" "$value" || return
}

ii_cmd_interactive_delete_variable() {
  local raw name shell_name

  raw="$1"
  name="$(ii_var_normalize_name "$raw")" || return
  shell_name="$(ii_var_shell_name "$name")"
  tmux set-environment -u "$name" 2>/dev/null
  unset "$name"
  unset "$shell_name"
  unset "${(U)shell_name}"
  print "unset $shell_name"
}

ii_var_set_tmux_only() {
  local name="$1"
  local value="$2"
  tmux set-environment "$name" "$value" || return
  if [[ "${II_SYNC_LOADED_VARS:-}" == "1" ]]; then
    ii_export_var_line "${name}=${value}" || return
    ii_enable_loaded_var_sync
  fi
  print "$(ii_var_display_line "${name}=${value}")"
}
