package filesystem

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type PayloadStore struct {
	root string
}

func NewPayloadStore(root string) *PayloadStore {
	return &PayloadStore{root: root}
}

func (s *PayloadStore) List() ([]string, error) {
	info, err := os.Stat(s.root)
	if err != nil || !info.IsDir() {
		return nil, fmt.Errorf("ii: payload directory not found: %s", s.root)
	}
	var paths []string
	err = filepath.WalkDir(s.root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == s.root {
			return nil
		}
		if strings.HasPrefix(entry.Name(), ".") {
			if entry.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if entry.Type().IsRegular() {
			relative, err := filepath.Rel(s.root, path)
			if err != nil {
				return err
			}
			paths = append(paths, filepath.ToSlash(relative))
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("ii: cannot list payload directory: %w", err)
	}
	sort.Strings(paths)
	return paths, nil
}

func (s *PayloadStore) Read(path string) (string, error) {
	if path == "" || filepath.IsAbs(path) {
		return "", errors.New("ii: invalid payload path")
	}
	clean := filepath.Clean(filepath.FromSlash(path))
	if clean == "." || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
		return "", errors.New("ii: invalid payload path")
	}
	full := filepath.Join(s.root, clean)
	info, err := os.Lstat(full)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return "", fmt.Errorf("ii: payload not found: %s", path)
		}
		return "", fmt.Errorf("ii: cannot read payload %s: %w", path, err)
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("ii: payload not found: %s", path)
	}
	data, err := os.ReadFile(full)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return "", fmt.Errorf("ii: payload not found: %s", path)
		}
		return "", fmt.Errorf("ii: cannot read payload %s: %w", path, err)
	}
	return string(data), nil
}
