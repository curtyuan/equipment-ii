# Zsh-owned helpers for publishing and inspecting files below II_WWW_ROOT.

ii_zsh_web_root() {
  local configured="${II_WWW_ROOT:-/www}" root
  [[ -d "$configured" ]] || {
    print -u2 -- "ii: web root directory not found: $configured"
    return 1
  }
  root="${configured:A}"
  [[ -d "$root" && ! -L "$root" ]] || {
    print -u2 -- "ii: invalid web root: $configured"
    return 1
  }
  print -r -- "$root"
}

ii_zsh_web_contained() {
  local root="${1%/}" candidate="$2" absolute
  absolute="${candidate:A}"
  [[ "$absolute" == "$root" || "$absolute" == "$root/"* ]] || {
    print -u2 -- "ii: path escapes web root: $candidate"
    return 1
  }
  print -r -- "$absolute"
}

ii_zsh_web_validate_name() {
  local name="$1"
  [[ -n "$name" && "$name" != (.|..) && "$name" != */* ]] || {
    print -u2 -- "ii: invalid link name: $name"
    return 2
  }
}

ii_zsh_web_find_entries() {
  local root="$1"
  LC_ALL=C command find -P "$root" -mindepth 1 \( -type f -o -type d -o -type l \) -print 2>/dev/null |
    LC_ALL=C sort
}

ii_zsh_web_find_dirs() {
  local root="$1"
  LC_ALL=C command find -P "$root" -type d -print 2>/dev/null | LC_ALL=C sort
}

ii_zsh_web_relative() {
  local root="${1%/}" entry_path="$2"
  [[ "$entry_path" == "$root" ]] && print -r -- . || print -r -- "${entry_path#$root/}"
}

ii_zsh_web_tree_label() {
  local root="$1" entry_path="$2" relative name indent=''
  local -i depth
  local -a parts
  relative="$(ii_zsh_web_relative "$root" "$entry_path")"
  parts=("${(@s:/:)relative}")
  name="${relative:t}"
  depth=$((${#parts[@]} - 1))
  while (( depth-- > 0 )); do indent+='  '; done
  print -r -- "${indent}${name}"
}

ii_zsh_web_dir_entries() {
  local root="$1" entry_path
  ii_zsh_web_find_dirs "$root" | while IFS= read -r entry_path; do
    [[ -n "$entry_path" ]] || continue
    print -r -- "$(ii_zsh_web_tree_label "$root" "$entry_path")"$'\t'"$entry_path"
  done
}

ii_zsh_web_entries() {
  local root="$1" entry_path kind
  ii_zsh_web_find_entries "$root" | while IFS= read -r entry_path; do
    [[ -n "$entry_path" ]] || continue
    if [[ -L "$entry_path" ]]; then kind=link
    elif [[ -d "$entry_path" ]]; then kind=dir
    else kind=file
    fi
    print -r -- "$(ii_zsh_web_relative "$root" "$entry_path")"$'\t'"$kind"$'\t'"$entry_path"
  done
}

ii_zsh_web_select_dir() {
  local root="$1" selected selected_path
  (( $+commands[fzf] )) || { print -u2 -- 'ii: required command not found: fzf'; return 1; }
  selected="$(ii_zsh_web_dir_entries "$root" | fzf -i --prompt='ii web dir> ' --height='80%' --border \
    $'--delimiter=\t' --with-nth=1 --footer='Enter Select     Esc Abort')" || return
  [[ -n "$selected" ]] || return 1
  selected_path="${selected##*$'\t'}"
  selected_path="$(ii_zsh_web_contained "$root" "$selected_path")" || return
  [[ -d "$selected_path" && ! -L "$selected_path" ]] || { print -u2 -- "ii: selected directory is unavailable: $selected_path"; return 1; }
  print -r -- "$selected_path"
}

ii_zsh_web_select_entry() {
  local root="$1" filter="$2" selected selected_path
  (( $+commands[fzf] )) || { print -u2 -- 'ii: required command not found: fzf'; return 1; }
  selected="$(ii_zsh_web_entries "$root" | fzf -i --query="$filter" --prompt='ii web search> ' \
    --height='80%' --border $'--delimiter=\t' --with-nth=1,2 \
    --footer='Enter Select     Esc Abort     Type Filter')" || return
  [[ -n "$selected" ]] || return 1
  selected_path="${selected##*$'\t'}"
  [[ -e "$selected_path" || -L "$selected_path" ]] || { print -u2 -- "ii: selected path is unavailable: $selected_path"; return 1; }
  # Keep the symlink itself inside the root; do not resolve or inspect its target.
  [[ "${selected_path:h:A}" == "$root" || "${selected_path:h:A}" == "$root/"* ]] || {
    print -u2 -- "ii: path escapes web root: $selected_path"
    return 1
  }
  print -r -- "$selected_path"
}

ii_zsh_web_relative_dir() {
  local root="$1" entry_path="$2" directory relative
  if [[ -d "$entry_path" && ! -L "$entry_path" ]]; then directory="$entry_path"; else directory="${entry_path:h}"; fi
  relative="$(ii_zsh_web_relative "$root" "$directory")"
  [[ "$relative" == . ]] && print -r -- / || print -r -- "/${relative%/}/"
}

ii_zsh_web_link() {
  local root="$1" directory="$2" source="$3" name="$4" target
  ii_zsh_web_validate_name "$name" || return
  directory="$(ii_zsh_web_contained "$root" "$directory")" || return
  [[ -d "$directory" && ! -L "$directory" ]] || { print -u2 -- "ii: invalid link directory: $directory"; return 1; }
  target="${directory%/}/$name"
  [[ ! -e "$target" && ! -L "$target" ]] || { print -u2 -- "ii: target already exists: $target"; return 1; }
  command ln -s -- "$source" "$target" || { print -u2 -- "ii: failed to create symlink: $target"; return 1; }
  typeset -g II_WWW_LINK_PATH="$target"
}

ii_zsh_web_print_analysis() {
  local root="$1" entry_path="$2" relative_dir
  relative_dir="$(ii_zsh_web_relative_dir "$root" "$entry_path")"
  print -r -- 'relative to web root:'
  print -r -- "$relative_dir"
  print -r -- 'absolute path:'
  print -r -- "$entry_path"
  print -r -- 'shell assignments:'
  print -r -- "relative_file=${(q)relative_dir}"
  print -r -- "file=${(q)entry_path}"
  print -r -- "rfile=${(q)entry_path:t}"
}

ii_zsh_cmd_web() {
  local public_command="$1"
  shift
  [[ "${1:-}" == -w ]] || { print -u2 -- 'ii: internal web dispatch error'; return 2; }
  shift
  local subcommand="${1:-}"
  [[ -n "$subcommand" ]] && shift
  case "$subcommand" in
    file) ii_zsh_cmd_web_file "$@" ;;
    ln) ii_zsh_cmd_web_ln "$@" ;;
    ls) ii_zsh_cmd_web_ls "$@" ;;
    search) ii_zsh_cmd_web_search "$@" ;;
    '') print -u2 -- 'ii: usage: ii p -w file|ln|ls|search'; return 2 ;;
    *) print -u2 -- "ii: unknown web command: $subcommand"; return 2 ;;
  esac
}

ii_zsh_cmd_web_file() {
  [[ $# -eq 1 ]] || { print -u2 -- 'ii: usage: ii p -w file PATH'; return 2; }
  local source="$1" source_abs root directory rendered report
  [[ -f "$source" ]] || { print -u2 -- "ii: file not found: $source"; return 1; }
  source_abs="${source:A}"
  [[ -f "$source_abs" && ! -L "$source_abs" ]] || { print -u2 -- "ii: invalid source file: $source"; return 1; }
  root="$(ii_zsh_web_root)" || return
  directory="${root}/p"
  command mkdir -p -- "$directory" || { print -u2 -- "ii: failed to create web directory: $directory"; return 1; }
  [[ -d "$directory" && ! -L "$directory" ]] || { print -u2 -- "ii: invalid web directory: $directory"; return 1; }
  ii_zsh_payload_render_text "$(<"$source_abs")" ordinary >/dev/null || return
  rendered="$II_PAYLOAD_RENDERED_TEXT"
  report="$(ii_zsh_payload_report)"
  ii_zsh_web_link "$root" "$directory" "$source_abs" "${source_abs:t}" || return
  [[ -n "$report" ]] && print -r -- "$report" && print
  print -r -- '----------------------------------------'
  print -r -- "$rendered"
  print
  print -r -- 'symlink written to:'
  print -r -- "$II_WWW_LINK_PATH"
  print
  ii_zsh_web_print_analysis "$root" "$II_WWW_LINK_PATH"
}

ii_zsh_cmd_web_ln() {
  (( $# == 1 || $# == 2 )) || { print -u2 -- 'ii: usage: ii p -w ln SOURCE_PATH [LINK_NAME]'; return 2; }
  local source="$1" name="${2:-}" source_abs root directory
  [[ -e "$source" ]] || { print -u2 -- "ii: source path not found: $source"; return 1; }
  source_abs="${source:A}"
  [[ -n "$name" ]] || name="${source_abs:t}"
  ii_zsh_web_validate_name "$name" || return
  root="$(ii_zsh_web_root)" || return
  directory="$(ii_zsh_web_select_dir "$root")" || return
  ii_zsh_web_link "$root" "$directory" "$source_abs" "$name" || return
  print -r -- 'symlink written to:'
  print -r -- "$II_WWW_LINK_PATH"
}

ii_zsh_cmd_web_ls() {
  (( $# == 0 )) || { print -u2 -- 'ii: usage: ii p -w ls'; return 2; }
  local root entry_path
  root="$(ii_zsh_web_root)" || return
  print -r -- "${root:t}"
  ii_zsh_web_find_entries "$root" | while IFS= read -r entry_path; do
    [[ -n "$entry_path" ]] && ii_zsh_web_tree_label "$root" "$entry_path"
  done
}

ii_zsh_cmd_web_search() {
  (( $# <= 1 )) || { print -u2 -- 'ii: usage: ii p -w search [FILTER]'; return 2; }
  local filter="${1:-}" root selected
  root="$(ii_zsh_web_root)" || return
  selected="$(ii_zsh_web_select_entry "$root" "$filter")" || return
  ii_zsh_web_print_analysis "$root" "$selected"
}
