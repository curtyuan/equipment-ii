# ii zsh plugin entrypoint.

local ii_plugin_dir
ii_plugin_dir="${${(%):-%x}:A:h}"

typeset -g II_PLUGIN_DIR="${II_PLUGIN_DIR:-$ii_plugin_dir}"
typeset -g II_PAYLOAD_DIR="${II_PAYLOAD_DIR:-${II_PLUGIN_DIR}/payloads}"
typeset -g II_WWW_ROOT="${II_WWW_ROOT:-/www}"
typeset -g II_CONFIG_FILE="${II_CONFIG_FILE:-${HOME}/.config/ii/ii.conf}"

if [[ -r "$II_CONFIG_FILE" ]]; then
  source "$II_CONFIG_FILE"
fi

source "${ii_plugin_dir}/lib/tmux.zsh"
source "${ii_plugin_dir}/lib/help_registry.zsh"
source "${ii_plugin_dir}/lib/tmux_integration.zsh"
source "${ii_plugin_dir}/lib/clipboard.zsh"
source "${ii_plugin_dir}/lib/fzf.zsh"
source "${ii_plugin_dir}/lib/interact.zsh"
source "${ii_plugin_dir}/lib/var_helpers.zsh"
source "${ii_plugin_dir}/lib/var_interactive.zsh"
source "${ii_plugin_dir}/lib/vars.zsh"
source "${ii_plugin_dir}/lib/var_output.zsh"
source "${ii_plugin_dir}/lib/payloads.zsh"
source "${ii_plugin_dir}/lib/payload_input.zsh"
source "${ii_plugin_dir}/lib/www.zsh"
source "${ii_plugin_dir}/lib/payload_command.zsh"
source "${ii_plugin_dir}/lib/help.zsh"
source "${ii_plugin_dir}/lib/version.zsh"
if (( II_HELP_REGISTRY_ERROR )); then
  print -u2 "ii: plugin load aborted because help registration failed"
  unset ii_plugin_dir
  return 1
fi
source "${ii_plugin_dir}/lib/core.zsh"

unset ii_plugin_dir
