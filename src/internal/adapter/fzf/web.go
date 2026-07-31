package fzf

import (
	"bytes"
	"errors"
	"os/exec"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
	wwwdomain "github.com/curtyuan/equipment-ii/src/internal/www"
)

func (m *Multi) SelectDirectory(entries []wwwdomain.Entry) (wwwdomain.Entry, error) {
	return m.selectWeb(entries, "", true)
}

func (m *Multi) SelectEntry(entries []wwwdomain.Entry, filter string) (wwwdomain.Entry, error) {
	return m.selectWeb(entries, filter, false)
}

func (m *Multi) selectWeb(entries []wwwdomain.Entry, filter string, directories bool) (wwwdomain.Entry, error) {
	if err := m.Available(); err != nil {
		return wwwdomain.Entry{}, err
	}
	var input strings.Builder
	byPath := make(map[string]wwwdomain.Entry, len(entries))
	for _, entry := range entries {
		label := entry.Relative
		if label == "." {
			label = entry.Absolute
		}
		kind := string(entry.Kind)
		input.WriteString(label + "\t" + kind + "\t" + entry.Absolute + "\n")
		byPath[entry.Absolute] = entry
	}
	prompt := "ii www search> "
	withNth := "1,2"
	if directories {
		prompt = "ii www dir> "
		withNth = "1"
	}
	args := []string{"-i", "--ansi", "--prompt=" + prompt, "--height=80%", "--border",
		"--delimiter=\t", "--with-nth=" + withNth}
	if filter != "" {
		args = append(args, "--filter="+filter)
	}
	command := exec.Command("fzf", args...)
	command.Stdin = strings.NewReader(input.String())
	var output bytes.Buffer
	command.Stdout = &output
	if err := command.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok &&
			(exitError.ExitCode() == 1 || exitError.ExitCode() == 130) {
			return wwwdomain.Entry{}, port.ErrSelectionCanceled
		}
		return wwwdomain.Entry{}, err
	}
	line := strings.Split(strings.TrimSpace(output.String()), "\n")[0]
	parts := strings.Split(line, "\t")
	if len(parts) < 3 {
		return wwwdomain.Entry{}, port.ErrSelectionCanceled
	}
	entry, ok := byPath[parts[len(parts)-1]]
	if !ok {
		return wwwdomain.Entry{}, errors.New("ii: selected web entry is invalid")
	}
	return entry, nil
}
