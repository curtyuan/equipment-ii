# Payload selection, filtering, rendering, and reporting.

jj_cmd_payload() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: jj payload [CATEGORY]
       jjp [CATEGORY]

Open the payload selector, render the selected template with fresh JJ_
variables from the tmux session, copy the result, and print the output.

CATEGORY may be all, shell, linux, windows, sqli, or xss.
EOF
    return 0
  fi

  jj_tmux_available || return
  jj_require_cmd fzf || return

  local filter="${1:-all}"
  local payloads payload selected rendered
  payloads="$(jj_payload_list)" || return
  if [[ -z "$payloads" ]]; then
    print -u2 "jj: no payloads found"
    return 1
  fi

  selected="$(print -r -- "$payloads" | jj_payload_filter "$filter" | jj_payload_select_fzf "$filter" | awk 'NF {print; exit}')" || return
  [[ -n "$selected" ]] || return

  payload="$(jj_payload_path_for "$selected")" || return
  rendered="$(jj_payload_render "$payload")" || return

  if jj_clip_copy "$rendered"; then
    print "payload copied successfully"
  else
    print "payload rendered; clipboard copy failed"
  fi

  print
  print -r -- "$rendered"
  print
  jj_payload_print_used_vars "$payload"
}

jj_payload_dir() {
  print -r -- "${JJ_PAYLOAD_DIR:-${HOME}/.config/jj/payloads}"
}

jj_payload_list() {
  local dir
  dir="$(jj_payload_dir)"
  if [[ ! -d "$dir" ]]; then
    print -u2 "jj: payload directory not found: $dir"
    print -u2 "jj: set JJ_PAYLOAD_DIR or create ~/.config/jj/payloads"
    return 1
  fi

  ( cd "$dir" && find . -type f | sed 's#^\./##' | sort )
}

jj_payload_filter() {
  local filter="${1:-all}"

  case "$filter" in
    all|"") cat ;;
    shell) awk '/^shell\//' ;;
    linux) awk '$0 ~ /(^|\/)linux(\/|$)/' ;;
    windows) awk '$0 ~ /(^|\/)windows(\/|$)/' ;;
    sqli) awk '/^sqli\//' ;;
    xss) awk '/^xss\//' ;;
    *) awk -v pat="$filter" 'index(tolower($0), tolower(pat)) > 0' ;;
  esac
}

jj_payload_select_fzf() {
  local filter="${1:-all}"
  fzf --prompt="jj payload:${filter}> " --height=80% --border
}

jj_payload_path_for() {
  local selected="$1"
  local dir
  dir="$(jj_payload_dir)"
  local payload_path="${dir%/}/${selected}"

  if [[ ! -f "$payload_path" ]]; then
    print -u2 "jj: payload not found: $selected"
    return 1
  fi

  print -r -- "$payload_path"
}

jj_payload_render() {
  local payload_path="$1"
  local rendered
  rendered="$(<"$payload_path")"

  local line name value
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="${line%%=*}"
    value="${line#*=}"
    rendered="${rendered//\$\{$name\}/$value}"
    rendered="${rendered//$name/$value}"
  done < <(jj_var_lines_from_tmux)

  print -r -- "$rendered"
}

jj_payload_required_vars() {
  local payload_path="$1"
  grep -Eoh '\$\{JJ_[A-Za-z_][A-Za-z0-9_]*\}|JJ_[A-Za-z_][A-Za-z0-9_]*' "$payload_path" \
    | sed -E 's/^\$\{//; s/\}$//' \
    | sort -u
}

jj_payload_print_used_vars() {
  local payload_path="$1"
  local var line value label

  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    line="$(jj_var_lines_from_tmux | awk -F= -v name="$var" '$1 == name {print; exit}')"
    [[ -n "$line" ]] || continue
    value="${line#*=}"
    label="${var#JJ_}"
    print "${(L)label} used: ${value}"
  done < <(jj_payload_required_vars "$payload_path")
}
