# Ordinary-command ownership and dispatch. Keep this table independent from
# combo parsing: a selected # flow: 1 payload is the only path into Go's
# workflow runtime once the ownership migration is complete.

typeset -gA II_ORDINARY_COMMAND_SPEC=(
  set-explicit ii_zsh_cmd_set_explicit
)

ii_ordinary_resolve() {
  local command="${1:-}"
  shift 2>/dev/null || true

  case "$command" in
    sr)
      [[ "$*" != *" -h"* && "$*" != *" --help"* ]] && print -r -- set-explicit
      ;;
    s:*)
      [[ " $* " != *" --from-shell "* && " $* " != *" --from-file "* &&
        " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- set-explicit
      ;;
    set|s)
      [[ $# -gt 0 && " $* " != *" --from-shell "* &&
        " $* " != *" --from-file "* && " $* " != *" -h "* &&
        " $* " != *" --help "* ]] && print -r -- set-explicit
      ;;
  esac
  return 0
}

ii() {
  local capability
  capability="$(ii_ordinary_resolve "$@")" || return
  if [[ -n "$capability" ]]; then
    "${II_ORDINARY_COMMAND_SPEC[$capability]}" "$@"
    return $?
  fi
  ii_go_command "$@"
}
