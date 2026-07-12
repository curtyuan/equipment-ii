# ii_ variable helper functions.

ii_color_wrap() {
  local code="$1"
  local text="$2"
  print -r -- $'\033['"${code}m${text}"$'\033[0m'
}

ii_color_blue() {
  ii_color_wrap 34 "$1"
}

ii_color_red() {
  ii_color_wrap 31 "$1"
}

ii_color_green() {
  ii_color_wrap 32 "$1"
}

ii_var_normalize_name() {
  local name="$1"
  name="${name#export }"
  name="${name%%=*}"
  name="${(L)name}"
  [[ "$name" == ii_* ]] || name="ii_${name}"

  if [[ ! "$name" =~ '^ii_[a-z_][a-z0-9_]*$' ]]; then
    print -u2 "ii: invalid variable name: $1"
    return 1
  fi

  print -r -- "$name"
}

ii_var_name_from_payload_var() {
  local name="$1"
  name="${name#II_}"
  ii_var_normalize_name "$name"
}

ii_var_lines_from_tmux() {
  tmux show-environment | awk -F= '/^ii_[a-z0-9_]*=/{print}'
}

ii_var_filter_by_name() {
  local pattern="$1"
  pattern="${(L)pattern}"
  awk -F= -v pat="$pattern" 'tolower($1) ~ pat {print}'
}

ii_var_print_named_view() {
  local raw name line
  for raw in "$@"; do
    name="$(ii_var_normalize_name "$raw")" || return
    line="$(ii_var_line_by_name "$name")"
    [[ -n "$line" ]] || continue
    ii_var_print_name_value "$line"
  done
}

ii_var_print_cred_view() {
  ii_var_lines_from_tmux \
    | awk -F= '
        /^ii_(usert|passt|cuser|cpass|tuser|tpass|user[1-5]|pass[1-5])=/ {
          name = $1
          sub(/^ii_/, "", name)
          if (name == "cuser") {
            suffix = -2
            rank = 0
          } else if (name == "cpass") {
            suffix = -2
            rank = 1
          } else if (name == "tuser") {
            suffix = -1
            rank = 0
          } else if (name == "tpass") {
            suffix = -1
            rank = 1
          } else if (name == "usert") {
            suffix = 0
            rank = 0
          } else if (name == "passt") {
            suffix = 0
            rank = 1
          } else if (name ~ /^user/) {
            suffix = name
            sub(/^user/, "", suffix)
            rank = 0
          } else {
            suffix = name
            sub(/^pass/, "", suffix)
            rank = 1
          }
          print suffix "\t" rank "\t" $0
        }
      ' \
    | sort -n -k1,1 -k2,2 \
    | cut -f3- \
    | while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        ii_var_print_name_value "$line"
      done
}

ii_var_line_by_name() {
  local name="$1"
  ii_var_lines_from_tmux | awk -F= -v target="$name" '$1 == target {print; exit}'
}

ii_var_value_by_name() {
  local name="$1"
  local line
  line="$(ii_var_line_by_name "$name")"
  [[ -n "$line" ]] && print -r -- "${line#*=}"
}

ii_var_print_name_value() {
  local line="$1"
  local name="${line%%=*}"
  local value="${line#*=}"
  local shell_name
  shell_name="$(ii_var_shell_name "$name")"
  print "$(ii_color_blue "$shell_name")"
  print -r -- "$value"
}

ii_var_print_list() {
  local pattern="${1:-}"
  local line name value shell_name lower_pattern
  lower_pattern="${(L)pattern}"

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="${line%%=*}"
    value="${line#*=}"
    [[ -n "$value" ]] || continue
    shell_name="$(ii_var_shell_name "$name")"
    if [[ -n "$lower_pattern" && "${(L)shell_name}" != *"$lower_pattern"* ]]; then
      continue
    fi
    print "$(ii_color_blue "$shell_name")"
    print -r -- "$value"
  done < <(ii_var_lines_from_tmux | sort)
}

ii_var_default_names() {
  print domain
  print lhost
  print rhost
  print lport
  print rport
  print user1
  print pass1
  print user2
  print pass2
  print user3
  print pass3
  print user4
  print pass4
  print user5
  print pass5
  print cuser
  print cpass
  print tuser
  print tpass
  print directs
}

ii_var_set_candidates() {
  {
    ii_var_default_names
    ii_var_lines_from_tmux | awk -F= '{sub(/^ii_/, "", $1); print tolower($1)}'
  } | awk 'NF && !seen[tolower($0)]++ {print tolower($0)}'
}

ii_var_match_candidate() {
  local filter="$1"
  local matches count

  matches="$(ii_var_set_candidates | awk -v pat="${(L)filter}" 'index(tolower($0), pat) > 0')"
  count="$(print -r -- "$matches" | awk 'NF {count++} END {print count + 0}')"

  case "$count" in
    0)
      print -u2 "no matched"
      return 1
      ;;
    1)
      print -r -- "$matches" | awk 'NF {print; exit}'
      ;;
    *)
      print -r -- "$matches" | fzf -i --prompt='ii set var> ' --height=40% --border
      ;;
  esac
}

ii_var_get_matches() {
  local filter="$1"
  local pattern
  pattern="${(L)filter}"

  ii_var_lines_from_tmux \
    | awk -F= -v pat="$pattern" '
        index(tolower($1), pat) > 0 {
          print
        }
      ' \
    | sort
}

ii_var_get_entries_for_fzf() {
  local line name value preview

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="${line%%=*}"
    value="${line#*=}"
    name="${name#ii_}"
    preview="$(ii_one_line_preview "$value" 72)"
    print -r -- "$name"$'\t'"$preview"$'\t'"$line"
  done
}

ii_var_get_select_fzf() {
  fzf -i --ansi --prompt='ii get var> ' --height=40% --border \
    --bind='space:accept,q:abort,esc:abort' \
    --delimiter=$'\t' --with-nth=1,2 \
    --preview='printf "%s" {2}' \
    --preview-window='down:50%:wrap'
}

ii_var_shortcut_filter() {
  case "${(L)1}" in
    r) print RHOST ;;
    l) print LHOST ;;
    d) print DOMAIN ;;
    *) print -r -- "$1" ;;
  esac
}

ii_var_detect_interface_ipv4() {
  local interface="${1:-tun0}"
  local value

  ii_require_cmd ip || return
  value="$(ip -4 addr show dev "$interface" 2>/dev/null | awk '/ inet / { sub(/\/.*/, "", $2); print $2; exit }')"
  if [[ -z "$value" ]]; then
    print -u2 "ii: no IPv4 address detected on interface: $interface"
    return 1
  fi

  print -r -- "$value"
}

ii_var_auto_detect_lhost_enabled() {
  local enabled="${II_AUTO_DETECT_LHOST:-1}"
  case "${(L)enabled}" in
    0|false|no|off|disabled) return 1 ;;
    *) return 0 ;;
  esac
}

ii_var_is_rhost_name() {
  case "$1" in
    ii_rhost|ii_rhosts) return 0 ;;
    *) return 1 ;;
  esac
}

ii_var_auto_detect_lhost_for_rhost() {
  local name="$1"
  local interface="${II_AUTO_DETECT_LHOST_INTERFACE:-tun0}"
  local value

  ii_var_auto_detect_lhost_enabled || return 0
  ii_var_is_rhost_name "$name" || return 0

  value="$(ii_var_detect_interface_ipv4 "$interface")" || return 0
  tmux set-environment ii_lhost "$value" || return
  ii_export_var_line "ii_lhost=${value}" || return
  print "lhost has automatically sets as ${value}"
}

ii_enable_auto_sync() {
  typeset -g II_SYNC_LOADED_VARS=1
  precmd_functions=(${precmd_functions:#ii_sync_loaded_vars_precmd} ii_sync_loaded_vars_precmd)
}

ii_disable_auto_sync() {
  typeset -g II_SYNC_LOADED_VARS=0
  precmd_functions=(${precmd_functions:#ii_sync_loaded_vars_precmd})
}

ii_auto_sync_status() {
  local state="off" hook="absent"
  [[ "${II_SYNC_LOADED_VARS:-}" == "1" ]] && state="on"
  (( ${precmd_functions[(I)ii_sync_loaded_vars_precmd]} )) && hook="present"

  print "II_SYNC_LOADED_VARS=${II_SYNC_LOADED_VARS:-0}"
  print "auto-sync: ${state}"
  print "precmd hook: ${hook}"
}

ii_sync_loaded_vars_precmd() {
  [[ "${II_SYNC_LOADED_VARS:-}" == "1" ]] || return
  ii_tmux_available >/dev/null 2>&1 || return

  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ -n "${line#*=}" ]] || continue
    ii_export_var_line "$line" >/dev/null || return
  done < <(ii_var_lines_from_tmux)
}

ii_var_entries_for_fzf() {
  local name line value preview overflow entry populated_entries empty_entries
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    line="$(ii_var_line_by_name "ii_${name}")"
    value=""
    [[ -n "$line" ]] && value="${line#*=}"
    preview="$(ii_one_line_preview "$value" 72)"
    overflow=""
    [[ "$preview" != "$value" ]] && overflow="$(ii_color_red more)"
    entry="${name}"$'\t'"${preview}"$'\t'"${overflow}"$'\t'"${value}"
    if [[ -n "$value" ]]; then
      populated_entries+="${entry}"$'\n'
    else
      empty_entries+="${entry}"$'\n'
    fi
  done < <(ii_var_set_candidates)
  [[ -n "$populated_entries" ]] && print -rn -- "$populated_entries"
  [[ -n "$empty_entries" ]] && print -rn -- "$empty_entries"
  print -r -- "add new variable"$'\t'"Create or update a variable. Empty values are stored but skipped by ii load."$'\t\t'"Create or update a variable. Empty values are stored but skipped by ii load."
}

ii_var_display_lines_for_fzf() {
  sed 's/^ii_//'
}

ii_var_display_line() {
  local line="$1"
  print -r -- "${line#ii_}"
}

ii_var_line_from_display() {
  local line="$1"
  [[ "$line" == ii_* ]] || line="ii_${line}"
  print -r -- "$line"
}

ii_var_shell_name() {
  local name="$1"
  print -r -- "${name#ii_}"
}

ii_var_export_case() {
  local export_case="${II_EXPORT_CASE:-lower}"
  case "${(L)export_case}" in
    lower|upper|both) print -r -- "${(L)export_case}" ;;
    *)
      print -u2 "ii: invalid II_EXPORT_CASE: $export_case"
      print -u2 "ii: valid values are lower, upper, both"
      return 1
      ;;
  esac
}

ii_export_var_line() {
  local line="$1"
  local name="${line%%=*}"
  local value="${line#*=}"
  local shell_name export_case

  if [[ ! "$name" =~ '^ii_[a-z_][a-z0-9_]*$' ]]; then
    print -u2 "ii: refusing to export invalid variable line: $line"
    return 1
  fi

  shell_name="$(ii_var_shell_name "$name")"
  export_case="$(ii_var_export_case)" || return
  case "$export_case" in
    lower)
      typeset -gx "${shell_name}=${value}"
      ;;
    upper)
      typeset -gx "${(U)shell_name}=${value}"
      ;;
    both)
      typeset -gx "${shell_name}=${value}"
      typeset -gx "${(U)shell_name}=${value}"
      ;;
  esac
}
