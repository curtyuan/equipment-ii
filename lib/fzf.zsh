# Shared fzf helpers.

ii_one_line_preview() {
  local value="$1"
  local limit="${2:-96}"
  local one_line
  one_line="${value//$'\r'/ }"
  one_line="${one_line//$'\n'/ }"
  one_line="${one_line//$'\t'/ }"
  if (( ${#one_line} > limit )); then
    print -r -- "${one_line[1,limit]}"
  else
    print -r -- "$one_line"
  fi
}

ii_fzf_print_preview_with_footer() {
  local footer="$1"
  ii_fzf_print_preview_blocks "" "$footer"
}

ii_fzf_print_preview_blocks() {
  local description="$1"
  local footer="$2"
  local preview_lines="${FZF_PREVIEW_LINES:-0}"
  local content shown desc_block footer_block reserved shown_count pad limit printed footer_count desc_limit

  content="$(cat)"
  desc_block="[description]"$'\n'"$description"$'\n'"--------------------------------------------------------------------------------"
  footer_block=""
  [[ -n "$footer" ]] && footer_block="$footer"

  if (( preview_lines <= 0 )); then
    print -r -- "$desc_block"
    [[ -n "$content" ]] && print -r -- "$content"
    [[ -n "$footer_block" ]] && print -r -- "$footer_block"
    return
  fi

  reserved=0
  reserved=$(( reserved + $(print -r -- "$desc_block" | awk 'END {print NR}') ))
  [[ -n "$footer_block" ]] && reserved=$(( reserved + $(print -r -- "$footer_block" | awk 'END {print NR}') ))

  if (( preview_lines <= reserved )); then
    if [[ -n "$footer_block" ]]; then
      footer_count="$(print -r -- "$footer_block" | awk 'END {print NR}')"
      if (( footer_count >= preview_lines )); then
        print -r -- "$footer_block" | awk -v limit="$preview_lines" 'NR <= limit {print}'
      else
        desc_limit=$(( preview_lines - footer_count ))
        print -r -- "$desc_block" | awk -v limit="$desc_limit" 'NR <= limit {print}'
        print -r -- "$footer_block"
      fi
    else
      print -r -- "$desc_block" | awk -v limit="$preview_lines" 'NR <= limit {print}'
    fi
    return
  fi

  limit=$(( preview_lines - reserved ))
  shown="$(print -r -- "$content" | awk -v limit="$limit" 'NR <= limit {print}')"
  shown_count="$(print -r -- "$shown" | awk 'END {print NR}')"
  [[ -z "$shown" ]] && shown_count=0

  printed=0
  print -r -- "$desc_block"
  printed=$(( printed + $(print -r -- "$desc_block" | awk 'END {print NR}') ))
  [[ -n "$shown" ]] && print -r -- "$shown"
  printed=$(( printed + shown_count ))
  pad=$(( preview_lines - reserved - shown_count ))
  while (( pad > 0 )); do
    print
    (( printed++ ))
    (( pad-- ))
  done
  if [[ -n "$footer_block" ]]; then
    print -r -- "$footer_block"
    printed=$(( printed + $(print -r -- "$footer_block" | awk 'END {print NR}') ))
  fi
  while (( printed < preview_lines )); do
    print
    (( printed++ ))
  done
}

ii_fzf_trim_leading_empty_lines() {
  local text="$1"

  while [[ "$text" == $'\n'* ]]; do
    text="${text#$'\n'}"
  done
  print -r -- "$text"
}

ii_fzf_select_one() {
  local filter="$1"
  shift

  if [[ -n "$filter" ]]; then
    FZF_DEFAULT_OPTS="--filter=${filter}" fzf -i "$@" | awk 'NF {print; exit}'
  else
    fzf -i "$@"
  fi
}

ii_fzf_input_value() {
  local filter="$1"
  shift

  if [[ -n "$filter" ]]; then
    FZF_DEFAULT_OPTS="--filter=${filter}" fzf -i --print-query --phony "$@" | awk 'NR == 1 {print; exit}'
  else
    print | fzf -i --print-query --phony "$@" | awk 'NR == 1 {print; exit}'
  fi
}
