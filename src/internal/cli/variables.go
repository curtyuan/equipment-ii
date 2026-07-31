package cli

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
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
	case "sync-help":
		fmt.Fprint(stdout, ColorizeAliases(syncHelp, c.color))
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

func (c *CLI) runSync(args []string, stdout, stderr io.Writer) int {
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
}

func (c *CLI) runSet(args []string, stdout, stderr io.Writer) int {
	values := args[1:]
	for _, value := range values {
		if value == "-h" || value == "--help" {
			fmt.Fprint(stdout, ColorizeAliases(setHelp, c.color))
			return 0
		}
	}
	if args[0] == "sf" && len(values) > 1 {
		fmt.Fprintln(stderr, "ii: usage: ii sf [PATH]")
		return 2
	}
	if args[0] == "sha" && len(values) > 0 {
		fmt.Fprintln(stderr, "ii: usage: ii sha")
		return 2
	}
	hasFromShell, hasFromFile, hasAll := false, false, false
	for _, value := range values {
		hasFromShell = hasFromShell || value == "--from-shell"
		hasFromFile = hasFromFile || value == "--from-file"
		hasAll = hasAll || value == "-a"
	}
	if hasFromShell && hasFromFile {
		fmt.Fprintln(stderr, "ii: --from-shell and --from-file cannot be used together")
		return 2
	}
	if hasAll && !hasFromShell {
		fmt.Fprintln(stderr, "ii: -a is only supported with --from-shell")
		return 2
	}
	if len(values) > 0 && values[0] == "-d" {
		values = append([]string{"lhost"}, values...)
	}
	if len(values) > 1 && values[1] == "-d" {
		internal, err := variables.NormalizeName(values[0])
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		if internal != "ii_lhost" {
			fmt.Fprintln(stderr, "ii: -d is only supported for lhost")
			return 2
		}
		if len(values) > 3 {
			fmt.Fprintln(stderr, "ii: -d accepts at most one interface")
			return 2
		}
		iface := "tun0"
		if len(values) == 3 {
			iface = values[2]
		}
		value, err := c.detector.InterfaceIPv4(iface)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		line, err := c.mutator.Set("lhost", value)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprintln(stdout, line)
		return 0
	}
	if args[0] == "sha" {
		return c.runSetFromShell(defaultVariableNames, true, stdout, stderr)
	}
	fromShell := false
	all := false
	filtered := make([]string, 0, len(values))
	for _, value := range values {
		switch value {
		case "--from-shell":
			fromShell = true
		case "-a":
			all = true
		default:
			filtered = append(filtered, value)
		}
	}
	if fromShell {
		names := filtered
		if strings.HasPrefix(args[0], "s:") {
			names = append([]string{strings.TrimPrefix(args[0], "s:")}, names...)
		}
		if all {
			if len(filtered) != 0 {
				fmt.Fprintln(stderr, "ii: --from-shell -a does not accept variable names")
				return 2
			}
			names = defaultVariableNames
		}
		return c.runSetFromShell(names, all, stdout, stderr)
	}
	if args[0] == "sf" {
		path := ".env"
		if len(values) > 0 {
			path = values[0]
		}
		return c.runSetFile(path, stdout, stderr)
	}
	for index, value := range values {
		if value == "--from-file" {
			remaining := append([]string{}, values[:index]...)
			remaining = append(remaining, values[index+1:]...)
			if len(remaining) > 1 {
				fmt.Fprintln(stderr, "ii: --from-file accepts at most one path")
				return 2
			}
			path := ".env"
			if len(remaining) == 1 {
				path = remaining[0]
			}
			return c.runSetFile(path, stdout, stderr)
		}
	}
	if strings.HasPrefix(args[0], "s:") {
		values = append([]string{strings.TrimPrefix(args[0], "s:")}, values...)
	}
	if len(values) == 0 {
		fmt.Fprint(stdout, setUsage)
		return 2
	}
	if args[0] == "sr" {
		if len(values) != 1 {
			fmt.Fprintln(stderr, "ii: usage: ii sr VALUE")
			return 2
		}
		values = []string{"rhost=" + values[0]}
	}
	if len(values) == 1 && !strings.Contains(values[0], "=") {
		fmt.Fprintln(stderr, "ii: set requires a value; use NAME=VALUE or NAME VALUE")
		return 2
	}
	if len(values) == 2 && !strings.Contains(values[0], "=") {
		line, err := c.mutator.Set(values[0], values[1])
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprintln(stdout, line)
		c.autoDetectLhost(values[0], stdout)
		return 0
	}
	explicitLhost := false
	for _, raw := range values {
		for _, assignment := range strings.Split(raw, ",") {
			name, _, ok := strings.Cut(assignment, "=")
			if ok {
				normalized, _ := variables.NormalizeName(name)
				explicitLhost = explicitLhost || normalized == "ii_lhost"
			}
		}
	}
	for _, raw := range values {
		for _, assignment := range strings.Split(raw, ",") {
			name, value, ok := strings.Cut(assignment, "=")
			if !ok {
				fmt.Fprintf(stderr, "ii: direct values must use name=value: %s\n", assignment)
				return 2
			}
			line, err := c.mutator.Set(name, value)
			if err != nil {
				fmt.Fprintln(stderr, err)
				return 1
			}
			fmt.Fprintln(stdout, line)
			if !explicitLhost {
				c.autoDetectLhost(name, stdout)
			}
		}
	}
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

func (c *CLI) autoDetectLhost(rawName string, stdout io.Writer) {
	internal, err := variables.NormalizeName(rawName)
	if err != nil || !c.autoDetect ||
		(internal != "ii_rhost" && internal != "ii_rhosts") {
		return
	}
	value, err := c.detector.InterfaceIPv4(c.detectInterface)
	if err != nil {
		return
	}
	if _, err = c.mutator.Set("lhost", value); err == nil {
		fmt.Fprintf(stdout, "lhost has automatically sets as %s\n", value)
	}
}

var defaultVariableNames = variables.DefaultVariableNames

func (c *CLI) runSetFromShell(rawNames []string, all bool, stdout, stderr io.Writer) int {
	names := make([]string, 0, len(rawNames))
	for _, raw := range rawNames {
		names = append(names, strings.Split(raw, ",")...)
	}
	if len(names) == 0 {
		fmt.Fprintln(stderr, "ii: --from-shell requires at least one variable name")
		return 2
	}
	missing := false
	count := 0
	for _, raw := range names {
		internal, err := variables.NormalizeName(raw)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		name := strings.TrimPrefix(internal, "ii_")
		state := c.state.Lookup(name)
		if !state.Present {
			state = c.state.Lookup(strings.ToUpper(name))
		}
		if !state.Present || (all && state.Value == "") {
			if !all {
				fmt.Fprintf(stderr, "ii: shell variable not found: %s\n", name)
				missing = true
			}
			continue
		}
		line, err := c.mutator.Set(name, state.Value)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprintln(stdout, line)
		count++
	}
	if all && count == 0 {
		fmt.Fprintln(stdout, "ii: no non-empty default shell variables found")
	}
	if missing {
		return 1
	}
	return 0
}

func (c *CLI) runSetFile(path string, stdout, stderr io.Writer) int {
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(stdout, "ii: variable file not found: %s\n", path)
		return 1
	}
	count := 0
	invalid := false
	for index, raw := range strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n") {
		entry := strings.TrimSpace(raw)
		if entry == "" || strings.HasPrefix(entry, "#") {
			continue
		}
		entry = strings.TrimSpace(strings.TrimPrefix(entry, "export "))
		name, value, ok := strings.Cut(entry, "=")
		if !ok || strings.TrimSpace(name) != name || name == "" {
			fmt.Fprintf(stdout, "ii: invalid variable entry in %s at line %d: expected NAME=VALUE\n", path, index+1)
			invalid = true
			continue
		}
		if len(value) >= 2 && value[0] == '\'' && value[len(value)-1] == '\'' {
			value = strings.ReplaceAll(value[1:len(value)-1], "'\\''", "'")
		} else if len(value) >= 2 && value[0] == '"' && value[len(value)-1] == '"' {
			value = strings.ReplaceAll(value[1:len(value)-1], `\"`, `"`)
		}
		line, setErr := c.mutator.Set(name, value)
		if setErr != nil {
			fmt.Fprintln(stderr, setErr)
			return 1
		}
		fmt.Fprintln(stdout, line)
		count++
	}
	if count == 0 {
		fmt.Fprintf(stdout, "ii: no variable entries found in %s\n", path)
	}
	if invalid {
		return 1
	}
	return 0
}
