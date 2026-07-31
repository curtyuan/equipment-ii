package cli

import (
	"bytes"
	"strings"
	"testing"
)

func TestPayloadInputHelpRoutes(t *testing.T) {
	tests := []struct {
		args []string
		want string
	}{
		{[]string{"pic", "--help"}, payloadInputCopyHelp},
		{[]string{"help", "pie"}, payloadInputExecuteHelp},
		{[]string{"help", "pice"}, payloadInputCopyExecuteHelp},
		{[]string{"help", "payload", "--input"}, payloadInputHelp},
	}
	for _, test := range tests {
		var stdout, stderr bytes.Buffer
		status := newTestCLI().Run(test.args, &stdout, &stderr)
		if status != 0 || stdout.String() != test.want || stderr.Len() != 0 {
			t.Fatalf("args=%q status=%d stdout=%q stderr=%q", test.args, status, stdout.String(), stderr.String())
		}
	}
}

func TestColorizeAliases(t *testing.T) {
	got := ColorizeAliases("Aliases:\n  h, -h    note\n  none\n\nBody\n", true)
	if !strings.Contains(got, "  \x1b[36mh, -h\x1b[0m    note\n") {
		t.Fatalf("unexpected colored help: %q", got)
	}
	if !strings.Contains(got, "  none\n") {
		t.Fatalf("none alias should remain plain: %q", got)
	}
}

func TestListHelpDoesNotReadSession(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"help", "ls"}, &stdout, &stderr)
	if status != 0 || stdout.String() != listHelp || stderr.Len() != 0 {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
}

func TestVariableHelpRoutes(t *testing.T) {
	tests := []struct {
		args []string
		want string
	}{
		{[]string{"v", "--help"}, variableHelp},
		{[]string{"help", "v"}, variableHelp},
		{[]string{"vo", "--help"}, variableOutputHelp},
		{[]string{"help", "v", "--out"}, variableOutputHelp},
	}
	for _, test := range tests {
		var stdout, stderr bytes.Buffer
		status := newTestCLI().Run(test.args, &stdout, &stderr)
		if status != 0 || stdout.String() != test.want || stderr.Len() != 0 {
			t.Fatalf("args=%q status=%d stdout=%q stderr=%q", test.args, status, stdout.String(), stderr.String())
		}
	}
}
