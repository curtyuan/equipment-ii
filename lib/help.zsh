# Top-level help command. Topic routing is provided by help_registry.zsh.

ii_cmd_help() {
  if [[ $# -gt 0 ]]; then
    ii_help_dispatch "$@"
    return $?
  fi

  cat <<'EOF'
usage: ii COMMAND [ARGS]

Aliases:
  h, -h, --help

Help:
  ii help

Variables:
  set|s NAME=VALUE      Set a variable in tmux and this shell
  set|s NAME VALUE      Set one variable from CLI arguments
  s:NAME=VALUE[,NAME=VALUE...]
                          Set one or more variables with "="
  set|s NAME[,NAME...] --from-shell
                          Save current shell variables back to tmux
  set|s --from-shell -a  Save all non-empty default shell variables
  set|s -d [IFACE]       Detect lhost from an interface, default tun0
  set|s rhost=VALUE      Set rhost and auto-detect lhost when enabled
  sr VALUE               Set rhost and trigger the same lhost auto-detection
  get|g FILTER           Copy and print one tmux variable value
  g:FILTER               Shortcut form of ii g FILTER
  load|l                 Load variables into this shell
  sync [on|off|status]   Control optional tmux-to-shell prompt auto-sync
  interactive|i          Select, edit, add, and copy variables
  ls [PATTERN]           List non-empty variables, optionally filtered by key
  v --out [PATH]         Write non-empty variables to .env or PATH
  voc [PATH]             Alias for ii v --out
  unset|u NAME [...]     Remove ii_ variables
  unset|u -a             Prompt, then remove all ii_ variables

Payloads:
  payload|p [CATEGORY]   Select, render, print, and optionally write a payload
  payload|p KEYWORD ...  Fuzzy-search using all keyword arguments
  pc KEYWORD ...         Copy the best payload match without opening the UI
  pe [KEYWORD ...]       Select, confirm, and execute without copying
  pce [KEYWORD ...]      Select, confirm, copy, and execute in this shell
  payload|p --input      Render input; optionally copy, execute, or write it
  pic [-o [PATH]]        Alias for ii p --input --copy
  pice                    Input, render, confirm, copy, and execute
  payload|p --www        Render a file, list, search, or symlink under /www

Clipboard:
  clip backend           Show or set clipboard backend
  clip doctor            Diagnose clipboard backend behavior

Tmux integration:
  tmux enable            Enable Prefix+: ii pice for this session
  tmux status            Inspect the tmux dispatcher state
  tmux disable           Disable it and restore : when no session uses it

Other:
  version                Show installed version
  help|h [COMMAND]       Show help
EOF
}

ii_cmd_help_topic() {
  ii_cmd_help
}

ii_help_register help ii_cmd_help_topic h -h --help
