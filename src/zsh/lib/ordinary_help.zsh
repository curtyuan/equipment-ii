# Zsh-owned public help, version, and unknown-command presentation.

ii_zsh_help_file() {
  print -r -- "${II_ROOT}/help/$1.txt"
}

ii_zsh_help_print() {
  local topic="$1" file line content aliases suffix in_aliases=0
  file="$(ii_zsh_help_file "$topic")"
  [[ -r "$file" ]] || { print -u2 -- "ii: help topic unavailable: $topic"; return 1; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == Aliases: ]]; then
      in_aliases=1
      print -r -- "$line"
      continue
    fi
    if (( in_aliases )) && [[ -z "$line" ]]; then
      in_aliases=0
    fi
    if (( in_aliases )) && [[ "$line" == '  '* && "${line#  }" != none ]] && ii_zsh_color_enabled; then
      content="${line#  }"
      aliases="$content"
      suffix=''
      if [[ "$content" == *'    '* ]]; then
        aliases="${content%%    *}"
        suffix="${content#"$aliases"}"
      elif [[ "$content" == *' ('* ]]; then
        aliases="${content%% \(*}"
        suffix="${content#"$aliases"}"
      fi
      print -r -- '  '$'\e[36m'"$aliases"$'\e[0m'"$suffix"
    else
      print -r -- "$line"
    fi
  done <"$file"
}

ii_zsh_help_topic() {
  local -a args=("$@")
  local joined=" ${(j: :)args} " first_arg="${args[1]:-}" topic=top
  case "$first_arg" in
    version|-v|--version) topic=version ;;
    ls|list|variable|vars|var) topic=list ;;
    v) [[ " $joined " == *' --out '* ]] && topic=output || topic=variable ;;
    vo|voc|variables-output) topic=output ;;
    set|s|sr|sf|sha) topic=set ;;
    unset|u) topic=unset ;;
    load|l|la) topic=load ;;
    get|g|gr|gl) topic=get ;;
    interactive|i) topic=interactive ;;
    clip|clipboard) topic=clipboard ;;
    tmux) topic=tmux ;;
    pc|payload-copy) topic=payload-copy ;;
    pe) topic=payload-execute ;;
    pce) topic=payload-copy-execute ;;
    pic) topic=payload-input-copy ;;
    pie) topic=payload-input-execute ;;
    pice) topic=payload-input-copy-execute ;;
    payload-input) topic=payload-input ;;
    payload|p)
      if [[ "$joined" == *' --input '* || "$joined" == *' input '* ]]; then
        if [[ "$joined" == *' --copy '* && "$joined" == *' --execute '* ]]; then topic=payload-input-copy-execute
        elif [[ "$joined" == *' --execute '* ]]; then topic=payload-input-execute
        elif [[ "$joined" == *' --copy '* ]]; then topic=payload-input-copy
        else topic=payload-input
        fi
      elif [[ "$joined" == *' --copy '* && "$joined" == *' --execute '* ]]; then topic=payload-copy-execute
      elif [[ "$joined" == *' --execute '* ]]; then topic=payload-execute
      elif [[ "$joined" == *' --copy '* ]]; then topic=payload-copy
      else topic=payload
      fi
      ;;
  esac
  print -r -- "$topic"
}

ii_zsh_cmd_help() {
  local command="${1:-}"
  shift 2>/dev/null || true
  if [[ "$command" == (version|-v|--version) && " $* " != *' -h '* && " $* " != *' --help '* ]]; then
    print -r -- "ii $(<"${II_ROOT}/VERSION")"
    return
  fi
  local -a topic_args
  if [[ "$command" == (help|h|-h|--help) ]]; then topic_args=("$@")
  elif [[ -z "$command" ]]; then topic_args=()
  else topic_args=("$command" "$@")
  fi
  if [[ "$command" != (help|h|-h|--help|version|-v|--version|'') && " $* " != *' -h '* && " $* " != *' --help '* ]]; then
    print -u2 -- "ii: unknown command: $command"
    ii_zsh_help_print top
    return 2
  fi
  ii_zsh_help_print "$(ii_zsh_help_topic "$topic_args[@]")"
}
