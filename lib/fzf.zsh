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
  local content shown desc_block footer_block reserved shown_count pad limit

  content="$(cat)"
  desc_block=""
  if [[ -n "$description" ]]; then
    desc_block="[description]"$'\n'"$description"$'\n'"--------------------------------------------------------------------------------"
  fi
  footer_block="[keys]"$'\n'"$footer"

  reserved=0
  [[ -n "$desc_block" ]] && reserved=$(( reserved + $(print -r -- "$desc_block" | awk 'END {print NR}') ))
  reserved=$(( reserved + $(print -r -- "$footer_block" | awk 'END {print NR}') ))

  if (( preview_lines <= reserved )); then
    [[ -n "$desc_block" ]] && print -r -- "$desc_block"
    print -r -- "$footer_block"
    return
  fi

  limit=$(( preview_lines - reserved ))
  shown="$(print -r -- "$content" | awk -v limit="$limit" 'NR <= limit {print}')"
  shown_count="$(print -r -- "$shown" | awk 'END {print NR}')"
  [[ -z "$shown" ]] && shown_count=0

  [[ -n "$desc_block" ]] && print -r -- "$desc_block"
  [[ -n "$shown" ]] && print -r -- "$shown"
  pad=$(( preview_lines - reserved - shown_count ))
  while (( pad > 0 )); do
    print
    (( pad-- ))
  done
  print -r -- "$footer_block"
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
