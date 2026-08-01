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

  local result action=enter selected name value
  result="$(ii_zsh_interactive_entries | fzf -i --ansi --expect=enter,i,y,q --layout=reverse --prompt='ii vars> ')" || return 1
  [[ -n "$result" ]] || return 1
  if [[ "$result" == (enter|i|y|q)$'\n'* ]]; then
    action="${result%%$'\n'*}"
    selected="${result#*$'\n'}"
  else
    selected="$result"
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
      ;;
    enter)
      if [[ "$name" == 'add new variable' ]]; then
        ii_zsh_interactive_add
      elif ii_zsh_clip_copy "$value"; then
        print -r -- "copied $name"
      else
        print -r -- "selected $name; clipboard copy failed"
      fi
      ;;
    y)
      if [[ "$name" == 'add new variable' ]]; then
        ii_zsh_interactive_add
      elif ii_zsh_clip_copy "$value"; then
        print -r -- "copied $name"
      else
        print -r -- "selected $name; clipboard copy failed"
      fi
      ;;
    *) return 1 ;;
  esac
}
