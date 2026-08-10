package terminal

import (
	"io"
	"strings"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

func TestWorkflowConfirmerShowsStageContractAndAcceptsY(t *testing.T) {
	var output, errors strings.Builder
	confirmer := NewWorkflowConfirmer(strings.NewReader(""), &output, &errors)
	confirmer.readKey = func(io.Reader) (string, error) { return "y", nil }
	confirmed, err := confirmer.ConfirmWorkflowStage(payload.WorkflowStageView{
		Index: 2, Count: 3, Ordinal: 1, Lane: "kali-main",
		Pane: payload.WorkflowPane{
			ID: "%1", Session: "$1", Window: "@2", Index: 0, Command: "zsh",
		},
		Shell: "bash", Title: "verify", Text: "echo $missing",
		Notes: []string{"wait first"}, AfterFirst: true,
		Report: []payload.ReportEntry{{Name: "missing", Source: payload.SourceMissing}},
	})
	if err != nil || !confirmed {
		t.Fatalf("confirmed=%v err=%v", confirmed, err)
	}
	for _, expected := range []string{
		"Workflow stage 2/3", "lane1: kali-main", "Shell: bash",
		"Title: verify", "Command: zsh", "Note: wait first",
		"Previous stage ready; send this stage? [y/N]",
	} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("output missing %q:\n%s", expected, output.String())
		}
	}
	if !strings.Contains(errors.String(), "Unresolved variables: missing") {
		t.Fatalf("errors = %q", errors.String())
	}
}
