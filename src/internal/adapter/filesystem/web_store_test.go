package filesystem

import (
	"os"
	"path/filepath"
	"testing"

	wwwdomain "github.com/curtyuan/equipment-ii/src/internal/www"
)

func TestWebStoreWalkDoesNotFollowSymlinks(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(root, "dir"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	entries, err := NewWebStore().Entries(root, false)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 2 || entries[0].Kind != wwwdomain.KindDir ||
		entries[1].Kind != wwwdomain.KindLink {
		t.Fatalf("entries = %#v", entries)
	}
}

func TestWebStoreSymlinkDoesNotOverwriteDanglingLink(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "existing")
	if err := os.Symlink("/missing", target); err != nil {
		t.Fatal(err)
	}
	if err := NewWebStore().Symlink("/source", target); err == nil {
		t.Fatal("Symlink overwrote a dangling link")
	}
}
