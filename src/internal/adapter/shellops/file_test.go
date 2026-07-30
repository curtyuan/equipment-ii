package shellops

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestFileWritesVersionedNULDelimitedOperations(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ops")
	if err := os.WriteFile(path, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	executePath := filepath.Join(t.TempDir(), "execute")
	if err := os.WriteFile(executePath, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	writer := NewFile(path, executePath)
	if err := writer.Export("rhost", "line 1\n'line 2'"); err != nil {
		t.Fatal(err)
	}
	if err := writer.Unset("RHOST"); err != nil {
		t.Fatal(err)
	}
	if err := writer.Chdir("/tmp/two words"); err != nil {
		t.Fatal(err)
	}
	if err := writer.SetSyncHook(true); err != nil {
		t.Fatal(err)
	}
	if err := writer.ExecuteScript("typeset -g executed=yes\n"); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	want := Header + "\x00" +
		"export\x00rhost\x00line 1\n'line 2'\x00" +
		"unset\x00RHOST\x00\x00" +
		"chdir\x00\x00/tmp/two words\x00" +
		"sync-hook\x00\x00on\x00" +
		"execute-file\x00\x00" + executePath + "\x00"
	if string(got) != want {
		t.Fatalf("protocol=%q, want %q", got, want)
	}
}

func TestFileRejectsInjectionNamesAndMissingChannel(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ops")
	if err := os.WriteFile(path, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := NewFile(path, "").Export("x; touch /tmp/pwn", "value"); err == nil {
		t.Fatal("invalid shell name accepted")
	}
	if err := NewFile("", "").Unset("rhost"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("error=%v, want ErrUnavailable", err)
	}
	if err := NewFile(path, "").ExecuteScript("echo unsafe"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("error=%v, want ErrUnavailable", err)
	}
}

func TestExecuteScriptRejectsSymlink(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "target")
	link := filepath.Join(root, "link")
	if err := os.WriteFile(target, []byte("safe"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, link); err != nil {
		t.Fatal(err)
	}
	ops := filepath.Join(root, "ops")
	if err := os.WriteFile(ops, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := NewFile(ops, link).ExecuteScript("unsafe"); err == nil {
		t.Fatal("ExecuteScript accepted a symlink")
	}
	data, err := os.ReadFile(target)
	if err != nil || string(data) != "safe" {
		t.Fatalf("target changed to %q, err=%v", data, err)
	}
}
