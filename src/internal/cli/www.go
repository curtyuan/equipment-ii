package cli

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
	wwwdomain "github.com/curtyuan/equipment-ii/src/internal/www"
)

func (c *CLI) runWWW(args []string, stdout, stderr io.Writer) int {
	values := wwwArgs(args)
	if isHelpCommand(first(args)) || len(values) == 0 ||
		values[0] == "-h" || values[0] == "--help" || containsHelp(values) {
		fmt.Fprint(stdout, wwwHelpFor(args, values))
		if len(values) == 0 && !isHelpCommand(first(args)) {
			return 2
		}
		return 0
	}
	switch values[0] {
	case "--file", "file":
		if len(values) < 2 {
			fmt.Fprintln(stderr, "ii: usage: ii p --www --file PATH")
			return 2
		}
		if len(values) > 2 {
			fmt.Fprintln(stderr, "ii: too many arguments for ii p --www --file")
			return 2
		}
		data, err := os.ReadFile(values[1])
		if err != nil {
			fmt.Fprintf(stderr, "ii: file not found: %s\n", values[1])
			return 1
		}
		rendered, diagnostic, err := c.inputRenderer.Render(string(data))
		fmt.Fprint(stderr, diagnostic)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		_, target, err := c.web.LinkIntoPayload(values[1])
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		printPayloadReport(rendered.Report, c.color, stdout)
		if len(rendered.Report) > 0 {
			fmt.Fprintln(stdout)
		}
		fmt.Fprintln(stdout, Color(34, "[payload]", c.color))
		fmt.Fprintln(stdout, rendered.Text)
		fmt.Fprintln(stdout)
		fmt.Fprintln(stdout, Color(34, "symlink written to:", c.color))
		fmt.Fprintln(stdout, target)
		fmt.Fprintln(stdout)
		relative, _ := filepath.Rel(c.web.Root(), target)
		entry := wwwdomain.Entry{Absolute: target, Relative: relative, Kind: wwwdomain.KindLink}
		printWWWAnalysis(entry, c.color, stdout)
		return 0
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
		if len(args) == 2 && strings.HasPrefix(args[1], "payload-www-") {
			return []string{strings.TrimPrefix(args[1], "payload-www-"), "--help"}
		}
		args = args[1:]
	}
	for index, arg := range args {
		if arg == "--www" || arg == "www" {
			return args[index+1:]
		}
	}
	return nil
}

func printWWWAnalysis(entry wwwdomain.Entry, color bool, stdout io.Writer) {
	relative := wwwdomain.RelativeDir(entry)
	fmt.Fprintln(stdout, Color(32, "relative to /www:", color))
	fmt.Fprintln(stdout, relative)
	fmt.Fprintln(stdout, Color(32, "absolute path:", color))
	fmt.Fprintln(stdout, entry.Absolute)
	fmt.Fprintln(stdout, Color(32, "shell commands:", color))
	fmt.Fprintf(stdout, "relative_file=%s\nfile=%s\nrfile=%s\n",
		zshPathQuote(relative), zshPathQuote(entry.Absolute), zshPathQuote(filepath.Base(entry.Absolute)))
}

func zshPathQuote(value string) string {
	replacer := strings.NewReplacer(
		"\\", "\\\\", " ", "\\ ", "\t", "\\\t", "\n", "\\\n",
		"'", "\\'", `"`, `\"`, "$", "\\$", "`", "\\`",
	)
	return replacer.Replace(value)
}

func wwwHelpFor(args, values []string) string {
	topic := ""
	if len(values) > 0 {
		topic = values[0]
	}
	if len(args) == 2 && strings.HasPrefix(args[1], "payload-www-") {
		topic = strings.TrimPrefix(args[1], "payload-www-")
	}
	switch topic {
	case "--file", "file":
		return wwwFileHelp
	case "ln":
		return wwwLinkHelp
	case "ls":
		return wwwListHelp
	case "search":
		return wwwSearchHelp
	default:
		return wwwHelp
	}
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

const wwwFileHelp = `usage: ii p --www --file PATH
       ii payload --www --file PATH

Aliases:
  none

Help:
  ii help payload --www --file
  ii help payload-www-file
`

const wwwLinkHelp = `usage: ii p --www ln SOURCE_PATH [LINK_NAME]
       ii payload --www ln SOURCE_PATH [LINK_NAME]

Aliases:
  none

Help:
  ii help payload --www ln
  ii help payload-www-ln
`

const wwwListHelp = `usage: ii p --www ls
       ii payload --www ls

Aliases:
  none

Help:
  ii help payload --www ls
  ii help payload-www-ls
`

const wwwSearchHelp = `usage: ii p --www search [FILTER]
       ii payload --www search [FILTER]

Aliases:
  none

Help:
  ii help payload --www search
  ii help payload-www-search
`
