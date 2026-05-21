# jj zsh plugin entrypoint.

local jj_plugin_dir
jj_plugin_dir="${${(%):-%x}:A:h}"

typeset -g JJ_PLUGIN_DIR="${JJ_PLUGIN_DIR:-$jj_plugin_dir}"
typeset -g JJ_PAYLOAD_DIR="${JJ_PAYLOAD_DIR:-${JJ_PLUGIN_DIR}/payloads}"

source "${jj_plugin_dir}/lib/tmux.zsh"
source "${jj_plugin_dir}/lib/clipboard.zsh"
source "${jj_plugin_dir}/lib/vars.zsh"
source "${jj_plugin_dir}/lib/payloads.zsh"
source "${jj_plugin_dir}/lib/help.zsh"
source "${jj_plugin_dir}/lib/core.zsh"

unset jj_plugin_dir
