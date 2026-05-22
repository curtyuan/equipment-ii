# ii zsh plugin entrypoint.

local ii_plugin_dir
ii_plugin_dir="${${(%):-%x}:A:h}"

typeset -g JJ_PLUGIN_DIR="${JJ_PLUGIN_DIR:-$ii_plugin_dir}"
typeset -g JJ_PAYLOAD_DIR="${JJ_PAYLOAD_DIR:-${JJ_PLUGIN_DIR}/payloads}"

source "${ii_plugin_dir}/lib/tmux.zsh"
source "${ii_plugin_dir}/lib/clipboard.zsh"
source "${ii_plugin_dir}/lib/vars.zsh"
source "${ii_plugin_dir}/lib/payloads.zsh"
source "${ii_plugin_dir}/lib/help.zsh"
source "${ii_plugin_dir}/lib/core.zsh"

unset ii_plugin_dir
