package filesystem

import (
	"fmt"
	"os"
	"path/filepath"
)

type AtomicFileWriter struct{}

func NewAtomicFileWriter() *AtomicFileWriter {
	return &AtomicFileWriter{}
}

func (w *AtomicFileWriter) WriteAtomic(path string, data []byte) (string, error) {
	absolutePath, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	parent := filepath.Dir(absolutePath)
	info, err := os.Stat(parent)
	if err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("ii: output directory not found: %s", parent)
		}
		return "", err
	}
	if !info.IsDir() {
		return "", fmt.Errorf("ii: output directory not found: %s", parent)
	}
	if info, err = os.Stat(absolutePath); err == nil && info.IsDir() {
		return "", fmt.Errorf("ii: output path is a directory: %s", absolutePath)
	} else if err != nil && !os.IsNotExist(err) {
		return "", err
	}

	temp, err := os.CreateTemp(parent, filepath.Base(absolutePath)+".tmp.*")
	if err != nil {
		return "", fmt.Errorf("ii: failed to create temporary output beside: %s", absolutePath)
	}
	tempPath := temp.Name()
	cleanup := true
	defer func() {
		if cleanup {
			_ = os.Remove(tempPath)
		}
	}()

	if _, err = temp.Write(data); err != nil {
		_ = temp.Close()
		return "", fmt.Errorf("ii: failed to serialize variable output: %s", absolutePath)
	}
	if err = temp.Close(); err != nil {
		return "", fmt.Errorf("ii: failed to serialize variable output: %s", absolutePath)
	}
	if err = os.Rename(tempPath, absolutePath); err != nil {
		return "", fmt.Errorf("ii: failed to replace variable output: %s", absolutePath)
	}
	cleanup = false
	return absolutePath, nil
}
