package www

import (
	"errors"
	"path/filepath"
	"testing"
)

type fakeStore struct {
	root    string
	entries []Entry
	source  string
	linked  string
}

func (s *fakeStore) RequireRoot(string) (string, error) { return s.root, nil }
func (s *fakeStore) ResolveSource(string, bool) (string, error) {
	if s.source == "" {
		return "", errors.New("missing")
	}
	return s.source, nil
}
func (s *fakeStore) MakeDir(string) error { return nil }
func (s *fakeStore) Entries(string, bool) ([]Entry, error) {
	return append([]Entry(nil), s.entries...), nil
}
func (s *fakeStore) Symlink(_, target string) error {
	s.linked = target
	return nil
}

func TestValidateLinkName(t *testing.T) {
	for _, name := range []string{"", ".", "..", "a/b", `a\b`} {
		if ValidateLinkName(name) == nil {
			t.Fatalf("ValidateLinkName(%q) accepted invalid name", name)
		}
	}
	if err := ValidateLinkName("payload.txt"); err != nil {
		t.Fatal(err)
	}
}

func TestLinkRejectsDirectoryOutsideRoot(t *testing.T) {
	store := &fakeStore{root: "/www", source: "/tmp/source"}
	service := NewService(store, "/www")
	if _, err := service.Link("source", "/tmp", "link"); err == nil {
		t.Fatal("Link accepted a directory outside root")
	}
}

func TestRelativeDirAndTreeLabel(t *testing.T) {
	entry := Entry{Relative: filepath.Join("p", "nested", "file"), Kind: KindFile}
	if got := RelativeDir(entry); got != "/p/nested/" {
		t.Fatalf("RelativeDir = %q", got)
	}
	if got := TreeLabel(entry); got != "    file" {
		t.Fatalf("TreeLabel = %q", got)
	}
}
