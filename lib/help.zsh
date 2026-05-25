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
      payload|p)
        case "${2:-}" in
          --input|input) ii_cmd_payload_input --help ;;
          *) ii_cmd_payload --help ;;
        esac
        ;;
      payload-input|input) ii_cmd_payload_input --help ;;
      unset|u) ii_cmd_unset --help ;;
      version|-v|--version) ii_cmd_version --help ;;
      help|h) ii_cmd_help ;;
      *) print -u2 "ii: unknown help topic: $1"; return 2 ;;
    esac
    return
  fi

  cat <<'EOF'
usage: ii COMMAND [ARGS]

Variables:
  set|s NAME VALUE       Set a variable in tmux and this shell
  set|s -d [IFACE]       Detect lhost from an interface, default tun0
  set|s [FILTER]         Select a variable and set its value
  s:FILTER               Shortcut form of ii s FILTER
  get|g FILTER           Copy and print one tmux variable value
  g:FILTER               Shortcut form of ii g FILTER
  load|l                 Load variables into this shell
  interactive|i          Select, edit, add, and copy variables
  ls [PATTERN]           List non-empty variables, optionally filtered by key
  unset|u NAME [...]     Remove ii_ variables
  unset|u -a             Prompt, then remove all ii_ variables

Payloads:
  payload|p [CATEGORY]   Select, render, print, and optionally write a payload
  payload|p --input      Render pasted input, optionally with --copy or -o
  payload|p -www         List, search, or symlink files under /www

Clipboard:
  clip backend           Show or set clipboard backend
  clip doctor            Diagnose clipboard backend behavior

Other:
  version                Show installed version
  help|h [COMMAND]       Show help
EOF
}
