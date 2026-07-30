package cli

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/port"
	"github.com/curtyuan/equipment-ii/src/internal/variables"
)

const (
	RouteGo     = "go"
	RouteLegacy = "legacy"
)

type CLI struct {
	version          string
	color            bool
	lister           *variables.Lister
	output           *variables.Outputter
	shell            port.ShellOperations
	mutator          *variables.Mutator
	loader           *variables.Loader
	state            port.ShellState
	detector         port.AddressDetector
	autoDetect       bool
	detectInterface  string
	stdin            io.Reader
	environment      port.Environment
	allPanes         *variables.AllPaneLoader
	getter           *variables.Getter
	interactive      *variables.Interactive
	payloads         *payload.Catalog
	payloadSelector  port.PayloadSelector
	clipboard        port.Clipboard
	clipboardBackend port.ClipboardBackend
	payloadOutput    *payload.Output
	tmuxIntegration  port.TmuxIntegration
}

func New(
	version string,
	color bool,
	environment port.Environment,
	writer port.AtomicFileWriter,
	shell port.ShellOperations,
	exportCase string,
	shellState port.ShellState,
	detector port.AddressDetector,
	autoDetect string,
	detectInterface string,
	stdin io.Reader,
	panes port.PaneController,
	selector port.Selector,
	clipboard port.ClipboardBackend,
	payloadStore port.PayloadStore,
	payloadWriter port.PayloadWriter,
	tmuxIntegration port.TmuxIntegration,
) *CLI {
	mutator := variables.NewMutator(environment, shell, exportCase)
	loader := variables.NewLoader(environment, mutator)
	enabled := true
	switch strings.ToLower(autoDetect) {
	case "0", "false", "no", "off", "disabled":
		enabled = false
	}
	if detectInterface == "" {
		detectInterface = "tun0"
	}
	return &CLI{
		version:          version,
		color:            color,
		lister:           variables.NewLister(environment),
		output:           variables.NewOutputter(environment, writer),
		shell:            shell,
		mutator:          mutator,
		loader:           loader,
		state:            shellState,
		detector:         detector,
		autoDetect:       enabled,
		detectInterface:  detectInterface,
		stdin:            stdin,
		environment:      environment,
		allPanes:         variables.NewAllPaneLoader(panes, selector, loader),
		getter:           variables.NewGetter(environment, selector, clipboard),
		interactive:      variables.NewInteractive(environment, selector, clipboard, mutator),
		payloads:         payload.NewCatalog(payloadStore),
		payloadSelector:  selector,
		clipboard:        clipboard,
		clipboardBackend: clipboard,
		payloadOutput:    payload.NewOutput(payloadWriter),
		tmuxIntegration:  tmuxIntegration,
	}
}

func (c *CLI) Run(args []string, stdout, stderr io.Writer) int {
	if len(args) > 0 && args[0] == "__route" {
		fmt.Fprintln(stdout, Route(args[1:]))
		return 0
	}
	if len(args) > 0 && args[0] == "__payload_names" {
		names, err := c.payloads.ReferencedNames()
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		for _, name := range names {
			fmt.Fprintln(stdout, name)
		}
		return 0
	}
	if len(args) > 0 && args[0] == "__payload_render" {
		if len(args) != 2 {
			fmt.Fprintln(stderr, "ii: usage: ii-go __payload_render PATH")
			return 2
		}
		resolver, diagnostic, err := payload.NewVariableResolver(c.state, c.environment)
		fmt.Fprint(stderr, diagnostic)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		result, err := payload.NewService(c.payloads, resolver).Render(args[1])
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprint(stdout, result.Text)
		return 0
	}
	if len(args) > 0 && args[0] == "__payload_select" {
		return c.runPayload(args[1:], stdout, stderr)
	}

	switch command(args) {
	case "help":
		if isVersionHelp(args) {
			fmt.Fprint(stdout, versionHelp)
			return 0
		}
		fmt.Fprint(stdout, ColorizeAliases(topHelp, c.color))
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

func Route(args []string) string {
	if len(args) == 0 {
		return RouteGo
	}
	switch args[0] {
	case "help", "h", "-h", "--help":
		if len(args) == 1 {
			return RouteGo
		}
		spec := findHelpPath(args[1:])
		if spec == nil || spec.owner == ownerLegacy {
			return RouteLegacy
		}
		return RouteGo
	}
	spec := findCommand(args[0])
	if spec != nil && spec.owner == ownerLegacy {
		return RouteLegacy
	}
	return RouteGo
}

func command(args []string) string {
	if len(args) == 0 {
		return "help"
	}
	switch args[0] {
	case "help", "h", "-h", "--help":
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "set" {
			return "set-help"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "unset" {
			return "unset-help"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "load" {
			return "load-help"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "sync" {
			return "sync-help"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "get" {
			return "get-help"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "interactive" {
			return "interactive"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "clipboard" {
			return "clipboard"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "tmux" {
			return "tmux"
		}
		if isVariableTopic(args[1:]) {
			if isVariableOutputTopic(args[1:]) {
				return "output"
			}
			return "variable-help"
		}
		if isListTopic(args[1:]) {
			return "list"
		}
		return "help"
	case "version", "-v", "--version":
		return "version"
	case "ls", "list", "variable", "vars", "var":
		return "list"
	case "v":
		if len(args) > 1 {
			switch args[1] {
			case "--out":
				return "output"
			case "-h", "--help":
				return "variable-help"
			}
		}
		return "list"
	case "vo", "voc":
		return "output"
	}
	if spec := findCommand(args[0]); spec != nil && spec.owner == ownerLegacy {
		return "legacy"
	}
	if spec := findCommand(args[0]); spec != nil && spec.owner == ownerGo {
		return spec.name
	}
	return "unknown"
}

func isVersionHelp(args []string) bool {
	if len(args) == 0 {
		return false
	}
	if args[0] == "help" || args[0] == "h" || args[0] == "-h" || args[0] == "--help" {
		return isVersionTopic(args[1:])
	}
	return false
}

func isVariableTopic(args []string) bool {
	if len(args) == 1 {
		switch args[0] {
		case "v", "vo", "voc", "variables-output":
			return true
		}
	}
	return isVariableOutputTopic(args)
}

func isVariableOutputTopic(args []string) bool {
	return len(args) == 2 && args[0] == "v" && args[1] == "--out"
}

func variableOutputArgs(args []string) []string {
	if len(args) == 0 {
		return nil
	}
	if isHelpCommand(args[0]) {
		return []string{"--help"}
	}
	if args[0] == "v" {
		return args[2:]
	}
	return args[1:]
}

func isListTopic(args []string) bool {
	if len(args) != 1 {
		return false
	}
	switch args[0] {
	case "ls", "list", "variable", "vars", "var":
		return true
	}
	return false
}

func isVersionTopic(args []string) bool {
	return len(args) == 1 &&
		(args[0] == "version" || args[0] == "-v" || args[0] == "--version")
}

func containsHelp(args []string) bool {
	for _, arg := range args {
		if arg == "-h" || arg == "--help" {
			return true
		}
	}
	return false
}

func isHelpCommand(command string) bool {
	switch command {
	case "help", "h", "-h", "--help":
		return true
	}
	return false
}

func first(args []string) string {
	if len(args) == 0 {
		return ""
	}
	return args[0]
}
