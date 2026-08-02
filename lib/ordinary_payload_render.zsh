# Shared payload token grammar with Zsh-owned ordinary state resolution.

ii_zsh_payload_path_tail() {
  local value="${1//\\//}"
  print -r -- "${value:t}"
}

ii_zsh_payload_is_powershell_scope() {
  [[ "$1" == (env|script|global|local|private) ]]
}

ii_zsh_payload_record() {
  local variable_name="$1" source="$2" variable_value="$3"
  if [[ -z "${II_PAYLOAD_RENDER_REPORT_SOURCE[$variable_name]:-}" ||
        "${II_PAYLOAD_RENDER_REPORT_SOURCE[$variable_name]}" == missing ]]; then
    II_PAYLOAD_RENDER_REPORT_SOURCE[$variable_name]="$source"
    II_PAYLOAD_RENDER_REPORT_VALUE[$variable_name]="$variable_value"
  fi
}

ii_zsh_payload_resolve() {
  local variable_name="$1" modifier="$2" original="$3" mode="${4:-ordinary}"
  local internal line variable_value rendered_value source
  if [[ "$mode" == ordinary && ${+parameters[$variable_name]} -eq 1 && -n "${(P)variable_name}" ]]; then
    variable_value="${(P)variable_name}"
    source=shell
  else
    internal="$(ii_zsh_normalize_name "$variable_name")" || return
    line="$(tmux show-environment "$internal" 2>/dev/null)" || line=''
    if [[ -n "$line" && -n "${line#*=}" ]]; then
      variable_value="${line#*=}"
      source=ii
    else
      variable_value="$original"
      source=missing
    fi
  fi
  rendered_value="$variable_value"
  if [[ "$source" != missing && "$modifier" == :t ]]; then
    rendered_value="$(ii_zsh_payload_path_tail "$variable_value")"
  fi
  ii_zsh_payload_record "$variable_name" "$source" "$variable_value"
  typeset -g II_PAYLOAD_RESOLVED_VALUE="$rendered_value"
}

ii_zsh_payload_render_text() {
  local text="$1" mode="${2:-ordinary}"
  local rendered='' ch next expression variable_name modifier token original
  local -i length=${#1} index=1 end
  typeset -gA II_PAYLOAD_RENDER_REPORT_SOURCE=()
  typeset -gA II_PAYLOAD_RENDER_REPORT_VALUE=()
  typeset -g II_PAYLOAD_RENDERED_TEXT=''

  while (( index <= length )); do
    ch="${text[index]}"
    if [[ "$ch" == '$' ]]; then
      next="${text[index+1]}"
      if [[ "$next" == '{' ]]; then
        end=$(( index + 2 ))
        while (( end <= length )) && [[ "${text[end]}" != '}' ]]; do (( ++end )); done
        if (( end <= length )); then
          expression="${text[index+2,end-1]}"
          if [[ "$expression" =~ '^([a-z_][a-z0-9_]*)(:t)?$' ]]; then
            variable_name="${match[1]}"
            modifier="${match[2]}"
            original="${text[index,end]}"
            ii_zsh_payload_resolve "$variable_name" "$modifier" "$original" "$mode" || return
            rendered+="$II_PAYLOAD_RESOLVED_VALUE"
            index=$(( end + 1 ))
            continue
          fi
        fi
      elif [[ "$next" =~ '[A-Za-z_]' ]]; then
        end=$(( index + 1 ))
        while (( end <= length )) && [[ "${text[end]}" =~ '[A-Za-z0-9_]' ]]; do (( ++end )); done
        token="${text[index+1,end-1]}"
        if [[ "$token" =~ '^[a-z_][a-z0-9_]*$' ]]; then
          if [[ "${text[end]}" == : ]] && ii_zsh_payload_is_powershell_scope "$token"; then
            rendered+="${text[index,end]}"
            index=$(( end + 1 ))
            continue
          fi
          original="${text[index,end-1]}"
          ii_zsh_payload_resolve "$token" '' "$original" "$mode" || return
          rendered+="$II_PAYLOAD_RESOLVED_VALUE"
          index=$end
          continue
        fi
      fi
    elif [[ "$ch" == '%' && "${text[index+1]}" =~ '[a-z_]' ]]; then
      end=$(( index + 2 ))
      while (( end <= length )) && [[ "${text[end]}" =~ '[a-z0-9_]' ]]; do (( ++end )); done
      if (( end <= length )) && [[ "${text[end]}" == '%' ]]; then
        token="${text[index+1,end-1]}"
        original="${text[index,end]}"
        ii_zsh_payload_resolve "$token" '' "$original" "$mode" || return
        rendered+="$II_PAYLOAD_RESOLVED_VALUE"
        index=$(( end + 1 ))
        continue
      fi
    fi
    rendered+="$ch"
    (( ++index ))
  done
  typeset -g II_PAYLOAD_RENDERED_TEXT="$rendered"
  print -rn -- "$rendered"
}
