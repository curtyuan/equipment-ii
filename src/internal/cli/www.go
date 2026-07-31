package cli

import (
	"errors"
	"fmt"
	"io"
	"path/filepath"

	"github.com/curtyuan/equipment-ii/src/internal/port"
	wwwdomain "github.com/curtyuan/equipment-ii/src/internal/www"
)

func (c *CLI) runWWW(args []string, stdout, stderr io.Writer) int {
	values := wwwArgs(args)
	if len(values) == 0 || values[0] == "-h" || values[0] == "--help" {
		fmt.Fprint(stdout, wwwHelp)
		if len(values) == 0 && !isHelpCommand(first(args)) {
			return 2
		}
		return 0
	}
	switch values[0] {
	case "ls":
		if len(values) > 1 {
			fmt.Fprintln(stderr, "ii: usage: ii p --www ls")
			return 2
		}
		root, entries, err := c.web.List()
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprintln(stdout, Color(34, filepath.Base(root), c.color))
		for _, entry := range entries {
			fmt.Fprintln(stdout, wwwdomain.TreeLabel(entry))
		}
		return 0
	case "search":
		if len(values) > 2 {
			fmt.Fprintln(stderr, "ii: usage: ii p --www search [FILTER]")
			return 2
		}
		filter := ""
		if len(values) == 2 {
			filter = values[1]
		}
		entries, err := c.web.Entries()
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		selected, err := c.webSelector.SelectEntry(entries, filter)
		if err != nil {
			if !errors.Is(err, port.ErrSelectionCanceled) {
				fmt.Fprintln(stderr, err)
			}
			return 1
		}
		fmt.Fprintln(stdout, Color(32, "relative to /www:", c.color))
		fmt.Fprintln(stdout, wwwdomain.RelativeDir(selected))
		fmt.Fprintln(stdout, Color(32, "absolute path:", c.color))
		fmt.Fprintln(stdout, selected.Absolute)
		return 0
	case "ln":
		if len(values) < 2 || len(values) > 3 {
			fmt.Fprintln(stderr, "ii: usage: ii p --www ln SOURCE_PATH [LINK_NAME]")
			return 2
		}
		directories, err := c.web.Directories()
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		selected, err := c.webSelector.SelectDirectory(directories)
		if err != nil {
			if !errors.Is(err, port.ErrSelectionCanceled) {
				fmt.Fprintln(stderr, err)
			}
			return 1
		}
		name := ""
		if len(values) == 3 {
			name = values[2]
		}
		target, err := c.web.Link(values[1], selected.Absolute, name)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprintln(stdout, Color(34, "symlink written to:", c.color))
		fmt.Fprintln(stdout, target)
		return 0
	default:
		fmt.Fprintf(stderr, "ii: unknown --www command: %s\n", values[0])
		fmt.Fprintln(stderr, "ii: expected --file, ln, ls, or search")
		return 2
	}
}

func wwwArgs(args []string) []string {
	if len(args) > 0 && isHelpCommand(args[0]) {
		args = args[1:]
	}
	for index, arg := range args {
		if arg == "--www" || arg == "www" {
			return args[index+1:]
		}
	}
	return nil
}

const wwwHelp = `usage: ii p --www --file PATH
       ii p --www ln SOURCE_PATH [LINK_NAME]
       ii p --www ls
       ii p --www search [FILTER]
       ii payload --www --file PATH
       ii payload --www ln SOURCE_PATH [LINK_NAME]
       ii payload --www ls
       ii payload --www search [FILTER]

Aliases:
  none

Help:
  ii help payload --www
  ii help payload-www
`
