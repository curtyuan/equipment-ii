package www

import (
	"errors"
	"fmt"
	"path/filepath"
	"sort"
	"strings"
)

type Kind string

const (
	KindFile Kind = "file"
	KindDir  Kind = "dir"
	KindLink Kind = "link"
)

type Entry struct {
	Absolute string
	Relative string
	Kind     Kind
}

type Store interface {
	RequireRoot(path string) (string, error)
	ResolveSource(path string, regular bool) (string, error)
	MakeDir(path string) error
	Entries(root string, includeRoot bool) ([]Entry, error)
	Symlink(source, target string) error
}

type Selector interface {
	SelectDirectory(entries []Entry) (Entry, error)
	SelectEntry(entries []Entry, filter string) (Entry, error)
}

type Service struct {
	store Store
	root  string
}

func NewService(store Store, root string) *Service {
	if root == "" {
		root = "/www"
	}
	return &Service{store: store, root: filepath.Clean(root)}
}

func (s *Service) Root() string {
	return s.root
}

func (s *Service) List() (string, []Entry, error) {
	root, err := s.store.RequireRoot(s.root)
	if err != nil {
		return "", nil, err
	}
	entries, err := s.store.Entries(root, false)
	if err != nil {
		return "", nil, err
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Absolute < entries[j].Absolute })
	return root, entries, nil
}

func (s *Service) Directories() ([]Entry, error) {
	root, err := s.store.RequireRoot(s.root)
	if err != nil {
		return nil, err
	}
	entries, err := s.store.Entries(root, true)
	if err != nil {
		return nil, err
	}
	directories := entries[:0]
	for _, entry := range entries {
		if entry.Kind == KindDir {
			directories = append(directories, entry)
		}
	}
	return directories, nil
}

func (s *Service) Entries() ([]Entry, error) {
	_, entries, err := s.List()
	return entries, err
}

func (s *Service) Link(source, directory, name string) (string, error) {
	sourceAbs, err := s.store.ResolveSource(source, false)
	if err != nil {
		return "", err
	}
	if name == "" {
		name = filepath.Base(sourceAbs)
	}
	if err := ValidateLinkName(name); err != nil {
		return "", err
	}
	root, err := s.store.RequireRoot(s.root)
	if err != nil {
		return "", err
	}
	directory = filepath.Clean(directory)
	if !contained(root, directory) {
		return "", errors.New("ii: selected directory is outside the configured web root")
	}
	target := filepath.Join(directory, name)
	if err := s.store.Symlink(sourceAbs, target); err != nil {
		return "", err
	}
	return target, nil
}

func (s *Service) LinkIntoPayload(source string) (sourceAbs, target string, err error) {
	sourceAbs, err = s.store.ResolveSource(source, true)
	if err != nil {
		return "", "", err
	}
	name := filepath.Base(sourceAbs)
	if err = ValidateLinkName(name); err != nil {
		return "", "", err
	}
	directory := filepath.Join(s.root, "p")
	if err = s.store.MakeDir(directory); err != nil {
		return "", "", err
	}
	target = filepath.Join(directory, name)
	if err = s.store.Symlink(sourceAbs, target); err != nil {
		return "", "", err
	}
	return sourceAbs, target, nil
}

func ValidateLinkName(name string) error {
	if name == "" || name == "." || name == ".." ||
		strings.ContainsAny(name, `/\`) {
		return fmt.Errorf("ii: invalid link name: %s", name)
	}
	return nil
}

func RelativeDir(entry Entry) string {
	relative := entry.Relative
	if entry.Kind != KindDir {
		relative = filepath.Dir(relative)
	}
	if relative == "." || relative == "" {
		return "/"
	}
	return "/" + filepath.ToSlash(relative) + "/"
}

func TreeLabel(entry Entry) string {
	depth := 0
	if entry.Relative != "" && entry.Relative != "." {
		depth = len(strings.Split(filepath.ToSlash(entry.Relative), "/")) - 1
	}
	return strings.Repeat(" ", depth*2) + filepath.Base(entry.Relative)
}

func contained(root, path string) bool {
	relative, err := filepath.Rel(root, path)
	return err == nil && relative != ".." &&
		!strings.HasPrefix(relative, ".."+string(filepath.Separator))
}
