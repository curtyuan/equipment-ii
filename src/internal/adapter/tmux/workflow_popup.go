package tmux

import (
	"strings"
)

func (s *SessionEnvironment) LaunchWorkflowPopup(
	helper, path string, copyStages bool,
) error {
	session, origin, err := s.CurrentWorkflowSession()
	if err != nil {
		return err
	}
	copyValue := "0"
	if copyStages {
		copyValue = "1"
	}
	command := workflowPopupCommand(helper, path, origin, session, copyValue)
	return s.run(
		"display-popup", "-EE", "-T", "ii workflow", "-w", "90%", "-h", "90%",
		"-d", "#{pane_current_path}", command,
	)
}

func workflowPopupCommand(helper, path, origin, session, copyValue string) string {
	return strings.Join([]string{
		shellQuote(helper), "__workflow_popup", shellQuote(path),
		shellQuote(origin), shellQuote(session), copyValue,
	}, " ")
}
