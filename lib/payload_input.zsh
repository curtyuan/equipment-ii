# Pasted payload input command, stream protocol, and interactive ZLE editor.

ii_cmd_payload_input() {
  local copy=0 execute=0 output=0 output_spec=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --copy) copy=1 ;;
      --execute) execute=1 ;;
      -o|--output)
        output=1
        shift
        if [[ $# -gt 0 && "${1:-}" != -* ]]; then
          output_spec="$1"
        else
          continue
        fi
        ;;
      --help|-h)
        cat <<'EOF'
usage: ii p --input [--copy] [--execute] [-o [PATH]]
       ii payload --input [--copy] [--execute] [-o [PATH]]
       ii pic [-o [PATH]]
       ii pice

Aliases:
  pic
  pice

Help:
  ii help payload --input
  ii help payload-input
  ii help pic
  ii help pice

Paste template text below the prompt, then render variables and print the
rendered output. In an interactive terminal, Enter finishes and Ctrl-J inserts
a newline; a bottom status line keeps these keys visible. Cancel by entering
`:q` or `:q!` as the complete buffer.

For piped input, finish with a single ":w" line and cancel with a single ":q" or
":q!" line.

Supported input placeholders:
  %name%      replace lowercase name
  $name       replace lowercase name
  ${name}     replace lowercase name
  ${name:t}   replace lowercase name with its trailing path component
Uppercase variables, legacy II_NAME forms, and PowerShell scope variables such
as $env:, $script:, $global:, $local:, and $private: are left unchanged.

Shell values win over ii tmux values. Missing values keep the original token and
are reported in red.

With --execute, ii shows the rendered input and asks [y/N] before executing it
in the current shell. With --copy --execute or pice, a confirmed payload is
copied before execution. Clipboard failure is reported but does not prevent
execution. pice accepts no positional arguments.

-o writes the rendered text to a file while keeping the normal terminal output.
With no PATH, output goes to /www/p/att.txt. A bare filename writes to
/www/FILENAME. Directory paths use att.txt. After rendering, ii prints the
output file note and ends with the absolute output path on its own line.
EOF
        return 0
        ;;
      *)
        print -u2 "ii: unknown payload input option: $1"
        return 2
        ;;
    esac
    shift
  done

  ii_tmux_available || return

  local input rendered report
  typeset -g II_PAYLOAD_OUTPUT_PATH=""
  input="$(ii_payload_read_input)" || return
  ii_payload_render_text "$input" >/dev/null || return
  rendered="$II_PAYLOAD_RENDERED_TEXT"
  report="$(ii_payload_render_report)"

  if (( output )); then
    ii_payload_write_output "$rendered" "$output_spec" || return
  fi

  if (( copy && ! execute )); then
    if ii_clip_copy "$rendered"; then
      print "payload copied successfully"
    else
      print "payload rendered; clipboard copy failed"
    fi
    print
  fi

  [[ -n "$report" ]] && print -r -- "$report" && print
  ii_payload_print_separator
  print -r -- "$rendered"
  ii_payload_print_output_report

  if (( execute )); then
    if ! ii_payload_confirm_execute "$rendered"; then
      print -u2 "ii: execution cancelled"
      return 1
    fi
    if (( copy )); then
      if ii_clip_copy "$rendered"; then
        print "payload copied successfully"
      else
        print -u2 "ii: clipboard copy failed; executing payload anyway"
      fi
    fi
    eval "$rendered"
    return $?
  fi
}

ii_cmd_payload_input_copy_execute() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    ii_cmd_payload_input_copy_execute_help --help
    return
  fi
  if [[ $# -ne 0 ]]; then
    print -u2 "ii: usage: ii pice"
    return 2
  fi
  ii_cmd_payload_input --copy --execute
}

ii_cmd_payload_input_copy_execute_help() {
  cat <<'EOF'
usage: ii payload --input --copy --execute
       ii p --input --copy --execute
       ii pice

Aliases:
  pice

Help:
  ii help payload --input --copy --execute
  ii help pice

Read payload text from interactive or piped input, render lowercase variables,
show the rendered result and unresolved-variable report, and ask [y/N]. After
y, ii copies the rendered payload and executes it in the current shell.
Clipboard failure is reported but does not prevent confirmed execution.

Interactive input uses Enter to finish, Ctrl-J for a newline, and :q or :q! as
the complete buffer to cancel. Piped input ends at EOF or a standalone :w line.
pice accepts no options or positional arguments.

The tmux Prefix+: dispatcher has a separate popup path documented by
`ii help tmux`; only the exact `ii pice` command is accepted there.
EOF
}

ii_payload_read_input() {
  if [[ -t 0 ]]; then
    ii_payload_read_input_interactive
    return $?
  fi

  ii_payload_read_input_stream
}

ii_payload_read_input_interactive() {
  local input=""

  ii_payload_input_zle_setup || return
  if ! vared -M ii-input -i ii_payload_input_zle_init -p 'ii input> ' input; then
    print -u2 "ii: input cancelled"
    return 1
  fi

  if ii_payload_input_is_cancel_line "$input"; then
    print -u2 "ii: input cancelled"
    return 1
  fi
  input="$(ii_payload_input_strip_finish_line "$input")"
  print -rn -- "$input"
}

ii_payload_input_zle_setup() {
  if (( ! $+widgets[ii_payload_input_newline] )); then
    zle -N ii_payload_input_newline
  fi
  if (( ! $+widgets[ii_payload_input_zle_init] )); then
    zle -N ii_payload_input_zle_init
  fi
  if [[ -z "${keymaps[ii-input]-}" ]]; then
    bindkey -N ii-input emacs
  fi
  bindkey -M ii-input '^J' ii_payload_input_newline
  bindkey -M ii-input '^M' accept-line
}

ii_payload_input_newline() {
  LBUFFER+=$'\n'
  zle redisplay
}

ii_payload_input_zle_init() {
  POSTDISPLAY=$'\nEnter Finish    Ctrl-J New line    :q Cancel'
  zle redisplay
}

ii_payload_input_strip_finish_line() {
  local input="$1"
  if [[ "$input" == ":w" ]]; then
    print -rn -- ""
  elif [[ "$input" == *$'\n:w' ]]; then
    print -rn -- "${input%$'\n:w'}"
  else
    print -rn -- "$input"
  fi
}

ii_payload_read_input_stream() {
  local input line

  while true; do
    IFS= read -r line || break
    ii_payload_input_is_finish_line "$line" && break
    if ii_payload_input_is_cancel_line "$line"; then
      print -u2 "ii: input cancelled"
      return 1
    fi
    input+="${line}"$'\n'
  done

  print -rn -- "$input"
}

ii_payload_input_is_finish_line() {
  [[ "$1" == ":w" ]]
}

ii_payload_input_is_cancel_line() {
  [[ "$1" == ":q" || "$1" == ":q!" ]]
}

ii_help_register payload-input ii_cmd_payload_input input pic \
  "payload --input" "payload input" "p --input" "p input"
ii_help_register payload-input-copy-execute ii_cmd_payload_input_copy_execute_help pice \
  "payload --input --copy --execute" "p --input --copy --execute"
