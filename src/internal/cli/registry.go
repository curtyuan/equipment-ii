package cli

import "strings"

type commandSpec struct {
	name      string
	aliases   []string
	helpPaths [][]string
}

var commandRegistry = []commandSpec{
	{name: "version", aliases: []string{"-v", "--version"},
		helpPaths: [][]string{{"version"}, {"-v"}, {"--version"}}},
	{name: "list", aliases: []string{"ls", "list", "variable", "vars", "var"},
		helpPaths: [][]string{{"ls"}, {"list"}, {"variable"}, {"vars"}, {"var"}}},
	{name: "variable", aliases: []string{"v"},
		helpPaths: [][]string{{"v"}}},
	{name: "output", aliases: []string{"vo", "voc"},
		helpPaths: [][]string{{"vo"}, {"voc"}, {"variables-output"}, {"v", "--out"}}},
	{name: "set", aliases: []string{"set", "s", "sr", "sf", "sha"},
		helpPaths: [][]string{{"set"}, {"s"}, {"sr"}, {"sf"}, {"sha"}}},
	{name: "get", aliases: []string{"get", "g", "gr", "gl"},
		helpPaths: [][]string{{"get"}, {"g"}, {"gr"}, {"gl"}}},
	{name: "clipboard", aliases: []string{"clip", "clipboard"},
		helpPaths: [][]string{{"clip"}, {"clipboard"}}},
	{name: "load", aliases: []string{"load", "l", "la"},
		helpPaths: [][]string{{"load"}, {"l"}, {"la"}, {"load", "--all-pane"}, {"l", "--all-pane"}}},
	{name: "interactive", aliases: []string{"interactive", "i"},
		helpPaths: [][]string{{"interactive"}, {"i"}}},
	{name: "payload", aliases: []string{"payload", "p", "pc", "pe", "pce"},
		helpPaths: [][]string{
			{"payload"}, {"p"}, {"pc"}, {"pe"}, {"pce"}, {"payload-copy"},
			{"payload", "--copy"}, {"p", "--copy"},
			{"payload", "--execute"}, {"p", "--execute"},
			{"payload", "--copy", "--execute"}, {"payload", "--execute", "--copy"},
			{"p", "--copy", "--execute"}, {"p", "--execute", "--copy"},
		}},
	{name: "payload-input", aliases: []string{"pic", "pie", "pice"},
		helpPaths: [][]string{
			{"payload-input"}, {"payload", "--input"}, {"payload", "input"},
			{"p", "--input"}, {"p", "input"},
			{"pic"}, {"payload", "--input", "--copy"}, {"p", "--input", "--copy"},
			{"pie"}, {"payload", "--input", "--execute"}, {"p", "--input", "--execute"},
			{"pice"}, {"payload", "--input", "--copy", "--execute"},
			{"p", "--input", "--copy", "--execute"},
		}},
	{name: "tmux", aliases: []string{"tmux"},
		helpPaths: [][]string{{"tmux"}, {"tmux", "status"}}},
	{name: "unset", aliases: []string{"unset", "u"},
		helpPaths: [][]string{{"unset"}, {"u"}}},
}

func findCommand(name string) *commandSpec {
	for index := range commandRegistry {
		spec := &commandRegistry[index]
		for _, alias := range spec.aliases {
			if name == alias {
				return spec
			}
		}
	}
	if strings.HasPrefix(name, "s:") {
		return findCanonical("set")
	}
	if strings.HasPrefix(name, "g:") {
		return findCanonical("get")
	}
	return nil
}

func findCanonical(name string) *commandSpec {
	for index := range commandRegistry {
		if commandRegistry[index].name == name {
			return &commandRegistry[index]
		}
	}
	return nil
}

func findHelpPath(path []string) *commandSpec {
	for index := range commandRegistry {
		spec := &commandRegistry[index]
		for _, candidate := range spec.helpPaths {
			if equalStrings(path, candidate) {
				return spec
			}
		}
	}
	return nil
}

func equalStrings(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for index := range left {
		if left[index] != right[index] {
			return false
		}
	}
	return true
}
