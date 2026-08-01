package cli

import (
	"strings"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type workflowPayloadStoreFake struct {
	text string
}

func (f workflowPayloadStoreFake) List() ([]string, error)     { return []string{"flow"}, nil }
func (f workflowPayloadStoreFake) Read(string) (string, error) { return f.text, nil }

type workflowRuntimeCLIFake struct {
	sent    []string
	written string
}

func (f *workflowRuntimeCLIFake) CurrentWorkflowSession() (string, string, error) {
	return "$1", "%1", nil
}
func (f *workflowRuntimeCLIFake) WorkflowPanes(string) ([]payload.WorkflowPane, error) {
	return []payload.WorkflowPane{
		{ID: "%1", Session: "$1", Window: "@1", Width: 40, Height: 20, Command: "zsh"},
		{ID: "%2", Session: "$1", Window: "@1", Left: 40, Width: 40, Height: 20, Command: "pwsh"},
	}, nil
}
func (f *workflowRuntimeCLIFake) ReadWorkflowMemory(string) (string, error) { return "", nil }
func (f *workflowRuntimeCLIFake) WriteWorkflowMemory(_, value string) error {
	f.written = value
	return nil
}
func (f *workflowRuntimeCLIFake) WorkflowPaneSnapshot(id string) (payload.WorkflowPane, error) {
	panes, _ := f.WorkflowPanes("$1")
	for _, pane := range panes {
		if pane.ID == id {
			return pane, nil
		}
	}
	return payload.WorkflowPane{}, nil
}
func (f *workflowRuntimeCLIFake) SendWorkflowStage(_, pane, text string) error {
	f.sent = append(f.sent, pane+":"+text)
	return nil
}

type workflowSelectorCLIFake struct{}

func (workflowSelectorCLIFake) SelectWorkflowLanes(
	lanes []string, state *payload.WorkflowSession,
) error {
	state.Assignments.Assign(lanes[0], "%1", "manual")
	state.Assignments.Assign(lanes[1], "%2", "manual")
	return nil
}

type workflowConfirmerCLIFake struct {
	views []payload.WorkflowStageView
}

type workflowPayloadSelectorFake struct{}

func (workflowPayloadSelectorFake) SelectPayload(
	[]port.PayloadSelectionItem, string, string,
) (port.PayloadSelection, error) {
	return port.PayloadSelection{Action: "enter", Path: "flow"}, nil
}

type workflowPopupCLIFake struct {
	helper string
	path   string
	copy   bool
}

func (f *workflowPopupCLIFake) LaunchWorkflowPopup(helper, path string, copyStages bool) error {
	f.helper, f.path, f.copy = helper, path, copyStages
	return nil
}

func (f *workflowConfirmerCLIFake) ConfirmWorkflowStage(
	view payload.WorkflowStageView,
) (bool, error) {
	f.views = append(f.views, view)
	return true, nil
}

func TestRunWorkflowPopupComposesSelectionAndRunner(t *testing.T) {
	const document = `# description: demo
# flow: 1
# note: wait
# stage: zsh | listen
# lane: kali-main
# advance: confirm
echo one
# stage: powershell | connect
# lane: remote-main
# advance: confirm
echo two
`
	app := newTestCLI()
	app.payloads = payload.NewCatalog(workflowPayloadStoreFake{text: document})
	runtime := &workflowRuntimeCLIFake{}
	confirmer := &workflowConfirmerCLIFake{}
	app.workflowRuntime = runtime
	app.workflowSelector = workflowSelectorCLIFake{}
	app.workflowConfirmer = confirmer
	var stdout, stderr strings.Builder

	status := app.Run(
		[]string{"__workflow_popup", "flow", "%1", "$1", "0"},
		&stdout, &stderr,
	)
	if status != 0 || stderr.String() != "" {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
	if runtime.written != "kali-main=%1\nremote-main=%2" {
		t.Fatalf("memory = %q", runtime.written)
	}
	if len(runtime.sent) != 2 || runtime.sent[0] != "%1:echo one" ||
		runtime.sent[1] != "%2:echo two" {
		t.Fatalf("sent = %#v", runtime.sent)
	}
	if len(confirmer.views) != 2 || confirmer.views[0].Notes[0] != "wait" {
		t.Fatalf("views = %#v", confirmer.views)
	}
	if !strings.Contains(stdout.String(), "workflow completed: 2 stage(s) sent") {
		t.Fatalf("stdout = %q", stdout.String())
	}
}

func TestRunWorkflowPopupRejectsChangedOrigin(t *testing.T) {
	app := newTestCLI()
	app.payloads = payload.NewCatalog(workflowPayloadStoreFake{text: `# flow: 1
# stage: zsh | one
# lane: kali-main
# advance: confirm
echo one
`})
	app.workflowRuntime = &workflowRuntimeCLIFake{}
	var stdout, stderr strings.Builder
	status := app.Run(
		[]string{"__workflow_popup", "flow", "%9", "$1", "0"},
		&stdout, &stderr,
	)
	if status != 1 || !strings.Contains(stderr.String(), "origin pane is no longer available") {
		t.Fatalf("status=%d stderr=%q", status, stderr.String())
	}
}

func TestRunPayloadLaunchesWorkflowPopupWithCopyMode(t *testing.T) {
	app := newTestCLI()
	app.payloads = payload.NewCatalog(workflowPayloadStoreFake{text: `# flow: 1
# stage: zsh | one
# lane: kali-main
# advance: confirm
echo one
`})
	app.payloadSelector = workflowPayloadSelectorFake{}
	popup := &workflowPopupCLIFake{}
	app.workflowPopup = popup
	var stdout, stderr strings.Builder
	status := app.Run([]string{"__payload_select", "--execute", "--copy"}, &stdout, &stderr)
	if status != 0 || stderr.String() != "" {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
	if popup.path != "flow" || !popup.copy || popup.helper == "" {
		t.Fatalf("popup = %#v", popup)
	}
}

func TestPublicPayloadAliasesLaunchWorkflowPopup(t *testing.T) {
	tests := []struct {
		command string
		copy    bool
	}{
		{command: "pe"},
		{command: "pce", copy: true},
	}
	for _, test := range tests {
		t.Run(test.command, func(t *testing.T) {
			app := newTestCLI()
			app.payloads = payload.NewCatalog(workflowPayloadStoreFake{text: `# flow: 1
# stage: zsh | one
# lane: kali-main
# advance: confirm
echo one
`})
			app.payloadSelector = workflowPayloadSelectorFake{}
			popup := &workflowPopupCLIFake{}
			app.workflowPopup = popup
			var stdout, stderr strings.Builder
			status := app.Run([]string{test.command, "flow"}, &stdout, &stderr)
			if status != 0 || stderr.String() != "" {
				t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
			}
			if popup.path != "flow" || popup.copy != test.copy {
				t.Fatalf("popup = %#v", popup)
			}
		})
	}
}
