package cli

import (
	"strings"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type workflowPayloadStoreFake struct{ text string }

func (f workflowPayloadStoreFake) List() ([]string, error)     { return []string{"flow"}, nil }
func (f workflowPayloadStoreFake) Read(string) (string, error) { return f.text, nil }

type workflowEnvironmentFake struct{ lines []string }

func (f workflowEnvironmentFake) Read() (port.EnvironmentRead, error) {
	return port.EnvironmentRead{Lines: f.lines}, nil
}
func (workflowEnvironmentFake) Set(string, string) error { return nil }
func (workflowEnvironmentFake) Unset(string) error       { return nil }

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

func (workflowSelectorCLIFake) SelectWorkflowLanes(lanes []string, state *payload.WorkflowSession) error {
	state.Assignments.Assign(lanes[0], "%1", "manual")
	state.Assignments.Assign(lanes[1], "%2", "manual")
	return nil
}

type workflowConfirmerCLIFake struct{ views []payload.WorkflowStageView }

func (f *workflowConfirmerCLIFake) ConfirmWorkflowStage(view payload.WorkflowStageView) (bool, error) {
	f.views = append(f.views, view)
	return true, nil
}

const comboDocument = `# description: demo
# flow: 1
# note: wait
# stage: zsh | listen
# lane: kali-main
# advance: confirm
echo $rhost
# stage: powershell | connect
# lane: remote-main
# advance: confirm
echo $rhost
`

func TestComboRunUsesTmuxStateOnly(t *testing.T) {
	app := newTestCLI()
	app.payloads = payload.NewCatalog(workflowPayloadStoreFake{text: comboDocument})
	app.environment = workflowEnvironmentFake{lines: []string{"ii_rhost=tmux-value"}}
	runtime := &workflowRuntimeCLIFake{}
	app.workflowRuntime = runtime
	app.workflowSelector = workflowSelectorCLIFake{}
	app.workflowConfirmer = &workflowConfirmerCLIFake{}
	var stdout, stderr strings.Builder
	status := app.Run([]string{"__combo-run", "flow", "%1", "$1", "0", "none"}, &stdout, &stderr)
	if status != 0 || stderr.String() != "" {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
	if len(runtime.sent) != 2 || runtime.sent[0] != "%1:echo tmux-value" || runtime.sent[1] != "%2:echo tmux-value" {
		t.Fatalf("sent = %#v", runtime.sent)
	}
}

func TestComboRunRejectsChangedOrigin(t *testing.T) {
	app := newTestCLI()
	app.payloads = payload.NewCatalog(workflowPayloadStoreFake{text: comboDocument})
	app.environment = workflowEnvironmentFake{lines: []string{"ii_rhost=value"}}
	app.workflowRuntime = &workflowRuntimeCLIFake{}
	var stdout, stderr strings.Builder
	status := app.Run([]string{"__combo-run", "flow", "%9", "$1", "0", "none"}, &stdout, &stderr)
	if status != 1 || !strings.Contains(stderr.String(), "origin pane is no longer available") {
		t.Fatalf("status=%d stderr=%q", status, stderr.String())
	}
}

func TestComboRunRejectsOpenClipboardChoice(t *testing.T) {
	app := newTestCLI()
	var stdout, stderr strings.Builder
	status := app.Run([]string{"__combo-run", "flow", "%1", "$1", "1", "auto"}, &stdout, &stderr)
	if status != 2 || !strings.Contains(stderr.String(), "invalid combo clipboard backend") {
		t.Fatalf("status=%d stderr=%q", status, stderr.String())
	}
}

func TestGoHelperRejectsPublicCommands(t *testing.T) {
	app := newTestCLI()
	var stdout, stderr strings.Builder
	status := app.Run([]string{"set", "rhost", "value"}, &stdout, &stderr)
	if status != 2 || !strings.Contains(stderr.String(), "unsupported Go helper command") {
		t.Fatalf("status=%d stderr=%q", status, stderr.String())
	}
}
