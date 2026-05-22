# Help command routing.

ii_cmd_help() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      set|s) ii_cmd_set --help ;;
      load|l) ii_cmd_load --help ;;
      interactive|i) ii_cmd_interactive --help ;;
      variable|vars|var|v) ii_cmd_variable --help ;;
      payload|p) ii_cmd_payload --help ;;
      unset|u) ii_cmd_unset --help ;;
      help|h) ii_cmd_help ;;
      *) print -u2 "ii: unknown help topic: $1"; return 2 ;;
    esac
    return
  fi

  cat <<'EOF'
usage: ii COMMAND [ARGS]

Commands:
  set|s NAME VALUE       Set a variable in tmux and this shell
  load|l                 Load variables into this shell
  interactive|i          Select variables with fzf and copy values
  variable|v [PATTERN]   Print variables, optionally filtered by name
  payload|p [CATEGORY]   Select, render, copy, and print a payload
  unset|u NAME [...]     Remove JJ_ variables
  help|h [COMMAND]       Show help
EOF
}
