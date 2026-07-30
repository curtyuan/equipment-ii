# Executable combo workflow classification and strict parsing.

ii_workflow_reset() {
  typeset -g II_WORKFLOW_CLASS="legacy"
  typeset -g II_WORKFLOW_VERSION=""
  typeset -g II_WORKFLOW_DESCRIPTION=""
  typeset -g II_WORKFLOW_ERROR=""
  typeset -gi II_WORKFLOW_ERROR_LINE=0
  typeset -ga II_WORKFLOW_NOTES=()
  typeset -ga II_WORKFLOW_LANES=()
  typeset -gA II_WORKFLOW_LANE_ROLE=()
  typeset -gA II_WORKFLOW_LANE_ORDINAL=()
  typeset -ga II_WORKFLOW_STAGE_SHELLS=()
  typeset -ga II_WORKFLOW_STAGE_TITLES=()
  typeset -ga II_WORKFLOW_STAGE_LANES=()
  typeset -ga II_WORKFLOW_STAGE_ADVANCES=()
  typeset -ga II_WORKFLOW_STAGE_BODIES=()
  typeset -ga II_WORKFLOW_STAGE_LINES=()
}

ii_workflow_fail() {
  local workflow_path="$1" line="$2" message="$3"
  typeset -g II_WORKFLOW_CLASS="invalid"
  typeset -gi II_WORKFLOW_ERROR_LINE="$line"
  typeset -g II_WORKFLOW_ERROR="${workflow_path}:${line}: ${message}"
  print -u2 -r -- "ii: workflow parse error: ${II_WORKFLOW_ERROR}"
  return 1
}

ii_workflow_trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  print -r -- "$value"
}

ii_workflow_classify() {
  local workflow_path="$1" line
  [[ -r "$workflow_path" ]] || {
    print -u2 -r -- "ii: workflow file is not readable: $workflow_path"
    return 1
  }
  ii_workflow_reset
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(ii_workflow_trim "$line")"
    if [[ "$line" == '# flow:'* ]]; then
      ii_workflow_parse "$workflow_path"
      return
    fi
  done < "$workflow_path"
  return 0
}

ii_workflow_parse() {
  local workflow_path="$1" line trimmed rest shell title lane role name advance
  local body="" stage_has_command=0 flow_seen=0 stage_open=0 stage_line=0
  local line_no=0 first_stage_seen=0
  local -a lines

  [[ -r "$workflow_path" ]] || {
    print -u2 -r -- "ii: workflow file is not readable: $workflow_path"
    return 1
  }
  ii_workflow_reset
  typeset -g II_WORKFLOW_CLASS="invalid"

  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("${line%$'\r'}")
  done < "$workflow_path"

  for (( line_no = 1; line_no <= ${#lines}; line_no++ )); do
    line="${lines[line_no]}"
    trimmed="$(ii_workflow_trim "$line")"

    if (( line_no == 1 )) && [[ "$trimmed" == '# description:'* ]]; then
      II_WORKFLOW_DESCRIPTION="$(ii_workflow_trim "${trimmed#\# description:}")"
      continue
    fi

    if (( ! stage_open )); then
      if [[ "$trimmed" == '# flow:'* ]]; then
        (( flow_seen )) && { ii_workflow_fail "$workflow_path" "$line_no" "duplicate flow marker"; return; }
        rest="$(ii_workflow_trim "${trimmed#\# flow:}")"
        [[ "$rest" == "1" ]] || { ii_workflow_fail "$workflow_path" "$line_no" "unsupported flow version: ${rest:-[empty]}"; return; }
        flow_seen=1
        II_WORKFLOW_VERSION=1
        continue
      fi
      if [[ "$trimmed" == '# note:'* ]]; then
        (( flow_seen )) || { ii_workflow_fail "$workflow_path" "$line_no" "note must follow the flow marker"; return; }
        rest="$(ii_workflow_trim "${trimmed#\# note:}")"
        [[ -n "$rest" ]] || { ii_workflow_fail "$workflow_path" "$line_no" "note must not be empty"; return; }
        II_WORKFLOW_NOTES+=("$rest")
        continue
      fi
      if [[ "$trimmed" == '# stage:'* ]]; then
        (( flow_seen )) || { ii_workflow_fail "$workflow_path" "$line_no" "stage appears before the flow marker"; return; }
        rest="$(ii_workflow_trim "${trimmed#\# stage:}")"
        [[ "$rest" == *'|'* ]] || { ii_workflow_fail "$workflow_path" "$line_no" "stage requires SHELL | TITLE"; return; }
        shell="$(ii_workflow_trim "${rest%%|*}")"
        title="$(ii_workflow_trim "${rest#*|}")"
        [[ -n "$shell" && "$shell" != *'|'* ]] || { ii_workflow_fail "$workflow_path" "$line_no" "stage shell is missing or malformed"; return; }
        [[ -n "$title" && "$title" != *'|'* ]] || { ii_workflow_fail "$workflow_path" "$line_no" "stage title is missing or malformed"; return; }

        (( line_no + 2 <= ${#lines} )) || { ii_workflow_fail "$workflow_path" "$line_no" "stage is missing lane and advance directives"; return; }
        trimmed="$(ii_workflow_trim "${lines[line_no + 1]}")"
        [[ "$trimmed" == '# lane:'* ]] || { ii_workflow_fail "$workflow_path" "$(( line_no + 1 ))" "lane must immediately follow stage"; return; }
        lane="$(ii_workflow_trim "${trimmed#\# lane:}")"
        if ! [[ "$lane" =~ '^(kali|remote)-[[:alnum:]][[:alnum:]_-]*$' ]]; then
          ii_workflow_fail "$workflow_path" "$(( line_no + 1 ))" "invalid lane name: ${lane:-[empty]}"
          return
        fi
        role="${lane%%-*}"
        name="${lane#*-}"

        trimmed="$(ii_workflow_trim "${lines[line_no + 2]}")"
        [[ "$trimmed" == '# advance:'* ]] || { ii_workflow_fail "$workflow_path" "$(( line_no + 2 ))" "advance must immediately follow lane"; return; }
        advance="$(ii_workflow_trim "${trimmed#\# advance:}")"
        [[ "$advance" == "confirm" ]] || { ii_workflow_fail "$workflow_path" "$(( line_no + 2 ))" "unsupported advance mode: ${advance:-[empty]}"; return; }

        if [[ -z "${II_WORKFLOW_LANE_ORDINAL[$lane]-}" ]]; then
          (( ${#II_WORKFLOW_LANES} < 3 )) || { ii_workflow_fail "$workflow_path" "$(( line_no + 1 ))" "more than three distinct lanes"; return; }
          II_WORKFLOW_LANES+=("$lane")
          II_WORKFLOW_LANE_ROLE[$lane]="$role"
          II_WORKFLOW_LANE_ORDINAL[$lane]="${#II_WORKFLOW_LANES}"
        fi
        II_WORKFLOW_STAGE_SHELLS+=("$shell")
        II_WORKFLOW_STAGE_TITLES+=("$title")
        II_WORKFLOW_STAGE_LANES+=("$lane")
        II_WORKFLOW_STAGE_ADVANCES+=("$advance")
        II_WORKFLOW_STAGE_LINES+=("$line_no")
        body=""
        stage_has_command=0
        stage_open=1
        first_stage_seen=1
        stage_line="$line_no"
        line_no=$(( line_no + 2 ))
        continue
      fi
      [[ -z "$trimmed" ]] && continue
      if [[ "$trimmed" == \#* ]]; then
        if (( flow_seen )); then
          ii_workflow_fail "$workflow_path" "$line_no" "unknown workflow metadata or comment before first stage"
          return
        fi
        continue
      fi
      ii_workflow_fail "$workflow_path" "$line_no" "executable text appears before the first stage"
      return
    fi

    if [[ "$trimmed" == '# stage:'* ]]; then
      (( stage_has_command )) || { ii_workflow_fail "$workflow_path" "$stage_line" "stage body is empty"; return; }
      II_WORKFLOW_STAGE_BODIES+=("${body%$'\n'}")
      stage_open=0
      (( line_no-- ))
      continue
    fi
    if [[ "$trimmed" == '# flow:'* || "$trimmed" == '# lane:'* || "$trimmed" == '# advance:'* || "$trimmed" == '# note:'* || "$trimmed" == '# description:'* ]]; then
      ii_workflow_fail "$workflow_path" "$line_no" "workflow metadata is misplaced inside a stage body"
      return
    fi
    body+="$line"$'\n'
    [[ -n "$trimmed" && "$trimmed" != \#* ]] && stage_has_command=1
  done

  (( flow_seen )) || { ii_workflow_fail "$workflow_path" 1 "missing flow marker"; return; }
  (( first_stage_seen && stage_open )) || { ii_workflow_fail "$workflow_path" "${line_no:-1}" "workflow has no stages"; return; }
  (( stage_has_command )) || { ii_workflow_fail "$workflow_path" "$stage_line" "stage body is empty"; return; }
  II_WORKFLOW_STAGE_BODIES+=("${body%$'\n'}")
  typeset -g II_WORKFLOW_CLASS="workflow"
  return 0
}

ii_workflow_is_workflow() {
  [[ "${II_WORKFLOW_CLASS:-legacy}" == "workflow" ]]
}

ii_workflow_render_file() {
  local workflow_path="$1" index name source value display=""
  local -A report_source report_value
  typeset -ga II_WORKFLOW_RENDERED_BODIES=()
  ii_workflow_classify "$workflow_path" || return
  ii_workflow_is_workflow || return 2

  for (( index = 1; index <= ${#II_WORKFLOW_STAGE_BODIES}; index++ )); do
    ii_payload_render_text "${II_WORKFLOW_STAGE_BODIES[index]}" >/dev/null || return
    II_WORKFLOW_RENDERED_BODIES+=("$II_PAYLOAD_RENDERED_TEXT")
    for name in ${(k)II_PAYLOAD_RENDER_REPORT_SOURCE}; do
      source="${II_PAYLOAD_RENDER_REPORT_SOURCE[$name]}"
      value="${II_PAYLOAD_RENDER_REPORT_VALUE[$name]}"
      if [[ -z "${report_source[$name]-}" || "${report_source[$name]}" == missing ]]; then
        report_source[$name]="$source"
        report_value[$name]="$value"
      fi
    done
    (( index > 1 )) && display+=$'\n\n'
    display+="# --- lane${II_WORKFLOW_LANE_ORDINAL[${II_WORKFLOW_STAGE_LANES[index]}]}: ${II_WORKFLOW_STAGE_LANES[index]} | ${II_WORKFLOW_STAGE_SHELLS[index]} | ${II_WORKFLOW_STAGE_TITLES[index]} ---"$'\n'
    display+="${II_WORKFLOW_RENDERED_BODIES[index]}"
  done

  typeset -gA II_PAYLOAD_RENDER_REPORT_SOURCE=()
  typeset -gA II_PAYLOAD_RENDER_REPORT_VALUE=()
  for name in ${(k)report_source}; do
    II_PAYLOAD_RENDER_REPORT_SOURCE[$name]="${report_source[$name]}"
    II_PAYLOAD_RENDER_REPORT_VALUE[$name]="${report_value[$name]}"
  done
  typeset -g II_PAYLOAD_RENDERED_TEXT="$display"
  print -rn -- "$display"
}

ii_workflow_preview_text() {
  local index item lane ordinal output=""
  if (( ${#II_WORKFLOW_NOTES} )); then
    output+="[notes]"$'\n'
    for item in "$II_WORKFLOW_NOTES[@]"; do
      output+="- ${item}"$'\n'
    done
    output+=$'\n'
  fi
  for (( index = 1; index <= ${#II_WORKFLOW_STAGE_BODIES}; index++ )); do
    lane="${II_WORKFLOW_STAGE_LANES[index]}"
    ordinal="${II_WORKFLOW_LANE_ORDINAL[$lane]}"
    (( index > 1 )) && output+=$'\n'
    output+="[stage ${index}/${#II_WORKFLOW_STAGE_BODIES}] lane${ordinal}: ${lane} | ${II_WORKFLOW_STAGE_SHELLS[index]} | ${II_WORKFLOW_STAGE_TITLES[index]}"$'\n'
    output+="advance: ${II_WORKFLOW_STAGE_ADVANCES[index]}"$'\n'
    output+="${II_WORKFLOW_STAGE_BODIES[index]}"$'\n'
  done
  print -rn -- "${output%$'\n'}"
}

ii_workflow_copy_stages() {
  local index answer lane ordinal
  for (( index = 1; index <= ${#II_WORKFLOW_RENDERED_BODIES}; index++ )); do
    lane="${II_WORKFLOW_STAGE_LANES[index]}"
    ordinal="${II_WORKFLOW_LANE_ORDINAL[$lane]}"
    if (( index > 1 )); then
      print
      print "Stage ${index}/${#II_WORKFLOW_RENDERED_BODIES} ready for copy"
      print "lane${ordinal}: ${lane} | ${II_WORKFLOW_STAGE_SHELLS[index]} | ${II_WORKFLOW_STAGE_TITLES[index]}"
      printf 'Press y to copy, n/Esc to abort. '
      if [[ -n "${II_INTERACTIVE_KEY:-}" ]]; then
        answer="$II_INTERACTIVE_KEY"
        print -r -- "$answer"
      elif [[ -t 0 ]]; then
        read -r -k 1 answer
        print
      elif [[ -r /dev/tty ]]; then
        read -r -k 1 answer </dev/tty
        print
      else
        print -u2 "ii: cannot confirm workflow copy without a terminal"
        return 1
      fi
      [[ "${(L)answer}" == y ]] || { print "workflow copy cancelled"; return 1; }
    fi
    if ii_clip_copy "${II_WORKFLOW_RENDERED_BODIES[index]}"; then
      print "stage ${index}/${#II_WORKFLOW_RENDERED_BODIES} copied successfully"
    else
      print -u2 "ii: clipboard copy failed for workflow stage ${index}"
      return 1
    fi
  done
}
