# Shared fzf interaction helpers.

ii_interact_footer() {
  local keys="$1"
  local footer_status="${2:-}"

  if [[ -n "$footer_status" ]]; then
    print -r -- "$keys"$'\n'"$footer_status"
  else
    print -r -- "$keys"
  fi
}

ii_interact_copy_status() {
  local ok="$1"
  local success="$2"
  local failure="$3"

  if [[ "$ok" == "0" ]]; then
    print -r -- "$success"
  else
    print -r -- "$failure"
  fi
}

ii_interact_keys_vars_normal() {
  print -r -- "j/k Move    / Search    i Edit    Enter Edit+Copy+Quit    y Copy    q Quit"
}

ii_interact_keys_vars_search() {
  print -r -- "Type Filter    Esc Normal    Enter Edit+Copy+Quit"
}

ii_interact_keys_payload_normal() {
  print -r -- "j/k Move    / Search    Enter Render/Output    y Copy    l Expand    q Quit"
}

ii_interact_keys_payload_expanded() {
  print -r -- "j/k Move    Enter Render/Output    y Copy    h Back    q Quit"
}

ii_interact_keys_payload_search() {
  print -r -- "Type Filter    Esc Normal    Enter Render/Output"
}

ii_fzf_modal_start_actions() {
  print -r -- "hide-input+disable-search"
}

ii_fzf_modal_search_actions() {
  local search_footer="$1"
  local normal_keys="$2"
  print -r -- "show-input+enable-search+change-footer($search_footer)+unbind($normal_keys)"
}

ii_fzf_modal_normal_actions() {
  local normal_footer="$1"
  local normal_keys="$2"
  print -r -- "clear-query+hide-input+disable-search+change-footer($normal_footer)+rebind($normal_keys)"
}
