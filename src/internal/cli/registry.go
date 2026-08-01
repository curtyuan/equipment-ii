package cli

import "strings"

type owner string

const (
	ownerGo     owner = "go"
	ownerLegacy owner = "legacy"
)

type commandSpec struct {
	name      string
	aliases   []string
	owner     owner
	helpPaths [][]string
}

var commandRegistry = []commandSpec{
	{name: "version", aliases: []string{"-v", "--version"}, owner: ownerGo,
		helpPaths: [][]string{{"version"}, {"-v"}, {"--version"}}},
	{name: "list", aliases: []string{"ls", "list", "variable", "vars", "var"}, owner: ownerGo,
		helpPaths: [][]string{{"ls"}, {"list"}, {"variable"}, {"vars"}, {"var"}}},
	{name: "variable", aliases: []string{"v"}, owner: ownerGo,
		helpPaths: [][]string{{"v"}}},
	{name: "output", aliases: []string{"vo", "voc"}, owner: ownerGo,
		helpPaths: [][]string{{"vo"}, {"voc"}, {"variables-output"}, {"v", "--out"}}},
	{name: "set", aliases: []string{"set", "s", "sr", "sf", "sha"}, owner: ownerGo,
		helpPaths: [][]string{{"set"}, {"s"}, {"sr"}, {"sf"}, {"sha"}}},
	{name: "get", aliases: []string{"get", "g", "gr", "gl"}, owner: ownerGo,
		helpPaths: [][]string{{"get"}, {"g"}, {"gr"}, {"gl"}}},
	{name: "clipboard", aliases: []string{"clip", "clipboard"}, owner: ownerGo,
		helpPaths: [][]string{{"clip"}, {"clipboard"}}},
	{name: "load", aliases: []string{"load", "l", "la"}, owner: ownerGo,
		helpPaths: [][]string{{"load"}, {"l"}, {"la"}, {"load", "--all-pane"}, {"l", "--all-pane"}}},
	{name: "sync", aliases: []string{"sync"}, owner: ownerGo,
		helpPaths: [][]string{{"sync"}}},
	{name: "interactive", aliases: []string{"interactive", "i"}, owner: ownerGo,
		helpPaths: [][]string{{"interactive"}, {"i"}}},
	{name: "payload", aliases: []string{"payload", "p", "pc", "pe", "pce"}, owner: ownerGo,
		helpPaths: [][]string{
			{"payload"}, {"p"}, {"pc"}, {"pe"}, {"pce"}, {"payload-copy"},
			{"payload", "--copy"}, {"p", "--copy"},
			{"payload", "--execute"}, {"p", "--execute"},
			{"payload", "--copy", "--execute"}, {"payload", "--execute", "--copy"},
			{"p", "--copy", "--execute"}, {"p", "--execute", "--copy"},
		}},
	{name: "payload-input", aliases: []string{"pic", "pie", "pice"}, owner: ownerGo,
		helpPaths: [][]string{
			{"payload-input"}, {"payload", "--input"}, {"payload", "input"},
			{"p", "--input"}, {"p", "input"},
			{"pic"}, {"payload", "--input", "--copy"}, {"p", "--input", "--copy"},
			{"pie"}, {"payload", "--input", "--execute"}, {"p", "--input", "--execute"},
			{"pice"}, {"payload", "--input", "--copy", "--execute"},
			{"p", "--input", "--copy", "--execute"},
		}},
	{name: "tmux", aliases: []string{"tmux"}, owner: ownerGo,
		helpPaths: [][]string{{"tmux"}, {"tmux", "status"}}},
	{name: "unset", aliases: []string{"unset", "u"}, owner: ownerGo,
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
