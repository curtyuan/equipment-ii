package fzf

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func (m *Multi) Available() error {
	if _, err := exec.LookPath("fzf"); err != nil {
		return errors.New("ii: required command not found: fzf")
	}
	return nil
}

func (m *Multi) SelectVariable(items []port.SelectionItem) (port.InteractiveSelection, error) {
	if err := m.Available(); err != nil {
		return port.InteractiveSelection{}, err
	}
	var input strings.Builder
	for _, item := range items {
		input.WriteString(item.ID + "\t" + item.Display + "\n")
	}
	args := []string{"-i", "--ansi", "--expect=enter", "--layout=reverse",
		"--prompt=ii vars> ", "--delimiter=\t", "--with-nth=1,2",
		"--bind=j:down,k:up,l:print(i)+accept,i:print(i)+accept,y:print(y)+accept,h:abort,q:abort"}
	command := exec.Command("fzf", args...)
	command.Stdin = strings.NewReader(input.String())
	var output bytes.Buffer
	command.Stdout = &output
	if err := command.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok &&
			(exitError.ExitCode() == 1 || exitError.ExitCode() == 130) {
			return port.InteractiveSelection{}, port.ErrSelectionCanceled
		}
		return port.InteractiveSelection{}, err
	}
	trimmed := strings.Trim(output.String(), "\n")
	if trimmed == "" {
		return port.InteractiveSelection{}, port.ErrSelectionCanceled
	}
	lines := strings.Split(trimmed, "\n")
	action := "enter"
	if len(lines) > 1 {
		action = lines[0]
		lines = lines[1:]
	}
	if override := os.Getenv("II_INTERACTIVE_KEY"); override != "" {
		action = override
	}
	id, _, _ := strings.Cut(lines[0], "\t")
	return port.InteractiveSelection{Action: action, ID: id}, nil
}

func (m *Multi) Input(prompt, initial string) (string, error) {
	if err := m.Available(); err != nil {
		return "", err
	}
	command := exec.Command("fzf", "-i", "--print-query", "--phony",
		"--query="+initial, "--prompt="+prompt, "--height=40%", "--border")
	command.Stdin = strings.NewReader("\n")
	var output bytes.Buffer
	command.Stdout = &output
	if err := command.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok &&
			(exitError.ExitCode() == 1 || exitError.ExitCode() == 130) {
			return "", port.ErrSelectionCanceled
		}
		return "", err
	}
	value, _, _ := strings.Cut(output.String(), "\n")
	return value, nil
}

func (m *Multi) SelectOne(items []port.SelectionItem) (string, error) {
	if err := m.Available(); err != nil {
		return "", err
	}
	var input strings.Builder
	for _, item := range items {
		input.WriteString(item.ID + "\t" + item.Display + "\n")
	}
	command := exec.Command("fzf", "-i", "--ansi", "--prompt=ii get var> ",
		"--height=40%", "--border", "--bind=space:accept,q:abort,esc:abort",
		"--delimiter=\t", "--with-nth=2")
	command.Stdin = strings.NewReader(input.String())
	var output bytes.Buffer
	command.Stdout = &output
	if err := command.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok &&
			(exitError.ExitCode() == 1 || exitError.ExitCode() == 130) {
			return "", port.ErrSelectionCanceled
		}
		return "", err
	}
	id, _, _ := strings.Cut(strings.TrimSuffix(output.String(), "\n"), "\t")
	return id, nil
}
