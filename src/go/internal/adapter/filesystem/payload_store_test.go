package filesystem

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestPayloadStoreListAndRead(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "shell", ".hidden"), 0o755); err != nil {
		t.Fatal(err)
	}
	for path, content := range map[string]string{
		"shell/z":         "z",
		"shell/a":         "a",
		"shell/.ignored":  "ignored",
		".root-ignored":   "ignored",
		"shell/.hidden/x": "ignored",
	} {
		full := filepath.Join(root, filepath.FromSlash(path))
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	store := NewPayloadStore(root)
	paths, err := store.List()
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"shell/a", "shell/z"}; !reflect.DeepEqual(paths, want) {
		t.Fatalf("List = %#v, want %#v", paths, want)
	}
	if text, err := store.Read("shell/a"); err != nil || text != "a" {
		t.Fatalf("Read = %q, %v", text, err)
	}
}

func TestPayloadStoreRejectsTraversal(t *testing.T) {
	root := t.TempDir()
	outside := filepath.Join(t.TempDir(), "secret")
	if err := os.WriteFile(outside, []byte("secret"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "link")); err != nil {
		t.Fatal(err)
	}
	store := NewPayloadStore(root)
	for _, path := range []string{"", "../secret", "/etc/passwd", "link"} {
		if _, err := store.Read(path); err == nil {
			t.Fatalf("Read(%q) succeeded", path)
		}
	}
}
