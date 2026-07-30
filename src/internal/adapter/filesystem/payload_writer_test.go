package filesystem

import (
	"os"
	"path/filepath"
	"testing"
)

func TestPayloadWriterCreatesParentDirectories(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nested", "payload.txt")
	absolute, err := NewPayloadWriter().WritePayload(path, "payload")
	if err != nil {
		t.Fatal(err)
	}
	if data, err := os.ReadFile(absolute); err != nil || string(data) != "payload" {
		t.Fatalf("ReadFile = %q, %v", data, err)
	}
}
