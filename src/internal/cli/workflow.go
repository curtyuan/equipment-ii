package cli

import (
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/terminal"
)

func (c *CLI) runCombo(args []string, stdout, stderr io.Writer) int {
	if len(args) != 5 || (args[3] != "0" && args[3] != "1") {
		fmt.Fprintln(stderr, "ii: usage: ii-go __combo-run PATH ORIGIN SESSION COPY CLIPBOARD")
		return 2
	}
	if !configureComboClipboard(args[4], args[3] == "1", stderr) {
		return 2
	}
	return c.runWorkflow(args[:4], stdout, stderr, true)
}

func (c *CLI) runComboRender(args []string, stdout, stderr io.Writer) int {
	if len(args) != 1 {
		fmt.Fprintln(stderr, "ii: usage: ii-go __combo-render PATH")
		return 2
	}
	result, ok := c.renderCombo(args[0], stderr)
	if !ok {
		return 1
	}
	printPayloadReport(result.Report, c.color, stdout)
	if len(result.Report) > 0 {
		fmt.Fprintln(stdout, Color(34, result.Path, c.color))
		fmt.Fprintln(stdout)
	}
	fmt.Fprint(stdout, result.Text)
	return 0
}

func (c *CLI) runComboCopy(args []string, stdout, stderr io.Writer) int {
	if len(args) != 2 {
		fmt.Fprintln(stderr, "ii: usage: ii-go __combo-copy PATH CLIPBOARD")
		return 2
	}
	if !configureComboClipboard(args[1], true, stderr) {
		return 2
	}
	result, ok := c.renderCombo(args[0], stderr)
	if !ok {
		return 1
	}
	return c.copySelectedPayload(result, stdout, stderr)
}

func (c *CLI) renderCombo(path string, stderr io.Writer) (payload.PayloadResult, bool) {
	resolver, diagnostic, err := payload.NewSessionVariableResolver(c.environment)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return payload.PayloadResult{}, false
	}
	result, err := payload.NewService(c.payloads, resolver).Render(path)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return payload.PayloadResult{}, false
	}
	if result.Workflow == nil {
		fmt.Fprintln(stderr, "ii: selected payload is not an executable workflow")
		return payload.PayloadResult{}, false
	}
	return result, true
}

func configureComboClipboard(backend string, required bool, stderr io.Writer) bool {
	if !validComboClipboard(backend) || (required && backend == "none") {
		fmt.Fprintln(stderr, "ii: invalid combo clipboard backend")
		return false
	}
	if strings.HasPrefix(backend, "cmd:") {
		_ = os.Unsetenv("II_CLIP_BACKEND")
		_ = os.Setenv("II_CLIP_CMD", strings.TrimPrefix(backend, "cmd:"))
	} else {
		_ = os.Unsetenv("II_CLIP_CMD")
		if backend == "none" {
			_ = os.Unsetenv("II_CLIP_BACKEND")
		} else {
			_ = os.Setenv("II_CLIP_BACKEND", backend)
		}
	}
	return true
}

func validComboClipboard(backend string) bool {
	switch backend {
	case "none", "tmux", "wl-copy", "pbcopy", "clip.exe", "xclip", "xclip-both", "xsel", "osc52":
		return true
	}
	return strings.HasPrefix(backend, "cmd:") && len(strings.TrimPrefix(backend, "cmd:")) > 0
}

func (c *CLI) runWorkflow(args []string, stdout, stderr io.Writer, _ bool) int {
	if c.workflowRuntime == nil {
		fmt.Fprintln(stderr, "ii: workflow tmux runtime is unavailable")
		return 1
	}
	resolver, diagnostic, err := payload.NewSessionVariableResolver(c.environment)
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
