package tmux

import (
	"os/exec"
	"reflect"
	"testing"
)

func TestCurrentWorkflowSessionTargetsProcessPane(t *testing.T) {
	var got []string
	adapter := &SessionEnvironment{
		getenv: func(name string) string {
			switch name {
			case "TMUX":
				return "socket,pid,0"
			case "TMUX_PANE":
				return "%4"
			}
			return ""
		},
		lookPath: func(string) (string, error) { return "/usr/bin/tmux", nil },
		command: func(_ string, args ...string) *exec.Cmd {
			got = append([]string(nil), args...)
			return exec.Command("sh", "-c", "printf '%s\\t%s' '$7' '%4'")
		},
	}
	session, pane, err := adapter.CurrentWorkflowSession()
	if err != nil || session != "$7" || pane != "%4" {
		t.Fatalf("session=%q pane=%q err=%v", session, pane, err)
	}
	want := []string{"display-message", "-p", "-t", "%4", "#{session_id}\t#{pane_id}"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("tmux args = %#v, want %#v", got, want)
	}
}

func TestParseWorkflowPane(t *testing.T) {
	pane, ok := parseWorkflowPane("%2\t$1\t@3\t1\t40\t0\t80\t24\t0\t1\tzsh\t/tmp\tremote")
	if !ok {
		t.Fatal("parseWorkflowPane rejected valid input")
	}
	if pane.ID != "%2" || pane.Session != "$1" || pane.Window != "@3" ||
		pane.Index != 1 || pane.Left != 40 || pane.Width != 80 ||
		pane.Dead || !pane.InMode || pane.Command != "zsh" {
		t.Fatalf("pane = %#v", pane)
	}
}
