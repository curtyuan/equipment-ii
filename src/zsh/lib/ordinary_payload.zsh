# Zsh-owned payload catalog, selector, ordinary actions, and combo handoff.

ii_zsh_payload_root() {
  local root="${II_PAYLOAD_DIR:-${HOME}/.config/ii/payloads}"
  [[ -d "$root" ]] || {
    print -u2 -- "ii: payload directory not found: $root"
    return 1
  }
  print -r -- "${root:A}"
}

ii_zsh_payload_list() {
  local root="$1"
  (cd "$root" && find . -type f ! -name '.*' -print | sed 's#^\./##' | LC_ALL=C sort)
}

ii_zsh_payload_filter() {
  local category="$1"
  case "$category" in
    all|'') cat ;;
    shell|script|sqli|xss) awk -v prefix="${category}/" 'index(tolower($0), prefix) == 1' ;;
    linux|windows) awk -v part="$category" '{ lower=tolower($0); if (lower ~ ("(^|/)" part "(/|$)")) print }' ;;
  esac
}

ii_zsh_payload_path() {
  local root="$1" relative_path="$2" absolute
  [[ -n "$relative_path" && "$relative_path" != /* &&
     "$relative_path" != (..|../*|*/../*|*/..) ]] || {
    print -u2 -- "ii: invalid payload path: $relative_path"
    return 1
  }
  absolute="${root}/${relative_path}"
  [[ -f "$absolute" && ! -L "$absolute" && "${absolute:A}" == "${root}/"* ]] || {
    print -u2 -- "ii: payload not found: $relative_path"
    return 1
  }
  print -r -- "$absolute"
}

ii_zsh_payload_is_combo() {
  awk '/^[[:space:]]*#[[:space:]]*flow:[[:space:]]*1[[:space:]]*$/ { found=1 } END { exit !found }' "$1"
}

ii_zsh_payload_body() {
  awk '
    NR == 1 && $0 ~ /^# description:[[:space:]]*/ { next }
    $0 ~ /^# stage:[[:space:]]*/ {
      label=$0; sub(/^# stage:[[:space:]]*/, "", label)
      if (label == "") label="stage"
      print "# --- " label " ---"; next
    }
    { print }
  ' "$1" | awk 'NR == 1 { first=$0; next } { lines[NR]=$0 } END {
    if (NR > 0) print first
    for (i=2; i<=NR; i++) print lines[i]
  }'
}

ii_zsh_payload_select() {
  local root="$1" category="$2" query="$3" preview_dir result action=enter selected line relative_path payload_path mode_file esc_normal_actions
  local -a result_lines
  local -a paths entries
  paths=("${(@f)$(ii_zsh_payload_list "$root" | ii_zsh_payload_filter "$category")}")
  (( ${#paths} )) || { print -u2 -- 'ii: no payloads found'; return 1; }
  preview_dir="$(mktemp -d "${TMPDIR:-/tmp}/ii-payload-preview.XXXXXXXX")" || return
  local index=0
  for relative_path in "$paths[@]"; do
    (( ++index ))
    payload_path="$(ii_zsh_payload_path "$root" "$relative_path")" || { command rm -rf -- "$preview_dir"; return 1; }
    command cp -- "$payload_path" "${preview_dir}/${index}"
    entries+=("$relative_path"$'\t'"${preview_dir}/${index}")
  done
  local normal_footer='j/k Move  / Search  l Expand  Enter Render  e Execute  y Yank  q Quit'
  local expanded_footer='j/k Move  h Back  Enter Render  y Yank  q Quit'
  local search_footer='Type Filter  Esc Normal  Enter Render'
  local normal_keys='j,k,e,y,q,l,h,/'
  local initial_keys="enter,$normal_keys"
  mode_file="${preview_dir}/mode"
  print -r -- normal >|"$mode_file"
  esc_normal_actions="clear-query+hide-input+disable-search+transform-footer(printf %s \"\$II_FZF_NORMAL_FOOTER\")+rebind($normal_keys)"
  result="$(print -rl -- "$entries[@]" | \
    II_FZF_NORMAL_FOOTER="$normal_footer" II_FZF_EXPANDED_FOOTER="$expanded_footer" \
    II_FZF_SEARCH_FOOTER="$search_footer" II_FZF_MODE_FILE="$mode_file" \
    II_FZF_ESC_NORMAL_ACTIONS="$esc_normal_actions" \
    fzf --sync --ansi --layout=reverse --prompt="ii payload:${category}> " \
      --query="$query" --height='80%' --border \
      --border-label=' Enter render | e execute | y yank | q quit ' \
      $'--delimiter=\t' --with-nth=1 --expect=enter,e,y \
      --bind="start:hide-input+unbind($initial_keys)" \
      --bind="result:disable-search+rebind($initial_keys)+unbind(result)" \
      --bind="/:execute-silent(printf search > \"\$II_FZF_MODE_FILE\")+show-input+enable-search+transform-footer(printf %s \"\$II_FZF_SEARCH_FOOTER\")+unbind($normal_keys)" \
      --bind='esc:transform(if [ "$(cat "$II_FZF_MODE_FILE")" = search ]; then printf normal > "$II_FZF_MODE_FILE"; printf %s "$II_FZF_ESC_NORMAL_ACTIONS"; else printf abort; fi)' \
      --bind='j:down,k:up,e:accept,y:accept,q:abort' \
      --bind="l:change-preview-window(up,99%,wrap,noinfo)+transform-footer(printf %s \"\$II_FZF_EXPANDED_FOOTER\")+hide-input+disable-search+unbind(/,e)+rebind(j,k,y,q,l,h)" \
      --bind="h:change-preview-window(up,50%,nowrap,noinfo)+transform-footer(printf %s \"\$II_FZF_NORMAL_FOOTER\")+hide-input+disable-search+rebind($normal_keys)" \
      '--preview=cat -- {2}' '--preview-window=up,50%,nowrap,noinfo' \
      --footer="$normal_footer" --no-separator)" || {
    command rm -rf -- "$preview_dir"
    return 1
  }
  command rm -rf -- "$preview_dir"
  [[ -n "$result" ]] || return 1
  result_lines=("${(@f)result}")
  action="${result_lines[1]:-}"
  if [[ "$action" == (enter|e|y|q) ]]; then
    line="${result_lines[2]}"
  elif [[ "${result_lines[2]:-}" == (enter|e|y|q) ]]; then
    action="${result_lines[2]}"
    line="${result_lines[1]}"
  else
    action=enter
    line="${result_lines[1]}"
  fi
  [[ -n "${II_PAYLOAD_KEY:-}" ]] && action="$II_PAYLOAD_KEY"
  selected="${line%%$'\t'*}"
  [[ -n "$selected" ]] || return 1
  print -r -- "$action"$'\t'"$selected"
}

ii_zsh_payload_report() {
  local color_enabled="${1:-0}" variable_name source variable_value label
  for variable_name in ${(ok)II_PAYLOAD_RENDER_REPORT_SOURCE}; do
    source="${II_PAYLOAD_RENDER_REPORT_SOURCE[$variable_name]}"
    variable_value="${II_PAYLOAD_RENDER_REPORT_VALUE[$variable_name]}"
    label="$variable_name"
    if (( color_enabled )); then
      if [[ "$source" == missing ]]; then
        label=$'\e[1;31m'"$variable_name"$'\e[0m'
      else
        label=$'\e[1;32m'"$variable_name"$'\e[0m'
      fi
    fi
    case "$source" in
      shell) print -r -- "$label used from shell: $variable_value" ;;
      ii) print -r -- "$label used from ii: $variable_value" ;;
      missing) print -r -- "$label unresolved: kept as $variable_value" ;;
    esac
  done
}

ii_zsh_payload_confirm() {
  local answer missing=''
  local variable_name
  for variable_name in ${(ok)II_PAYLOAD_RENDER_REPORT_SOURCE}; do
    [[ "${II_PAYLOAD_RENDER_REPORT_SOURCE[$variable_name]}" == missing ]] && missing+="${missing:+, }$variable_name"
  done
  if [[ -n "$missing" ]]; then
    print -u2 -- "ii: unresolved variables: $missing"
    print -n -- 'Unresolved variables may make this payload ineffective. Execute anyway? [Y/Enter] '
  else
    print -n -- 'Execute this payload? [Y/Enter] '
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
    print -u2 -- 'ii: cannot confirm execution without a terminal'
    return 1
  fi
  [[ -z "$answer" || "${(L)answer}" == y ]]
}

ii_zsh_payload_output_path() {
  local spec="$1"
  if [[ -z "$spec" ]]; then print -r -- /www/p/att.txt
  elif [[ "$spec" == */ || -d "$spec" ]]; then print -r -- "${spec%/}/att.txt"
  elif [[ "$spec" == /* || "$spec" == ./* || "$spec" == ../* || "$spec" == */* ]]; then print -r -- "$spec"
  else print -r -- "/www/$spec"
  fi
}

ii_zsh_payload_write() {
  local text="$1" spec="$2" output_path directory temp
  output_path="$(ii_zsh_payload_output_path "$spec")" || return
  directory="${output_path:h}"
  mkdir -p -- "$directory" || return
  temp="$(mktemp "${directory}/.ii-output.XXXXXXXX")" || return
  print -rn -- "$text" >|"$temp" || { command rm -f -- "$temp"; return 1; }
  command mv -f -- "$temp" "$output_path" || { command rm -f -- "$temp"; return 1; }
  typeset -g II_PAYLOAD_OUTPUT_PATH="${output_path:A}"
}

ii_zsh_combo_direct() {
  [[ -x "$II_GO_BIN" ]] || { print -u2 -- "ii: Go runtime unavailable: $II_GO_BIN"; return 127; }
  II_PAYLOAD_DIR="$II_PAYLOAD_DIR" "$II_GO_BIN" "$@"
}

ii_zsh_cmd_payload() {
  local command="$1" category=all query='' execute=0 copy=0 output=0 output_spec=''
  shift
  case "$command" in pc) copy=1 ;; pe) execute=1 ;; pce) copy=1; execute=1 ;; esac
  local -a terms
  while (( $# )); do
    case "$1" in
      --www|www) print -u2 -- "ii: unknown payload option: $1"; return 2 ;;
      --copy) copy=1 ;;
      --execute) execute=1 ;;
      -o|--output)
        output=1
        if (( $# > 1 )) && [[ "$2" != -* ]]; then output_spec="$2"; shift; fi
        ;;
      -*) print -u2 -- "ii: unknown payload option: $1"; return 2 ;;
      *) terms+=("$1") ;;
    esac
    shift
  done
  if (( ${#terms} == 1 )) && [[ "$terms[1]" == (all|shell|script|linux|windows|sqli|xss) ]]; then
    category="$terms[1]"
  else query="${(j: :)terms}"
  fi
  (( $+commands[fzf] )) || { print -u2 -- 'ii: required command not found: fzf'; return 1; }
  local root selection action relative_path payload_path body rendered report backend report_color=0
  root="$(ii_zsh_payload_root)" || return
  selection="$(ii_zsh_payload_select "$root" "$category" "$query")" || return
  action="${selection%%$'\t'*}"
  relative_path="${selection#*$'\t'}"
  payload_path="$(ii_zsh_payload_path "$root" "$relative_path")" || return
  [[ "$action" == e ]] && execute=1

  if ii_zsh_payload_is_combo "$payload_path"; then
    if [[ "$action" == y || ( $copy -eq 1 && $execute -eq 0 ) ]]; then
      backend="$(ii_zsh_clip_effective)" || { print -u2 -- 'ii: clipboard unavailable'; return 1; }
      ii_zsh_combo_direct __combo-copy "$relative_path" "$backend"
    elif (( execute )); then
      ii_zsh_combo_launch "$relative_path" "$copy"
    else
      ii_zsh_combo_direct __combo-render "$relative_path"
    fi
    return
  fi

  body="$(ii_zsh_payload_body "$payload_path")"
  ii_zsh_payload_render_text "$body" ordinary >/dev/null || return
  rendered="$II_PAYLOAD_RENDERED_TEXT"
  ii_zsh_color_enabled && report_color=1
  report="$(ii_zsh_payload_report "$report_color")"
  if (( output )); then ii_zsh_payload_write "$rendered" "$output_spec" || return; fi
  if [[ "$action" == y || ( $copy -eq 1 && $execute -eq 0 ) ]]; then
    if ii_zsh_clip_copy "$rendered"; then print -r -- 'payload copied successfully'
    else print -r -- 'payload rendered; clipboard copy failed'; return 1
    fi
    if [[ -n "$report" ]]; then
      print
      print -r -- "$report"
      print -r -- "$relative_path"
    fi
    return
  fi
  if [[ -n "$report" ]]; then
    print -r -- "$report"
    print -r -- "$relative_path"
    print
  fi
  if (( execute )); then
    ii_zsh_payload_confirm || { print -u2 -- 'ii: execution cancelled'; return 1; }
    if (( copy )); then ii_zsh_clip_copy "$rendered" && print -r -- 'payload copied successfully' || print -u2 -- 'ii: clipboard copy failed; executing payload anyway'; fi
    print -r -- 'executing payload in current shell:' "$relative_path"
    eval "$rendered"
  else
    print -rn -- "$rendered"
    if [[ -n "${II_PAYLOAD_OUTPUT_PATH:-}" ]]; then print -r -- '' 'payload output written to:' "$II_PAYLOAD_OUTPUT_PATH"; fi
  fi
}

ii_zsh_payload_read_input() {
  typeset -g II_PAYLOAD_INPUT_TEXT=''
  if [[ -t 0 ]]; then
    local input=''
    print -r -- 'Paste payload input below. Enter renders; Alt-Enter adds a line; Esc cancels.' ''
    ii_zsh_payload_input_newline() { LBUFFER+=$'\n'; zle redisplay; }
    ii_zsh_payload_input_cancel() { BUFFER=:q; zle accept-line; }
    zle -N ii-zsh-payload-input-newline ii_zsh_payload_input_newline
    zle -N ii-zsh-payload-input-cancel ii_zsh_payload_input_cancel
    bindkey -N ii-zsh-payload-input emacs
    bindkey -M ii-zsh-payload-input $'\e[200~' .bracketed-paste
    bindkey -M ii-zsh-payload-input $'\e\r' ii-zsh-payload-input-newline
    bindkey -M ii-zsh-payload-input $'\e\n' ii-zsh-payload-input-newline
    bindkey -M ii-zsh-payload-input $'\e' ii-zsh-payload-input-cancel
    vared -M ii-zsh-payload-input -p 'ii input> ' input || { print -u2 -- 'ii: input cancelled'; return 130; }
    [[ "$input" != (:q|:q!) ]] || { print -u2 -- 'ii: input cancelled'; return 130; }
    [[ "$input" == *$'\n':w ]] && input="${input%$'\n':w}"
    [[ "$input" == :w ]] && input=''
    typeset -g II_PAYLOAD_INPUT_TEXT="$input"
    return
  fi
  local line input=''
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == :w ]] && break
    [[ "$line" != (:q|:q!) ]] || { print -u2 -- 'ii: input cancelled'; return 130; }
    input+="${line}"$'\n'
  done
  typeset -g II_PAYLOAD_INPUT_TEXT="${input%$'\n'}"
}

ii_zsh_cmd_payload_input() {
  local command="$1" copy=0 execute=0 output=0 output_spec=''
  shift
  local supplied=$#
  case "$command" in pic) copy=1 ;; pie) execute=1 ;; pice) copy=1; execute=1 ;; esac
  while (( $# )); do
    case "$1" in
      --input|input) ;;
      --copy) copy=1 ;;
      --execute) execute=1 ;;
      -o|--output)
        output=1
        if (( $# > 1 )) && [[ "$2" != -* ]]; then output_spec="$2"; shift; fi
        ;;
      *) print -u2 -- "ii: unknown payload input option: $1"; return 2 ;;
    esac
    shift
  done
  if [[ "$command" == (pie|pice) && $supplied -gt 0 ]]; then
    print -u2 -- "ii: usage: ii $command"
    return 2
  fi
  ii_zsh_payload_read_input || return
  ii_zsh_payload_render_text "$II_PAYLOAD_INPUT_TEXT" ordinary >/dev/null || return
  local rendered="$II_PAYLOAD_RENDERED_TEXT" report report_color=0
  ii_zsh_color_enabled && report_color=1
  report="$(ii_zsh_payload_report "$report_color")"
  typeset -g II_PAYLOAD_OUTPUT_PATH=''
  if (( output )); then ii_zsh_payload_write "$rendered" "$output_spec" || return; fi
  if (( copy && ! execute )); then
    if ii_zsh_clip_copy "$rendered"; then print -r -- 'payload copied successfully'
    else print -r -- 'payload rendered; clipboard copy failed'; return 1
    fi
    print
  fi
  [[ -n "$report" ]] && print -r -- "$report"
  [[ -n "$report" ]] && print
  print -r -- '----------------------------------------'
  print -r -- "$rendered"
  if (( execute )); then
    ii_zsh_payload_confirm || { print -u2 -- 'ii: execution cancelled'; return 1; }
    if (( copy )); then ii_zsh_clip_copy "$rendered" && print -r -- 'payload copied successfully' || print -u2 -- 'ii: clipboard copy failed; executing payload anyway'; fi
    eval "$rendered"
  fi
  if [[ -n "$II_PAYLOAD_OUTPUT_PATH" ]]; then
    print
    print -r -- 'payload output written to:'
    print -r -- "$II_PAYLOAD_OUTPUT_PATH"
  fi
}
