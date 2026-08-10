package terminal

import (
	"errors"
	"io"
	"strings"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

func TestWorkflowSelectorAssignsMovesAndConfirms(t *testing.T) {
	state := payload.WorkflowSession{
		OriginPane: "%1",
		Panes: []payload.WorkflowPane{
			{ID: "%1", Window: "@1", Width: 40, Height: 20, Command: "zsh"},
			{ID: "%2", Window: "@1", Left: 40, Width: 40, Height: 20, Command: "pwsh"},
		},
		Assignments: payload.NewLaneAssignments(),
	}
	keys := []string{"1", "l", "2", "\r"}
	selector := NewWorkflowSelector(strings.NewReader(""), &strings.Builder{})
	selector.readKey = func(_ io.Reader) (string, error) {
		key := keys[0]
		keys = keys[1:]
		return key, nil
	}
	err := selector.SelectWorkflowLanes([]string{"kali-main", "remote-main"}, &state)
	if err != nil {
		t.Fatal(err)
	}
	if state.Assignments.Pane("kali-main") != "%1" ||
		state.Assignments.Pane("remote-main") != "%2" {
		t.Fatalf("bindings = %#v", state.Assignments.Bindings())
	}
}

func TestWorkflowSelectorAbortDoesNotConfirm(t *testing.T) {
	state := payload.WorkflowSession{
		Panes:       []payload.WorkflowPane{{ID: "%1", Window: "@1", Width: 80, Height: 20}},
		Assignments: payload.NewLaneAssignments(),
	}
	selector := NewWorkflowSelector(strings.NewReader(""), &strings.Builder{})
	selector.readKey = func(_ io.Reader) (string, error) {
		return "q", nil
	}
	if err := selector.SelectWorkflowLanes([]string{"kali-main"}, &state); !errors.Is(err, ErrCancelled) {
		t.Fatalf("err = %v", err)
	}
}

func TestRenderWorkflowPaneMapIncludesAssignmentAndPane(t *testing.T) {
	assignments := payload.NewLaneAssignments()
	assignments.Assign("remote-main", "%2", "remembered")
	got := RenderWorkflowPaneMap(
		[]payload.WorkflowPane{{ID: "%2", Width: 80, Height: 20, Command: "pwsh"}},
		assignments, []string{"remote-main"}, "%2", 80, 16,
	)
	for _, expected := range []string{"> [1/lane1] remote-main · remembered", "%2  pwsh"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("map missing %q:\n%s", expected, got)
		}
	}
}
