package cli

import (
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func (c *CLI) runPayload(args []string, stdout, stderr io.Writer) int {
	category, query, output, outputSpec, execute, copyExecute, err := parsePayloadArgs(args)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	resolver, diagnostic, err := payload.NewVariableResolver(c.state, c.environment)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	service := payload.NewService(c.payloads, resolver)
	selected, err := payload.NewSelector(c.payloads, service, c.payloadSelector).Select(category, query)
	if err != nil {
		if !errors.Is(err, port.ErrSelectionCanceled) {
			fmt.Fprintln(stderr, err)
		}
		return 1
	}
	if output {
		absolute, writeErr := c.payloadOutput.Write(selected.Payload.Text, outputSpec)
		if writeErr != nil {
			fmt.Fprintln(stderr, writeErr)
			return 1
		}
		defer func() {
			fmt.Fprintln(stdout)
			fmt.Fprintln(stdout, Color(34, "payload output written to:", c.color))
			fmt.Fprintln(stdout, absolute)
		}()
	}
	if selected.Action == "y" {
		return c.copySelectedPayload(selected.Payload, stdout, stderr)
	}
	execute = execute || selected.Action == "e"
	printPayloadReport(selected.Payload.Report, c.color, stdout)
	if len(selected.Payload.Report) > 0 {
		fmt.Fprintln(stdout, Color(34, selected.Payload.Path, c.color))
		fmt.Fprintln(stdout)
	}
	if !execute {
		fmt.Fprint(stdout, selected.Payload.Text)
		return 0
	}
	if selected.Payload.Workflow != nil {
		return c.launchWorkflowPopup(selected.Payload.Path, copyExecute, stderr)
	}
	if !c.confirmPayload(selected.Payload.Report, stdout, stderr) {
		fmt.Fprintln(stderr, "ii: execution cancelled")
		return 1
	}
	if copyExecute {
		if err = c.clipboard.Copy(selected.Payload.Text); err == nil {
			fmt.Fprintln(stdout, "payload copied successfully")
		} else {
			fmt.Fprintln(stderr, "ii: clipboard copy failed; executing payload anyway")
		}
	}
	fmt.Fprintln(stdout, Color(34, "executing payload in current shell:", c.color))
	fmt.Fprintln(stdout, selected.Payload.Path)
	if err = c.shell.ExecuteScript(selected.Payload.Text); err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	return 0
}

func (c *CLI) launchWorkflowPopup(path string, copyStages bool, stderr io.Writer) int {
	if c.workflowPopup == nil {
		fmt.Fprintln(stderr, "ii: workflow popup launcher is unavailable")
		return 1
	}
	helper := os.Getenv("II_GO_BIN")
	if helper == "" {
		helper, _ = os.Executable()
	}
	if err := c.workflowPopup.LaunchWorkflowPopup(helper, path, copyStages); err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	return 0
}

func parsePayloadArgs(args []string) (category, query string, output bool, outputSpec string, execute, copy bool, err error) {
	var terms []string
	for index := 0; index < len(args); index++ {
		switch args[index] {
		case "--execute":
			execute = true
		case "--copy":
			copy = true
		case "-o", "--output":
			output = true
			if index+1 < len(args) && !strings.HasPrefix(args[index+1], "-") {
				index++
				outputSpec = args[index]
			}
		default:
			if strings.HasPrefix(args[index], "-") {
				return "", "", false, "", false, false, fmt.Errorf("ii: unknown payload option: %s", args[index])
			}
			terms = append(terms, args[index])
		}
	}
	category = "all"
	if len(terms) == 1 && payloadCategory(terms[0]) {
		category = terms[0]
	} else {
		query = strings.Join(terms, " ")
	}
	return
}

func payloadCategory(value string) bool {
	switch value {
	case "all", "shell", "script", "linux", "windows", "sqli", "xss":
		return true
	}
	return false
}

func printPayloadReport(report []payload.ReportEntry, color bool, output io.Writer) {
	for _, entry := range report {
		switch entry.Source {
		case payload.SourceShell:
			fmt.Fprintln(output, Color(34, fmt.Sprintf("%s used from shell: %s", entry.Name, entry.Value), color))
		case payload.SourceSession:
			fmt.Fprintf(output, "%s used from ii: %s\n", entry.Name, entry.Value)
		case payload.SourceMissing:
			fmt.Fprintln(output, Color(31, fmt.Sprintf("%s unresolved: kept as %s", entry.Name, entry.Value), color))
		}
	}
}

func (c *CLI) confirmPayload(report []payload.ReportEntry, stdout, stderr io.Writer) bool {
	unresolved := make([]string, 0)
	for _, entry := range report {
		if entry.Source == payload.SourceMissing {
			unresolved = append(unresolved, entry.Name)
		}
	}
	if len(unresolved) > 0 {
		fmt.Fprintf(stderr, "ii: unresolved variables: %s\n", strings.Join(unresolved, ", "))
		fmt.Fprint(stdout, "Unresolved variables may make this payload ineffective. Execute anyway? [y/N] ")
	} else {
		fmt.Fprint(stdout, "Execute this payload? [y/N] ")
	}
	answer, _ := readConfirmation(c.stdin)
	fmt.Fprintln(stdout, answer)
	return strings.EqualFold(strings.TrimSpace(answer), "y")
}

func (c *CLI) copySelectedPayload(selected payload.PayloadResult, stdout, stderr io.Writer) int {
	if selected.Workflow != nil {
		for index, stage := range selected.Stages {
			if index > 0 && !c.confirmStage(index+1, len(selected.Stages), stdout) {
				fmt.Fprintln(stdout, "workflow copy cancelled")
				return 1
			}
			if err := c.clipboard.Copy(stage.Text); err != nil {
				fmt.Fprintf(stderr, "ii: clipboard copy failed for workflow stage %d\n", index+1)
				return 1
			}
			fmt.Fprintf(stdout, "stage %d/%d copied successfully\n", index+1, len(selected.Stages))
		}
		return 0
	}
	copyErr := c.clipboard.Copy(selected.Text)
	status := "payload copied successfully"
	if copyErr != nil {
		status = "payload rendered; clipboard copy failed"
	}
	fmt.Fprintln(stdout, status)
	printPayloadReport(selected.Report, c.color, stdout)
	if len(selected.Report) > 0 {
		fmt.Fprintln(stdout)
		fmt.Fprintln(stdout, Color(34, selected.Path, c.color))
	}
	if copyErr != nil {
		return 1
	}
	return 0
}

func (c *CLI) confirmStage(index, count int, stdout io.Writer) bool {
	fmt.Fprintf(stdout, "\nStage %d/%d ready for copy\nPress y to copy, n/Esc to abort. ", index, count)
	answer, _ := readConfirmation(c.stdin)
	fmt.Fprintln(stdout, answer)
	return strings.EqualFold(strings.TrimSpace(answer), "y")
}
