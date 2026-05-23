# Payload selection, filtering, rendering, and reporting.

ii_cmd_payload() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOF'
usage: ii payload [CATEGORY]
       ii p [CATEGORY]

Open the payload selector, render the selected template with fresh II_
variables from the tmux session, copy the result, and print the output.
The selector shows a single-line rendered preview in the list and a full
selected preview at the bottom. A first-line "# description: ..." metadata line
is shown in preview but omitted from copied output.

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

  selected="$(print -r -- "$payloads" | ii_payload_filter "$filter" | ii_payload_entries_for_fzf | ii_payload_select_fzf "$filter" | awk -F '\t' 'NF {print $1; exit}')" || return
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
  print -r -- "${II_PAYLOAD_DIR:-${HOME}/.config/ii/payloads}"
}

ii_payload_list() {
  local dir
  dir="$(ii_payload_dir)"
  if [[ ! -d "$dir" ]]; then
    print -u2 "ii: payload directory not found: $dir"
    print -u2 "ii: set II_PAYLOAD_DIR or create ~/.config/ii/payloads"
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
  local plugin_file payload_dir
  plugin_file="${II_PLUGIN_DIR%/}/ii.plugin.zsh"
  payload_dir="$(ii_payload_dir)"

  fzf --ansi --prompt="ii payload:${filter}> " --height=80% --border --delimiter=$'\t' --with-nth=1,2,3 \
    --bind='enter:accept' \
    --preview="zsh -fc 'source \"\$1\"; export II_PAYLOAD_DIR=\"\$2\"; ii_payload_preview_fzf \"\$3\" \$'\'' Enter Render/Copy     Type Filter\n Esc Abort'\''' -- ${(q)plugin_file} ${(q)payload_dir} {1}" \
    --preview-window='down:50%:nowrap:noinfo'
}

ii_payload_entries_for_fzf() {
  local selected payload rendered preview overflow
  while IFS= read -r selected; do
    [[ -n "$selected" ]] || continue
    payload="$(ii_payload_path_for "$selected")" || return
    rendered="$(ii_payload_render "$payload")" || return
    preview="$(ii_one_line_preview "$rendered" 96)"
    overflow=""
    [[ "$preview" != "$rendered" ]] && overflow=$'\033[31mmore\033[0m'
    print -r -- "$selected"$'\t'"$preview"$'\t'"$overflow"
  done
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
  rendered="$(ii_payload_body "$payload_path")"

  local var line value label fallback
  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    line="$(ii_var_lines_from_tmux | awk -F= -v name="$var" '$1 == name {print; exit}')"
    value="${line#*=}"
    if [[ -n "$line" && -n "$value" ]]; then
      fallback="$value"
    else
      label="${var#II_}"
      fallback="\$${(L)label}"
    fi
    rendered="${rendered//\$\{$var\}/$fallback}"
    rendered="${rendered//$var/$fallback}"
  done < <(ii_payload_required_vars "$payload_path")

  print -r -- "$rendered"
}

ii_payload_preview() {
  local selected="$1"
  local payload description
  payload="$(ii_payload_path_for "$selected")" || return
  description="$(ii_payload_description "$payload")"
  if [[ -n "$description" ]]; then
    print -r -- "description: $description"
    print -r -- "--------------------------------------------------------------------------------"
  fi
  ii_payload_render "$payload"
}

ii_payload_preview_fzf() {
  local selected="$1"
  local footer="$2"
  local payload description
  payload="$(ii_payload_path_for "$selected")" || return
  description="$(ii_payload_description "$payload")"
  ii_payload_render "$payload" | ii_fzf_print_preview_blocks "$description" "$footer"
}

ii_payload_description() {
  local payload_path="$1"
  awk '
    NR == 1 && $0 ~ /^# description:[[:space:]]*/ {
      sub(/^# description:[[:space:]]*/, "")
      print
      exit
    }
  ' "$payload_path"
}

ii_payload_body() {
  local payload_path="$1"
  awk '
    NR == 1 && $0 ~ /^# description:[[:space:]]*/ { next }
    { print }
  ' "$payload_path"
}

ii_payload_required_vars() {
  local payload_path="$1"
  grep -Eoh '\$\{II_[A-Za-z_][A-Za-z0-9_]*\}|II_[A-Za-z_][A-Za-z0-9_]*' "$payload_path" \
    | sed -E 's/^\$\{//; s/\}$//' \
    | sort -u
}

ii_payload_print_used_vars() {
  local payload_path="$1"
  local var line value label

  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    label="${var#II_}"
    line="$(ii_var_lines_from_tmux | awk -F= -v name="$var" '$1 == name {print; exit}')"
    value="${line#*=}"
    if [[ -z "$line" || -z "$value" ]]; then
      value="\$${(L)label}"
    fi
    print "${(L)label} used: ${value}"
  done < <(ii_payload_required_vars "$payload_path")
}
