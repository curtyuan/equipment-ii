package cli

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

const tmuxIntegrationSchema = 2

func (c *CLI) ensureTmuxIntegration(_ io.Writer, stderr io.Writer) int {
	if os.Getenv("II_TMUX_INTEGRATION") == "0" {
		return 0
	}
	if os.Getenv("TMUX") == "" {
		return 0
	}
	if _, err := exec.LookPath("tmux"); err != nil {
		return 0
	}
	helper := os.Getenv("II_GO_BIN")
	if helper == "" {
		helper, _ = os.Executable()
	}
	info, err := os.Stat(helper)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&0o111 == 0 {
		fmt.Fprintf(stderr, "ii: Go runtime is not executable: %s\n", helper)
		return 1
	}
	notice, err := c.tmuxIntegration.EnsureIntegration(
		helper,
		c.version,
		tmuxIntegrationSchema,
		os.Getenv("II_TMUX_INTEGRATION_FORCE") == "1",
	)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprint(stderr, notice)
	return 0
}

func (c *CLI) runTmuxPopup(args []string, stdout, stderr io.Writer) int {
	if len(args) != 1 || args[0] != "execute" {
		fmt.Fprintf(stderr, "ii: unsupported tmux input popup mode: %s\n", first(args))
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

	fmt.Fprintln(stdout, "Paste payload input below. Enter renders; :q cancels.")
	fmt.Fprintln(stdout)
	fmt.Fprint(stdout, "ii input> ")
	input, readErr := bufio.NewReader(c.stdin).ReadString('\n')
	if readErr != nil && input == "" {
		fmt.Fprintln(stderr, "ii: input cancelled")
		return 0
	}
	input = strings.TrimSuffix(input, "\n")
	if input == ":q" || input == ":q!" {
		fmt.Fprintln(stdout, "cancelled")
		return 0
	}
	if input == "" {
		fmt.Fprintln(stderr, "ii: input is empty")
		return 1
	}

	resolver, diagnostic, err := payload.NewVariableResolver(c.state, c.environment)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	rendered := payload.Render(input, resolver)
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

func (c *CLI) runTmux(args []string, stdout, stderr io.Writer) int {
	for _, arg := range args[1:] {
		if arg == "-h" || arg == "--help" {
			fmt.Fprint(stdout, tmuxHelp)
			return 0
		}
	}
	if len(args) > 2 || (len(args) == 2 && args[1] != "status") {
		fmt.Fprintln(stderr, "ii: usage: ii tmux status")
		return 2
	}
	helper := os.Getenv("II_GO_BIN")
	if helper == "" {
		helper, _ = os.Executable()
	}
	status, err := c.tmuxIntegration.IntegrationStatus(helper, tmuxIntegrationSchema)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	configured := "default"
	if os.Getenv("II_TMUX_INTEGRATION") == "0" {
		configured = "disabled"
	} else if os.Getenv("II_TMUX_INTEGRATION_FORCE") == "1" {
		configured = "force"
	}
	fmt.Fprintf(stdout, "server: %s\nconfigured: %s\ncommand alias: %s\ncommand: ii\nhelper: %s\n",
		status.Server, configured, status.AliasState, helper)
	if status.PrefixLegacy {
		fmt.Fprintln(stdout, "Prefix+: legacy ii adapter")
	} else {
		fmt.Fprintln(stdout, "Prefix+: native or user-defined")
	}
	return 0
}
