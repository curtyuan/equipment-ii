# Payload selection, filtering, rendering, and reporting.

ii_cmd_payload() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii payload [CATEGORY]
       ii p [CATEGORY]
       ii p [CATEGORY] -o [PATH]
       ii p -www ln SOURCE_PATH [LINK_NAME]
       ii p -www ls
       ii p -www search [FILTER]
       ii p --input [--copy] [-o [PATH]]

Payload files:
  Open the payload selector, render the selected template, and print the output.

  The selector shows a single-line template preview in the list and a full
  selected template preview at the bottom, with renderable tokens highlighted.
  A first-line "# description: ..." metadata line is shown in preview but
  omitted from copied output.
  Use y to copy the selected rendered payload without leaving the selector.
  Use l to unfold the selected script into a full preview, and h to
  return to the searchable selector. In unfolded preview, j and k still move
  between payloads, Enter still renders and outputs, q aborts, and filtering is
  disabled until returning.
  Payload files render ${II_NAME}, bare II_NAME, $name, ${name}, and ${name:t}.
  Shell values win over ii tmux values. Uppercase shell variables such as $RHOST
  are left unchanged. Missing values keep their original token.

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

/www helpers:
  ii p -www ln SOURCE_PATH [LINK_NAME]
    Select a directory under /www and create a symlink to SOURCE_PATH there.

  ii p -www ls
    Print files and directories under /www as a tree.

  ii p -www search [FILTER]
    Fuzzy-select an entry under /www and print its path relative to /www, then
    its absolute path. FILTER preselects the first case-insensitive fzf match.

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

  if [[ "${1:-}" == "-www" ]]; then
    shift
    ii_cmd_payload_www "$@"
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

  local payloads payload selected key line rendered report last_yank_selected last_yank_report last_yank_count footer_status copy_rc
  typeset -g II_PAYLOAD_OUTPUT_PATH=""
  last_yank_selected=""
  last_yank_report=""
  last_yank_count=0
  footer_status=""
  payloads="$(ii_payload_list)" || return
  if [[ -z "$payloads" ]]; then
    print -u2 "ii: no payloads found"
    return 1
  fi

  while true; do
    if ! selected="$(print -r -- "$payloads" | ii_payload_filter "$filter" | ii_payload_entries_for_fzf | ii_payload_select_fzf "$filter" "$footer_status")"; then
      [[ $last_yank_count -gt 0 && -n "$last_yank_report" ]] && print && print -r -- "$last_yank_report"
      return
    fi
    if [[ -z "$selected" ]]; then
      [[ $last_yank_count -gt 0 && -n "$last_yank_report" ]] && print && print -r -- "$last_yank_report"
      return
    fi

    key="${selected%%$'\n'*}"
    if [[ "$key" == "enter" || "$key" == "y" || "$key" == "q" ]]; then
      line="${selected#*$'\n'}"
    else
      key="enter"
      line="${selected%%$'\n'*}"
    fi
    [[ -n "${II_PAYLOAD_KEY:-}" ]] && key="$II_PAYLOAD_KEY"
    selected="$(print -r -- "$line" | awk -F '\t' 'NF {print $1; exit}')"
    [[ -n "$selected" ]] || return

    if [[ "$key" == "q" ]]; then
      [[ $last_yank_count -gt 0 && -n "$last_yank_report" ]] && print && print -r -- "$last_yank_report"
      return
    fi

    payload="$(ii_payload_path_for "$selected")" || return
    ii_payload_render "$payload" >/dev/null || return
    rendered="$II_PAYLOAD_RENDERED_TEXT"

    if [[ "$key" == "y" ]]; then
      report="$(ii_payload_render_report)"
      if ii_clip_copy "$rendered"; then
        copy_rc=0
      else
        copy_rc=1
      fi
      footer_status="$(ii_interact_copy_status "$copy_rc" "payload copied successfully" "payload rendered; clipboard copy failed")"
      last_yank_selected="$selected"
      last_yank_report="$report"
      (( last_yank_count++ ))
      if [[ -n "${II_PAYLOAD_KEY:-}" ]]; then
        print -r -- "$footer_status"
        [[ -n "$last_yank_report" ]] && print && print -r -- "$last_yank_report"
        return
      fi
      continue
    fi

    break
  done

  report="$(ii_payload_render_report)"

  if (( output )); then
    ii_payload_write_output "$rendered" "$output_spec"
  fi

  ii_payload_print_separator
  print -r -- "$rendered"
  [[ -n "$report" ]] && print && print -r -- "$report"
  if [[ $last_yank_count -gt 0 && "$last_yank_selected" != "$selected" && -n "$last_yank_report" ]]; then
    print
    print -r -- "$last_yank_report"
  fi
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

Paste template text below the prompt, then render variables and print the
rendered output.

Finish input with a single "." line. Cancel with a single ":q" or ":q!" line.

Supported input placeholders:
  $name       replace lowercase name
  ${name}     replace lowercase name
  ${name:t}   replace lowercase name with its trailing path component
  ${II_NAME}  replace internal ii name as lowercase name
  II_NAME     replace bare internal ii name as lowercase name

Uppercase variables and PowerShell scope variables such as $env:, $script:,
$global:, $local:, and $private: are left unchanged.

Shell values win over ii tmux values. Missing values keep the original token and
are reported in red.

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

  [[ -n "$report" ]] && print -r -- "$report" && print
  ii_payload_print_separator
  print -r -- "$rendered"
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
  local footer_status="${2:-}"
  local plugin_file payload_dir compact_keys expanded_keys compact_footer expanded_footer
  plugin_file="${II_PLUGIN_DIR%/}/ii.plugin.zsh"
  payload_dir="$(ii_payload_dir)"
  compact_keys='j/k Move    Enter Render/Output    y Copy    l Expand    q Quit'
  expanded_keys='j/k Move    Enter Render/Output    y Copy    h Back    q Quit'
  compact_footer="$(ii_interact_footer "$compact_keys" "$footer_status")"
  expanded_footer="$(ii_interact_footer "$expanded_keys" "$footer_status")"

  fzf --ansi --prompt="ii payload:${filter}> " --height=80% --border --delimiter=$'\t' --with-nth=1,2,3,4 \
    --expect=enter,y,q \
    --bind='j:down,k:up' \
    --bind="l:change-preview-window(up,99%,wrap,noinfo)+hide-input+disable-search+change-footer($expanded_footer)" \
    --bind="h:change-preview-window(down,50%,nowrap,noinfo)+show-input+enable-search+change-footer($compact_footer)" \
    --preview="zsh -fc 'source \"\$1\"; export II_PAYLOAD_DIR=\"\$2\"; ii_payload_preview_fzf \"\$3\"' -- ${(q)plugin_file} ${(q)payload_dir} {1}" \
    --preview-window='down,50%,nowrap,noinfo' \
    --footer="$compact_footer" --footer-border=line
}

ii_payload_entries_for_fzf() {
  local selected payload preview_text preview overflow
  while IFS= read -r selected; do
    [[ -n "$selected" ]] || continue
    payload="$(ii_payload_path_for "$selected")" || return
    preview_text="$(ii_payload_preview_text "$payload")" || return
    preview="$(ii_one_line_preview "$preview_text" 96)"
    overflow=""
    [[ "$preview" != "$preview_text" ]] && overflow="$(ii_color_red more)"
    print -r -- "$selected"$'\t'"$(ii_color_blue "■")"$'\t'"$(ii_payload_highlight_preview_text "$preview")"$'\t'"$overflow"
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
  ii_payload_render_text "$rendered"
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
  ii_color_blue "payload output written to:"
  print -r -- "$II_PAYLOAD_OUTPUT_PATH"
}

ii_payload_read_input() {
  local input line

  if [[ -t 0 ]]; then
    ii_payload_print_input_intro
    ii_payload_print_input_prompt
  fi

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

ii_payload_render_text() {
  local text="$1"
  local rendered="" length i ch next expr end name modifier token original

  typeset -gA II_PAYLOAD_RENDER_REPORT_SOURCE=()
  typeset -gA II_PAYLOAD_RENDER_REPORT_VALUE=()
  typeset -g II_PAYLOAD_RENDERED_TEXT=""

  length="${#text}"
  i=1
  while (( i <= length )); do
    ch="${text[i]}"
    if [[ "$ch" == '$' ]]; then
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
            original="${text[i,end]}"
            ii_payload_resolve_render_var "$name" "$modifier" "$original"
            rendered+="$II_PAYLOAD_RESOLVED_VALUE"
            i=$(( end + 1 ))
            continue
          elif [[ "$expr" =~ '^II_([A-Za-z_][A-Za-z0-9_]*)$' ]]; then
            name="${(L)match[1]}"
            original="${text[i,end]}"
            ii_payload_resolve_render_var "$name" "" "$original"
            rendered+="$II_PAYLOAD_RESOLVED_VALUE"
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
          original="${text[i,end-1]}"
          ii_payload_resolve_render_var "$token" "" "$original"
          rendered+="$II_PAYLOAD_RESOLVED_VALUE"
          i="$end"
          continue
        fi
      fi
    fi

    if [[ "$ch" == "I" && "${text[i,i+2]}" == "II_" && ( i == 1 || ! "${text[i-1]}" =~ '[A-Za-z0-9_$]' ) ]]; then
      end="$i"
      while (( end <= length )) && [[ "${text[end]}" =~ '[A-Za-z0-9_]' ]]; do
        (( end++ ))
      done
      token="${text[i,end-1]}"
      if [[ "$token" =~ '^II_([A-Za-z_][A-Za-z0-9_]*)$' ]]; then
        name="${(L)match[1]}"
        original="$token"
        ii_payload_resolve_render_var "$name" "" "$original"
        rendered+="$II_PAYLOAD_RESOLVED_VALUE"
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

ii_payload_resolve_render_var() {
  local name="$1"
  local modifier="$2"
  local original="$3"
  local ii_name line value source

  if (( ${+parameters[$name]} )) && [[ -n "${(P)name}" ]]; then
    value="${(P)name}"
    source="shell"
  else
    ii_name="$(ii_var_normalize_name "$name")" || return
    if ii_tmux_available >/dev/null 2>&1; then
      line="$(ii_var_line_by_name "$ii_name")"
    else
      line=""
    fi
    if [[ -n "$line" && -n "${line#*=}" ]]; then
      value="${line#*=}"
      source="ii"
    else
      value="$original"
      source="missing"
    fi
  fi

  if [[ "$source" != "missing" && "$modifier" == ":t" ]]; then
    value="${value:t}"
  fi

  ii_payload_record_render_var "$name" "$source" "$value"
  typeset -g II_PAYLOAD_RESOLVED_VALUE="$value"
  typeset -g II_PAYLOAD_RESOLVED_SOURCE="$source"
}

ii_payload_record_render_var() {
  local name="$1"
  local source="$2"
  local value="$3"

  if [[ -z "${II_PAYLOAD_RENDER_REPORT_SOURCE[$name]:-}" || "${II_PAYLOAD_RENDER_REPORT_SOURCE[$name]}" == "missing" ]]; then
    II_PAYLOAD_RENDER_REPORT_SOURCE[$name]="$source"
    II_PAYLOAD_RENDER_REPORT_VALUE[$name]="$value"
  fi
}

ii_payload_render_report() {
  local name source value

  for name in ${(ok)II_PAYLOAD_RENDER_REPORT_SOURCE}; do
    source="${II_PAYLOAD_RENDER_REPORT_SOURCE[$name]}"
    value="${II_PAYLOAD_RENDER_REPORT_VALUE[$name]}"
    case "$source" in
      shell)
        ii_color_blue "${name} used from shell: ${value}"
        ;;
      ii)
        print -r -- "${name} used from ii: ${value}"
        ;;
      missing)
        ii_color_red "${name} unresolved: kept as ${value}"
        ;;
    esac
  done
}

ii_payload_preview() {
  local selected="$1"
  local payload description preview_text
  payload="$(ii_payload_path_for "$selected")" || return
  description="$(ii_payload_description "$payload")"
  preview_text="$(ii_payload_preview_text "$payload")" || return
  if [[ -n "$description" ]]; then
    print -r -- "description: $description"
    print -r -- "--------------------------------------------------------------------------------"
  fi
  ii_payload_highlight_preview_text "$preview_text"
}

ii_payload_preview_fzf() {
  local selected="$1"
  local payload description preview_text
  payload="$(ii_payload_path_for "$selected")" || return
  description="$(ii_payload_description "$payload")"
  preview_text="$(ii_payload_preview_text "$payload")" || return
  ii_payload_highlight_preview_text "$preview_text" | ii_fzf_print_preview_blocks "$description" ""
}

ii_payload_preview_text() {
  local payload_path="$1"
  ii_payload_body "$payload_path"
}

ii_payload_highlight_preview_text() {
  local text="$1"
  local highlighted="" length i ch next expr end token original

  length="${#text}"
  i=1
  while (( i <= length )); do
    ch="${text[i]}"
    if [[ "$ch" == '$' ]]; then
      next="${text[i+1]}"
      if [[ "$next" == "{" ]]; then
        end=$(( i + 2 ))
        while (( end <= length )) && [[ "${text[end]}" != "}" ]]; do
          (( end++ ))
        done
        if (( end <= length )); then
          expr="${text[i+2,end-1]}"
          if [[ "$expr" =~ '^([a-z_][a-z0-9_]*)(:t)?$' || "$expr" =~ '^II_([A-Za-z_][A-Za-z0-9_]*)$' ]]; then
            original="${text[i,end]}"
            highlighted+="$(ii_color_green "$original")"
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
            highlighted+="${text[i,end]}"
            i=$(( end + 1 ))
            continue
          fi
          original="${text[i,end-1]}"
          highlighted+="$(ii_color_green "$original")"
          i="$end"
          continue
        fi
      fi
    fi

    if [[ "$ch" == "I" && "${text[i,i+2]}" == "II_" && ( i == 1 || ! "${text[i-1]}" =~ '[A-Za-z0-9_$]' ) ]]; then
      end="$i"
      while (( end <= length )) && [[ "${text[end]}" =~ '[A-Za-z0-9_]' ]]; do
        (( end++ ))
      done
      token="${text[i,end-1]}"
      if [[ "$token" =~ '^II_([A-Za-z_][A-Za-z0-9_]*)$' ]]; then
        highlighted+="$(ii_color_green "$token")"
        i="$end"
        continue
      fi
    fi

    highlighted+="$ch"
    (( i++ ))
  done

  print -rn -- "$highlighted"
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
