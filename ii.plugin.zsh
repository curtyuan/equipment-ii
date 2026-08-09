# Zsh public runtime with a Go combo-workflow helper.

local ii_adapter_dir
ii_adapter_dir="${${(%):-%x}:A:h}"

typeset -g II_GO_ROOT="${II_GO_ROOT:-$ii_adapter_dir}"
if [[ -z "${II_GO_BIN:-}" ]]; then
  if [[ -x "${II_GO_ROOT}/ii-go" ]]; then
    typeset -g II_GO_BIN="${II_GO_ROOT}/ii-go"
  else
    typeset -g II_GO_BIN="${II_GO_ROOT}/build/ii-go"
  fi
fi
typeset -g II_PLUGIN_DIR="$II_GO_ROOT"
typeset -g II_PAYLOAD_DIR="${II_PAYLOAD_DIR:-${II_GO_ROOT}/payloads}"
typeset -g II_CONFIG_FILE="${II_CONFIG_FILE:-${HOME}/.config/ii/ii.conf}"
[[ -r "$II_CONFIG_FILE" ]] && source "$II_CONFIG_FILE"

unset ii_adapter_dir

source "${II_GO_ROOT}/lib/ordinary_variables.zsh"
source "${II_GO_ROOT}/lib/ordinary_read.zsh"
source "${II_GO_ROOT}/lib/ordinary_clipboard.zsh"
source "${II_GO_ROOT}/lib/ordinary_get.zsh"
source "${II_GO_ROOT}/lib/ordinary_interactive.zsh"
source "${II_GO_ROOT}/lib/ordinary_payload_render.zsh"
source "${II_GO_ROOT}/lib/ordinary_payload.zsh"
source "${II_GO_ROOT}/lib/ordinary_web.zsh"
source "${II_GO_ROOT}/lib/ordinary_tmux.zsh"
source "${II_GO_ROOT}/lib/ordinary_help.zsh"
source "${II_GO_ROOT}/lib/ordinary_runtime.zsh"

ii_zsh_tmux_ensure || true
