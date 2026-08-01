package cli

import (
	"errors"
	"fmt"
	"io"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
	"github.com/curtyuan/equipment-ii/src/internal/variables"
)

func (c *CLI) runVariableHelp(command string, stdout io.Writer) int {
	switch command {
	case "variable-help":
		fmt.Fprint(stdout, variableHelp)
	case "set-help":
		fmt.Fprint(stdout, ColorizeAliases(setHelp, c.color))
	case "unset-help":
		fmt.Fprint(stdout, ColorizeAliases(unsetHelp, c.color))
	case "load-help":
		fmt.Fprint(stdout, ColorizeAliases(loadHelp, c.color))
	case "get-help":
		fmt.Fprint(stdout, ColorizeAliases(getHelp, c.color))
	}
	return 0
}

func (c *CLI) runVariableList(args []string, stdout, stderr io.Writer) int {
	if isHelpCommand(first(args)) ||
		(len(args) > 1 && (args[1] == "-h" || args[1] == "--help")) {
		fmt.Fprint(stdout, ColorizeAliases(listHelp, c.color))
		return 0
	}
	pattern := ""
	if len(args) > 1 {
		pattern = args[1]
	}
	entries, diagnostic, err := c.lister.List(pattern)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprint(stderr, diagnostic)
	for _, entry := range entries {
		fmt.Fprintln(stdout, Color(34, entry.Name, c.color))
		fmt.Fprintln(stdout, entry.Value)
	}
	return 0
}

func (c *CLI) runVariableOutput(args []string, stdout, stderr io.Writer) int {
	outputArgs := variableOutputArgs(args)
	if len(outputArgs) > 0 && (outputArgs[0] == "-h" || outputArgs[0] == "--help") {
		fmt.Fprint(stdout, variableOutputHelp)
		return 0
	}
	if len(outputArgs) > 1 {
		fmt.Fprintln(stderr, "ii: usage: ii v --out [PATH] | ii vo [PATH]")
		return 2
	}
	path := ".env"
	if len(outputArgs) == 1 {
		path = outputArgs[0]
	}
	count, absolutePath, diagnostic, err := c.output.Write(path)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprintf(stdout, "wrote %d variable(s) to %s\n", count, absolutePath)
	return 0
}

func (c *CLI) runGet(args []string, stdout, stderr io.Writer) int {
	for _, arg := range args[1:] {
		if arg == "-h" || arg == "--help" {
			fmt.Fprint(stdout, ColorizeAliases(getHelp, c.color))
			return 0
		}
	}
	filter := ""
	switch args[0] {
	case "gr":
		filter = "r"
	case "gl":
		filter = "l"
	default:
		if strings.HasPrefix(args[0], "g:") {
			filter = strings.TrimPrefix(args[0], "g:")
		} else if len(args) > 1 {
			filter = args[1]
		}
	}
	if filter == "" {
		fmt.Fprint(stdout, getUsage)
		return 2
	}
	value, diagnostic, copyErr, err := c.getter.Get(filter)
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		if errors.Is(err, variables.ErrNoMatch) {
			fmt.Fprintln(stderr, "no matched")
		} else if !errors.Is(err, port.ErrSelectionCanceled) {
			fmt.Fprintln(stderr, err)
		}
		return 1
	}
	if copyErr == nil {
		fmt.Fprintln(stdout, "value copied successfully")
	} else {
		fmt.Fprintln(stdout, "value selected; clipboard copy failed")
	}
	fmt.Fprintln(stdout)
	fmt.Fprintln(stdout, value)
	return 0
}
