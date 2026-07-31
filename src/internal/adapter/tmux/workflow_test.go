package tmux

import "testing"

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
