# Help command routing.

ii_help_topics() {
  print -r -- help
  print -r -- set
  print -r -- get
  print -r -- clip
  print -r -- load
  print -r -- interactive
  print -r -- ls
  print -r -- payload
  print -r -- payload-input
  print -r -- payload-www
  print -r -- payload-www-file
  print -r -- unset
  print -r -- version
}

ii_help_dispatch() {
  case "$1" in
    set|s) ii_cmd_set --help ;;
    get|g) ii_cmd_get --help ;;
    clip|clipboard) ii_cmd_clip --help ;;
    load|l) ii_cmd_load --help ;;
    interactive|i) ii_cmd_interactive --help ;;
    ls|list|variable|vars|var|v) ii_cmd_list --help ;;
    payload|p)
      case "${2:-}" in
        --input|input) ii_cmd_payload_input --help ;;
        --www|www)
          case "${3:-}" in
            --file|file) ii_cmd_payload_www_file --help ;;
            "") ii_cmd_payload_www --help ;;
            *) ii_cmd_payload_www --help ;;
          esac
          ;;
        -www|-wwww) print -u2 "ii: use --www instead of ${2:-}"; return 2 ;;
        *) ii_cmd_payload --help ;;
      esac
      ;;
    payload-input|input) ii_cmd_payload_input --help ;;
    payload-www) ii_cmd_payload_www --help ;;
    payload-www-file) ii_cmd_payload_www_file --help ;;
    unset|u) ii_cmd_unset --help ;;
    version|-v|--version) ii_cmd_version --help ;;
    help|h) ii_cmd_help ;;
    *) print -u2 "ii: unknown help topic: $1"; return 2 ;;
  esac
}

ii_cmd_help() {
  if [[ $# -gt 0 ]]; then
    ii_help_dispatch "$@"
    return $?
  fi

  cat <<'EOF'
usage: ii COMMAND [ARGS]

Variables:
  set|s NAME=VALUE      Set a variable in tmux and this shell
  s:NAME=VALUE[,NAME=VALUE...]
                          Set one or more variables with "="
  set|s NAME[,NAME...] --from-shell
                          Save current shell variables back to tmux
  set|s -d [IFACE]       Detect lhost from an interface, default tun0
  set|s rhost=VALUE      Set rhost and auto-detect lhost when enabled
  set|s [FILTER]         Select a variable and set its value
  s:FILTER               Shortcut form of ii s FILTER
  get|g FILTER           Copy and print one tmux variable value
  g:FILTER               Shortcut form of ii g FILTER
  load|l                 Load variables into this shell
  interactive|i          Select, edit, add, and copy variables
  ls [PATTERN]           List non-empty variables, optionally filtered by key
  unset|u NAME [...]     Remove ii_ variables
  unset|u -a             Prompt, then remove all ii_ variables

Payloads:
  payload|p [CATEGORY]   Select, render, print, and optionally write a payload
  payload|p --input      Render pasted input, optionally with --copy or -o
  payload|p --www        Render a file, list, search, or symlink under /www

Clipboard:
  clip backend           Show or set clipboard backend
  clip doctor            Diagnose clipboard backend behavior

Other:
  version                Show installed version
  help|h [COMMAND]       Show help
EOF
}
