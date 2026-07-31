package payload

import (
	"errors"
	"testing"
)

type workflowRuntimeFake struct {
	panes   []WorkflowPane
	memory  string
	written string
}

func (f *workflowRuntimeFake) CurrentWorkflowSession() (string, string, error) {
	return "$1", "%1", nil
}
func (f *workflowRuntimeFake) WorkflowPanes(string) ([]WorkflowPane, error) {
	return f.panes, nil
}
func (f *workflowRuntimeFake) ReadWorkflowMemory(string) (string, error) { return f.memory, nil }
func (f *workflowRuntimeFake) WriteWorkflowMemory(_, value string) error {
	f.written = value
	return nil
}
func (f *workflowRuntimeFake) WorkflowPaneSnapshot(id string) (WorkflowPane, error) {
	for _, pane := range f.panes {
		if pane.ID == id {
			return pane, nil
		}
	}
	return WorkflowPane{}, nil
}
func (f *workflowRuntimeFake) SendWorkflowStage(string, string, string) error { return nil }

func TestWorkflowCoordinatorPrepareSaveAndRevalidate(t *testing.T) {
	runtime := &workflowRuntimeFake{
		panes: []WorkflowPane{
			{ID: "%1", Session: "$1", Command: "zsh"},
			{ID: "%2", Session: "$1", Command: "pwsh"},
		},
	}
	workflow := Workflow{Lanes: []string{"kali-main", "remote-main"}}
	coordinator := NewWorkflowCoordinator(runtime)
	state, err := coordinator.Prepare(workflow)
	if err != nil {
		t.Fatal(err)
	}
	if !state.Assignments.Complete(workflow.Lanes) {
		t.Fatalf("bindings = %#v", state.Assignments.Bindings())
	}
	if err := coordinator.Revalidate(workflow, state); err != nil {
		t.Fatal(err)
	}
	if err := coordinator.Save(state); err != nil {
		t.Fatal(err)
	}
	if runtime.written != "kali-main=%1\nremote-main=%2" {
		t.Fatalf("written memory = %q", runtime.written)
	}
}

type workflowSelectorFake struct {
	err error
}

func (f workflowSelectorFake) SelectWorkflowLanes(lanes []string, state *WorkflowSession) error {
	if f.err != nil {
		return f.err
	}
	for index, lane := range lanes {
		state.Assignments.Assign(lane, state.Panes[index].ID, "manual")
	}
	return nil
}

func TestWorkflowCoordinatorSelectSavesOnlyConfirmedAssignments(t *testing.T) {
	runtime := &workflowRuntimeFake{
		panes:  []WorkflowPane{{ID: "%1"}, {ID: "%2"}},
		memory: "kali-old=%9",
	}
	workflow := Workflow{Lanes: []string{"kali-main", "remote-main"}}
	state := WorkflowSession{
		Session: "$1", Panes: runtime.panes, Memory: runtime.memory,
		Assignments: NewLaneAssignments(),
	}
	coordinator := NewWorkflowCoordinator(runtime)
	if err := coordinator.Select(workflow, &state, workflowSelectorFake{}); err != nil {
		t.Fatal(err)
	}
	if runtime.written != "kali-main=%1\nkali-old=%9\nremote-main=%2" {
		t.Fatalf("written memory = %q", runtime.written)
	}

	runtime.written = ""
	cancelled := errors.New("cancelled")
	if err := coordinator.Select(workflow, &state, workflowSelectorFake{err: cancelled}); !errors.Is(err, cancelled) {
		t.Fatalf("err = %v", err)
	}
	if runtime.written != "" {
		t.Fatalf("memory written after cancellation: %q", runtime.written)
	}
}
