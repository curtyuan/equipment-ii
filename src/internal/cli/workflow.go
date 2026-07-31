package cli

import (
	"errors"
	"fmt"
	"io"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/terminal"
)

func (c *CLI) runWorkflowPopup(args []string, stdout, stderr io.Writer) int {
	if len(args) != 4 || (args[3] != "0" && args[3] != "1") {
		fmt.Fprintln(stderr, "ii: usage: ii-go __workflow_popup PATH ORIGIN SESSION COPY")
		return 2
	}
	if c.workflowRuntime == nil {
		fmt.Fprintln(stderr, "ii: workflow tmux runtime is unavailable")
		return 1
	}
	resolver, diagnostic, err := payload.NewVariableResolver(c.state, c.environment)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	result, err := payload.NewService(c.payloads, resolver).Render(args[0])
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	if result.Workflow == nil {
		fmt.Fprintln(stderr, "ii: selected payload is not an executable workflow")
		return 1
	}
	coordinator := payload.NewWorkflowCoordinator(c.workflowRuntime)
	state, err := coordinator.Prepare(*result.Workflow)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	if state.OriginPane != args[1] || state.Session != args[2] {
		fmt.Fprintln(stderr, "ii: workflow origin pane is no longer available")
		return 1
	}
	selector := c.workflowSelector
	if selector == nil {
		selector = terminal.NewWorkflowSelector(c.stdin, stdout)
	}
	if err = coordinator.Select(*result.Workflow, &state, selector); err != nil {
		if errors.Is(err, terminal.ErrCancelled) {
			return 0
		}
		fmt.Fprintln(stderr, err)
		return 1
	}
	confirmer := c.workflowConfirmer
	if confirmer == nil {
		confirmer = terminal.NewWorkflowConfirmer(c.stdin, stdout, stderr)
	}
	runner := payload.NewWorkflowRunner(
		coordinator, c.workflowRuntime, confirmer, c.clipboard,
	)
	if err = runner.Run(*result.Workflow, result.Stages, state, args[3] == "1"); err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprintf(stdout, "workflow completed: %d stage(s) sent\n", len(result.Stages))
	return 0
}
