package tmux

import (
	"errors"
	"strconv"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

const workflowMemoryOption = "@ii_workflow_lane_bindings"

var _ payload.WorkflowRuntime = (*SessionEnvironment)(nil)

func (s *SessionEnvironment) CurrentWorkflowSession() (string, string, error) {
	output, err := s.output("display-message", "-p", "#{session_id}\t#{pane_id}")
	if err != nil {
		return "", "", err
	}
	session, pane, ok := strings.Cut(output, "\t")
	if !ok || session == "" || pane == "" {
		return "", "", errors.New("ii: invalid workflow session identity")
	}
	return session, pane, nil
}

func (s *SessionEnvironment) WorkflowPanes(session string) ([]payload.WorkflowPane, error) {
	format := "#{pane_id}\t#{session_id}\t#{window_id}\t#{pane_index}\t#{pane_left}\t#{pane_top}\t#{pane_width}\t#{pane_height}\t#{pane_dead}\t#{pane_in_mode}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}"
	output, err := s.output("list-panes", "-s", "-t", session, "-F", format)
	if err != nil {
		return nil, err
	}
	var panes []payload.WorkflowPane
	for _, line := range strings.Split(output, "\n") {
		if line == "" {
			continue
		}
		pane, ok := parseWorkflowPane(line)
		if ok && pane.Session == session && !pane.Dead {
			panes = append(panes, pane)
		}
	}
	if len(panes) == 0 {
		return nil, errors.New("ii: no usable tmux panes found")
	}
	return panes, nil
}

func (s *SessionEnvironment) ReadWorkflowMemory(session string) (string, error) {
	output, err := s.output("show-options", "-t", session, "-qv", workflowMemoryOption)
	if err != nil {
		return "", nil
	}
	return output, nil
}

func (s *SessionEnvironment) WriteWorkflowMemory(session, value string) error {
	return s.run("set-option", "-t", session, workflowMemoryOption, value)
}

func (s *SessionEnvironment) WorkflowPaneSnapshot(id string) (payload.WorkflowPane, error) {
	format := "#{pane_id}\t#{session_id}\t#{window_id}\t#{pane_index}\t#{pane_left}\t#{pane_top}\t#{pane_width}\t#{pane_height}\t#{pane_dead}\t#{pane_in_mode}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}"
	output, err := s.output("display-message", "-p", "-t", id, format)
	if err != nil {
		return payload.WorkflowPane{}, err
	}
	pane, ok := parseWorkflowPane(output)
	if !ok {
		return payload.WorkflowPane{}, errors.New("ii: invalid workflow pane snapshot")
	}
	return pane, nil
}

func (s *SessionEnvironment) SendWorkflowStage(session, pane, text string) error {
	return s.SendLiteral(session, pane, text)
}

func parseWorkflowPane(line string) (payload.WorkflowPane, bool) {
	fields := strings.SplitN(line, "\t", 13)
	if len(fields) != 13 {
		return payload.WorkflowPane{}, false
	}
	number := func(index int) int {
		value, _ := strconv.Atoi(fields[index])
		return value
	}
	return payload.WorkflowPane{
		ID: fields[0], Session: fields[1], Window: fields[2],
		Index: number(3), Left: number(4), Top: number(5),
		Width: number(6), Height: number(7), Dead: number(8) == 1,
		InMode: number(9) == 1, Command: fields[10], Path: fields[11], Title: fields[12],
	}, true
}
