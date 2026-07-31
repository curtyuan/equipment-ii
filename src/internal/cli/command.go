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

func (c *CLI) runPublic(args []string, stdout, stderr io.Writer) int {
	switch Resolve(args).Command {
	case "help":
		if isVersionHelp(args) {
			fmt.Fprint(stdout, versionHelp)
			return 0
		}
		fmt.Fprint(stdout, ColorizeAliases(topHelp, c.color))
		return 0
	case "payload-input-help":
		fmt.Fprint(stdout, payloadInputHelpFor(args))
		return 0
	case "version":
		if containsHelp(args[1:]) {
			fmt.Fprint(stdout, versionHelp)
			return 0
		}
		fmt.Fprintf(stdout, "ii %s\n", c.version)
		return 0
	case "list":
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
	case "variable-help":
		fmt.Fprint(stdout, variableHelp)
		return 0
	case "set-help":
		fmt.Fprint(stdout, ColorizeAliases(setHelp, c.color))
		return 0
	case "unset-help":
		fmt.Fprint(stdout, ColorizeAliases(unsetHelp, c.color))
		return 0
	case "load-help":
		fmt.Fprint(stdout, ColorizeAliases(loadHelp, c.color))
		return 0
	case "get-help":
		fmt.Fprint(stdout, ColorizeAliases(getHelp, c.color))
		return 0
	case "sync-help":
		fmt.Fprint(stdout, ColorizeAliases(syncHelp, c.color))
		return 0
	case "output":
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
	case "set":
		return c.runSet(args, stdout, stderr)
	case "unset":
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
	case "load":
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
	case "get":
		return c.runGet(args, stdout, stderr)
	case "clipboard":
		return c.runClipboard(args, stdout, stderr)
	case "tmux":
		return c.runTmux(args, stdout, stderr)
	case "interactive":
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
	case "payload-input":
		return c.runPayloadInput(args, stdout, stderr)
	case "sync":
		action := "status"
		if len(args) > 1 {
			action = args[1]
		}
		switch action {
		case "-h", "--help":
			fmt.Fprint(stdout, ColorizeAliases(syncHelp, c.color))
		case "on":
			if err := c.shell.SetSyncHook(true); err != nil {
				fmt.Fprintln(stderr, err)
				return 1
			}
			fmt.Fprintln(stdout, "ii auto-sync enabled")
		case "off":
			if err := c.shell.SetSyncHook(false); err != nil {
				fmt.Fprintln(stderr, err)
				return 1
			}
			fmt.Fprintln(stdout, "ii auto-sync disabled")
		case "status":
			state := "off"
			if os.Getenv("II_SYNC_LOADED_VARS") == "1" {
				state = "on"
			}
			hook := os.Getenv("II_SYNC_HOOK_PRESENT")
			if hook == "" {
				hook = "absent"
			}
			fmt.Fprintf(stdout, "II_SYNC_LOADED_VARS=%s\nauto-sync: %s\nprecmd hook: %s\n",
				os.Getenv("II_SYNC_LOADED_VARS"), state, hook)
		default:
			fmt.Fprintf(stderr, "ii: unknown sync command: %s\n", action)
			return 2
		}
		return 0
	case "legacy":
		fmt.Fprintf(stderr, "ii-go: legacy route invoked directly: %s\n", first(args))
		return 3
	default:
		fmt.Fprintf(stderr, "ii: unknown command: %s\n", first(args))
		fmt.Fprint(stdout, topHelp)
		return 2
	}
}
