package tmux

import "testing"

func TestWorkflowPopupCommandQuotesRuntimeValues(t *testing.T) {
	got := workflowPopupCommand(
		"/tmp/ii go", "script/combo/a payload", "%1", "$2", "1",
	)
	want := `'/tmp/ii go' __workflow_popup 'script/combo/a payload' %1 '$2' 1`
	if got != want {
		t.Fatalf("command = %q, want %q", got, want)
	}
}
