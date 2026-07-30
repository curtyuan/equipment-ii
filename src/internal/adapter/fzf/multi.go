package fzf

import (
	"bytes"
	"errors"
	"os/exec"
	"strconv"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type Multi struct{}

func NewMulti() *Multi { return &Multi{} }

func (m *Multi) Select(items []port.SelectionItem) ([]string, error) {
	if _, err := exec.LookPath("fzf"); err != nil {
		return nil, errors.New("ii: required command not found: fzf")
	}
	var input strings.Builder
	for _, item := range items {
		input.WriteString(item.ID)
		input.WriteByte('\t')
		input.WriteString(item.Display)
		input.WriteByte('\n')
	}
	args := []string{"-i", "--multi", "--sync", "--no-sort",
		"--height=80%", "--border", "--prompt=ii load panes> ",
		"--header=SPACE toggle · ENTER load · ESC cancel",
		"--bind=space:toggle,enter:accept,esc:abort,q:abort",
		"--delimiter=\t", "--with-nth=2"}
	startBind := ""
	for index, item := range items {
		if item.Preselected {
			if startBind == "" {
				startBind = "start:"
			} else {
				startBind += "+"
			}
			startBind += "pos(" + strconv.Itoa(index+1) + ")+select"
		}
	}
	if startBind != "" {
		args = append(args, "--bind="+startBind)
	}
	command := exec.Command("fzf", args...)
	command.Stdin = strings.NewReader(input.String())
	var output bytes.Buffer
	command.Stdout = &output
	if err := command.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok && exitError.ExitCode() == 130 {
			return nil, port.ErrSelectionCanceled
		}
		return nil, err
	}
	var selected []string
	for _, line := range strings.Split(strings.TrimSuffix(output.String(), "\n"), "\n") {
		if id, _, ok := strings.Cut(line, "\t"); ok && id != "" {
			selected = append(selected, id)
		}
	}
	return selected, nil
}
