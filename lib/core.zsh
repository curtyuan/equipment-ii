# ii command dispatcher.

ii_dispatch() {
  local cmd="${1:-help}"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "$cmd" in
    set|s) ii_cmd_set "$@" ;;
    s:*) ii_cmd_set "${cmd#s:}" "$@" ;;
    sr) ii_cmd_set_rhost "$@" ;;
    sf) ii_cmd_set_from_file_alias "$@" ;;
    sha) ii_cmd_set_from_shell_all_alias "$@" ;;
    get|g) ii_cmd_get "$@" ;;
    gr) ii_cmd_get r "$@" ;;
    gl) ii_cmd_get l "$@" ;;
    g:*) ii_cmd_get "${cmd#g:}" "$@" ;;
    clip|clipboard) ii_cmd_clip "$@" ;;
    load|l) ii_cmd_load "$@" ;;
    la) ii_cmd_load --all-pane "$@" ;;
    sync) ii_cmd_sync "$@" ;;
    interactive|i) ii_cmd_interactive "$@" ;;
    ls|list|variable|vars|var) ii_cmd_list "$@" ;;
    v) ii_cmd_variable "$@" ;;
    vo|voc) ii_cmd_vars_output "$@" ;;
    payload|p) ii_cmd_payload "$@" ;;
    pc) ii_cmd_payload_copy "$@" ;;
    pe) ii_cmd_payload_execute "$@" ;;
    pce) ii_cmd_payload_execute --copy "$@" ;;
    pic) ii_cmd_payload_input --copy "$@" ;;
    pie) ii_cmd_payload_input_execute "$@" ;;
    pice) ii_cmd_payload_input_copy_execute "$@" ;;
    tmux) ii_cmd_tmux "$@" ;;
    unset|u) ii_cmd_unset "$@" ;;
    version|-v|--version) ii_cmd_version "$@" ;;
    help|h|-h|--help) ii_cmd_help "$@" ;;
    *) print -u2 "ii: unknown command: $cmd"; ii_cmd_help; return 2 ;;
  esac
}

ii() {
  local arg help_output=0
  if [[ $# -eq 0 || "${1:-}" == (help|h|-h|--help) ]]; then
    help_output=1
  else
    for arg in "$@"; do
      [[ "$arg" == "-h" || "$arg" == "--help" ]] && {
        help_output=1
        break
      }
    done
  fi

  if (( ! help_output )); then
    ii_dispatch "$@"
    return $?
  fi

  setopt local_options pipe_fail
  ii_dispatch "$@" | ii_help_color_aliases
  return $pipestatus[1]
}
