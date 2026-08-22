package tmux

import (
	"errors"
	"testing"
)

func TestReadRejectsOutsideTmux(t *testing.T) {
	adapter := &SessionEnvironment{
		getenv: func(string) string { return "" },
	}
	_, err := adapter.Read()
	if !errors.Is(err, ErrOutsideTmux) {
		t.Fatalf("error=%v, want ErrOutsideTmux", err)
	}
}

func TestReadRejectsMissingTmuxCommand(t *testing.T) {
	adapter := &SessionEnvironment{
		getenv: func(string) string { return "socket,pid,0" },
		lookPath: func(string) (string, error) {
			return "", errors.New("missing")
		},
	}
	_, err := adapter.Read()
	if !errors.Is(err, ErrTmuxMissing) {
		t.Fatalf("error=%v, want ErrTmuxMissing", err)
	}
}
