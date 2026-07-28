# Shared ANSI color policy and helpers.

ii_color_mode() {
  local mode="${(L)${II_COLOR:-auto}}"
  case "$mode" in
    auto|always|never) print -r -- "$mode" ;;
    *) print -r -- auto ;;
  esac
}

ii_color_enabled() {
  [[ -z "${NO_COLOR:-}" ]] || return 1

  local mode context
  mode="$(ii_color_mode)"
  context="${1:-${II_COLOR_CONTEXT:-terminal}}"
  case "$mode" in
    always) return 0 ;;
    never) return 1 ;;
  esac

  [[ "$context" == ansi ]] && return 0
  [[ "${TERM:-}" != dumb ]] || return 1
  test -t 1
}

ii_color_wrap() {
  local code="$1"
  local text="$2"
  local context="${3:-${II_COLOR_CONTEXT:-terminal}}"
  if ii_color_enabled "$context"; then
    print -r -- $'\033['"${code}m${text}"$'\033[0m'
  else
    print -r -- "$text"
  fi
}

ii_color_wrap_inline() {
  local code="$1"
  local text="$2"
  local context="${3:-${II_COLOR_CONTEXT:-terminal}}"
  if ii_color_enabled "$context"; then
    print -rn -- $'\033['"${code}m${text}"$'\033[0m'
  else
    print -rn -- "$text"
  fi
}

ii_color_blue() {
  ii_color_wrap 34 "$1" "${2:-${II_COLOR_CONTEXT:-terminal}}"
}

ii_color_red() {
  ii_color_wrap 31 "$1" "${2:-${II_COLOR_CONTEXT:-terminal}}"
}

ii_color_green() {
  ii_color_wrap 32 "$1" "${2:-${II_COLOR_CONTEXT:-terminal}}"
}

ii_color_yellow() {
  ii_color_wrap 33 "$1" "${2:-${II_COLOR_CONTEXT:-terminal}}"
}

ii_color_cyan() {
  ii_color_wrap 36 "$1" "${2:-${II_COLOR_CONTEXT:-terminal}}"
}

ii_color_bold() {
  ii_color_wrap 1 "$1" "${2:-${II_COLOR_CONTEXT:-terminal}}"
}
