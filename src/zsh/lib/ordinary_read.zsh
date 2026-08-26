# Zsh-owned read-only variable presentation and file output.

ii_zsh_color_enabled() {
  [[ -z "${NO_COLOR:-}" ]] || return 1
  case "${(L)${II_COLOR:-auto}}" in
    always) return 0 ;;
    never) return 1 ;;
    auto) [[ -t 1 ]] ;;
    *) [[ -t 1 ]] ;;
  esac
}

ii_zsh_print_key() {
  if ii_zsh_color_enabled; then
    print -r -- $'\e[34m'"$1"$'\e[0m'
  else
    print -r -- "$1"
  fi
}

ii_zsh_print_env_diff() {
  local color="$1" prefix="$2" name="$3" value="$4"
  if ii_zsh_color_enabled; then
    print -r -- "${color}${prefix} ${name}=${(qq)value}"$'\e[0m'
  else
    print -r -- "${prefix} ${name}=${(qq)value}"
  fi
}

ii_zsh_cmd_list() {
  shift
  ii_zsh_tmux_available || return
  local pattern="${(L)${1:-}}" line name value
  while IFS= read -r line; do
    [[ "$line" == *=* ]] || continue
    name="${line%%=*}"
    value="${line#*=}"
    [[ -n "$value" ]] || continue
    name="${name#ii_}"
    [[ -z "$pattern" || "${(L)name}" == *"$pattern"* ]] || continue
    ii_zsh_print_key "$name"
    print -r -- "$value"
  done < <(ii_zsh_tmux_variable_lines)
}

ii_zsh_output_entry_name() {
  local entry="$1" name
  entry="${entry%$'\r'}"
  entry="${entry#${entry%%[![:space:]]*}}"
  [[ -n "$entry" && "$entry" != \#* ]] || return 1
  if [[ "$entry" == export[[:space:]]* ]]; then
    entry="${entry#export}"
    entry="${entry#${entry%%[![:space:]]*}}"
  fi
  [[ "$entry" == *=* ]] || return 1
  name="${entry%%=*}"
  [[ "$name" != *[[:space:]]* && "${(L)name}" =~ '^[a-z_][a-z0-9_]*$' ]] || return 1
  REPLY="${(L)name}"
}

ii_zsh_cmd_output() {
  local command="$1"
  shift
  [[ "$command" == v && "${1:-}" == --out ]] && shift
  [[ $# -le 1 ]] || {
    print -u2 "ii: usage: ii v --out [PATH] | ii vo [PATH]"
    return 2
  }
  ii_zsh_tmux_available || return
  local output="${1:-.env}" output_abs parent temp line name value answer
  local count=0 kept_count=0 different=0
  local -A current_names current_values current_entries file_names file_values managed_names written
  output_abs="${output:A}"
  parent="${output_abs:h}"
  [[ -d "$parent" ]] || {
    print -u2 "ii: output directory not found: $parent"
    return 1
  }
  [[ ! -d "$output_abs" ]] || {
    print -u2 "ii: output path is a directory: $output_abs"
    return 1
  }
  temp="$(mktemp "${output_abs}.tmp.XXXXXX")" || {
    print -u2 "ii: failed to create temporary output beside: $output_abs"
    return 1
  }
  {
    while IFS= read -r line; do
      [[ "$line" == *=* ]] || continue
      name="${line%%=*}"
      value="${line#*=}"
      [[ -n "$value" ]] || continue
      name="${name#ii_}"
      current_names[$name]=1
      current_values[$name]="$value"
      current_entries[$name]="${name}=${(qq)value}"
      (( ++count ))
    done < <(ii_zsh_tmux_variable_lines)
    for name in ${(@f)$(ii_zsh_default_names)}; do
      managed_names[$name]=1
    done
    for name in ${(k)current_names}; do
      managed_names[$name]=1
    done

    if [[ ! -f "$output_abs" ]]; then
      for name in ${(ok)current_names}; do
        print -r -- "${current_entries[$name]}" >>"$temp"
      done
      command mv -f -- "$temp" "$output_abs" || {
        print -u2 "ii: failed to replace variable output: $output_abs"
        return 1
      }
      temp=""
      print -r -- "wrote $count variable(s) to $output_abs"
      return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
      ii_zsh_output_entry_name "$line" || continue
      name="$REPLY"
      (( ${+managed_names[$name]} )) || continue
      value="${line#*=}"
      file_names[$name]=1
      file_values[$name]="$(ii_zsh_unquote_file_value "$value")"
    done <"$output_abs"

    for name in ${(ok)file_names}; do
      if (( ! ${+current_names[$name]} )); then
        ii_zsh_print_env_diff $'\e[31m' - "$name" "${file_values[$name]}"
        different=1
      elif [[ "${file_values[$name]}" != "${current_values[$name]}" ]]; then
        ii_zsh_print_env_diff $'\e[31m' - "$name" "${file_values[$name]}"
        ii_zsh_print_env_diff $'\e[34m' + "$name" "${current_values[$name]}"
        different=1
      fi
    done
    for name in ${(ok)current_names}; do
      if (( ! ${+file_names[$name]} )); then
        ii_zsh_print_env_diff $'\e[34m' + "$name" "${current_values[$name]}"
        different=1
      fi
    done

    if (( different )); then
      print -n -- "Update $output_abs? (Y) update current variables / (C) cover all / (N) abort: "
      if [[ -t 0 ]]; then
        IFS= read -r -k 1 answer || true
        print
      else
        IFS= read -r answer || true
      fi
      case "${(L)answer}" in
        y)
          while IFS= read -r line || [[ -n "$line" ]]; do
            ii_zsh_output_entry_name "$line" || {
              print -r -- "$line" >>"$temp"
              continue
            }
            name="$REPLY"
            if (( ${+current_names[$name]} )); then
              (( ${+written[$name]} )) || print -r -- "${current_entries[$name]}" >>"$temp"
              written[$name]=1
            else
              print -r -- "$line" >>"$temp"
              (( ++kept_count ))
            fi
          done <"$output_abs"
          for name in ${(ok)current_names}; do
            (( ${+written[$name]} )) || print -r -- "${current_entries[$name]}" >>"$temp"
          done
          ;;
        c)
          while IFS= read -r line || [[ -n "$line" ]]; do
            ii_zsh_output_entry_name "$line" || {
              print -r -- "$line" >>"$temp"
              continue
            }
            name="$REPLY"
            (( ${+managed_names[$name]} )) && continue
            print -r -- "$line" >>"$temp"
            (( ++kept_count ))
          done <"$output_abs"
          for name in ${(ok)current_names}; do
            print -r -- "${current_entries[$name]}" >>"$temp"
          done
          ;;
        n|*)
          print -r -- aborted
          return 1
          ;;
      esac
    else
      print -r -- "$output_abs already matches the current variables"
      return 0
    fi
    command mv -f -- "$temp" "$output_abs" || {
      print -u2 "ii: failed to replace variable output: $output_abs"
      return 1
    }
    temp=""
  } always {
    [[ -n "$temp" ]] && command rm -f -- "$temp"
  }
  print -r -- "wrote $(( count + kept_count )) variable(s) to $output_abs"
}
