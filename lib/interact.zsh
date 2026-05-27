# Shared fzf interaction helpers.

ii_interact_footer() {
  local keys="$1"
  local footer_status="${2:-}"

  if [[ -n "$footer_status" ]]; then
    print -r -- "$keys"$'\n'"$(ii_interact_status_line "$footer_status")"
  else
    print -r -- "$keys"
  fi
}

ii_interact_hint_line() {
  local key label out

  out=$'\033[48;5;236m'
  while (( $# >= 2 )); do
    key="$1"
    label="$2"
    shift 2
    out+=$' \033[1;97m'"${key}"$'\033[22;2;37m '"${label}"$'  '
  done
  out+=$'\033[0m'
  print -r -- "$out"
}

ii_interact_status_line() {
  local message="$1"
  print -r -- $'\033[48;5;238;97m '"$message"$' \033[0m'
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
  ii_interact_hint_line "j/k" "move" "/" "search" "i/l" "edit"
  ii_interact_hint_line "Enter" "copy+quit" "y" "copy" "h/q" "quit"
}

ii_interact_keys_vars_search() {
  ii_interact_hint_line "type" "filter" "Esc" "normal"
  ii_interact_hint_line "Enter" "copy+quit"
}

ii_interact_keys_payload_normal() {
  ii_interact_hint_line "j/k" "move" "/" "search" "l" "expand"
  ii_interact_hint_line "Enter" "render" "y" "copy" "q" "quit"
}

ii_interact_keys_payload_expanded() {
  ii_interact_hint_line "j/k" "move" "h" "back"
  ii_interact_hint_line "Enter" "render" "y" "copy" "q" "quit"
}

ii_interact_keys_payload_search() {
  ii_interact_hint_line "type" "filter" "Esc" "normal"
  ii_interact_hint_line "Enter" "render"
}

ii_fzf_modal_start_actions() {
  print -r -- "hide-input+disable-search"
}
