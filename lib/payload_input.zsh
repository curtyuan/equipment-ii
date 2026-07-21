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
        if (( copy && execute )); then
          ii_cmd_payload_input_copy_execute_help
          return 0
        fi
        if (( copy )); then
          ii_cmd_payload_input_copy_help
          return 0
        fi
        if (( execute )); then
          ii_cmd_payload_input_execute_help
          return 0
        fi
        cat <<'EOF'
usage: ii p --input [-o [PATH]]
       ii payload --input [-o [PATH]]
       ii p --input --copy [-o [PATH]]
       ii payload --input --copy [-o [PATH]]
       ii pic [-o [PATH]]
       ii p --input --execute [-o [PATH]]
       ii payload --input --execute [-o [PATH]]
       ii p --input --copy --execute [-o [PATH]]
       ii payload --input --copy --execute [-o [PATH]]
       ii pice

Aliases:
  none

Help:
  ii help payload --input
  ii help payload-input
  ii help payload --input --copy
  ii help pic
  ii help payload --input --execute
  ii help payload --input --copy --execute
  ii help pice

Related aliases:
  ii pic     ii payload --input --copy
  ii pice    ii payload --input --copy --execute

Paste template text below the prompt, then render variables and print the
rendered output. In an interactive terminal, Enter finishes, Alt+Enter inserts
a newline, and Esc cancels; a bottom status line keeps these keys visible.
Entering `:q` or `:q!` as the complete buffer also cancels.

For piped input, finish with a single ":w" line and cancel with a single ":q" or
":q!" line.

Input paths:
  ii p --input <<EOF       read and render a here-document
  COMMAND | ii p --input   read and render piped standard input
  ii pic <<EOF             read, render, and copy a here-document
  COMMAND | ii pic         read, render, and copy piped standard input

Non-interactive paths read the complete standard input through EOF. A standalone
:w may finish before EOF; standalone :q or :q! cancels.

Supported input placeholders:
  %name%      replace lowercase name
  $name       replace lowercase name
  ${name}     replace lowercase name
  ${name:t}   replace lowercase name with its trailing path component
Uppercase placeholders and PowerShell scope variables such as $env:, $script:,
$global:, $local:, and $private: are left unchanged.

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
  ii_payload_read_input || return
  input="$II_PAYLOAD_INPUT_TEXT"
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

ii_cmd_payload_input_copy_help() {
  cat <<'EOF'
usage: ii payload --input --copy [-o [PATH]]
       ii p --input --copy [-o [PATH]]
       ii pic [-o [PATH]]

Aliases:
  pic

Help:
  ii help payload --input --copy
  ii help pic

Read payload text, render lowercase variables, copy the complete rendered
result, and print it. In an interactive terminal, Enter finishes, Alt+Enter
inserts a newline, and Esc cancels.

Input paths:
  ii pic <<EOF     read a here-document until its EOF delimiter
  COMMAND | ii pic read piped standard input until EOF

Both non-interactive paths render and copy the complete standard input. A
standalone :w may finish before EOF; standalone :q or :q! cancels.

-o writes the rendered text to a file while preserving normal output and copy
behavior. With no PATH, output goes to /www/p/att.txt.
EOF
}

ii_cmd_payload_input_execute_help() {
  cat <<'EOF'
usage: ii payload --input --execute [-o [PATH]]
       ii p --input --execute [-o [PATH]]

Aliases:
  none

Help:
  ii help payload --input --execute

Read payload text, render lowercase variables, show the rendered result and
unresolved-variable report, and ask [y/N] before executing it in the current
shell. Nothing is copied.

Interactive input uses Enter to finish, Alt+Enter for a newline, and Esc to
cancel. Piped and here-document input reads through EOF; standalone :w may
finish early and standalone :q or :q! cancels.

-o writes the rendered text to a file before confirmation. With no PATH,
output goes to /www/p/att.txt.
EOF
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
usage: ii payload --input --copy --execute [-o [PATH]]
       ii p --input --copy --execute [-o [PATH]]
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

Interactive input uses Enter to finish, Alt+Enter for a newline, and Esc to
cancel. :q or :q! as the complete buffer also cancels. Piped input ends at EOF
or a standalone :w line. pice accepts no options or positional arguments.

Inside tmux, entering `ii pice` through tmux Prefix+: opens the popup form
described by `ii help tmux`. The adapter is installed automatically unless
II_TMUX_INTEGRATION=0 is configured.
EOF
}

ii_payload_read_input() {
  typeset -g II_PAYLOAD_INPUT_TEXT=""
  typeset -gi II_PAYLOAD_INPUT_CANCELLED=0
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
    return 130
  fi

  if (( II_PAYLOAD_INPUT_CANCELLED )); then
    print -u2 "ii: input cancelled"
    return 130
  fi

  if ii_payload_input_is_cancel_line "$input"; then
    print -u2 "ii: input cancelled"
    return 130
  fi
  input="$(ii_payload_input_strip_finish_line "$input")"
  typeset -g II_PAYLOAD_INPUT_TEXT="$input"
}

ii_payload_input_zle_setup() {
  zle -N ii_payload_input_newline
  zle -N ii_payload_input_cancel
  zle -N ii_payload_input_zle_init
  bindkey -N ii-input emacs
  bindkey -M ii-input '^J' ii_payload_input_newline
  bindkey -M ii-input '^M' accept-line
  bindkey -M ii-input $'\e\n' ii_payload_input_newline
  bindkey -M ii-input $'\e\r' ii_payload_input_newline
  bindkey -M ii-input '^[' ii_payload_input_cancel
}

ii_payload_input_newline() {
  LBUFFER+=$'\n'
  zle redisplay
}

ii_payload_input_cancel() {
  typeset -gi II_PAYLOAD_INPUT_CANCELLED=1
  zle accept-line
}

ii_payload_input_zle_init() {
  POSTDISPLAY=$'\nEnter Finish    Alt-Enter New line    Esc Cancel'
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
      return 130
    fi
    input+="${line}"$'\n'
  done

  typeset -g II_PAYLOAD_INPUT_TEXT="${input%$'\n'}"
}

ii_payload_input_is_finish_line() {
  [[ "$1" == ":w" ]]
}

ii_payload_input_is_cancel_line() {
  [[ "$1" == ":q" || "$1" == ":q!" ]]
}

ii_help_register payload-input ii_cmd_payload_input input \
  "payload --input" "payload input" "p --input" "p input"
ii_help_register payload-input-copy ii_cmd_payload_input_copy_help pic \
  "payload --input --copy" "p --input --copy"
ii_help_register payload-input-execute ii_cmd_payload_input_execute_help \
  "payload --input --execute" "p --input --execute"
ii_help_register payload-input-copy-execute ii_cmd_payload_input_copy_execute_help pice \
  "payload --input --copy --execute" "p --input --copy --execute"
