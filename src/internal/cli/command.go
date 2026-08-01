package cli

import (
	"fmt"
	"io"
)

func (c *CLI) runPublic(args []string, stdout, stderr io.Writer) int {
	resolution := Resolve(args)
	switch resolution.Command {
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
	case "payload-help":
		fmt.Fprint(stdout, payloadHelpFor(args))
		return 0
	case "version":
		if containsHelp(args[1:]) {
			fmt.Fprint(stdout, versionHelp)
			return 0
		}
		fmt.Fprintf(stdout, "ii %s\n", c.version)
		return 0
	case "list":
		return c.runVariableList(args, stdout, stderr)
	case "variable-help", "set-help", "unset-help", "load-help", "get-help":
		return c.runVariableHelp(resolution.Command, stdout)
	case "output":
		return c.runVariableOutput(args, stdout, stderr)
	case "set":
		return c.runSet(args, stdout, stderr)
	case "unset":
		return c.runUnset(args, stdout, stderr)
	case "load":
		return c.runLoad(args, stdout, stderr)
	case "get":
		return c.runGet(args, stdout, stderr)
	case "clipboard":
		return c.runClipboard(args, stdout, stderr)
	case "tmux":
		return c.runTmux(args, stdout, stderr)
	case "interactive":
		return c.runVariableInteractive(args, stdout, stderr)
	case "payload-input":
		return c.runPayloadInput(args, stdout, stderr)
	case "payload":
		return c.runPublicPayload(args, stdout, stderr)
	case "www":
		return c.runWWW(args, stdout, stderr)
	default:
		fmt.Fprintf(stderr, "ii: unknown command: %s\n", first(args))
		fmt.Fprint(stdout, topHelp)
		return 2
	}
}
