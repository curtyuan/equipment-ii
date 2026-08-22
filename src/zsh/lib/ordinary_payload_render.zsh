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
  local ii_pr_name="$1" ii_pr_modifier="$2" ii_pr_original="$3" ii_pr_mode="${4:-ordinary}"
  local ii_pr_internal ii_pr_line ii_pr_value ii_pr_rendered ii_pr_source
  if [[ "$ii_pr_mode" == ordinary && ${+parameters[$ii_pr_name]} -eq 1 && -n "${(P)ii_pr_name}" ]]; then
    ii_pr_value="${(P)ii_pr_name}"
    ii_pr_source=shell
  else
    ii_pr_internal="$(ii_zsh_normalize_name "$ii_pr_name")" || return
    ii_pr_line="$(tmux show-environment "$ii_pr_internal" 2>/dev/null)" || ii_pr_line=''
    if [[ -n "$ii_pr_line" && -n "${ii_pr_line#*=}" ]]; then
      ii_pr_value="${ii_pr_line#*=}"
      ii_pr_source=ii
    else
      ii_pr_value="$ii_pr_original"
      ii_pr_source=missing
    fi
  fi
  ii_pr_rendered="$ii_pr_value"
  if [[ "$ii_pr_source" != missing && "$ii_pr_modifier" == :t ]]; then
    ii_pr_rendered="$(ii_zsh_payload_path_tail "$ii_pr_value")"
  fi
  ii_zsh_payload_record "$ii_pr_name" "$ii_pr_source" "$ii_pr_value"
  typeset -g II_PAYLOAD_RESOLVED_VALUE="$ii_pr_rendered"
}

ii_zsh_payload_render_text() {
  local text="$1" mode="${2:-ordinary}"
  local rendered='' ch next expression variable_name modifier parsed_name original
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
        parsed_name="${text[index+1,end-1]}"
        if [[ "$parsed_name" =~ '^[a-z_][a-z0-9_]*$' ]]; then
          if [[ "${text[end]}" == : ]] && ii_zsh_payload_is_powershell_scope "$parsed_name"; then
            rendered+="${text[index,end]}"
            index=$(( end + 1 ))
            continue
          fi
          original="${text[index,end-1]}"
          ii_zsh_payload_resolve "$parsed_name" '' "$original" "$mode" || return
          rendered+="$II_PAYLOAD_RESOLVED_VALUE"
          index=$end
          continue
        fi
      fi
    elif [[ "$ch" == '%' && "${text[index+1]}" =~ '[a-z_]' ]]; then
      end=$(( index + 2 ))
      while (( end <= length )) && [[ "${text[end]}" =~ '[a-z0-9_]' ]]; do (( ++end )); done
      if (( end <= length )) && [[ "${text[end]}" == '%' ]]; then
        parsed_name="${text[index+1,end-1]}"
        original="${text[index,end]}"
        ii_zsh_payload_resolve "$parsed_name" '' "$original" "$mode" || return
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

ii_zsh_combo_launch() {
  local relative_path="$1" copy_stages="${2:-0}"
  local root="${II_PAYLOAD_DIR:A}" payload_path backend identity session origin popup_command answer
  [[ "$relative_path" != /* && "$relative_path" != (..|../*|*/../*|*/..) ]] || {
    print -u2 -- "ii: invalid payload path: $relative_path"
    return 1
  }
  payload_path="${root}/${relative_path}"
  [[ -f "$payload_path" && "${payload_path:A}" == "${root}/"* ]] || {
    print -u2 -- "ii: payload not found: $relative_path"
    return 1
  }
  awk 'BEGIN { found=0 } /^[[:space:]]*#[[:space:]]*flow:[[:space:]]*1[[:space:]]*$/ { found=1 } END { exit !found }' "$payload_path" || {
    print -u2 -- "ii: selected payload is not an executable workflow"
    return 1
  }
  print -n -- 'Execute this combo workflow? [y/N] '
  if [[ -n "${II_INTERACTIVE_KEY:-}" ]]; then
    answer="$II_INTERACTIVE_KEY"
    print -r -- "$answer"
  else
    IFS= read -r answer || true
  fi
  [[ "${(L)answer}" == y ]] || {
    print -u2 -- 'ii: execution cancelled'
    return 1
  }
  if [[ "$copy_stages" == 1 ]]; then
    backend="$(ii_zsh_clip_effective)" || {
      print -u2 -- 'ii: clipboard unavailable'
      return 1
    }
  else
    backend=none
  fi
  identity="$(tmux display-message -p '#{session_id}'$'\t''#{pane_id}')" || return
  session="${identity%%$'\t'*}"
  origin="${identity#*$'\t'}"
  popup_command="${(q)II_GO_BIN} __combo-run ${(q)relative_path} ${(q)origin} ${(q)session} ${(q)copy_stages} ${(q)backend}"
  tmux display-popup -EE -T 'ii workflow' -w '90%' -h '90%' -d '#{pane_current_path}' "$popup_command"
}
