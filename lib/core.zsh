# ii command dispatcher.

ii() {
  local cmd="${1:-help}"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "$cmd" in
    set|s) ii_cmd_set "$@" ;;
    s:*) ii_cmd_set "${cmd#s:}" "$@" ;;
    load|l) ii_cmd_load "$@" ;;
    interactive|i) ii_cmd_interactive "$@" ;;
    ls|list|variable|vars|var|v) ii_cmd_list "$@" ;;
    payload|p) ii_cmd_payload "$@" ;;
    unset|u) ii_cmd_unset "$@" ;;
    help|h|-h|--help) ii_cmd_help "$@" ;;
    *) print -u2 "ii: unknown command: $cmd"; ii_cmd_help; return 2 ;;
  esac
}
