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
  local key label line line_len unit unit_len separator separator_len width

  width="${II_INTERACT_COLUMNS:-${FZF_PREVIEW_COLUMNS:-${COLUMNS:-80}}}"
  [[ "$width" == <-> ]] || width=80
  (( width > 0 )) || width=80
  width=$(( width - 2 ))
  (( width > 0 )) || width=1

  line=$'\033[48;5;236m'
  line_len=0
  while (( $# >= 2 )); do
    key="$1"
    label="$2"
    shift 2
    unit=$'\033[1;97m'"${key}"$'\033[22;2;37m '"${label}"
    unit_len=$(( ${#key} + 1 + ${#label} ))
    separator=""
    separator_len=0
    if (( line_len > 0 )); then
      separator="  "
      separator_len=2
    fi
    if (( line_len > 0 && line_len + separator_len + unit_len > width )); then
      print -r -- "$line"$'\033[0m'
      line=$'\033[48;5;236m'
      line_len=0
      separator=""
      separator_len=0
    fi
    line+="${separator}${unit}"
    line_len=$(( line_len + separator_len + unit_len ))
  done
  print -r -- "$line"$'\033[0m'
}

ii_interact_status_line() {
  local message="$1"
  print -r -- $'\033[48;5;238;97m'"$message"$'\033[0m'
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
  ii_interact_hint_line "j/k" "move" "/" "search" "i/l" "edit" "Enter" "copy+quit" "y" "copy" "h/q" "quit"
}

ii_interact_keys_vars_search() {
  ii_interact_hint_line "type" "filter" "Esc" "normal" "Enter" "copy+quit"
}

ii_interact_keys_payload_normal() {
  ii_interact_hint_line "j/k" "move" "/" "search" "l" "expand" "Enter" "render" "e" "execute" "y" "copy+quit" "q" "quit"
}

ii_interact_keys_payload_expanded() {
  ii_interact_hint_line "j/k" "move" "h" "back" "Enter" "render" "y" "copy+quit" "q" "quit"
}

ii_interact_keys_payload_search() {
  ii_interact_hint_line "type" "filter" "Esc" "normal" "Enter" "render"
}

ii_fzf_modal_start_actions() {
  print -r -- "hide-input+disable-search"
}
