package cli

import (
	"bytes"
	"testing"
)

func TestVersion(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"version"}, &stdout, &stderr)
	if status != 0 || stdout.String() != "ii 0.2.4\n" || stderr.Len() != 0 {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
}

func TestUnknownCommand(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"wat"}, &stdout, &stderr)
	if status != 2 {
		t.Fatalf("status=%d, want 2", status)
	}
	if stderr.String() != "ii: unknown command: wat\n" {
		t.Fatalf("stderr=%q", stderr.String())
	}
	if stdout.String() != topHelp {
		t.Fatal("unknown command did not print top-level help")
	}
}
