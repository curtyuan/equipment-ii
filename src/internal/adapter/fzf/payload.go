package fzf

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func (m *Multi) SelectPayload(items []port.PayloadSelectionItem, category, query string) (port.PayloadSelection, error) {
	if err := m.Available(); err != nil {
		return port.PayloadSelection{}, err
	}
	previewDir, err := os.MkdirTemp("", "ii-payload-preview.*")
	if err != nil {
		return port.PayloadSelection{}, err
	}
	defer os.RemoveAll(previewDir)

	var input strings.Builder
	for index, item := range items {
		previewPath := filepath.Join(previewDir, strings.ReplaceAll(item.Path, "/", "_"))
		previewPath += "." + strconv.Itoa(index)
		if err = os.WriteFile(previewPath, []byte(item.Preview), 0o600); err != nil {
			return port.PayloadSelection{}, err
		}
		input.WriteString(item.Path + "\t" + previewPath + "\n")
	}
	args := []string{
		"--ansi", "--layout=reverse", "--prompt=ii payload:" + category + "> ",
		"--query=" + query, "--height=80%", "--border", "--delimiter=\t", "--with-nth=1",
		"--expect=enter",
		"--bind=j:down,k:up,e:print(e)+accept,y:print(y)+accept,q:abort",
		"--preview=cat -- {2}", "--preview-window=up,50%,nowrap,noinfo",
	}
	command := exec.Command("fzf", args...)
	command.Stdin = strings.NewReader(input.String())
	var output bytes.Buffer
	command.Stdout = &output
	if err = command.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok &&
			(exitError.ExitCode() == 1 || exitError.ExitCode() == 130) {
			return port.PayloadSelection{}, port.ErrSelectionCanceled
		}
		return port.PayloadSelection{}, err
	}
	trimmed := strings.Trim(output.String(), "\n")
	if trimmed == "" {
		return port.PayloadSelection{}, port.ErrSelectionCanceled
	}
	lines := strings.Split(trimmed, "\n")
	action := "enter"
	if len(lines) > 1 {
		action = lines[0]
		lines = lines[1:]
	}
	if override := os.Getenv("II_PAYLOAD_KEY"); override != "" {
		action = override
	}
	path, _, _ := strings.Cut(lines[0], "\t")
	if path == "" {
		return port.PayloadSelection{}, errors.New("ii: invalid payload selection")
	}
	return port.PayloadSelection{Action: action, Path: path}, nil
}
