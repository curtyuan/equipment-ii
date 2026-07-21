# Version helpers.

ii_version() {
  local version_file="${II_PLUGIN_DIR}/VERSION"

  if [[ -r "$version_file" ]]; then
    command cat "$version_file"
    return
  fi

  print "unknown"
}

ii_cmd_version() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
usage: ii version

Aliases:
  -v, --version

Help:
  ii help version

Print the installed ii version.
EOF
    return
  fi

  print "ii $(ii_version)"
}

ii_help_register version ii_cmd_version -v --version
