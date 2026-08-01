package cli

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func (c *CLI) runUnset(args []string, stdout, stderr io.Writer) int {
	if len(args) > 1 && (args[1] == "-h" || args[1] == "--help") {
		fmt.Fprint(stdout, ColorizeAliases(unsetHelp, c.color))
		return 0
	}
	if len(args) < 2 {
		fmt.Fprint(stdout, unsetHelp)
		return 2
	}
	if args[1] == "-a" {
		fmt.Fprint(stdout, "unset all ii_ variables in this tmux session? [y/N] ")
		answer, _ := bufio.NewReader(c.stdin).ReadString('\n')
		if strings.TrimSuffix(answer, "\n") != "y" {
			fmt.Fprintln(stdout, "aborted")
			return 1
		}
		read, err := c.environment.Read()
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		count := 0
		for _, line := range read.Lines {
			name, _, ok := strings.Cut(line, "=")
			if !ok || !strings.HasPrefix(name, "ii_") {
				continue
			}
			shellName, err := c.mutator.Unset(name)
			if err != nil {
				fmt.Fprintln(stderr, err)
				return 1
			}
			fmt.Fprintf(stdout, "unset %s\n", shellName)
			count++
		}
		fmt.Fprintf(stdout, "unset %d variable(s)\n", count)
		return 0
	}
	for _, raw := range args[1:] {
		name, err := c.mutator.Unset(raw)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprintf(stdout, "unset %s\n", name)
	}
	return 0
}

func (c *CLI) runLoad(args []string, stdout, stderr io.Writer) int {
	if len(args) > 1 && (args[1] == "-h" || args[1] == "--help") {
		fmt.Fprint(stdout, ColorizeAliases(loadHelp, c.color))
		return 0
	}
	if args[0] == "la" || (len(args) > 1 && args[1] == "--all-pane") {
		result, err := c.allPanes.Run(os.Getenv("TMUX_PANE"))
		if err != nil {
			if errors.Is(err, port.ErrSelectionCanceled) {
				fmt.Fprintln(stdout, "aborted")
			} else {
				fmt.Fprintln(stderr, err)
			}
			return 1
		}
		for _, line := range result.Lines {
			fmt.Fprintln(stdout, line)
		}
		if result.Failed > 0 {
			return 1
		}
		return 0
	}
	if len(args) > 1 {
		fmt.Fprintf(stderr, "ii: unknown load option: %s\n", args[1])
		return 2
	}
	count, diagnostic, err := c.loader.Load()
	fmt.Fprint(stderr, diagnostic)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprintf(stdout, "loaded %d variable(s)\n", count)
	return 0
}
