package cli

import "strings"

type Resolution struct {
	Owner   string
	Command string
}

func Resolve(args []string) Resolution {
	return Resolution{
		Owner:   resolveOwner(args),
		Command: resolveCommand(args),
	}
}

func Route(args []string) string {
	return Resolve(args).Owner
}

func resolveOwner(args []string) string {
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
	if isPayloadInputRoute(args) {
		return RouteGo
	}
	if isWWWRoute(args) {
		return RouteGo
	}
	spec := findCommand(args[0])
	if spec != nil && spec.owner == ownerLegacy {
		return RouteLegacy
	}
	return RouteGo
}

func resolveCommand(args []string) string {
	if len(args) == 0 {
		return "help"
	}
	switch args[0] {
	case "help", "h", "-h", "--help":
		if isWWWHelpPath(args[1:]) {
			return "www"
		}
		if spec := findHelpPath(args[1:]); spec != nil && spec.name == "payload-input" {
			return "payload-input-help"
		}
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
	case "pic", "pie", "pice":
		return "payload-input"
	case "payload", "p":
		if isWWWRoute(args) {
			return "www"
		}
		if containsString(args[1:], "--input") || containsString(args[1:], "input") {
			return "payload-input"
		}
	}
	if spec := findCommand(args[0]); spec != nil && spec.owner == ownerLegacy {
		return "legacy"
	}
	if spec := findCommand(args[0]); spec != nil && spec.owner == ownerGo {
		return spec.name
	}
	return "unknown"
}

func isWWWRoute(args []string) bool {
	if len(args) < 2 || (args[0] != "payload" && args[0] != "p") {
		return false
	}
	if args[1] != "--www" && args[1] != "www" {
		return false
	}
	if containsHelp(args[2:]) {
		return false
	}
	return true
}

func isWWWHelpPath(args []string) bool {
	if len(args) == 1 && strings.HasPrefix(args[0], "payload-www") {
		return true
	}
	if len(args) == 0 || (args[0] != "payload" && args[0] != "p") {
		return false
	}
	if len(args) < 2 || (args[1] != "--www" && args[1] != "www") {
		return false
	}
	return len(args) == 2 || (len(args) == 3 &&
		(args[2] == "--file" || args[2] == "file" || args[2] == "ln" ||
			args[2] == "ls" || args[2] == "search"))
}

func isPayloadInputRoute(args []string) bool {
	if len(args) == 0 {
		return false
	}
	switch args[0] {
	case "pic", "pie", "pice":
		return true
	case "payload", "p":
		return containsString(args[1:], "--input") || containsString(args[1:], "input")
	}
	return false
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

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
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
