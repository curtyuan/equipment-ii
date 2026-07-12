# Public payload command facade and aggregate help.

ii_cmd_payload() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
usage: ii payload [CATEGORY]
       ii p [CATEGORY]
       ii p [CATEGORY] -o [PATH]
       ii p [KEYWORD ...]
       ii p --copy KEYWORD [KEYWORD ...]
       ii pc KEYWORD [KEYWORD ...]
       ii p --execute [KEYWORD ...]
       ii pe [KEYWORD ...]
       ii p --copy --execute [KEYWORD ...]
       ii pce [KEYWORD ...]
       ii p --www --file PATH
       ii p --www ln SOURCE_PATH [LINK_NAME]
       ii p --www ls
       ii p --www search [FILTER]
       ii p --input [--copy] [--execute] [-o [PATH]]
       ii pice

Aliases:
  p
  pc
  pe
  pce
  pice

Help:
  ii help payload
  ii help pc
  ii help pe
  ii help pce
  ii help pice

Payload files:
  Open the payload selector, render the selected template, and print the output.

  The selector shows payload paths in the list and a selected template preview
  at the bottom, with resolved renderable tokens highlighted green and missing
  tokens highlighted red.
  A first-line "# description: ..." metadata line is shown in preview but
  omitted from copied output.
  "# stage: ..." metadata lines are emitted as paste-safe "# --- ... ---"
  comment delimiters for combo payloads.
  The selector starts in normal mode. Press / to search; Esc returns to normal.
  Use y to copy the selected rendered payload and close the selector.
  Use --copy or pc with one or more keywords to skip the UI, render the best
  fzf match, and copy it immediately.
  Use e in normal mode to execute the selected rendered payload in the current
  shell. With --execute or pe, Enter confirms execution instead of printing.
  With --copy --execute or pce, confirmed execution also copies first. Execution
  is not isolated: shell variables, cwd, and other side effects persist.
  Use l to unfold the selected script into a full preview, and h to return to
  compact normal mode. In unfolded preview, j and k still move between
  payloads, Enter still renders and outputs, and q aborts.
  Payload files render lowercase %name%, $name, ${name}, and ${name:t}. Shell
  values win over ii tmux values. Uppercase variables and legacy II_NAME forms
  are left unchanged. Missing values keep their original token.

Pasted input:
  ii p --input [--copy] [--execute] [-o [PATH]]

  Paste template text below the prompt. In a terminal, Enter finishes, Ctrl-J
  inserts a newline, and a bottom status line keeps the keys visible. Piped
  input finishes with a single ":w" line. The renderer uses lowercase
  shell-style variables from this shell first and ii variables second. Use
  --copy to copy the rendered input to the clipboard.
  With --copy --execute or pice, ii confirms, copies, and executes the rendered
  input in the current shell. pice accepts no positional arguments.

Output:
  -o writes the rendered text to a file while keeping the normal terminal
  output. With no PATH, output goes to /www/p/att.txt. A bare filename writes
  to /www/FILENAME. Directory paths use att.txt. After rendering, ii prints the
  output file note and ends with the absolute output path on its own line.

/www helpers:
  ii p --www --file PATH
    Read PATH, render it with the normal payload renderer, print the render
    report and rendered output, then symlink PATH into /www/p and print
    relative_file, file, and rfile shell commands for manual copy.

  ii p --www ln SOURCE_PATH [LINK_NAME]
    Select a directory under /www and create a symlink to SOURCE_PATH there.

  ii p --www ls
    Print files and directories under /www as a tree.

  ii p --www search [FILTER]
    Fuzzy-select an entry under /www and print its containing directory relative
    to /www, then its absolute path. FILTER preselects the first
    case-insensitive fzf match.

Categories:
  all, shell, script, linux, windows, sqli, xss
EOF
    return 0
  fi

  local arg copy=0 execute=0 input=0
  for arg in "$@"; do
    [[ "$arg" == "--input" ]] && input=1
  done
  if (( input )); then
    local -a input_args
    input_args=()
    for arg in "$@"; do
      [[ "$arg" == "--input" ]] || input_args+=("$arg")
    done
    ii_cmd_payload_input "$input_args[@]"
    return
  fi

  while [[ "${1:-}" == "--copy" || "${1:-}" == "--execute" ]]; do
    [[ "$1" == "--copy" ]] && copy=1
    [[ "$1" == "--execute" ]] && execute=1
    shift
  done
  if (( execute )); then
      if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        ii_cmd_payload --help
      else
        local -a opts
        opts=(--execute)
        (( copy )) && opts+=(--copy)
        ii_cmd_payload_select "$opts[@]" "$@"
      fi
      return
  fi
  if (( copy )); then
      ii_cmd_payload_copy_best "$@"
      return
  fi
  case "${1:-}" in
    --www)
      shift
      ii_cmd_payload_www "$@"
      ;;
    -www|-wwww)
      print -u2 "ii: use --www instead of ${1:-}"
      return 2
      ;;
    *)
      ii_cmd_payload_select "$@"
      ;;
  esac
}

ii_cmd_payload_execute() {
  local -a opts
  opts=(--execute)
  if [[ "${1:-}" == "--copy" ]]; then
    opts+=(--copy)
    shift
  fi
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    if (( ${opts[(I)--copy]} )); then
      ii_cmd_payload_copy_execute_help --help
    else
      ii_cmd_payload_execute_help --help
    fi
    return
  fi
  ii_cmd_payload "$opts[@]" "$@"
}

ii_cmd_payload_execute_help() {
  cat <<'EOF'
usage: ii payload --execute [KEYWORD ...]
       ii p --execute [KEYWORD ...]
       ii pe [KEYWORD ...]

Aliases:
  pe

Help:
  ii help payload --execute
  ii help pe

Open the payload selector with all keywords joined as its initial query. Enter
renders the selected payload, shows unresolved lowercase variables when
present, and asks [y/N] before executing in the current shell. Nothing is
copied. Execution is not isolated: cwd, variables, functions, and other shell
side effects persist.
EOF
}

ii_cmd_payload_copy_execute_help() {
  cat <<'EOF'
usage: ii payload --copy --execute [KEYWORD ...]
       ii p --copy --execute [KEYWORD ...]
       ii pce [KEYWORD ...]

Aliases:
  pce

Help:
  ii help payload --copy --execute
  ii help pce

Open the payload selector with all keywords joined as its initial query. Enter
renders the selected payload, shows unresolved lowercase variables when
present, and asks [y/N]. After y, ii copies the rendered payload and executes
it in the current shell. Clipboard failure is reported but does not prevent
confirmed execution. The letter c in pce always means copy.
EOF
}

ii_cmd_payload_copy_best() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
usage: ii p --copy KEYWORD [KEYWORD ...]
       ii pc KEYWORD [KEYWORD ...]

Aliases:
  pc

Help:
  ii help payload-copy
  ii help pc

Join all keywords into one non-interactive fzf query, render the highest-ranked
payload match, copy it, print copy status and the render report, then exit.
No selector or confirmation prompt is opened.
EOF
    return 0
  fi
  if [[ $# -lt 1 ]]; then
    print -u2 "ii: usage: ii pc KEYWORD [KEYWORD ...]"
    return 2
  fi

  ii_tmux_available || return
  ii_require_cmd fzf || return

  local query="${(j: :)@}"
  local selected payload rendered report copy_status copy_rc
  selected="$(ii_payload_best_match "$query")" || {
    print -u2 "ii: no payload matched: $query"
    return 1
  }
  payload="$(ii_payload_path_for "$selected")" || return
  ii_payload_render "$payload" >/dev/null || return
  rendered="$II_PAYLOAD_RENDERED_TEXT"
  report="$(ii_payload_render_report)"

  if ii_clip_copy "$rendered"; then
    copy_rc=0
  else
    copy_rc=1
  fi
  copy_status="$(ii_interact_copy_status "$copy_rc" "payload copied successfully" "payload rendered; clipboard copy failed")"
  print -r -- "$copy_status"
  [[ -n "$report" ]] && print && ii_payload_print_report "$report" "$selected"
  return "$copy_rc"
}

ii_help_register payload ii_cmd_payload p
ii_help_register payload-execute ii_cmd_payload_execute_help pe \
  "payload --execute" "p --execute"
ii_help_register payload-copy-execute ii_cmd_payload_copy_execute_help pce \
  "payload --copy --execute" "payload --execute --copy" \
  "p --copy --execute" "p --execute --copy"
ii_help_register payload-copy ii_cmd_payload_copy_best pc "payload --copy" "p --copy"
