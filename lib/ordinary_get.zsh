# Zsh-owned variable selection and clipboard copy.

ii_zsh_get_filter() {
  case "${(L)1}" in
    r) print -r -- rhost ;;
    l) print -r -- lhost ;;
    d) print -r -- domain ;;
    *) print -r -- "${(L)1}" ;;
  esac
}

ii_zsh_cmd_get() {
  local command="$1"
  shift
  ii_zsh_tmux_available || return
  (( $+commands[fzf] )) || {
    print -u2 'ii: fzf command not found'
    return 1
  }
  local filter
  case "$command" in
    gr) filter=r ;;
    gl) filter=l ;;
    g:*) filter="${command#g:}" ;;
    *) filter="${1:-}" ;;
  esac
  [[ -n "$filter" ]] || {
    print -r -- 'usage: ii get FILTER'
    print -r -- '       ii g FILTER'
    print -r -- '       ii g:FILTER'
    print -r -- '       ii gr'
    print -r -- '       ii gl'
    return 2
  }
  filter="$(ii_zsh_get_filter "$filter")"
  local line name value
  local -a matches
  while IFS= read -r line; do
    name="${line%%=*}"
    [[ "${(L)name}" == *"$filter"* ]] || continue
    matches+=("$line")
  done < <(ii_zsh_tmux_variable_lines)
  (( ${#matches} )) || {
    print -u2 'no matched'
    return 1
  }
  if (( ${#matches} == 1 )); then
    line="$matches[1]"
  else
    local selected
    selected="$(for line in "$matches[@]"; do
      name="${line%%=*}"
      value="${line#*=}"
      print -r -- "${name#ii_}\t${value}\t${line}"
    done | fzf -i --no-sort)" || return 1
    [[ -n "$selected" ]] || return 1
    line="${selected##*$'\t'}"
  fi
  value="${line#*=}"
  if ii_zsh_clip_copy "$value"; then
    print -r -- 'value copied successfully'
  else
    print -r -- 'value selected; clipboard copy failed'
  fi
  print
  print -r -- "$value"
}
