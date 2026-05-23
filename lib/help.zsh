# Help command routing.

ii_cmd_help() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      set|s) ii_cmd_set --help ;;
      get|g) ii_cmd_get --help ;;
      clip|clipboard) ii_cmd_clip --help ;;
      load|l) ii_cmd_load --help ;;
      interactive|i) ii_cmd_interactive --help ;;
      ls|list|variable|vars|var|v) ii_cmd_list --help ;;
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
  set|s -d [IFACE]       Detect LHOST from an interface, default tun0
  set|s [FILTER]         Select a variable and set its value
  s:FILTER               Shortcut form of ii s FILTER
  get|g FILTER           Print one tmux variable value
  g:FILTER               Shortcut form of ii g FILTER
  load|l                 Load variables into this shell
  clip backend           Show or set clipboard backend
  clip doctor            Diagnose clipboard backend behavior
  interactive|i          Select, edit, delete, add, and copy variables
  ls [PATTERN]           List non-empty variables, optionally filtered by key
  payload|p [CATEGORY]   Select, render, copy, and print a payload
  unset|u NAME [...]     Remove II_ variables
  unset|u -a             Prompt, then remove all II_ variables
  help|h [COMMAND]       Show help
EOF
}
