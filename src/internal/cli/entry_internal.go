package cli

import (
	"fmt"
	"io"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

func (c *CLI) runInternal(args []string, stdout, stderr io.Writer) (int, bool) {
	if len(args) == 0 {
		return 0, false
	}
	switch args[0] {
	case "__payload_names":
		names, err := c.payloads.ReferencedNames()
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1, true
		}
		for _, name := range names {
			fmt.Fprintln(stdout, name)
		}
		return 0, true
	case "__payload_render":
		if len(args) != 2 {
			fmt.Fprintln(stderr, "ii: usage: ii-go __payload_render PATH")
			return 2, true
		}
		resolver, diagnostic, err := payload.NewVariableResolver(c.state, c.environment)
		fmt.Fprint(stderr, diagnostic)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1, true
		}
		result, err := payload.NewService(c.payloads, resolver).Render(args[1])
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1, true
		}
		fmt.Fprint(stdout, result.Text)
		return 0, true
	case "__payload_select":
		return c.runPayload(args[1:], stdout, stderr), true
	case "__tmux_ensure":
		return c.ensureTmuxIntegration(stdout, stderr), true
	case "__tmux_popup":
		return c.runTmuxPopup(args[1:], stdout, stderr), true
	case "__workflow_popup":
		return c.runWorkflowPopup(args[1:], stdout, stderr), true
	case "__combo-run":
		return c.runCombo(args[1:], stdout, stderr), true
	case "__combo-render":
		return c.runComboRender(args[1:], stdout, stderr), true
	case "__combo-copy":
		return c.runComboCopy(args[1:], stdout, stderr), true
	default:
		return 0, false
	}
}
