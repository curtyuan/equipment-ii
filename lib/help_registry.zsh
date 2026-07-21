# Shared help topic registry.

typeset -ga II_HELP_TOPICS=()
typeset -gA II_HELP_HANDLERS=()
typeset -gA II_HELP_ROUTES=()
typeset -gi II_HELP_REGISTRY_ERROR=0

ii_help_register() {
  local topic="$1" handler="$2" route
  shift 2

  if [[ -z "$topic" || -z "$handler" ]]; then
    II_HELP_REGISTRY_ERROR=1
    print -u2 "ii: help registration requires a topic and handler"
    return 2
  fi
  if (( ! $+functions[$handler] )); then
    II_HELP_REGISTRY_ERROR=1
    print -u2 "ii: help handler unavailable during registration: $handler"
    return 1
  fi
  if [[ -n "${II_HELP_HANDLERS[$topic]-}" && "${II_HELP_HANDLERS[$topic]}" != "$handler" ]]; then
    II_HELP_REGISTRY_ERROR=1
    print -u2 "ii: help topic already registered with another handler: $topic"
    return 1
  fi
  if [[ -n "${II_HELP_ROUTES[$topic]-}" && "${II_HELP_ROUTES[$topic]}" != "$topic" ]]; then
    II_HELP_REGISTRY_ERROR=1
    print -u2 "ii: help route already registered for another topic: $topic"
    return 1
  fi

  for route in "$@"; do
    if [[ -z "$route" ]]; then
      II_HELP_REGISTRY_ERROR=1
      print -u2 "ii: help route cannot be empty for topic: $topic"
      return 2
    fi
    if [[ -n "${II_HELP_ROUTES[$route]-}" && "${II_HELP_ROUTES[$route]}" != "$topic" ]]; then
      II_HELP_REGISTRY_ERROR=1
      print -u2 "ii: help route already registered for another topic: $route"
      return 1
    fi
  done

  if [[ -z "${II_HELP_HANDLERS[$topic]-}" ]]; then
    II_HELP_TOPICS+=("$topic")
  fi
  II_HELP_HANDLERS[$topic]="$handler"
  II_HELP_ROUTES[$topic]="$topic"
  for route in "$@"; do
    II_HELP_ROUTES[$route]="$topic"
  done
}

ii_help_topics() {
  local topic
  print -r -- help
  for topic in "$II_HELP_TOPICS[@]"; do
    [[ "$topic" == "help" ]] && continue
    print -r -- "$topic"
  done
}

ii_help_dispatch() {
  local route topic handler
  local -a route_parts
  local route_length

  for (( route_length = $#; route_length >= 1; route_length-- )); do
    route_parts=("${(@)argv[1,$route_length]}")
    route="${(j: :)route_parts}"
    topic="${II_HELP_ROUTES[$route]-}"
    [[ -n "$topic" ]] || continue

    handler="${II_HELP_HANDLERS[$topic]-}"
    if [[ -z "$handler" || $+functions[$handler] -eq 0 ]]; then
      print -u2 "ii: help handler unavailable for topic: $topic"
      return 1
    fi
    "$handler" --help
    return $?
  done

  print -u2 "ii: unknown help topic: $1"
  return 2
}
