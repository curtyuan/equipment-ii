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
  print -r -- "j/k move  / search  i/l edit"
  print -r -- "Enter copy+quit  y copy  h/q quit"
}

ii_interact_keys_vars_search() {
  print -r -- "type filter  Esc normal"
  print -r -- "Enter copy+quit"
}

ii_interact_keys_payload_normal() {
  print -r -- "j/k move  / search  l expand  w write"
  print -r -- "Enter render  y copy  q quit"
}

ii_interact_keys_payload_expanded() {
  print -r -- "j/k move  h back  w write"
  print -r -- "Enter render  y copy  q quit"
}

ii_interact_keys_payload_search() {
  print -r -- "type filter  Esc normal"
  print -r -- "Enter render"
}

ii_fzf_modal_start_actions() {
  print -r -- "hide-input+disable-search"
}
