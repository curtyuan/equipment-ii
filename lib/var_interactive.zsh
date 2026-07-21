# Interactive variable selection and editing.

ii_cmd_interactive() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
usage: ii interactive
       ii i

Aliases:
  i

Help:
  ii help interactive

Select variables with fzf, edit values, and copy values.
Default variable names are shown even before they have values.
Variables with values are listed before empty default names.
Select "add new variable" to create or update a variable.
The selector starts in normal mode. Press / to search; Esc returns to normal.
Enter copies the selected value and closes.
i or l edits the selected variable. y copies the selected value without closing.
Edit prompts show Return to save or continue, and Esc to abort.
h, q, or Ctrl-C aborts. Use ii load to load variables into this shell.
EOF
    return 0
  fi

  ii_tmux_available || return
  ii_require_cmd fzf || return

  local key selected line name value plugin_file footer search_footer footer_status copy_rc normal_keys preview_cmd
  plugin_file="${II_PLUGIN_DIR%/}/ii.plugin.zsh"
  footer="$(ii_interact_footer "$(ii_interact_keys_vars_normal)" "")"
  search_footer="$(ii_interact_footer "$(ii_interact_keys_vars_search)" "")"
  normal_keys="j,k,h,l,i,y,q,/"
  footer_status=""
  [[ -t 0 ]] && stty -ixon 2>/dev/null
  while true; do
    preview_cmd="zsh -fc 'source \"\$1\"; printf \"%s\" \"\$2\" | ii_fzf_print_preview_blocks \"\" \"\"' -- ${(q)plugin_file} {4..}"
    selected="$(
      ii_var_entries_for_fzf \
        | II_FZF_NORMAL_FOOTER="$footer" II_FZF_SEARCH_FOOTER="$search_footer" \
          fzf -i --ansi --expect=enter --layout=reverse --prompt='ii vars> ' --delimiter=$'\t' --with-nth=1,2,3 \
            --bind="start:$(ii_fzf_modal_start_actions)+rebind($normal_keys)" \
            --bind="/:show-input+enable-search+transform-footer(printf %s \"\$II_FZF_SEARCH_FOOTER\")+unbind($normal_keys)" \
            --bind="esc:clear-query+hide-input+disable-search+transform-footer(printf %s \"\$II_FZF_NORMAL_FOOTER\")+rebind($normal_keys)" \
            --bind='j:down,k:up,l:print(i)+accept,i:print(i)+accept,y:print(y)+accept,h:abort,q:abort' \
            --preview="$preview_cmd" \
            --preview-window='up,5,wrap,noinfo' \
            --footer="$footer" \
            --no-separator
    )" || return
    [[ -n "$selected" ]] || return

    selected="$(ii_fzf_trim_leading_empty_lines "$selected")"
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
          value="${line##*$'\t'}"
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
    footer="$(ii_interact_footer "$(ii_interact_keys_vars_normal)" "$footer_status")"
    search_footer="$(ii_interact_footer "$(ii_interact_keys_vars_search)" "$footer_status")"
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
    raw="$(ii_fzf_input_value "" --prompt='ii add name> ' --height=40% --border --footer='Return Continue    Esc Abort')" || return
  fi
  [[ -n "$raw" ]] || return

  name="$(ii_var_normalize_name "$raw")" || return
  if [[ -v II_ADD_VALUE_FILTER ]]; then
    value="$II_ADD_VALUE_FILTER"
  else
    value="$(ii_fzf_input_value "" --prompt="${name#ii_} value> " --height=40% --border --footer='Return Save    Esc Abort')" || return
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
    edited="$(print -r -- "$current" | fzf -i --print-query --phony --query="$current" --prompt="${name#ii_} value> " --height=40% --border --footer='Return Save    Esc Abort')" || return
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
    ii_enable_auto_sync
  fi
  print "$(ii_var_display_line "${name}=${value}")"
}

ii_help_register interactive ii_cmd_interactive i
