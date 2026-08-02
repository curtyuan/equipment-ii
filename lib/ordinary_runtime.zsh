# Ordinary-command ownership and dispatch. Keep this table independent from
# combo parsing: a selected # flow: 1 payload is the only path into Go's
# workflow runtime once the ownership migration is complete.

typeset -gA II_ORDINARY_COMMAND_SPEC=(
  set-explicit ii_zsh_cmd_set_explicit
  load-current ii_zsh_cmd_load
  load-all-panes ii_zsh_cmd_load_all_panes
  unset-variable ii_zsh_cmd_unset
  variable-list ii_zsh_cmd_list
  variable-output ii_zsh_cmd_output
  variable-get ii_zsh_cmd_get
  clipboard ii_zsh_cmd_clip
  variable-interactive ii_zsh_cmd_interactive
  payload-select ii_zsh_cmd_payload
  payload-input ii_zsh_cmd_payload_input
  tmux-integration ii_zsh_cmd_tmux
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
      if [[ $# -eq 0 ]]; then
        print -r -- load-current
      elif [[ $# -eq 1 && "$1" == --all-pane ]]; then
        print -r -- load-all-panes
      fi
      ;;
    la)
      [[ $# -eq 0 ]] && print -r -- load-all-panes
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
    pc|pe|pce)
      [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- payload-select
      ;;
    payload|p)
      if [[ " $* " != *" -h "* && " $* " != *" --help "* &&
            " $* " != *" --www "* && " $* " != *" www "* &&
            " $* " != *" -w "* ]]; then
        if [[ " $* " == *" --input "* || " $* " == *" input "* ]]; then
          print -r -- payload-input
        else
          print -r -- payload-select
        fi
      fi
      ;;
    pic|pie|pice)
      [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- payload-input
      ;;
    tmux)
      [[ " $* " != *" -h "* && " $* " != *" --help "* ]] && print -r -- tmux-integration
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
