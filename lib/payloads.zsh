# Payload selection, filtering, rendering, and reporting.

ii_cmd_payload() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii payload [CATEGORY]
       ii p [CATEGORY]

Open the payload selector, render the selected template with fresh JJ_
variables from the tmux session, copy the result, and print the output.

CATEGORY may be all, shell, script, linux, windows, sqli, or xss.
EOF
    return 0
  fi

  ii_tmux_available || return
  ii_require_cmd fzf || return

  local filter="${1:-all}"
  local payloads payload selected rendered
  payloads="$(ii_payload_list)" || return
  if [[ -z "$payloads" ]]; then
    print -u2 "ii: no payloads found"
    return 1
  fi

  selected="$(print -r -- "$payloads" | ii_payload_filter "$filter" | ii_payload_select_fzf "$filter" | awk 'NF {print; exit}')" || return
  [[ -n "$selected" ]] || return

  payload="$(ii_payload_path_for "$selected")" || return
  rendered="$(ii_payload_render "$payload")" || return

  if ii_clip_copy "$rendered"; then
    print "payload copied successfully"
  else
    print "payload rendered; clipboard copy failed"
  fi

  print
  print -r -- "$rendered"
  print
  ii_payload_print_used_vars "$payload"
}

ii_payload_dir() {
  print -r -- "${JJ_PAYLOAD_DIR:-${HOME}/.config/ii/payloads}"
}

ii_payload_list() {
  local dir
  dir="$(ii_payload_dir)"
  if [[ ! -d "$dir" ]]; then
    print -u2 "ii: payload directory not found: $dir"
    print -u2 "ii: set JJ_PAYLOAD_DIR or create ~/.config/ii/payloads"
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
  fzf --prompt="ii payload:${filter}> " --height=80% --border
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
  rendered="$(<"$payload_path")"

  local var line value label fallback
  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    line="$(ii_var_lines_from_tmux | awk -F= -v name="$var" '$1 == name {print; exit}')"
    value="${line#*=}"
    if [[ -n "$line" && -n "$value" ]]; then
      fallback="$value"
    else
      label="${var#JJ_}"
      fallback="\$${(L)label}"
    fi
    rendered="${rendered//\$\{$var\}/$fallback}"
    rendered="${rendered//$var/$fallback}"
  done < <(ii_payload_required_vars "$payload_path")

  print -r -- "$rendered"
}

ii_payload_required_vars() {
  local payload_path="$1"
  grep -Eoh '\$\{JJ_[A-Za-z_][A-Za-z0-9_]*\}|JJ_[A-Za-z_][A-Za-z0-9_]*' "$payload_path" \
    | sed -E 's/^\$\{//; s/\}$//' \
    | sort -u
}

ii_payload_print_used_vars() {
  local payload_path="$1"
  local var line value label

  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    label="${var#JJ_}"
    line="$(ii_var_lines_from_tmux | awk -F= -v name="$var" '$1 == name {print; exit}')"
    value="${line#*=}"
    if [[ -z "$line" || -z "$value" ]]; then
      value="\$${(L)label}"
    fi
    print "${(L)label} used: ${value}"
  done < <(ii_payload_required_vars "$payload_path")
}
