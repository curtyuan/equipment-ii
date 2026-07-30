package shellops

import (
	"errors"
	"fmt"
	"os"
	"regexp"
	"syscall"
)

const Header = "ii-shell-ops-v1"

var (
	ErrUnavailable = errors.New("ii: parent-shell operation channel unavailable")
	shellName      = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
)

type File struct {
	path        string
	executePath string
}

func NewFile(path, executePath string) *File {
	return &File{path: path, executePath: executePath}
}

func (f *File) ExecuteScript(script string) error {
	if f.executePath == "" {
		return ErrUnavailable
	}
	info, err := os.Lstat(f.executePath)
	if err != nil || !info.Mode().IsRegular() {
		return errors.New("ii: parent-shell execution channel unavailable")
	}
	file, err := os.OpenFile(f.executePath, os.O_WRONLY|os.O_TRUNC|syscall.O_NOFOLLOW, 0o600)
	if err != nil {
		return fmt.Errorf("ii: parent-shell execution channel failed: %w", err)
	}
	if _, err = file.WriteString(script); err != nil {
		_ = file.Close()
		return fmt.Errorf("ii: parent-shell execution channel failed: %w", err)
	}
	if err = file.Close(); err != nil {
		return fmt.Errorf("ii: parent-shell execution channel failed: %w", err)
	}
	return f.append("execute-file", "", f.executePath)
}

func (f *File) Export(name, value string) error {
	if !shellName.MatchString(name) {
		return fmt.Errorf("ii: invalid parent-shell variable name: %s", name)
	}
	return f.append("export", name, value)
}

func (f *File) Unset(name string) error {
	if !shellName.MatchString(name) {
		return fmt.Errorf("ii: invalid parent-shell variable name: %s", name)
	}
	return f.append("unset", name, "")
}

func (f *File) Chdir(path string) error {
	if path == "" {
		return errors.New("ii: parent-shell directory cannot be empty")
	}
	return f.append("chdir", "", path)
}

func (f *File) SetSyncHook(enabled bool) error {
	value := "off"
	if enabled {
		value = "on"
	}
	return f.append("sync-hook", "", value)
}

func (f *File) append(operation, name, value string) error {
	if f.path == "" {
		return ErrUnavailable
	}
	file, err := os.OpenFile(f.path, os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		return fmt.Errorf("ii: parent-shell operation channel failed: %w", err)
	}
	defer file.Close()

	info, err := file.Stat()
	if err != nil {
		return fmt.Errorf("ii: parent-shell operation channel failed: %w", err)
	}
	if info.Size() == 0 {
		if _, err = file.WriteString(Header + "\x00"); err != nil {
			return fmt.Errorf("ii: parent-shell operation channel failed: %w", err)
		}
	}
	if _, err = file.WriteString(operation + "\x00" + name + "\x00" + value + "\x00"); err != nil {
		return fmt.Errorf("ii: parent-shell operation channel failed: %w", err)
	}
	return nil
}
