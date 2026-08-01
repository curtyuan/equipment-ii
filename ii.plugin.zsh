# Go runtime parent-shell adapter.

local ii_adapter_dir
ii_adapter_dir="${${(%):-%x}:A:h}"

typeset -g II_GO_ROOT="${II_GO_ROOT:-$ii_adapter_dir}"
if [[ -z "${II_GO_BIN:-}" ]]; then
  if [[ -x "${II_GO_ROOT}/ii-go" ]]; then
    typeset -g II_GO_BIN="${II_GO_ROOT}/ii-go"
  else
    typeset -g II_GO_BIN="${II_GO_ROOT}/build/ii-go"
  fi
fi
typeset -g II_PLUGIN_DIR="$II_GO_ROOT"
typeset -g II_PAYLOAD_DIR="${II_PAYLOAD_DIR:-${II_GO_ROOT}/ori-ii/payloads}"
typeset -g II_CONFIG_FILE="${II_CONFIG_FILE:-${HOME}/.config/ii/ii.conf}"
[[ -r "$II_CONFIG_FILE" ]] && source "$II_CONFIG_FILE"
if [[ -x "$II_GO_BIN" ]]; then
  II_PLUGIN_DIR="$II_PLUGIN_DIR" II_GO_ROOT="$II_GO_ROOT" \
    "$II_GO_BIN" __tmux_ensure || true
fi

ii_go_command() {
  if [[ ! -x "$II_GO_BIN" ]]; then
    print -u2 "ii: Go runtime unavailable: $II_GO_BIN"
    print -u2 "ii: run 'make build' from $II_GO_ROOT"
    return 127
  fi

  local ops_file state_file exec_file ii_exit_status=0
  ops_file="$(mktemp "${TMPDIR:-/tmp}/ii-shell-ops.XXXXXXXX")" || {
    print -u2 "ii: failed to create parent-shell operation channel"
    return 1
  }
  state_file="$(mktemp "${TMPDIR:-/tmp}/ii-shell-state.XXXXXXXX")" || {
    command rm -f -- "$ops_file"
    print -u2 "ii: failed to create parent-shell state channel"
    return 1
  }
  exec_file="$(mktemp "${TMPDIR:-/tmp}/ii-shell-exec.XXXXXXXX")" || {
    command rm -f -- "$ops_file" "$state_file"
    print -u2 "ii: failed to create parent-shell execution channel"
    return 1
  }
  ii_write_requested_shell_state "$state_file" "$@" || {
    command rm -f -- "$ops_file" "$state_file" "$exec_file"
    return 1
  }
  II_SHELL_OPS_FILE="$ops_file" \
    II_SHELL_STATE_FILE="$state_file" \
    II_SHELL_EXEC_FILE="$exec_file" \
    II_PLUGIN_DIR="$II_PLUGIN_DIR" \
    II_GO_ROOT="$II_GO_ROOT" \
    "$II_GO_BIN" "$@" || ii_exit_status=$?
  if [[ -s "$ops_file" ]]; then
    ii_apply_shell_operations "$ops_file" "$exec_file" || ii_exit_status=1
  fi
  command rm -f -- "$ops_file"
  command rm -f -- "$state_file"
  command rm -f -- "$exec_file"
  return "$ii_exit_status"
}

ii_write_requested_shell_state() {
  local file="$1"
  shift
  local command="${1:-}" raw name candidate present value
  shift 2>/dev/null || true
  local -a names

  if [[ "$command" == "sha" ]]; then
    names=(domain lhost rhost lport rport user1 pass1 user2 pass2 user3 pass3
      user4 pass4 user5 pass5 cuser cpass tuser tpass directs)
  elif [[ "$command" == (set|s|s:*) && " $* " == *" --from-shell "* ]]; then
    [[ "$command" == s:* ]] && names+=("${command#s:}")
    for raw in "$@"; do
      [[ "$raw" == --from-shell || "$raw" == -a ]] && continue
      names+=("${(@s:,:)raw}")
    done
  elif [[ "$command" == (pic|pie|pice) ||
          ( "$command" == (payload|p) &&
            ( " $* " == *" --input "* || " $* " == *" input "* ) ) ]]; then
    local parameter_name parameter_type
    local -A input_names
    for parameter_name in ${(k)parameters}; do
      [[ "$parameter_name" =~ '^[A-Za-z_][A-Za-z0-9_]*$' &&
        "$parameter_name" != _* &&
        "${(L)parameter_name}" != ii_* ]] || continue
      parameter_type="${parameters[$parameter_name]}"
      [[ "$parameter_type" == *scalar* &&
        "$parameter_type" != *special* ]] &&
        input_names[${(L)parameter_name}]=1
    done
    names=(${(k)input_names})
  elif [[ "$command" == (payload|p|pc|pe|pce) ]]; then
    names=("${(@f)$("$II_GO_BIN" __payload_names)}") || return
  else
    return 0
  fi

  print -rn -- 'ii-shell-state-v1'$'\0' >| "$file"
  for raw in "$names[@]"; do
    name="${(L)${raw#ii_}}"
    for candidate in "$name" "${(U)name}"; do
      present=0
      value=""
      if (( ${+parameters[$candidate]} )); then
        present=1
        value="${(P)candidate}"
      fi
      print -rn -- "$candidate"$'\0'"$present"$'\0'"$value"$'\0' >> "$file"
    done
  done
}

ii_apply_shell_operations() {
  local file="$1" expected_exec_file="${2:-}" header operation name value
  {
    IFS= read -r -d $'\0' header || {
      print -u2 "ii: incomplete parent-shell operation protocol"
      return 1
    }
    if [[ "$header" != "ii-shell-ops-v1" ]]; then
      print -u2 "ii: unsupported parent-shell operation protocol: $header"
      return 1
    fi

    while IFS= read -r -d $'\0' operation; do
      IFS= read -r -d $'\0' name &&
        IFS= read -r -d $'\0' value || {
          print -u2 "ii: incomplete parent-shell operation record"
          return 1
        }
      case "$operation" in
        export)
          [[ "$name" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || {
            print -u2 "ii: rejected parent-shell export name: $name"
            return 1
          }
          export "$name=$value"
          ;;
        unset)
          [[ "$name" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || {
            print -u2 "ii: rejected parent-shell unset name: $name"
            return 1
          }
          unset "$name"
          ;;
        chdir)
          [[ -z "$name" && -n "$value" ]] || {
            print -u2 "ii: invalid parent-shell chdir operation"
            return 1
          }
          builtin cd -- "$value" || return
          ;;
        execute-file)
          [[ -z "$name" && -n "$expected_exec_file" && "$value" == "$expected_exec_file" &&
            -f "$value" && ! -L "$value" ]] || {
            print -u2 "ii: rejected parent-shell execution file"
            return 1
          }
          source "$value" || return
          ;;
        *)
          print -u2 "ii: rejected parent-shell operation: $operation"
          return 1
          ;;
      esac
    done
  } < "$file"
}

unset ii_adapter_dir

source "${II_GO_ROOT}/lib/ordinary_variables.zsh"
source "${II_GO_ROOT}/lib/ordinary_read.zsh"
source "${II_GO_ROOT}/lib/ordinary_runtime.zsh"
