# Payload selection, filtering, rendering, and reporting.

ii_cmd_payload_select() {
  ii_tmux_available || return
  ii_require_cmd fzf || return

  local category="all" query="" execute=0 copy_execute=0 output=0 output_spec=""
  local -a terms
  terms=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --execute)
        execute=1
        shift
        ;;
      --copy)
        copy_execute=1
        shift
        ;;
      -o|--output)
        output=1
        shift
        if [[ $# -gt 0 && "${1:-}" != -* ]]; then
          output_spec="$1"
          shift
        fi
        ;;
      *)
        terms+=("$1")
        shift
        ;;
    esac
  done

  if (( $#terms == 1 )); then
    case "$terms[1]" in
      all|shell|script|linux|windows|sqli|xss) category="$terms[1]" ;;
      *) query="$terms[1]" ;;
    esac
  elif (( $#terms > 1 )); then
    query="${(j: :)terms}"
  fi

  local payloads payload selected key line rendered report copy_status copy_rc execute_selected=0
  typeset -g II_PAYLOAD_OUTPUT_PATH=""
  payloads="$(ii_payload_list)" || return
  if [[ -z "$payloads" ]]; then
    print -u2 "ii: no payloads found"
    return 1
  fi

  while true; do
    if ! selected="$(print -r -- "$payloads" | ii_payload_filter "$category" | ii_payload_entries_for_fzf | ii_payload_select_fzf "$category" "" "$query")"; then
      return
    fi
    if [[ -z "$selected" ]]; then
      return
    fi

    selected="$(ii_fzf_trim_leading_empty_lines "$selected")"
    [[ -n "$selected" ]] || return
    key="${selected%%$'\n'*}"
    if [[ "$key" == "enter" || "$key" == "e" || "$key" == "y" || "$key" == "q" ]]; then
      line="${selected#*$'\n'}"
    else
      key="enter"
      line="${selected%%$'\n'*}"
    fi
    [[ -n "${II_PAYLOAD_KEY:-}" ]] && key="$II_PAYLOAD_KEY"
    selected="$(print -r -- "$line" | awk -F '\t' 'NF {print $1; exit}')"
    [[ -n "$selected" ]] || return

    if [[ "$key" == "q" ]]; then
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
      copy_status="$(ii_interact_copy_status "$copy_rc" "payload copied successfully" "payload rendered; clipboard copy failed")"
      print -r -- "$copy_status"
      [[ -n "$report" ]] && print && ii_payload_print_report "$report" "$selected"
      return "$copy_rc"
    fi

    if [[ "$key" == "e" || ( "$key" == "enter" && $execute -eq 1 ) ]]; then
      execute_selected=1
    fi

    break
  done

  report="$(ii_payload_render_report)"

  if (( output )); then
    ii_payload_write_output "$rendered" "$output_spec" || return
  fi

  [[ -n "$report" ]] && ii_payload_print_report "$report" "$selected" && print
  if (( execute_selected )); then
    if ! ii_payload_confirm_execute "$rendered"; then
      print -u2 "ii: execution cancelled"
      return 1
    fi
    if (( copy_execute )); then
      if ii_clip_copy "$rendered"; then
        print "payload copied successfully"
      else
        print -u2 "ii: clipboard copy failed; executing payload anyway"
      fi
    fi
    ii_color_blue "executing payload in current shell:"
    print -r -- "$selected"
    eval "$rendered"
    return $?
  fi
  print -r -- "$rendered"
  ii_payload_print_output_report
}

ii_payload_confirm_execute() {
  local rendered="$1" answer
  local missing="$(ii_payload_missing_names)"
  if [[ -n "$missing" ]]; then
    print -u2 "ii: unresolved variables: ${(j:, :)${(f)missing}}"
    printf 'Unresolved variables may make this payload ineffective. Execute anyway? [y/N] '
  else
    printf 'Execute this payload? [y/N] '
  fi
  if [[ -n "${II_INTERACTIVE_KEY:-}" ]]; then
    answer="$II_INTERACTIVE_KEY"
    print -r -- "$answer"
  elif [[ -t 0 ]]; then
    read -r -k 1 answer
    print
  elif [[ -r /dev/tty ]]; then
    read -r -k 1 answer </dev/tty
    print
  else
    print -u2 "ii: cannot confirm execution without a terminal"
    return 1
  fi
  [[ "${(L)answer}" == "y" ]]
}

ii_payload_missing_names() {
  local name
  for name in ${(ok)II_PAYLOAD_RENDER_REPORT_SOURCE}; do
    [[ "${II_PAYLOAD_RENDER_REPORT_SOURCE[$name]}" == "missing" ]] && print -r -- "$name"
  done
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
  local query="${3:-}"
  local plugin_file payload_dir compact_footer expanded_footer search_footer normal_keys preview_cmd
  plugin_file="${II_PLUGIN_DIR%/}/ii.plugin.zsh"
  payload_dir="$(ii_payload_dir)"
  compact_footer="$(ii_interact_footer "$(ii_interact_keys_payload_normal)" "$footer_status")"
  expanded_footer="$(ii_interact_footer "$(ii_interact_keys_payload_expanded)" "$footer_status")"
  search_footer="$(ii_interact_footer "$(ii_interact_keys_payload_search)" "$footer_status")"
  normal_keys="j,k,e,y,q,l,h,/"
  preview_cmd="zsh -fc 'source \"\$1\"; export II_PAYLOAD_DIR=\"\$2\"; ii_payload_preview_fzf \"\$3\"' -- ${(q)plugin_file} ${(q)payload_dir} {1}"

  II_FZF_COMPACT_FOOTER="$compact_footer" II_FZF_EXPANDED_FOOTER="$expanded_footer" II_FZF_SEARCH_FOOTER="$search_footer" \
  fzf --ansi --layout=reverse --prompt="ii payload:${filter}> " --query="$query" --height=80% --border --delimiter=$'\t' --with-nth=1 \
    --expect=enter \
    --bind="start:$(ii_fzf_modal_start_actions)" \
    --bind="/:show-input+enable-search+transform-footer(printf %s \"\$II_FZF_SEARCH_FOOTER\")+unbind($normal_keys)" \
    --bind="esc:clear-query+hide-input+disable-search+transform-footer(printf %s \"\$II_FZF_COMPACT_FOOTER\")+rebind($normal_keys)" \
    --bind='j:down,k:up,e:print(e)+accept,y:print(y)+accept,q:abort' \
    --bind="l:change-preview-window(up,99%,wrap,noinfo)+transform-footer(printf %s \"\$II_FZF_EXPANDED_FOOTER\")+hide-input+disable-search+unbind(/,e)+rebind(j,k,y,q,l,h)" \
    --bind="h:change-preview-window(up,50%,nowrap,noinfo)+transform-footer(printf %s \"\$II_FZF_COMPACT_FOOTER\")+hide-input+disable-search+rebind($normal_keys)" \
    --preview="$preview_cmd" \
    --preview-window='up,50%,nowrap,noinfo' \
    --footer="$compact_footer" \
    --no-separator
}

ii_payload_entries_for_fzf() {
  local selected
  while IFS= read -r selected; do
    [[ -n "$selected" ]] || continue
    print -r -- "$selected"
  done
}

ii_payload_best_match() {
  local query="$1"
  local selected

  selected="$(ii_payload_list | ii_payload_entries_for_fzf | FZF_DEFAULT_OPTS='' fzf -i --filter="$query" | awk 'NF {print; exit}')" || return
  [[ -n "$selected" ]] || return 1
  print -r -- "$selected"
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

ii_payload_print_report() {
  local report="$1"
  local selected="$2"

  [[ -n "$report" ]] && print -r -- "$report"
  ii_payload_print_separator "$selected"
}

ii_payload_print_separator() {
  local selected="${1:-[payload]}"
  ii_color_blue "$selected"
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
  [[ -n "${II_PAYLOAD_OUTPUT_PATH:-}" ]] || return 0
  print
  ii_color_blue "payload output written to:"
  print -r -- "$II_PAYLOAD_OUTPUT_PATH"
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

    if [[ "$ch" == "%" && "${text[i+1]}" =~ '[a-z_]' ]]; then
      end=$(( i + 2 ))
      while (( end <= length )) && [[ "${text[end]}" =~ '[a-z0-9_]' ]]; do
        (( end++ ))
      done
      if (( end <= length )) && [[ "${text[end]}" == "%" ]]; then
        token="${text[i+1,end-1]}"
        original="${text[i,end]}"
        ii_payload_resolve_render_var "$token" "" "$original"
        rendered+="$II_PAYLOAD_RESOLVED_VALUE"
        i=$(( end + 1 ))
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
  local ii_name line value render_value source

  if [[ -z "${II_PAYLOAD_TMUX_ONLY:-}" ]] && (( ${+parameters[$name]} )) && [[ -n "${(P)name}" ]]; then
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

  render_value="$value"
  if [[ "$source" != "missing" && "$modifier" == ":t" ]]; then
    render_value="$(ii_payload_path_tail "$value")"
  fi

  ii_payload_record_render_var "$name" "$source" "$value"
  typeset -g II_PAYLOAD_RESOLVED_VALUE="$render_value"
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

ii_payload_path_tail() {
  local value="$1"
  value="${value##*/}"
  value="${value##*\\}"
  print -r -- "$value"
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
            name="${match[1]}"
            original="${text[i,end]}"
            highlighted+="$(ii_payload_highlight_preview_var "$name" "$original")"
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
          highlighted+="$(ii_payload_highlight_preview_var "$token" "$original")"
          i="$end"
          continue
        fi
      fi
    fi

    if [[ "$ch" == "%" && "${text[i+1]}" =~ '[a-z_]' ]]; then
      end=$(( i + 2 ))
      while (( end <= length )) && [[ "${text[end]}" =~ '[a-z0-9_]' ]]; do
        (( end++ ))
      done
      if (( end <= length )) && [[ "${text[end]}" == "%" ]]; then
        token="${text[i+1,end-1]}"
        original="${text[i,end]}"
        highlighted+="$(ii_payload_highlight_preview_var "$token" "$original")"
        i=$(( end + 1 ))
        continue
      fi
    fi

    highlighted+="$ch"
    (( i++ ))
  done

  print -rn -- "$highlighted"
}

ii_payload_highlight_preview_var() {
  local name="$1"
  local display="$2"

  if ii_payload_preview_var_available "$name"; then
    ii_color_green "$display"
  else
    ii_color_red "$display"
  fi
}

ii_payload_preview_var_available() {
  local name="$1"
  local ii_name line

  if (( ${+parameters[$name]} )) && [[ -n "${(P)name}" ]]; then
    return 0
  fi

  ii_name="$(ii_var_normalize_name "$name")" || return 1
  if ii_tmux_available >/dev/null 2>&1; then
    line="$(ii_var_line_by_name "$ii_name")"
  else
    line=""
  fi
  [[ -n "$line" && -n "${line#*=}" ]]
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
