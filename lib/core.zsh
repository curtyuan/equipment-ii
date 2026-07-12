# ii command dispatcher.

ii() {
  local cmd="${1:-help}"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "$cmd" in
    set|s) ii_cmd_set "$@" ;;
    s:*) ii_cmd_set "${cmd#s:}" "$@" ;;
    sr) ii_cmd_set_rhost "$@" ;;
    get|g) ii_cmd_get "$@" ;;
    g:*) ii_cmd_get "${cmd#g:}" "$@" ;;
    clip|clipboard) ii_cmd_clip "$@" ;;
    load|l) ii_cmd_load "$@" ;;
    sync) ii_cmd_sync "$@" ;;
    interactive|i) ii_cmd_interactive "$@" ;;
    ls|list|variable|vars|var) ii_cmd_list "$@" ;;
    v) ii_cmd_variable "$@" ;;
    voc) ii_cmd_vars_output "$@" ;;
    payload|p) ii_cmd_payload "$@" ;;
    pc) ii_cmd_payload_copy_best "$@" ;;
    pe) ii_cmd_payload_execute "$@" ;;
    pce) ii_cmd_payload_execute --copy "$@" ;;
    pic) ii_cmd_payload_input --copy "$@" ;;
    pice) ii_cmd_payload_input_copy_execute "$@" ;;
    tmux) ii_cmd_tmux "$@" ;;
    unset|u) ii_cmd_unset "$@" ;;
    version|-v|--version) ii_cmd_version "$@" ;;
    help|h|-h|--help) ii_cmd_help "$@" ;;
    *) print -u2 "ii: unknown command: $cmd"; ii_cmd_help; return 2 ;;
  esac
}
