# Help command routing.

jj_cmd_help() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      set) jj_cmd_set --help ;;
      load) jj_cmd_load --help ;;
      interactive) jj_cmd_interactive --help ;;
      variable|vars|var) jj_cmd_variable --help ;;
      payload) jj_cmd_payload --help ;;
      unset) jj_cmd_unset --help ;;
      help) jj_cmd_help ;;
      *) print -u2 "jj: unknown help topic: $1"; return 2 ;;
    esac
    return
  fi

  cat <<'EOF'
usage: jj COMMAND [ARGS]

Commands:
  set NAME VALUE       Set a variable in tmux and this shell
  load                 Load variables into this shell
  interactive          Select variables with fzf and load them
  variable [PATTERN]   Print variables, optionally filtered by name
  payload [CATEGORY]   Select, render, copy, and print a payload
  unset NAME [...]     Remove JJ_ variables
  help [COMMAND]       Show help

Wrappers:
  jjs  jj set
  jjl  jj load
  jji  jj interactive
  jjv  jj variable
  jjp  jj payload
  jjh  jj help
EOF
}
