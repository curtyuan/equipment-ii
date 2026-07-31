package terminal

import (
	"fmt"
	"io"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

type WorkflowConfirmer struct {
	input   io.Reader
	output  io.Writer
	errors  io.Writer
	readKey func(io.Reader) (string, error)
}

func NewWorkflowConfirmer(input io.Reader, output, errors io.Writer) *WorkflowConfirmer {
	return &WorkflowConfirmer{
		input: input, output: output, errors: errors, readKey: ReadKey,
	}
}

func (c *WorkflowConfirmer) ConfirmWorkflowStage(stage payload.WorkflowStageView) (bool, error) {
	var screen strings.Builder
	screen.WriteString("\x1b[2J\x1b[H")
	fmt.Fprintf(&screen, "Workflow stage %d/%d\n", stage.Index, stage.Count)
	fmt.Fprintf(&screen, "lane%d: %s -> %s:%s.%d (%s)\n",
		stage.Ordinal, stage.Lane, stage.Pane.Session, stage.Pane.Window,
		stage.Pane.Index, stage.Pane.ID)
	fmt.Fprintf(&screen, "Shell: %s\n", stage.Shell)
	fmt.Fprintf(&screen, "Title: %s\n", stage.Title)
	fmt.Fprintf(&screen, "Command: %s\n", stage.Pane.Command)
	for _, note := range stage.Notes {
		fmt.Fprintf(&screen, "Note: %s\n", note)
	}
	screen.WriteByte('\n')
	screen.WriteString(stage.Text)
	screen.WriteString("\n\n")
	if stage.AfterFirst {
		screen.WriteString("Previous stage ready; send this stage? [y/N] ")
	} else {
		screen.WriteString("Send this stage? [y/N] ")
	}
	_, _ = io.WriteString(c.output, screen.String())
	var unresolved []string
	for _, entry := range stage.Report {
		if entry.Source == payload.SourceMissing {
			unresolved = append(unresolved, entry.Name)
		}
	}
	if len(unresolved) > 0 {
		fmt.Fprintf(c.errors, "Unresolved variables: %s\n", strings.Join(unresolved, ", "))
	}
	key, err := c.readKey(c.input)
	if err != nil {
		return false, err
	}
	fmt.Fprintln(c.output, key)
	return strings.EqualFold(key, "y"), nil
}
