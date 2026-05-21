# jj command dispatcher and public wrappers.

jj() {
  local cmd="${1:-help}"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "$cmd" in
    set) jj_cmd_set "$@" ;;
    load) jj_cmd_load "$@" ;;
    interactive) jj_cmd_interactive "$@" ;;
    variable|vars|var) jj_cmd_variable "$@" ;;
    payload) jj_cmd_payload "$@" ;;
    unset) jj_cmd_unset "$@" ;;
    help|-h|--help) jj_cmd_help "$@" ;;
    *) print -u2 "jj: unknown command: $cmd"; jj_cmd_help; return 2 ;;
  esac
}

jjs() { jj set "$@" }
jjl() { jj load "$@" }
jji() { jj interactive "$@" }
jjv() { jj variable "$@" }
jjp() { jj payload "$@" }
jjh() { jj help "$@" }
