# Payload selection, filtering, rendering, and reporting.

ii_cmd_payload() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii payload [CATEGORY]
       ii p [CATEGORY]
       ii p [CATEGORY] -o [PATH]
       ii p --input [--copy] [-o [PATH]]

Payload files:
  Open the payload selector, render the selected template with fresh tmux
  variables, copy the result, and print the output.

  The selector shows a single-line rendered preview in the list and a full
  selected preview at the bottom. A first-line "# description: ..." metadata
  line is shown in preview but omitted from copied output.

Pasted input:
  ii p --input [--copy] [-o [PATH]]

  Paste template text below the prompt. Finish with a single "." line, or cancel
  with a single ":q" or ":q!" line. The renderer uses lowercase shell-style
  variables from this shell first and ii variables second. Use --copy to copy
  the rendered input to the clipboard.

Output:
  -o writes the rendered text to a file while keeping the normal terminal
  output. With no PATH, output goes to /www/p/att.txt. A bare filename writes
  to /www/FILENAME. Directory paths use att.txt. After rendering, ii prints the
  output file note and ends with the absolute output path on its own line.

Categories:
  all, shell, script, linux, windows, sqli, xss
EOF
    return 0
  fi

  if [[ "${1:-}" == "--input" ]]; then
    shift
    ii_cmd_payload_input "$@"
    return
  fi

  ii_tmux_available || return
  ii_require_cmd fzf || return

  local filter="all" output=0 output_spec=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output)
        output=1
        shift
        if [[ $# -gt 0 && "${1:-}" != -* ]]; then
          output_spec="$1"
          shift
        fi
        ;;
      *)
        if [[ "$filter" == "all" ]]; then
          filter="$1"
        else
          print -u2 "ii: unknown payload option: $1"
          return 2
        fi
        shift
        ;;
    esac
  done

  local payloads payload selected rendered
  typeset -g II_PAYLOAD_OUTPUT_PATH=""
  payloads="$(ii_payload_list)" || return
  if [[ -z "$payloads" ]]; then
    print -u2 "ii: no payloads found"
    return 1
  fi

  selected="$(print -r -- "$payloads" | ii_payload_filter "$filter" | ii_payload_entries_for_fzf | ii_payload_select_fzf "$filter" | awk -F '\t' 'NF {print $1; exit}')" || return
  [[ -n "$selected" ]] || return

  payload="$(ii_payload_path_for "$selected")" || return
  rendered="$(ii_payload_render "$payload")" || return

  if (( output )); then
    ii_payload_write_output "$rendered" "$output_spec"
  fi

  if ii_clip_copy "$rendered"; then
    print "payload copied successfully"
  else
    print "payload rendered; clipboard copy failed"
  fi

  print
  ii_payload_print_separator
  print -r -- "$rendered"
  print
  ii_payload_print_used_vars "$payload"
  ii_payload_print_output_report
}

ii_cmd_payload_input() {
  local copy=0 output=0 output_spec=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --copy) copy=1 ;;
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
usage: ii p --input [--copy] [-o [PATH]]

Paste template text below the prompt, then render lowercase variables and print
the rendered output.

Finish input with a single "." line. Cancel with a single ":q" or ":q!" line.

Supported input placeholders:
  $name       replace lowercase name
  ${name}     replace lowercase name
  ${name:t}   replace lowercase name with its trailing path component

Uppercase variables and PowerShell scope variables such as $env:, $script:,
$global:, $local:, and $private: are left unchanged.

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
  ii_payload_render_input_text "$input" >/dev/null || return
  rendered="$II_PAYLOAD_RENDERED_TEXT"
  report="$(ii_payload_input_report)"

  if (( output )); then
    ii_payload_write_output "$rendered" "$output_spec"
  fi

  if (( copy )); then
    if ii_clip_copy "$rendered"; then
      print "payload copied successfully"
    else
      print "payload rendered; clipboard copy failed"
    fi
    print
  fi

  ii_payload_print_separator
  print -r -- "$rendered"
  [[ -n "$report" ]] && print && print -r -- "$report"
  ii_payload_print_output_report
}

ii_payload_dir() {
  print -r -- "${II_PAYLOAD_DIR:-${HOME}/.config/ii/payloads}"
}

ii_payload_list() {
  local dir
  dir="$(ii_payload_dir)"
  if [[ ! -d "$dir" ]]; then
    print -u2 "ii: payload directory not found: $dir"
    print -u2 "ii: set II_PAYLOAD_DIR or create ~/.config/ii/payloads"
    return 1
  fi

  ( cd "$dir" && find . -type f ! -name '.*' | sed 's#^\./##' | sort )
}

ii_payload_filter() {
  local filter="${1:-all}"

  case "$filter" in
    all|"") cat ;;
    shell) awk '/^shell\//' ;;
    script) awk '/^script\//' ;;
    linux) awk '$0 ~ /(^|\/)linux(\/|$)/' ;;
    windows) awk '$0 ~ /(^|\/)windows(\/|$)/' ;;
    sqli) awk '/^sqli\//' ;;
    xss) awk '/^xss\//' ;;
    *) awk -v pat="$filter" 'index(tolower($0), tolower(pat)) > 0' ;;
  esac
}

ii_payload_select_fzf() {
  local filter="${1:-all}"
  local plugin_file payload_dir
  plugin_file="${II_PLUGIN_DIR%/}/ii.plugin.zsh"
  payload_dir="$(ii_payload_dir)"

  fzf --ansi --prompt="ii payload:${filter}> " --height=80% --border --delimiter=$'\t' --with-nth=1,2,3 \
    --bind='enter:accept' \
    --preview="zsh -fc 'source \"\$1\"; export II_PAYLOAD_DIR=\"\$2\"; ii_payload_preview_fzf \"\$3\" \$'\'' Enter Render/Copy     Type Filter\n Esc Abort'\''' -- ${(q)plugin_file} ${(q)payload_dir} {1}" \
    --preview-window='down:50%:nowrap:noinfo'
}

ii_payload_entries_for_fzf() {
  local selected payload rendered preview overflow
  while IFS= read -r selected; do
    [[ -n "$selected" ]] || continue
    payload="$(ii_payload_path_for "$selected")" || return
    rendered="$(ii_payload_render "$payload")" || return
    preview="$(ii_one_line_preview "$rendered" 96)"
    overflow=""
    [[ "$preview" != "$rendered" ]] && overflow=$'\033[31mmore\033[0m'
    print -r -- "$selected"$'\t'"$preview"$'\t'"$overflow"
  done
}

ii_payload_path_for() {
  local selected="$1"
  local dir
  dir="$(ii_payload_dir)"
  local payload_path="${dir%/}/${selected}"

  if [[ ! -f "$payload_path" ]]; then
    print -u2 "ii: payload not found: $selected"
    return 1
  fi

  print -r -- "$payload_path"
}

ii_payload_render() {
  local payload_path="$1"
  local rendered
  rendered="$(ii_payload_body "$payload_path")"

  local var name line value label fallback
  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    name="$(ii_var_name_from_payload_var "$var")" || return
    line="$(ii_var_lines_from_tmux | awk -F= -v name="$name" '$1 == name {print; exit}')"
    value="${line#*=}"
    if [[ -n "$line" && -n "$value" ]]; then
      fallback="$value"
    else
      label="${var#II_}"
      fallback="\$${(L)label}"
    fi
    rendered="${rendered//\$\{$var\}/$fallback}"
    rendered="${rendered//$var/$fallback}"
  done < <(ii_payload_required_vars "$payload_path")

  print -r -- "$rendered"
}

ii_payload_print_separator() {
  print -r -- "--------------------------------------------------------------------------------"
}

ii_payload_output_path() {
  local spec="${1:-}"
  local default_dir="/www/p"
  local default_file="att.txt"

  if [[ -z "$spec" ]]; then
    print -r -- "${default_dir}/${default_file}"
    return
  fi

  if [[ "$spec" == */ || -d "$spec" ]]; then
    print -r -- "${spec%/}/${default_file}"
    return
  fi

  if [[ "$spec" == /* ]]; then
    print -r -- "$spec"
    return
  fi

  if [[ "$spec" == ./* || "$spec" == ../* || "$spec" == */* ]]; then
    print -r -- "$spec"
    return
  fi

  print -r -- "/www/${spec}"
}

ii_payload_write_output() {
  local text="$1"
  local spec="$2"
  local output_path output_abs dir

  typeset -g II_PAYLOAD_OUTPUT_PATH=""

  output_path="$(ii_payload_output_path "$spec")" || return
  dir="${output_path:h}"
  if [[ -z "$dir" || "$dir" == "$output_path" ]]; then
    print -u2 "ii: invalid output path: $output_path"
    return 1
  fi

  if ! mkdir -p -- "$dir"; then
    print -u2 "ii: failed to create output directory: $dir"
    return 1
  fi
  if ! print -rn -- "$text" > "$output_path"; then
    print -u2 "ii: failed to write output file: $output_path"
    return 1
  fi
  output_abs="${output_path:a}"
  typeset -g II_PAYLOAD_OUTPUT_PATH="$output_abs"
}

ii_payload_print_output_report() {
  [[ -n "${II_PAYLOAD_OUTPUT_PATH:-}" ]] || return
  print
  print "payload output written to:"
  print -r -- "$II_PAYLOAD_OUTPUT_PATH"
}

ii_payload_read_input() {
  local input line

  if [[ -t 0 ]]; then
    ii_payload_print_input_intro
  fi

  while true; do
    if [[ -t 0 ]]; then
      ii_payload_print_input_prompt
    fi
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

ii_payload_print_input_intro() {
  print -u2 "paste content below"
  print -u2 'finish: single "." line OR ":q"/":q!" line -> cancel, don'\''t save'
}

ii_payload_print_input_prompt() {
  printf 'ii input> ' >&2
}

ii_payload_input_is_finish_line() {
  [[ "$1" == "." ]]
}

ii_payload_input_is_cancel_line() {
  [[ "$1" == ":q" || "$1" == ":q!" ]]
}

ii_payload_render_input_text() {
  local text="$1"
  local rendered="" length i ch next expr end name modifier value source token

  typeset -gA II_PAYLOAD_INPUT_REPORT_SOURCE=()
  typeset -gA II_PAYLOAD_INPUT_REPORT_VALUE=()
  typeset -g II_PAYLOAD_RENDERED_TEXT=""

  length="${#text}"
  i=1
  while (( i <= length )); do
    ch="${text[i]}"
    if [[ "$ch" != '$' ]]; then
      rendered+="$ch"
      (( i++ ))
      continue
    fi

    next="${text[i+1]}"
    if [[ "$next" == "{" ]]; then
      end=$(( i + 2 ))
      while (( end <= length )) && [[ "${text[end]}" != "}" ]]; do
        (( end++ ))
      done
      if (( end <= length )); then
        expr="${text[i+2,end-1]}"
        if [[ "$expr" =~ '^([a-z_][a-z0-9_]*)(:t)?$' ]]; then
          name="${match[1]}"
          modifier="${match[2]}"
          ii_payload_resolve_input_var "$name" "$modifier"
          value="$II_PAYLOAD_RESOLVED_VALUE"
          source="$II_PAYLOAD_RESOLVED_SOURCE"
          rendered+="$value"
          ii_payload_record_input_var "$name" "$source" "$value"
          i=$(( end + 1 ))
          continue
        fi
      fi
    elif [[ "$next" =~ '[A-Za-z_]' ]]; then
      end=$(( i + 1 ))
      while (( end <= length )) && [[ "${text[end]}" =~ '[A-Za-z0-9_]' ]]; do
        (( end++ ))
      done
      token="${text[i+1,end-1]}"
      if [[ "$token" =~ '^[a-z_][a-z0-9_]*$' ]]; then
        if [[ "${text[end]}" == ":" ]] && ii_payload_is_powershell_scope "$token"; then
          rendered+="${text[i,end]}"
          i=$(( end + 1 ))
          continue
        fi
        ii_payload_resolve_input_var "$token" ""
        value="$II_PAYLOAD_RESOLVED_VALUE"
        source="$II_PAYLOAD_RESOLVED_SOURCE"
        rendered+="$value"
        ii_payload_record_input_var "$token" "$source" "$value"
        i="$end"
        continue
      fi
    fi

    rendered+="$ch"
    (( i++ ))
  done

  typeset -g II_PAYLOAD_RENDERED_TEXT="$rendered"
  print -rn -- "$rendered"
}

ii_payload_is_powershell_scope() {
  case "$1" in
    env|script|global|local|private) return 0 ;;
    *) return 1 ;;
  esac
}

ii_payload_resolve_input_var() {
  local name="$1"
  local modifier="$2"
  local ii_name line value source

  if (( ${+parameters[$name]} )); then
    value="${(P)name}"
    source="shell"
  else
    ii_name="$(ii_var_normalize_name "$name")" || return
    if ii_tmux_available >/dev/null 2>&1; then
      line="$(ii_var_line_by_name "$ii_name")"
    else
      line=""
    fi
    if [[ -n "$line" ]]; then
      value="${line#*=}"
      source="ii"
    else
      value=""
      source="missing"
    fi
  fi

  if [[ "$modifier" == ":t" ]]; then
    value="${value:t}"
  fi

  typeset -g II_PAYLOAD_RESOLVED_VALUE="$value"
  typeset -g II_PAYLOAD_RESOLVED_SOURCE="$source"
}

ii_payload_record_input_var() {
  local name="$1"
  local source="$2"
  local value="$3"

  if [[ -z "${II_PAYLOAD_INPUT_REPORT_SOURCE[$name]:-}" || "${II_PAYLOAD_INPUT_REPORT_SOURCE[$name]}" == "missing" ]]; then
    II_PAYLOAD_INPUT_REPORT_SOURCE[$name]="$source"
    II_PAYLOAD_INPUT_REPORT_VALUE[$name]="$value"
  fi
}

ii_payload_input_report() {
  local name source value color reset
  reset=$'\033[0m'

  for name in ${(ok)II_PAYLOAD_INPUT_REPORT_SOURCE}; do
    source="${II_PAYLOAD_INPUT_REPORT_SOURCE[$name]}"
    value="${II_PAYLOAD_INPUT_REPORT_VALUE[$name]}"
    case "$source" in
      shell)
        color=$'\033[34m'
        print -r -- "${color}${name} used from shell: ${value}${reset}"
        ;;
      ii)
        print -r -- "${name} used from ii: ${value}"
        ;;
      missing)
        color=$'\033[31m'
        print -r -- "${color}${name} unresolved: rendered as empty${reset}"
        ;;
    esac
  done
}

ii_payload_preview() {
  local selected="$1"
  local payload description
  payload="$(ii_payload_path_for "$selected")" || return
  description="$(ii_payload_description "$payload")"
  if [[ -n "$description" ]]; then
    print -r -- "description: $description"
    print -r -- "--------------------------------------------------------------------------------"
  fi
  ii_payload_render "$payload"
}

ii_payload_preview_fzf() {
  local selected="$1"
  local footer="$2"
  local payload description
  payload="$(ii_payload_path_for "$selected")" || return
  description="$(ii_payload_description "$payload")"
  ii_payload_render "$payload" | ii_fzf_print_preview_blocks "$description" "$footer"
}

ii_payload_description() {
  local payload_path="$1"
  awk '
    NR == 1 && $0 ~ /^# description:[[:space:]]*/ {
      sub(/^# description:[[:space:]]*/, "")
      print
      exit
    }
  ' "$payload_path"
}

ii_payload_body() {
  local payload_path="$1"
  awk '
    NR == 1 && $0 ~ /^# description:[[:space:]]*/ { next }
    { print }
  ' "$payload_path"
}

ii_payload_required_vars() {
  local payload_path="$1"
  grep -Eoh '\$\{II_[A-Za-z_][A-Za-z0-9_]*\}|II_[A-Za-z_][A-Za-z0-9_]*' "$payload_path" \
    | sed -E 's/^\$\{//; s/\}$//' \
    | sort -u
}

ii_payload_print_used_vars() {
  local payload_path="$1"
  local var name line value label

  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    label="${var#II_}"
    name="$(ii_var_name_from_payload_var "$var")" || return
    line="$(ii_var_lines_from_tmux | awk -F= -v name="$name" '$1 == name {print; exit}')"
    value="${line#*=}"
    if [[ -z "$line" || -z "$value" ]]; then
      value="\$${(L)label}"
    fi
    print "${(L)label} used: ${value}"
  done < <(ii_payload_required_vars "$payload_path")
}
