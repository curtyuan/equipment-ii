# Go runtime adapter. Legacy behavior remains isolated under ori-ii during migration.

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
typeset -g II_LEGACY_ROOT="${II_LEGACY_ROOT:-${II_GO_ROOT}/ori-ii}"

if [[ ! -r "${II_LEGACY_ROOT}/ii.plugin.zsh" ]]; then
  print -u2 "ii: legacy adapter unavailable: ${II_LEGACY_ROOT}/ii.plugin.zsh"
  unset ii_adapter_dir
  return 1
fi

typeset -g II_PLUGIN_DIR="$II_LEGACY_ROOT"
typeset -g II_PAYLOAD_DIR="${II_PAYLOAD_DIR:-${II_LEGACY_ROOT}/payloads}"
source "${II_LEGACY_ROOT}/ii.plugin.zsh" || {
  unset ii_adapter_dir
  return 1
}

functions[ii_legacy]="${functions[ii]}"
unfunction ii
typeset -ga precmd_functions

ii() {
  if [[ ! -x "$II_GO_BIN" ]]; then
    print -u2 "ii: Go runtime unavailable: $II_GO_BIN"
    print -u2 "ii: run 'make build' from $II_GO_ROOT"
    return 127
  fi

  local route
  route="$("$II_GO_BIN" __route "$@")" || {
    print -u2 "ii: Go dispatcher failed"
    return 1
  }

  case "$route" in
    go)
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
      local ii_hook_present=absent
      (( ${precmd_functions[(I)ii_sync_loaded_vars_precmd]} )) && ii_hook_present=present
      II_SHELL_OPS_FILE="$ops_file" \
        II_SHELL_STATE_FILE="$state_file" \
        II_SHELL_EXEC_FILE="$exec_file" \
        II_PLUGIN_DIR="$II_PLUGIN_DIR" \
        II_GO_ROOT="$II_GO_ROOT" \
        II_SYNC_LOADED_VARS="${II_SYNC_LOADED_VARS:-0}" \
        II_SYNC_HOOK_PRESENT="$ii_hook_present" \
        "$II_GO_BIN" "$@" || ii_exit_status=$?
      if [[ -s "$ops_file" ]]; then
        ii_apply_shell_operations "$ops_file" "$exec_file" || ii_exit_status=1
      fi
      command rm -f -- "$ops_file"
      command rm -f -- "$state_file"
      command rm -f -- "$exec_file"
      return "$ii_exit_status"
      ;;
    legacy) ii_legacy "$@" ;;
    *)
      print -u2 "ii: invalid Go dispatcher route: $route"
      return 1
      ;;
  esac
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
        sync-hook)
          [[ -z "$name" && ( "$value" == "on" || "$value" == "off" ) ]] || {
            print -u2 "ii: invalid parent-shell sync-hook operation"
            return 1
          }
          ii_apply_sync_hook_operation "$value" || return
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

ii_apply_sync_hook_operation() {
  typeset -ga precmd_functions
  case "$1" in
    on)
      typeset -g II_SYNC_LOADED_VARS=1
      precmd_functions=(${precmd_functions:#ii_sync_loaded_vars_precmd} ii_sync_loaded_vars_precmd)
      ;;
    off)
      typeset -g II_SYNC_LOADED_VARS=0
      precmd_functions=(${precmd_functions:#ii_sync_loaded_vars_precmd})
      ;;
    *) return 1 ;;
  esac
}

ii_sync_loaded_vars_precmd() {
  ii load >/dev/null
}

unset ii_adapter_dir
