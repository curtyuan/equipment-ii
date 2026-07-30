package filesystem

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteAtomicReplacesFileAndLeavesNoTemporaryFile(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "vars.env")
	if err := os.WriteFile(path, []byte("stale\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	absolute, err := NewAtomicFileWriter().WriteAtomic(path, []byte("new\n"))
	if err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if absolute != path || string(got) != "new\n" {
		t.Fatalf("absolute=%q data=%q", absolute, got)
	}
	entries, err := os.ReadDir(directory)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Name() != "vars.env" {
		t.Fatalf("temporary output leaked: %#v", entries)
	}
}

func TestWriteAtomicRejectsMissingParentAndDirectoryTarget(t *testing.T) {
	directory := t.TempDir()
	writer := NewAtomicFileWriter()
	_, err := writer.WriteAtomic(filepath.Join(directory, "missing", "out"), nil)
	if err == nil || !strings.Contains(err.Error(), "output directory not found") {
		t.Fatalf("missing-parent error=%v", err)
	}
	_, err = writer.WriteAtomic(directory, nil)
	if err == nil || !strings.Contains(err.Error(), "output path is a directory") {
		t.Fatalf("directory-target error=%v", err)
	}
}
