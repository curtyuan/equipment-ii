package tmux

import (
	"errors"
	"os"
	"os/exec"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

var (
	ErrOutsideTmux = errors.New("ii: this command must run inside tmux")
	ErrTmuxMissing = errors.New("ii: tmux command not found")
)

type SessionEnvironment struct {
	getenv   func(string) string
	lookPath func(string) (string, error)
	command  func(string, ...string) *exec.Cmd
}

func NewSessionEnvironment() *SessionEnvironment {
	return &SessionEnvironment{
		getenv:   os.Getenv,
		lookPath: exec.LookPath,
		command:  exec.Command,
	}
}

func (s *SessionEnvironment) Read() (port.EnvironmentRead, error) {
	if s.getenv("TMUX") == "" {
		return port.EnvironmentRead{}, ErrOutsideTmux
	}
	if _, err := s.lookPath("tmux"); err != nil {
		return port.EnvironmentRead{}, ErrTmuxMissing
	}

	command := s.command("tmux", "show-environment")
	output, err := command.CombinedOutput()
	if err != nil {
		// Once the preflight succeeds, the legacy awk pipeline exposes tmux's
		// diagnostic but returns success with an empty list.
		return port.EnvironmentRead{Diagnostic: string(output)}, nil
	}

	text := strings.TrimSuffix(string(output), "\n")
	if text == "" {
		return port.EnvironmentRead{}, nil
	}
	return port.EnvironmentRead{Lines: strings.Split(text, "\n")}, nil
}

func (s *SessionEnvironment) Set(name, value string) error {
	if err := s.available(); err != nil {
		return err
	}
	return s.run("set-environment", name, value)
}

func (s *SessionEnvironment) Unset(name string) error {
	if err := s.available(); err != nil {
		return err
	}
	return s.run("set-environment", "-u", name)
}

func (s *SessionEnvironment) available() error {
	if s.getenv("TMUX") == "" {
		return ErrOutsideTmux
	}
	if _, err := s.lookPath("tmux"); err != nil {
		return ErrTmuxMissing
	}
	return nil
}

func (s *SessionEnvironment) run(args ...string) error {
	output, err := s.command("tmux", args...).CombinedOutput()
	if err != nil {
		message := strings.TrimSuffix(string(output), "\n")
		if message != "" {
			return errors.New(message)
		}
		return err
	}
	return nil
}
