package cli

import (
	"bytes"
	"testing"
)

func TestVariableOutputUsageDoesNotReadSession(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"vo", "one", "two"}, &stdout, &stderr)
	if status != 2 || stdout.Len() != 0 ||
		stderr.String() != "ii: usage: ii v --out [PATH] | ii vo [PATH]\n" {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
}
