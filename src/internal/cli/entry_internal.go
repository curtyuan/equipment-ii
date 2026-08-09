package cli

import (
	"fmt"
	"io"
)

func (c *CLI) runInternal(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "ii: Go helper accepts internal combo commands only")
		return 2
	}
	switch args[0] {
	case "__combo-run":
		return c.runCombo(args[1:], stdout, stderr)
	case "__combo-render":
		return c.runComboRender(args[1:], stdout, stderr)
	case "__combo-copy":
		return c.runComboCopy(args[1:], stdout, stderr)
	default:
		fmt.Fprintf(stderr, "ii: unsupported Go helper command: %s\n", args[0])
		return 2
	}
}
