package payload

import (
	"errors"
	"testing"
)

func TestParseWorkflow(t *testing.T) {
	text := "# description: transfer\n# flow: 1\n# note: ready\n\n" +
		"# stage: powershell | Receive\n# lane: remote-receiver\n# advance: confirm\n$PORT = $rport\n\n" +
		"# stage: zsh | Send\n# lane: kali-sender\n# advance: confirm\nnc \"$rhost\" \"$rport\"\n"
	workflow, err := ParseWorkflow("fixture", text)
	if err != nil {
		t.Fatal(err)
	}
	if workflow.Version != "1" || workflow.Description != "transfer" ||
		len(workflow.Notes) != 1 || len(workflow.Lanes) != 2 || len(workflow.Stages) != 2 {
		t.Fatalf("unexpected workflow: %#v", workflow)
	}
	if workflow.Stages[1].Body != `nc "$rhost" "$rport"` {
		t.Fatalf("unexpected body: %q", workflow.Stages[1].Body)
	}
}

func TestParseWorkflowRejectsInvalidStructure(t *testing.T) {
	tests := []struct {
		name string
		text string
		line int
	}{
		{"duplicate flow", "# flow: 1\n# flow: 1\n", 2},
		{"lane adjacency", "# flow: 1\n# stage: zsh | run\n\n# lane: kali-main\n# advance: confirm\nprint ok\n", 3},
		{"invalid advance", "# flow: 1\n# stage: zsh | run\n# lane: kali-main\n# advance: delay 1\nprint ok\n", 4},
		{"empty stage", "# flow: 1\n# stage: zsh | run\n# lane: kali-main\n# advance: confirm\n# comment\n", 2},
		{"executable prefix", "# flow: 1\necho unsafe\n", 2},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := ParseWorkflow("fixture", test.text)
			var parseError *WorkflowError
			if !errors.As(err, &parseError) || parseError.Line != test.line {
				t.Fatalf("error = %#v, want WorkflowError line %d", err, test.line)
			}
		})
	}
}
