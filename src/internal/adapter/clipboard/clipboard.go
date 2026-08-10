package clipboard

import (
	"bytes"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type Adapter struct {
	environment port.EnvironmentReader
}

func New(environment port.EnvironmentReader) *Adapter {
	return &Adapter{environment: environment}
}

func (a *Adapter) Copy(text string) error {
	backend, command, err := a.configuration()
	if err != nil {
		return err
	}
	if backend == "" && command == "" {
		backend, err = a.detect()
		if err != nil {
			return err
		}
	}
	if command != "" {
		if command == "osc52" {
			return a.copyOSC52(text)
		}
		process := exec.Command("sh", "-c", command)
		process.Stdin = bytes.NewBufferString(text)
		return process.Run()
	}
	return a.copyBackend(backend, text)
}

func (a *Adapter) EffectiveBackend() (string, error) {
	backend, command, err := a.configuration()
	if err != nil {
		return "", err
	}
	if backend != "" {
		return backend, nil
	}
	if command != "" {
		return "cmd:" + command, nil
	}
	return a.detect()
}

func (a *Adapter) Context() string {
	if os.Getenv("SSH_CONNECTION") != "" ||
		(os.Getenv("SSH_CLIENT") != "" && os.Getenv("DISPLAY") == "") {
		return "ssh"
	}
	return "local"
}

func (a *Adapter) configuration() (backend, command string, err error) {
	backend = os.Getenv("II_CLIP_BACKEND")
	command = os.Getenv("II_CLIP_CMD")
	if backend != "" || command != "" || os.Getenv("TMUX") == "" {
		return backend, command, nil
	}
	read, err := a.environment.Read()
	if err != nil {
		return "", "", err
	}
	for _, line := range read.Lines {
		name, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		switch name {
		case "II_CLIP_BACKEND":
			backend = value
		case "II_CLIP_CMD":
			command = value
		}
	}
	return backend, command, nil
}

func (a *Adapter) detect() (string, error) {
	if a.Context() == "ssh" {
		if _, err := exec.LookPath("base64"); err == nil {
			return "osc52", nil
		}
	}
	if os.Getenv("TMUX") != "" && os.Getenv("DISPLAY") != "" {
		if _, err := exec.LookPath("xclip"); err == nil {
			return "xclip-both", nil
		}
	}
	if os.Getenv("TMUX") != "" {
		if _, err := exec.LookPath("base64"); err == nil {
			return "osc52", nil
		}
	}
	for _, candidate := range []string{"clip.exe", "wl-copy", "xclip", "xsel", "pbcopy"} {
		if _, err := exec.LookPath(candidate); err == nil {
			return candidate, nil
		}
	}
	if os.Getenv("TMUX") != "" {
		if _, err := exec.LookPath("tmux"); err == nil {
			return "tmux", nil
		}
	}
	return "", errors.New("clipboard unavailable")
}

func (a *Adapter) copyBackend(backend, text string) error {
	run := func(name string, args ...string) error {
		command := exec.Command(name, args...)
		command.Stdin = bytes.NewBufferString(text)
		command.Stdout = nil
		command.Stderr = nil
		return command.Run()
	}
	switch backend {
	case "clip.exe", "wl-copy", "pbcopy":
		return run(backend)
	case "xclip":
		return run("xclip", "-selection", "clipboard")
	case "xclip-both":
		if err := run("xclip", "-i", "-selection", "primary"); err != nil {
			return err
		}
		return run("xclip", "-i", "-selection", "clipboard")
	case "xsel":
		return run("xsel", "--clipboard", "--input")
	case "osc52":
		return a.copyOSC52(text)
	case "tmux":
		return run("tmux", "load-buffer", "-")
	default:
		return fmt.Errorf("clipboard unavailable")
	}
}

func (a *Adapter) copyOSC52(text string) error {
	if os.Getenv("TMUX") != "" {
		command := exec.Command("tmux", "load-buffer", "-w", "-")
		command.Stdin = bytes.NewBufferString(text)
		if command.Run() == nil {
			return nil
		}
		command = exec.Command("tmux", "load-buffer", "-")
		command.Stdin = bytes.NewBufferString(text)
		if command.Run() == nil {
			return nil
		}
	}
	sequence := "\x1b]52;c;" + base64.StdEncoding.EncodeToString([]byte(text)) + "\a"
	if os.Getenv("TMUX") != "" {
		sequence = "\x1bPtmux;\x1b" + sequence + "\x1b\\"
	}
	tty, err := os.OpenFile("/dev/tty", os.O_WRONLY, 0)
	if err == nil {
		defer tty.Close()
		_, err = tty.WriteString(sequence)
		return err
	}
	_, err = os.Stdout.WriteString(sequence)
	return err
}
