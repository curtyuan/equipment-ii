package cli

import (
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func (c *CLI) runVariableInteractive(args []string, stdout, stderr io.Writer) int {
	if len(args) > 1 && (args[1] == "-h" || args[1] == "--help") {
		fmt.Fprint(stdout, interactiveHelp)
		return 0
	}
	if len(args) > 1 {
		fmt.Fprintln(stderr, "ii: usage: ii interactive")
		return 2
	}
	for {
		result, diagnostic, err := c.interactive.Run()
		fmt.Fprint(stderr, diagnostic)
		if err != nil {
			if errors.Is(err, port.ErrSelectionCanceled) {
				return 1
			}
			fmt.Fprintln(stderr, err)
			return 1
		}
		if result.Line != "" {
			fmt.Fprintln(stdout, result.Line)
		}
		if os.Getenv("II_INTERACTIVE_KEY") != "" || !result.Repeat {
			return 0
		}
	}
}
