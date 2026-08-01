# Ordinary-command ownership and dispatch. Keep this table independent from
# combo parsing: a selected # flow: 1 payload is the only path into Go's
# workflow runtime once the ownership migration is complete.

typeset -gA II_ORDINARY_COMMAND_SPEC=(
  set-explicit ii_zsh_cmd_set_explicit
  load-current ii_zsh_cmd_load
  unset-variable ii_zsh_cmd_unset
  variable-list ii_zsh_cmd_list
  variable-output ii_zsh_cmd_output
  variable-get ii_zsh_cmd_get
  clipboard ii_zsh_cmd_clip
  variable-interactive ii_zsh_cmd_interactive
)

ii_ordinary_resolve() {
  local command="${1:-}"
  shift 2>/dev/null || true

  case "$command" in
    sr|sf|sha)
      [[ "$*" != *" -h"* && "$*" != *" --help"* ]] && print -r -- set-explicit
      ;;
    s:*)
      [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- set-explicit
      ;;
    set|s)
      [[ $# -gt 0 && " $* " != *" -h "* &&
        " $* " != *" --help "* ]] && print -r -- set-explicit
      ;;
    load|l)
      [[ $# -eq 0 ]] && print -r -- load-current
      ;;
    unset|u)
      [[ $# -gt 0 && " $* " != *" -h "* && " $* " != *" --help "* ]] &&
        print -r -- unset-variable
      ;;
    ls|list|variable|vars|var)
      [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- variable-list
      ;;
    v)
      if [[ "${1:-}" == --out ]]; then
        shift
        [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- variable-output
      elif [[ " $* " != *" -h "* && " $* " != *" --help "* ]]; then
        print -r -- variable-list
      fi
      ;;
    vo|voc)
      [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- variable-output
      ;;
    get|g|gr|gl|g:*)
      [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- variable-get
      ;;
    clip|clipboard)
      [[ " $* " != *" -h "* && " $* " != *" --help "* && " $* " != *" help "* ]] &&
        print -r -- clipboard
      ;;
    interactive|i)
      [[ $# -eq 0 ]] && print -r -- variable-interactive
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
