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

type payloadInputOptions struct {
	copy       bool
	execute    bool
	output     bool
	outputSpec string
}

func (c *CLI) runPayloadInput(args []string, stdout, stderr io.Writer) int {
	if containsString(args[1:], "-h") || containsString(args[1:], "--help") {
		fmt.Fprint(stdout, payloadInputHelpFor(args))
		return 0
	}
	options, err := parsePayloadInputOptions(args)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	fmt.Fprintln(stdout, "Paste payload input below. Enter renders; Alt-Enter adds a line; Esc cancels.")
	fmt.Fprintln(stdout)
	fmt.Fprint(stdout, "ii input> ")
	input, err := terminal.ReadPayloadInput(c.stdin, stdout)
	if errors.Is(err, terminal.ErrCancelled) {
		fmt.Fprintln(stderr, "ii: input cancelled")
		return 130
	}
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}

	resolver, diagnostic, err := payload.NewVariableResolver(c.state, c.environment)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	rendered := payload.Render(input, resolver)
	if options.output {
		absolute, writeErr := c.payloadOutput.Write(rendered.Text, options.outputSpec)
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
	if options.copy && !options.execute {
		if err = c.clipboard.Copy(rendered.Text); err != nil {
			fmt.Fprintln(stdout, "payload rendered; clipboard copy failed")
		} else {
			fmt.Fprintln(stdout, "payload copied successfully")
		}
		fmt.Fprintln(stdout)
	}
	printPayloadReport(rendered.Report, c.color, stdout)
	if len(rendered.Report) > 0 {
		fmt.Fprintln(stdout)
	}
	fmt.Fprintln(stdout, "----------------------------------------")
	fmt.Fprintln(stdout, rendered.Text)

	if !options.execute {
		return 0
	}
	if !c.confirmPayload(rendered.Report, stdout, stderr) {
		fmt.Fprintln(stderr, "ii: execution cancelled")
		return 1
	}
	if options.copy {
		if err = c.clipboard.Copy(rendered.Text); err != nil {
			fmt.Fprintln(stderr, "ii: clipboard copy failed; executing payload anyway")
		} else {
			fmt.Fprintln(stdout, "payload copied successfully")
		}
	}
	if err = c.shell.ExecuteScript(rendered.Text); err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	return 0
}

func parsePayloadInputOptions(args []string) (payloadInputOptions, error) {
	var options payloadInputOptions
	start := 1
	switch first(args) {
	case "pic":
		options.copy = true
	case "pie":
		options.execute = true
	case "pice":
		options.copy, options.execute = true, true
	default:
		for start < len(args) && (args[start] == "--input" || args[start] == "input") {
			start++
		}
	}
	for index := start; index < len(args); index++ {
		switch args[index] {
		case "--input", "input":
		case "--copy":
			options.copy = true
		case "--execute":
			options.execute = true
		case "-o", "--output":
			options.output = true
			if index+1 < len(args) && !strings.HasPrefix(args[index+1], "-") {
				index++
				options.outputSpec = args[index]
			}
		default:
			return options, fmt.Errorf("ii: unknown payload input option: %s", args[index])
		}
	}
	if (first(args) == "pie" || first(args) == "pice") && len(args) > 1 {
		return options, fmt.Errorf("ii: usage: ii %s", first(args))
	}
	return options, nil
}

func readConfirmation(reader io.Reader) (string, error) {
	if key := os.Getenv("II_INTERACTIVE_KEY"); key != "" {
		return key, nil
	}
	return terminal.ReadKey(reader)
}
