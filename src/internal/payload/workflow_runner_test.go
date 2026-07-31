package payload

import "testing"

type workflowConfirmerFake struct {
	views  []WorkflowStageView
	reject int
}

func (f *workflowConfirmerFake) ConfirmWorkflowStage(view WorkflowStageView) (bool, error) {
	f.views = append(f.views, view)
	return view.Index != f.reject, nil
}

type workflowClipboardFake struct {
	values []string
}

func (f *workflowClipboardFake) Copy(value string) error {
	f.values = append(f.values, value)
	return nil
}

type workflowRunnerRuntimeFake struct {
	workflowRuntimeFake
	sent []string
}

func (f *workflowRunnerRuntimeFake) SendWorkflowStage(_, pane, text string) error {
	f.sent = append(f.sent, pane+":"+text)
	return nil
}

func TestWorkflowRunnerConfirmsRevalidatesCopiesAndSendsInOrder(t *testing.T) {
	runtime := &workflowRunnerRuntimeFake{workflowRuntimeFake: workflowRuntimeFake{
		panes: []WorkflowPane{
			{ID: "%1", Session: "$1", Command: "zsh"},
			{ID: "%2", Session: "$1", Command: "pwsh"},
		},
	}}
	workflow := Workflow{
		Notes: []string{"wait for listener"},
		Lanes: []string{"kali-main", "remote-main"},
		Stages: []WorkflowStage{
			{Lane: "kali-main", Shell: "zsh", Title: "listen"},
			{Lane: "remote-main", Shell: "powershell", Title: "connect"},
			{Lane: "kali-main", Shell: "zsh", Title: "verify"},
		},
	}
	assignments := NewLaneAssignments()
	assignments.Assign("kali-main", "%1", "manual")
	assignments.Assign("remote-main", "%2", "manual")
	state := WorkflowSession{Session: "$1", Panes: runtime.panes, Assignments: assignments}
	rendered := []RenderResult{{Text: "one"}, {Text: "two"}, {Text: "three"}}
	confirmer := &workflowConfirmerFake{}
	clipboard := &workflowClipboardFake{}
	coordinator := NewWorkflowCoordinator(runtime)

	err := NewWorkflowRunner(coordinator, runtime, confirmer, clipboard).
		Run(workflow, rendered, state, true)
	if err != nil {
		t.Fatal(err)
	}
	if len(confirmer.views) != 3 || !confirmer.views[1].AfterFirst ||
		confirmer.views[1].Pane.Command != "pwsh" ||
		len(confirmer.views[0].Notes) != 1 {
		t.Fatalf("views = %#v", confirmer.views)
	}
	wantSent := []string{"%1:one", "%2:two", "%1:three"}
	if len(runtime.sent) != len(wantSent) {
		t.Fatalf("sent = %#v", runtime.sent)
	}
	for index := range wantSent {
		if runtime.sent[index] != wantSent[index] {
			t.Fatalf("sent = %#v", runtime.sent)
		}
	}
	if len(clipboard.values) != 3 {
		t.Fatalf("clipboard = %#v", clipboard.values)
	}
}

func TestWorkflowRunnerStopsBeforeRejectedStage(t *testing.T) {
	runtime := &workflowRunnerRuntimeFake{workflowRuntimeFake: workflowRuntimeFake{
		panes: []WorkflowPane{{ID: "%1", Session: "$1"}},
	}}
	workflow := Workflow{
		Lanes: []string{"kali-main"},
		Stages: []WorkflowStage{
			{Lane: "kali-main"}, {Lane: "kali-main"},
		},
	}
	assignments := NewLaneAssignments()
	assignments.Assign("kali-main", "%1", "manual")
	state := WorkflowSession{Session: "$1", Assignments: assignments}
	confirmer := &workflowConfirmerFake{reject: 2}
	err := NewWorkflowRunner(
		NewWorkflowCoordinator(runtime), runtime, confirmer, nil,
	).Run(workflow, []RenderResult{{Text: "one"}, {Text: "two"}}, state, false)
	if err == nil || len(runtime.sent) != 1 {
		t.Fatalf("err=%v sent=%#v", err, runtime.sent)
	}
}

func TestWorkflowRunnerRejectsMismatchedRenderedStages(t *testing.T) {
	runtime := &workflowRunnerRuntimeFake{}
	err := NewWorkflowRunner(
		NewWorkflowCoordinator(runtime), runtime, &workflowConfirmerFake{}, nil,
	).Run(Workflow{Stages: []WorkflowStage{{}}}, nil, WorkflowSession{}, false)
	if err == nil {
		t.Fatalf("err = %v", err)
	}
}
