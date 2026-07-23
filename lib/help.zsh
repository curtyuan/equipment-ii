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
  set|s --from-file [PATH]
                          Import variables from PATH, default .env
  set|s -d [IFACE]       Detect lhost from an interface, default tun0
  set|s rhost=VALUE      Set rhost and auto-detect lhost when enabled
  sr VALUE               Set rhost and trigger the same lhost auto-detection
  get|g FILTER           Copy and print one tmux variable value
  g:FILTER               Shortcut form of ii g FILTER
  gr                     Copy and print rhost (ii g r)
  gl                     Copy and print lhost (ii g l)
  load|l                 Load variables into this shell
  load --all-pane|la     Review panes, then load selected shells
  sync [on|off|status]   Control optional tmux-to-shell prompt auto-sync
  interactive|i          Select, edit, add, and copy variables
  ls|list|variable|vars|var [PATTERN]
                          List non-empty variables, optionally filtered by key
  v [PATTERN]            List variables; --out writes them to a file
  v --out [PATH]         Write non-empty variables to .env or PATH
  vo [PATH]              Alias for ii v --out
  voc [PATH]             Compatibility alias for ii v --out
  unset|u NAME [...]     Remove ii_ variables
  unset|u -a             Prompt, then remove all ii_ variables

Payloads:
  payload|p [CATEGORY]   Select, render, print, and optionally write a payload
  payload|p KEYWORD ...  Fuzzy-search using all keyword arguments
  payload|p --copy [KEYWORD ...] | pc [KEYWORD ...]
                          Review and copy a selection from an initial query
  payload|p --execute [KEYWORD ...] | pe [KEYWORD ...]
                          Select, confirm, and execute without copying
  payload|p --copy --execute [KEYWORD ...] | pce [KEYWORD ...]
                          Select, confirm, copy, and execute in this shell
  payload|p --input [-o [PATH]]
                          Render pasted or standard input
  payload|p --input --copy [-o [PATH]] | pic [-o [PATH]]
                          Render and copy input
  payload|p --input --execute [-o [PATH]]
                          Render, confirm, and execute input
  payload|p --input --copy --execute [-o [PATH]] | pice
                          Render, confirm, copy, and execute input
  payload|p --www        Render a file, list, search, or symlink under /www

Clipboard:
  clip|clipboard backend Show or set clipboard backend
  clip|clipboard doctor  Diagnose clipboard backend behavior

Tmux integration:
  tmux status            Diagnose the default Prefix+: ii pice integration

Other:
  version|-v|--version   Show installed version
  help|h|-h|--help [COMMAND]
                          Show help
EOF
}

ii_cmd_help_topic() {
  ii_cmd_help
}

ii_help_register help ii_cmd_help_topic h -h --help
