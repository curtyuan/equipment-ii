package cli

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/terminal"
)

func (c *CLI) runTmuxPopup(args []string, stdout, stderr io.Writer) int {
	if len(args) != 1 || args[0] != "execute" {
		mode := "[missing]"
		if len(args) > 0 {
			mode = args[0]
		}
		fmt.Fprintf(stderr, "ii: unsupported tmux input popup mode: %s\n", mode)
		return 2
	}
	target := os.Getenv("TMUX_PANE")
	if target == "" || !strings.HasPrefix(target, "%") {
		fmt.Fprintf(stderr, "ii: cannot determine originating pane: %s\n", missingLabel(target))
		return 1
	}
	pane, err := c.panes.Snapshot(target)
	if err != nil {
		fmt.Fprintf(stderr, "ii: cannot determine session for target pane: %s\n", target)
		return 1
	}

	fmt.Fprintln(stdout, "Paste payload input below. Enter renders; Alt-Enter adds a line; Esc cancels.")
	fmt.Fprintln(stdout)
	fmt.Fprint(stdout, "ii input> ")
	input, readErr := terminal.ReadPayloadInput(c.stdin, stdout)
	if errors.Is(readErr, terminal.ErrCancelled) {
		fmt.Fprintln(stdout, "cancelled")
		return 0
	}
	if readErr != nil {
		fmt.Fprintln(stderr, readErr)
		return 1
	}
	if input == "" {
		fmt.Fprintln(stderr, "ii: input is empty")
		return 1
	}

	rendered, diagnostic, err := c.inputRenderer.Render(input)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprintf(stdout, "Target: %s (%s)\n", pane.Window, pane.ID)
	fmt.Fprintf(stdout, "Command: %s\n", pane.Command)
	if len(rendered.Report) > 0 {
		fmt.Fprintln(stdout)
		printPayloadReport(rendered.Report, c.color, stdout)
	}
	fmt.Fprintln(stdout)
	fmt.Fprintln(stdout, "----------------------------------------")
	fmt.Fprintln(stdout, rendered.Text)
	fmt.Fprintln(stdout)

	unresolved := missingPayloadNames(rendered.Report)
	if len(unresolved) > 0 {
		fmt.Fprintf(stderr, "Unresolved variables: %s\n", strings.Join(unresolved, ", "))
		fmt.Fprint(stdout, "Unresolved variables may make this payload ineffective. Send and execute anyway? [y/N] ")
	} else {
		fmt.Fprint(stdout, "Send and execute? [y/N] ")
	}
	answer := os.Getenv("II_INTERACTIVE_KEY")
	if answer != "" {
		fmt.Fprintln(stdout, answer)
	} else {
		answer, _ = bufio.NewReader(c.stdin).ReadString('\n')
	}
	if !strings.EqualFold(strings.TrimSpace(answer), "y") {
		fmt.Fprintln(stdout, "cancelled")
		return 1
	}
	if err := c.panes.SendLiteral(pane.Session, target, rendered.Text); err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprintln(stdout, "payload sent and executed")
	return 0
}

func missingPayloadNames(report []payload.ReportEntry) []string {
	var names []string
	for _, entry := range report {
		if entry.Source == payload.SourceMissing {
			names = append(names, entry.Name)
		}
	}
	return names
}

func missingLabel(value string) string {
	if value == "" {
		return "[missing]"
	}
	return value
}
