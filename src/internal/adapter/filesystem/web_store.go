package filesystem

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"

	wwwdomain "github.com/curtyuan/equipment-ii/src/internal/www"
)

type WebStore struct{}

func NewWebStore() *WebStore { return &WebStore{} }

func (s *WebStore) RequireRoot(path string) (string, error) {
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		return "", fmt.Errorf("ii: /www directory not found: %s", path)
	}
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	return absolute, nil
}

func (s *WebStore) ResolveSource(path string, regular bool) (string, error) {
	info, err := os.Stat(path)
	if err != nil {
		if regular {
			return "", fmt.Errorf("ii: file not found: %s", path)
		}
		return "", fmt.Errorf("ii: source path not found: %s", path)
	}
	if regular && !info.Mode().IsRegular() {
		return "", fmt.Errorf("ii: file not found: %s", path)
	}
	return filepath.Abs(path)
}

func (s *WebStore) MakeDir(path string) error {
	if err := os.MkdirAll(path, 0o755); err != nil {
		return fmt.Errorf("ii: failed to create /www/p directory: %s", path)
	}
	return nil
}

func (s *WebStore) Entries(root string, includeRoot bool) ([]wwwdomain.Entry, error) {
	var entries []wwwdomain.Entry
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == root && !includeRoot {
			return nil
		}
		kind := wwwdomain.KindFile
		if entry.Type()&os.ModeSymlink != 0 {
			kind = wwwdomain.KindLink
		} else if entry.IsDir() {
			kind = wwwdomain.KindDir
		} else if !entry.Type().IsRegular() {
			return nil
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		entries = append(entries, wwwdomain.Entry{
			Absolute: path,
			Relative: relative,
			Kind:     kind,
		})
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Absolute < entries[j].Absolute })
	return entries, nil
}

func (s *WebStore) Symlink(source, target string) error {
	if _, err := os.Lstat(target); err == nil {
		return fmt.Errorf("ii: target already exists: %s", target)
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	if err := os.Symlink(source, target); err != nil {
		return fmt.Errorf("ii: failed to create symlink: %s", target)
	}
	return nil
}
