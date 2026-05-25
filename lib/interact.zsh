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
