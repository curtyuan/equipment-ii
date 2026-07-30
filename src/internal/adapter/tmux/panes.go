package tmux

import (
	"errors"
	"strconv"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func (s *SessionEnvironment) CurrentSessionWindow() (string, string, error) {
	output, err := s.output("display-message", "-p", "#{session_id}\t#{window_id}")
	if err != nil {
		return "", "", err
	}
	session, window, ok := strings.Cut(output, "\t")
	if !ok {
		return "", "", errors.New("ii: invalid tmux session identity")
	}
	return session, window, nil
}

func (s *SessionEnvironment) List(window string) ([]port.Pane, error) {
	format := "#{pane_id}\t#{session_id}\t#{window_id}\t#{pane_dead}\t#{pane_in_mode}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}"
	output, err := s.output("list-panes", "-t", window, "-F", format)
	if err != nil {
		return nil, err
	}
	var panes []port.Pane
	for _, line := range strings.Split(output, "\n") {
		if line == "" {
			continue
		}
		pane, ok := parsePane(line)
		if ok {
			panes = append(panes, pane)
		}
	}
	return panes, nil
}

func (s *SessionEnvironment) Snapshot(id string) (port.Pane, error) {
	format := "#{pane_id}\t#{session_id}\t#{window_id}\t#{pane_dead}\t#{pane_in_mode}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}"
	output, err := s.output("display-message", "-p", "-t", id, format)
	if err != nil {
		return port.Pane{}, err
	}
	pane, ok := parsePane(output)
	if !ok {
		return port.Pane{}, errors.New("ii: invalid tmux pane snapshot")
	}
	return pane, nil
}

func (s *SessionEnvironment) SendLoad(id string) error {
	if err := s.run("send-keys", "-t", id, "-l", "ii l"); err != nil {
		return err
	}
	return s.run("send-keys", "-t", id, "Enter")
}

func (s *SessionEnvironment) output(args ...string) (string, error) {
	if err := s.available(); err != nil {
		return "", err
	}
	data, err := s.command("tmux", args...).CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(data))
		if message != "" {
			return "", errors.New(message)
		}
		return "", err
	}
	return strings.TrimSuffix(string(data), "\n"), nil
}

func parsePane(line string) (port.Pane, bool) {
	fields := strings.SplitN(line, "\t", 8)
	if len(fields) != 8 {
		return port.Pane{}, false
	}
	dead, _ := strconv.Atoi(fields[3])
	inMode, _ := strconv.Atoi(fields[4])
	return port.Pane{
		ID: fields[0], Session: fields[1], Window: fields[2],
		Dead: dead == 1, InMode: inMode == 1, Command: fields[5],
		Path: fields[6], Title: fields[7],
	}, true
}
