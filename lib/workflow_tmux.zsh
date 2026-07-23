# Tmux pane discovery, spatial lane assignment, and workflow session memory.

typeset -g II_WORKFLOW_MEMORY_OPTION='@ii_workflow_lane_bindings'

ii_workflow_assignment_reset() {
  typeset -gA II_WORKFLOW_LANE_PANE=()
  typeset -gA II_WORKFLOW_LANE_SOURCE=()
  typeset -gA II_WORKFLOW_PANE_LANE=()
}

ii_workflow_assign_lane() {
  local lane="$1" pane="$2" source="${3:-manual}"
  local old_pane="${II_WORKFLOW_LANE_PANE[$lane]-}"
  local other_lane="${II_WORKFLOW_PANE_LANE[$pane]-}"

  [[ "$old_pane" == "$pane" ]] && {
    II_WORKFLOW_LANE_SOURCE[$lane]="$source"
    return
  }
  if [[ -n "$other_lane" && "$other_lane" != "$lane" ]]; then
    if [[ -n "$old_pane" ]]; then
      II_WORKFLOW_LANE_PANE[$other_lane]="$old_pane"
      II_WORKFLOW_PANE_LANE[$old_pane]="$other_lane"
      II_WORKFLOW_LANE_SOURCE[$other_lane]="manual"
    else
      unset "II_WORKFLOW_LANE_PANE[$other_lane]"
      unset "II_WORKFLOW_LANE_SOURCE[$other_lane]"
    fi
  elif [[ -n "$old_pane" ]]; then
    unset "II_WORKFLOW_PANE_LANE[$old_pane]"
  fi
  II_WORKFLOW_LANE_PANE[$lane]="$pane"
  II_WORKFLOW_PANE_LANE[$pane]="$lane"
  II_WORKFLOW_LANE_SOURCE[$lane]="$source"
}

ii_workflow_toggle_lane() {
  local lane="$1" pane="$2"
  if [[ "${II_WORKFLOW_LANE_PANE[$lane]-}" == "$pane" ]]; then
    unset "II_WORKFLOW_LANE_PANE[$lane]"
    unset "II_WORKFLOW_LANE_SOURCE[$lane]"
    unset "II_WORKFLOW_PANE_LANE[$pane]"
  else
    ii_workflow_assign_lane "$lane" "$pane" manual
  fi
}

ii_workflow_assignments_complete() {
  local lane pane
  local -A seen
  for lane in "$II_WORKFLOW_LANES[@]"; do
    pane="${II_WORKFLOW_LANE_PANE[$lane]-}"
    [[ -n "$pane" && -z "${seen[$pane]-}" ]] || return 1
    seen[$pane]=1
  done
}

ii_workflow_memory_read() {
  local session="$1" data line lane pane snapshot snapshot_pane current_session window dead in_mode command
  local -A used
  typeset -gA II_WORKFLOW_REMEMBERED_PANE=()
  data="$(tmux show-options -t "$session" -qv "$II_WORKFLOW_MEMORY_OPTION" 2>/dev/null)"
  while IFS= read -r line; do
    [[ "$line" == *=* ]] || continue
    lane="${line%%=*}"
    pane="${line#*=}"
    [[ "$lane" =~ '^(kali|remote)-[[:alnum:]][[:alnum:]_-]*$' && "$pane" == %<-> ]] || continue
    snapshot="$(ii_tmux_pane_snapshot "$pane")"
    [[ -n "$snapshot" ]] || continue
    IFS=$'\t' read -r snapshot_pane current_session window dead in_mode command <<< "$snapshot"
    [[ "$current_session" == "$session" ]] || continue
    [[ -z "${used[$pane]-}" ]] || continue
    II_WORKFLOW_REMEMBERED_PANE[$lane]="$pane"
    used[$pane]="$lane"
  done <<< "$data"
}

ii_workflow_memory_write() {
  local session="$1" lane other pane data=""
  local -A merged used
  for lane in ${(ok)II_WORKFLOW_REMEMBERED_PANE}; do
    pane="${II_WORKFLOW_REMEMBERED_PANE[$lane]}"
    [[ -z "${used[$pane]-}" ]] || continue
    merged[$lane]="$pane"
    used[$pane]="$lane"
  done
  for lane in ${(ok)II_WORKFLOW_LANE_PANE}; do
    pane="${II_WORKFLOW_LANE_PANE[$lane]}"
    for other in ${(k)merged}; do
      [[ "$other" != "$lane" && "${merged[$other]}" == "$pane" ]] && unset "merged[$other]"
    done
    merged[$lane]="$pane"
  done
  for lane in ${(ok)merged}; do
    data+="${lane}=${merged[$lane]}"$'\n'
  done
  tmux set-option -t "$session" "$II_WORKFLOW_MEMORY_OPTION" "${data%$'\n'}"
}

ii_workflow_discover_panes() {
  local session="$1" line pane session_id window window_name index left top width height dead command title pane_path
  local format
  typeset -ga II_WORKFLOW_WINDOWS=()
  typeset -gA II_WORKFLOW_WINDOW_NAME=()
  typeset -ga II_WORKFLOW_PANES=()
  typeset -gA II_WORKFLOW_PANE_WINDOW=()
  typeset -gA II_WORKFLOW_PANE_LEFT=()
  typeset -gA II_WORKFLOW_PANE_TOP=()
  typeset -gA II_WORKFLOW_PANE_WIDTH=()
  typeset -gA II_WORKFLOW_PANE_HEIGHT=()
  typeset -gA II_WORKFLOW_PANE_COMMAND=()
  typeset -gA II_WORKFLOW_PANE_TITLE=()
  typeset -gA II_WORKFLOW_PANE_PATH=()

  while IFS=$'\t' read -r window index window_name; do
    [[ -n "$window" ]] || continue
    II_WORKFLOW_WINDOWS+=("$window")
    II_WORKFLOW_WINDOW_NAME[$window]="${index}:${window_name}"
  done < <(tmux list-windows -t "$session" -F '#{window_id}'$'\t''#{window_index}'$'\t''#{window_name}')

  format='#{pane_id}'$'\t''#{session_id}'$'\t''#{window_id}'$'\t''#{pane_left}'$'\t''#{pane_top}'$'\t''#{pane_width}'$'\t''#{pane_height}'$'\t''#{pane_dead}'$'\t''#{pane_current_command}'$'\t''#{pane_title}'$'\t''#{pane_current_path}'
  while IFS= read -r line; do
    IFS=$'\t' read -r pane session_id window left top width height dead command title pane_path <<< "$line"
    [[ -n "$pane" && "$session_id" == "$session" && "$dead" != 1 ]] || continue
    II_WORKFLOW_PANES+=("$pane")
    II_WORKFLOW_PANE_WINDOW[$pane]="$window"
    II_WORKFLOW_PANE_LEFT[$pane]="$left"
    II_WORKFLOW_PANE_TOP[$pane]="$top"
    II_WORKFLOW_PANE_WIDTH[$pane]="$width"
    II_WORKFLOW_PANE_HEIGHT[$pane]="$height"
    II_WORKFLOW_PANE_COMMAND[$pane]="$command"
    II_WORKFLOW_PANE_TITLE[$pane]="$title"
    II_WORKFLOW_PANE_PATH[$pane]="$pane_path"
  done < <(tmux list-panes -s -t "$session" -F "$format")
  (( ${#II_WORKFLOW_PANES} )) || { print -u2 "ii: no usable panes in session"; return 1; }
}

ii_workflow_detect_initial_assignments() {
  local session="$1" origin="$2" lane role pane remembered
  ii_workflow_assignment_reset
  ii_workflow_memory_read "$session"

  for lane in "$II_WORKFLOW_LANES[@]"; do
    remembered="${II_WORKFLOW_REMEMBERED_PANE[$lane]-}"
    if [[ -n "$remembered" && -z "${II_WORKFLOW_PANE_LANE[$remembered]-}" ]]; then
      ii_workflow_assign_lane "$lane" "$remembered" remembered
    fi
  done
  for lane in "$II_WORKFLOW_LANES[@]"; do
    [[ -n "${II_WORKFLOW_LANE_PANE[$lane]-}" ]] && continue
    role="${II_WORKFLOW_LANE_ROLE[$lane]}"
    if [[ "$role" == kali && -n "$origin" && -z "${II_WORKFLOW_PANE_LANE[$origin]-}" ]]; then
      ii_workflow_assign_lane "$lane" "$origin" detected
      continue
    fi
    if [[ "$role" == remote ]]; then
      for pane in "$II_WORKFLOW_PANES[@]"; do
        [[ -z "${II_WORKFLOW_PANE_LANE[$pane]-}" && "$pane" != "$origin" ]] || continue
        case "${II_WORKFLOW_PANE_COMMAND[$pane]}" in
          nc|ncat|netcat|socat|ssh|python|python3|pwsh|powershell|cmd.exe) ii_workflow_assign_lane "$lane" "$pane" detected; break ;;
        esac
      done
    fi
    [[ -n "${II_WORKFLOW_LANE_PANE[$lane]-}" ]] && continue
    for pane in "$II_WORKFLOW_PANES[@]"; do
      [[ -z "${II_WORKFLOW_PANE_LANE[$pane]-}" ]] || continue
      ii_workflow_assign_lane "$lane" "$pane" detected
      break
    done
  done
}

ii_workflow_window_panes() {
  local window="$1" pane
  for pane in "$II_WORKFLOW_PANES[@]"; do
    [[ "${II_WORKFLOW_PANE_WINDOW[$pane]}" == "$window" ]] && print -r -- "$pane"
  done
}

ii_workflow_draw_selector() {
  local window="$1" cursor="$2" active_lane="$3" pane lane ordinal source marker
  local rows="" columns="${COLUMNS:-100}" lines="${LINES:-32}"
  (( columns > 120 )) && columns=120
  (( columns < 50 )) && columns=50
  (( lines > 36 )) && lines=36
  (( lines < 16 )) && lines=16

  print -n -- $'\033[2J\033[H'
  print "Workflow lane assignment · window ${II_WORKFLOW_WINDOW_NAME[$window]} (${window})"
  print "h/j/k/l move · [/] window · Space toggle active · 1/2/3 assign · Enter confirm · Esc/q abort"
  print "Active: lane${II_WORKFLOW_LANE_ORDINAL[$active_lane]} ${active_lane}"
  print
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    lane="${II_WORKFLOW_PANE_LANE[$pane]-}"
    marker=" "
    [[ "$pane" == "$cursor" ]] && marker='>'
    if [[ -n "$lane" ]]; then
      ordinal="${II_WORKFLOW_LANE_ORDINAL[$lane]}"
      source="${II_WORKFLOW_LANE_SOURCE[$lane]}"
      rows+="$pane"$'\t'"${II_WORKFLOW_PANE_LEFT[$pane]}"$'\t'"${II_WORKFLOW_PANE_TOP[$pane]}"$'\t'"${II_WORKFLOW_PANE_WIDTH[$pane]}"$'\t'"${II_WORKFLOW_PANE_HEIGHT[$pane]}"$'\t'"${marker} [${ordinal}/lane${ordinal}] ${lane} · ${source}"$'\t'"${II_WORKFLOW_PANE_COMMAND[$pane]}"$'\n'
    else
      rows+="$pane"$'\t'"${II_WORKFLOW_PANE_LEFT[$pane]}"$'\t'"${II_WORKFLOW_PANE_TOP[$pane]}"$'\t'"${II_WORKFLOW_PANE_WIDTH[$pane]}"$'\t'"${II_WORKFLOW_PANE_HEIGHT[$pane]}"$'\t'"${marker} unassigned"$'\t'"${II_WORKFLOW_PANE_COMMAND[$pane]}"$'\n'
    fi
  done < <(ii_workflow_window_panes "$window")

  print -rn -- "$rows" | awk -F '\t' -v W="$columns" -v H="$(( lines - 7 ))" '
    function put(x,y,s, i) { if (y<1||y>H) return; for(i=1;i<=length(s)&&x+i-1<=W;i++) if(x+i-1>=1) c[y,x+i-1]=substr(s,i,1) }
    { p[NR]=$1; l[NR]=$2; t[NR]=$3; w[NR]=$4; h[NR]=$5; label[NR]=$6; cmd[NR]=$7; maxx=(l[NR]+w[NR]>maxx?l[NR]+w[NR]:maxx); maxy=(t[NR]+h[NR]>maxy?t[NR]+h[NR]:maxy) }
    END {
      for(n=1;n<=NR;n++) {
        x=1+int(l[n]*(W-2)/maxx); y=2+int(t[n]*(H-3)/maxy)
        ww=int(w[n]*(W-2)/maxx); hh=int(h[n]*(H-3)/maxy)
        if(ww<12)ww=12; if(x+ww>W)ww=W-x; if(hh<3)hh=3; if(y+hh>H)hh=H-y
        put(x,y-1,label[n]); put(x,y,"+" sprintf("%*s",ww-2,"") "+")
        for(j=1;j<ww;j++){c[y,x+j]="-";c[y+hh,x+j]="-"} c[y,x]="+";c[y,x+ww]="+";c[y+hh,x]="+";c[y+hh,x+ww]="+"
        for(j=1;j<hh;j++){c[y+j,x]="|";c[y+j,x+ww]="|"}
        put(x+2,y+1,p[n] "  " cmd[n])
      }
      for(y=1;y<=H;y++){s="";for(x=1;x<=W;x++)s=s ((y SUBSEP x) in c?c[y,x]:" ");sub(/[ ]+$/, "", s);print s}
    }'
  print
  for lane in "$II_WORKFLOW_LANES[@]"; do
    print "lane${II_WORKFLOW_LANE_ORDINAL[$lane]} ${lane} -> ${II_WORKFLOW_LANE_PANE[$lane]:-[unassigned]} (${II_WORKFLOW_LANE_SOURCE[$lane]:-manual})"
  done
}

ii_workflow_spatial_select() {
  local session="$1" origin="$2" window cursor active_lane key index pane_count
  local -a visible
  ii_workflow_discover_panes "$session" || return
  ii_workflow_detect_initial_assignments "$session" "$origin"
  window="${II_WORKFLOW_PANE_WINDOW[$origin]:-${II_WORKFLOW_WINDOWS[1]}}"
  active_lane="${II_WORKFLOW_LANES[1]}"
  visible=("${(@f)$(ii_workflow_window_panes "$window")}")
  cursor="${visible[1]}"

  while true; do
    visible=("${(@f)$(ii_workflow_window_panes "$window")}")
    (( ${#visible} )) || return 1
    (( ${visible[(Ie)$cursor]} )) || cursor="${visible[1]}"
    ii_workflow_draw_selector "$window" "$cursor" "$active_lane"
    read -rs -k 1 key || return 1
    case "$key" in
      q|$'\e') print; print "workflow assignment aborted"; return 130 ;;
      $'\r'|$'\n')
        if ii_workflow_assignments_complete; then
          ii_workflow_memory_write "$session" || return
          print
          return 0
        fi
        ;;
      ' ')
        ii_workflow_toggle_lane "$active_lane" "$cursor"
        ;;
      1|2|3)
        (( key <= ${#II_WORKFLOW_LANES} )) && {
          active_lane="${II_WORKFLOW_LANES[key]}"
          ii_workflow_assign_lane "$active_lane" "$cursor" manual
        }
        ;;
      j|l)
        index="${visible[(Ie)$cursor]}"; (( index = index % ${#visible} + 1 )); cursor="${visible[index]}"
        ;;
      k|h)
        index="${visible[(Ie)$cursor]}"; (( index = (index + ${#visible} - 2) % ${#visible} + 1 )); cursor="${visible[index]}"
        ;;
      ']')
        index="${II_WORKFLOW_WINDOWS[(Ie)$window]}"; (( index = index % ${#II_WORKFLOW_WINDOWS} + 1 )); window="${II_WORKFLOW_WINDOWS[index]}"
        ;;
      '[')
        index="${II_WORKFLOW_WINDOWS[(Ie)$window]}"; (( index = (index + ${#II_WORKFLOW_WINDOWS} - 2) % ${#II_WORKFLOW_WINDOWS} + 1 )); window="${II_WORKFLOW_WINDOWS[index]}"
        ;;
    esac
  done
}

ii_workflow_revalidate_assignments() {
  local session="$1" lane pane
  local -A seen
  for lane in "$II_WORKFLOW_LANES[@]"; do
    pane="${II_WORKFLOW_LANE_PANE[$lane]-}"
    [[ -n "$pane" && -z "${seen[$pane]-}" ]] || {
      print -u2 -r -- "ii: workflow lane target is missing or duplicated: $lane"
      return 1
    }
    seen[$pane]=1
    ii_tmux_pane_identity_valid "$pane" "$session" || return
  done
}

ii_workflow_popup() {
  local workflow_path="$1" origin="$2" session="$3" copy="${4:-0}"
  local index lane pane rendered missing answer ordinal
  local II_PAYLOAD_TMUX_ONLY=1
  ii_tmux_available || return
  [[ "$(tmux display-message -p -t "$origin" '#{session_id}' 2>/dev/null)" == "$session" ]] || {
    print -u2 "ii: workflow origin pane is no longer available"
    return 1
  }
  ii_workflow_render_file "$workflow_path" >/dev/null || return
  ii_workflow_spatial_select "$session" "$origin"
  local select_rc=$?
  (( select_rc == 0 )) || { (( select_rc == 130 )) && return 0; return "$select_rc"; }

  for (( index = 1; index <= ${#II_WORKFLOW_STAGE_BODIES}; index++ )); do
    lane="${II_WORKFLOW_STAGE_LANES[index]}"
    pane="${II_WORKFLOW_LANE_PANE[$lane]}"
    ordinal="${II_WORKFLOW_LANE_ORDINAL[$lane]}"
    ii_payload_render_text "${II_WORKFLOW_STAGE_BODIES[index]}" >/dev/null || return
    rendered="$II_PAYLOAD_RENDERED_TEXT"
    missing="$(ii_payload_missing_names)"
    print -n -- $'\033[2J\033[H'
    print "Workflow stage ${index}/${#II_WORKFLOW_STAGE_BODIES}"
    print "lane${ordinal}: ${lane} -> $(tmux display-message -p -t "$pane" '#S:#I.#P (#{pane_id})')"
    print "Shell: ${II_WORKFLOW_STAGE_SHELLS[index]}"
    print "Title: ${II_WORKFLOW_STAGE_TITLES[index]}"
    print "Command: $(tmux display-message -p -t "$pane" '#{pane_current_command}')"
    [[ -n "$missing" ]] && print -u2 "Unresolved variables: ${(j:, :)${(f)missing}}"
    print
    print -r -- "$rendered"
    print
    if (( index == 1 )); then
      printf 'Send this stage? [y/N] '
    else
      printf 'Previous stage ready; send this stage? [y/N] '
    fi
    read -r -k 1 answer
    print
    [[ "${(L)answer}" == y ]] || { print "workflow execution aborted before stage ${index}"; return 1; }
    ii_workflow_revalidate_assignments "$session" || {
      print -u2 "ii: workflow aborted; stage ${index} and later stages were not sent"
      return 1
    }
    if (( copy )); then
      ii_clip_copy "$rendered" || print -u2 "ii: clipboard copy failed; sending confirmed stage anyway"
    fi
    ii_tmux_send_literal "$session" "$pane" "$rendered" || {
      print -u2 "ii: workflow aborted while sending stage ${index}; later stages were not sent"
      return 1
    }
    print "stage ${index}/${#II_WORKFLOW_STAGE_BODIES} sent to ${pane}"
  done
  print "workflow completed: ${#II_WORKFLOW_STAGE_BODIES} stage(s) sent"
}

ii_workflow_popup_helper() {
  print -r -- "${II_PLUGIN_DIR}/script/ii-tmux-workflow"
}

ii_workflow_launch_popup() {
  local workflow_path="$1" copy="${2:-0}" origin session helper command
  ii_tmux_available || {
    print -u2 "ii: workflow execution requires tmux"
    return 1
  }
  origin="${TMUX_PANE:-}"
  [[ -n "$origin" ]] || { print -u2 "ii: cannot determine originating pane"; return 1; }
  session="$(tmux display-message -p -t "$origin" '#{session_id}')" || return
  helper="$(ii_workflow_popup_helper)"
  [[ -x "$helper" ]] || { print -u2 -r -- "ii: workflow popup helper is not executable: $helper"; return 1; }
  command="${(q)helper} ${(q)workflow_path} ${(q)origin} ${(q)session} ${(q)copy}"
  tmux display-popup -EE -T 'ii workflow' -w 90% -h 90% -d '#{pane_current_path}' "$command"
}
