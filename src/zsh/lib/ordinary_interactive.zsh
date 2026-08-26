# Zsh-owned interactive variable selection, mutation, and copy.

ii_zsh_interactive_entries() {
  local line name value
  local -A values seen
  while IFS= read -r line; do
    name="${${line%%=*}#ii_}"
    value="${line#*=}"
    values[$name]="$value"
  done < <(ii_zsh_tmux_variable_lines)

  local -a populated empty names
  names=("${(@f)$(ii_zsh_default_names)}" "${(@k)values}")
  for name in "$names[@]"; do
    [[ -n "$name" && -z "${seen[$name]:-}" ]] || continue
    seen[$name]=1
    value="${values[$name]:-}"
    if [[ -n "$value" ]]; then
      populated+=("$name"$'\t'"${value//$'\n'/ }")
    else
      empty+=("$name"$'\t')
    fi
  done
  for line in ${(on)populated}; do print -r -- "$line"; done
  for line in "$empty[@]"; do print -r -- "$line"; done
  print -r -- $'add new variable\tCreate or update a variable'
}

ii_zsh_interactive_input() {
  local prompt="$1" initial="${2:-}" result
  result="$(print -r -- "$initial" | fzf -i --print-query --phony --query="$initial" --prompt="$prompt")" || return
  print -r -- "${result%%$'\n'*}"
}

ii_zsh_interactive_add() {
  local raw value internal
  if (( ${+II_ADD_VAR_FILTER} )); then raw="$II_ADD_VAR_FILTER"
  else raw="$(ii_zsh_interactive_input 'ii add name> ')" || return
  fi
  [[ -n "$raw" ]] || return 1
  internal="$(ii_zsh_normalize_name "$raw")" || return
  if (( ${+II_ADD_VALUE_FILTER} )); then value="$II_ADD_VALUE_FILTER"
  else value="$(ii_zsh_interactive_input "${internal#ii_} value> ")" || return
  fi
  ii_zsh_store_value "$internal" "$value"
}

ii_zsh_interactive_edit() {
  local name="$1" current="$2" value internal
  internal="$(ii_zsh_normalize_name "$name")" || return
  if (( ${+II_EDIT_VALUE_FILTER} )); then value="$II_EDIT_VALUE_FILTER"
  else value="$(ii_zsh_interactive_input "$name value> " "$current")" || return
  fi
  ii_zsh_store_value "$internal" "$value"
}

ii_zsh_cmd_interactive() {
  shift
  ii_zsh_tmux_available || return
  (( $+commands[fzf] )) || { print -u2 'ii: fzf command not found'; return 1; }

  local result action selected name value footer_status=''
  local -a result_lines
  local normal_footer search_footer
  local normal_keys='j,k,h,l,i,y,q,/'
  while true; do
    normal_footer="j/k Move  / Search  i/l Edit  Enter Copy+Quit  y Copy  h/q Quit${footer_status:+  |  $footer_status}"
    search_footer="Type Filter  Esc Normal  Enter Copy+Quit${footer_status:+  |  $footer_status}"
    result="$(ii_zsh_interactive_entries | \
      II_FZF_NORMAL_FOOTER="$normal_footer" II_FZF_SEARCH_FOOTER="$search_footer" \
        fzf -i --ansi --expect=enter,i,y --layout=reverse --prompt='ii vars> ' \
        $'--delimiter=\t' --with-nth=1,2 \
        --bind="start:hide-input+disable-search+rebind($normal_keys)" \
        --bind="/:show-input+enable-search+transform-footer(printf %s \"\$II_FZF_SEARCH_FOOTER\")+unbind($normal_keys)" \
        --bind="esc:clear-query+hide-input+disable-search+transform-footer(printf %s \"\$II_FZF_NORMAL_FOOTER\")+rebind($normal_keys)" \
        --bind='j:down,k:up,l:accept,i:accept,y:accept,h:abort,q:abort' \
        --footer="$normal_footer" --no-separator)" || return 1
    [[ -n "$result" ]] || return 1
    result_lines=("${(@f)result}")
    action="${result_lines[1]:-}"
    if [[ "$action" == (enter|i|y|q) ]]; then
      selected="${result_lines[2]}"
    elif [[ "${result_lines[2]:-}" == (enter|i|y|q) ]]; then
      action="${result_lines[2]}"
      selected="${result_lines[1]}"
    else
      action=enter
      selected="${result_lines[1]}"
    fi
    [[ -n "${II_INTERACTIVE_KEY:-}" ]] && action="$II_INTERACTIVE_KEY"
    selected="${selected%%$'\n'*}"
    name="${selected%%$'\t'*}"
    value="${selected#*$'\t'}"
    [[ -n "$name" ]] || return 1

    case "$action" in
      q) return 1 ;;
      i)
        if [[ "$name" == 'add new variable' ]]; then ii_zsh_interactive_add
        else ii_zsh_interactive_edit "$name" "$value"
        fi
        [[ -n "${II_INTERACTIVE_KEY:-}" ]] && return
        footer_status='variable saved'
        ;;
      enter)
        if [[ "$name" == 'add new variable' ]]; then
          ii_zsh_interactive_add
        elif ii_zsh_clip_copy "$value"; then
          print -r -- "copied $name"
        else
          print -r -- "selected $name; clipboard copy failed"
        fi
        return
        ;;
      y)
        if [[ "$name" == 'add new variable' ]]; then
          ii_zsh_interactive_add || return
          footer_status='variable saved'
        elif ii_zsh_clip_copy "$value"; then
          footer_status="copied $name"
        else
          footer_status="selected $name; clipboard copy failed"
        fi
        [[ -n "${II_INTERACTIVE_KEY:-}" ]] && print -r -- "$footer_status" && return
        ;;
      *) return 1 ;;
    esac
  done
}
