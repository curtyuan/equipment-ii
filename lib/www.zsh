# /www helper commands used from ii p -www.

ii_cmd_payload_www() {
  case "${1:-}" in
    ln)
      shift
      ii_cmd_payload_www_ln "$@"
      ;;
    search)
      shift
      ii_cmd_payload_www_search "$@"
      ;;
    ls)
      shift
      ii_cmd_payload_www_ls "$@"
      ;;
    --help|-h|"")
      cat <<'EOF'
usage: ii p -www ln SOURCE_PATH [LINK_NAME]
       ii p -www ls
       ii p -www search [FILTER]

Commands:
  ln SOURCE_PATH [LINK_NAME]
    Select a directory under /www and create a symlink to SOURCE_PATH there.
    With no LINK_NAME, the symlink name is SOURCE_PATH's basename.

  ls
    Print files and directories under /www as a tree. Symlinks are shown by name
    only; their targets are not printed.

  search [FILTER]
    Fuzzy-select a file or directory under /www, then print its path relative to
    /www followed by its absolute path. FILTER preselects the first
    case-insensitive fzf match.
EOF
      [[ -n "${1:-}" ]] && return 0
      return 2
      ;;
    *)
      print -u2 "ii: unknown -www command: $1"
      print -u2 "ii: expected ln, ls, or search"
      return 2
      ;;
  esac
}

ii_cmd_payload_www_ls() {
  if [[ $# -gt 0 ]]; then
    print -u2 "ii: usage: ii p -www ls"
    return 2
  fi

  local root
  root="$(ii_www_root)"
  ii_www_require_root "$root" || return
  ii_www_tree "$root"
}

ii_cmd_payload_www_ln() {
  local source="${1:-}" link_name="${2:-}"
  local root selected source_abs target

  if [[ -z "$source" ]]; then
    print -u2 "ii: usage: ii p -www ln SOURCE_PATH [LINK_NAME]"
    return 2
  fi
  if [[ $# -gt 2 ]]; then
    print -u2 "ii: too many arguments for ii p -www ln"
    return 2
  fi
  if [[ ! -e "$source" ]]; then
    print -u2 "ii: source path not found: $source"
    return 1
  fi

  root="$(ii_www_root)"
  ii_www_require_root "$root" || return
  ii_require_cmd fzf || return

  source_abs="${source:a}"
  [[ -n "$link_name" ]] || link_name="${source:t}"
  ii_www_validate_link_name "$link_name" || return

  selected="$(ii_www_select_dir "$root")" || return
  [[ -n "$selected" ]] || return

  target="${selected%/}/${link_name}"
  if [[ -e "$target" || -L "$target" ]]; then
    print -u2 "ii: target already exists: $target"
    return 1
  fi
  if ! ln -s -- "$source_abs" "$target"; then
    print -u2 "ii: failed to create symlink: $target"
    return 1
  fi

  ii_color_blue "symlink written to:"
  print -r -- "${target:a}"
}

ii_cmd_payload_www_search() {
  local filter="${1:-}"

  if [[ $# -gt 1 ]]; then
    print -u2 "ii: usage: ii p -www search [FILTER]"
    return 2
  fi

  local root selected
  root="$(ii_www_root)"
  ii_www_require_root "$root" || return
  ii_require_cmd fzf || return

  selected="$(ii_www_select_entry "$root" "$filter")" || return
  [[ -n "$selected" ]] || return

  ii_color_green "relative to /www:"
  print -r -- "$(ii_www_relative_path "$root" "$selected")"
  ii_color_green "absolute path:"
  print -r -- "${selected:a}"
}

ii_www_root() {
  print -r -- "${II_WWW_ROOT:-/www}"
}

ii_www_require_root() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    print -u2 "ii: /www directory not found: $root"
    return 1
  fi
}

ii_www_validate_link_name() {
  local link_name="$1"
  if [[ -z "$link_name" || "$link_name" == */* || "$link_name" == "." || "$link_name" == ".." ]]; then
    print -u2 "ii: invalid link name: $link_name"
    return 2
  fi
}

ii_www_select_dir() {
  local root="$1"
  local selected
  selected="$(ii_www_dir_entries "$root" | fzf -i --ansi --prompt='ii www dir> ' --height=80% --border --delimiter=$'\t' --with-nth=1 --footer='Enter Select     Esc Abort')"
  [[ -n "$selected" ]] || return
  print -r -- "${selected##*$'\t'}"
}

ii_www_select_entry() {
  local root="$1"
  local filter="${2:-}"
  local selected
  selected="$(ii_www_entries "$root" | ii_fzf_select_one "$filter" --ansi --prompt='ii www search> ' --height=80% --border --delimiter=$'\t' --with-nth=1,2 --footer='Enter Select     Esc Abort     Type Filter')"
  [[ -n "$selected" ]] || return
  print -r -- "${selected##*$'\t'}"
}

ii_www_dir_entries() {
  local root="$1"
  local entry_path
  ii_www_find_dirs "$root" | while IFS= read -r entry_path; do
    [[ -n "$entry_path" ]] || continue
    print -r -- "$(ii_www_tree_label "$root" "$entry_path")"$'\t'"${entry_path:a}"
  done
}

ii_www_entries() {
  local root="$1"
  local entry_path
  ii_www_find_entries "$root" | while IFS= read -r entry_path; do
    [[ -n "$entry_path" ]] || continue
    print -r -- "$(ii_www_search_label "$root" "$entry_path")"$'\t'"$(ii_www_kind_label "$entry_path")"$'\t'"${entry_path:a}"
  done
}

ii_www_find_dirs() {
  local root="$1"
  find "$root" -type d 2>/dev/null | sort
}

ii_www_find_entries() {
  local root="$1"
  find "$root" -mindepth 1 \( -type f -o -type d -o -type l \) 2>/dev/null | sort
}

ii_www_tree() {
  local root="$1"
  local entry_path
  print -r -- "$(ii_color_blue "${root:t}")"
  ii_www_find_entries "$root" | while IFS= read -r entry_path; do
    [[ -n "$entry_path" ]] || continue
    print -r -- "$(ii_www_tree_label "$root" "$entry_path")"
  done
}

ii_www_relative_path() {
  local root="${1%/}"
  local entry_path="$2"
  if [[ "$entry_path" == "$root" ]]; then
    print -r -- "."
  else
    print -r -- "${entry_path#$root/}"
  fi
}

ii_www_tree_label() {
  local root="$1"
  local entry_path="$2"
  local rel depth indent name
  local -a rel_parts
  rel="$(ii_www_relative_path "$root" "$entry_path")"
  if [[ "$rel" == "." ]]; then
    print -r -- "$(ii_color_blue "${root:t}")"
    return
  fi
  rel_parts=("${(@s:/:)rel}")
  depth="${#rel_parts[@]}"
  indent="${(l:$(( (depth - 1) * 2 )):: :)}"
  name="${rel:t}"
  print -r -- "${indent}${name}"
}

ii_www_search_label() {
  local root="$1"
  local entry_path="$2"
  ii_www_relative_path "$root" "$entry_path"
}

ii_www_kind_label() {
  local entry_path="$1"
  if [[ -d "$entry_path" ]]; then
    ii_color_blue "dir"
  elif [[ -L "$entry_path" ]]; then
    ii_color_green "link"
  else
    print -r -- "file"
  fi
}
