package payload

import (
	"path/filepath"
	"sort"
	"strings"
)

type Source string

const (
	SourceShell   Source = "shell"
	SourceSession Source = "ii"
	SourceMissing Source = "missing"
)

type Value struct {
	Value  string
	Source Source
}

type ReportEntry struct {
	Name   string
	Value  string
	Source Source
}

type Resolver interface {
	Resolve(name string) (Value, bool)
}

type MapResolver map[string]Value

func (r MapResolver) Resolve(name string) (Value, bool) {
	value, ok := r[name]
	return value, ok && value.Value != ""
}

type RenderResult struct {
	Text   string
	Report []ReportEntry
}

func Render(text string, resolver Resolver) RenderResult {
	var output strings.Builder
	report := make(map[string]ReportEntry)
	for index := 0; index < len(text); {
		name, modifier, original, end, ok := tokenAt(text, index)
		if !ok {
			output.WriteByte(text[index])
			index++
			continue
		}
		value, found := resolver.Resolve(name)
		if !found {
			value = Value{Value: original, Source: SourceMissing}
		}
		rendered := value.Value
		if found && modifier == ":t" {
			rendered = pathTail(rendered)
		}
		output.WriteString(rendered)
		current, recorded := report[name]
		if !recorded || current.Source == SourceMissing {
			report[name] = ReportEntry{Name: name, Value: value.Value, Source: value.Source}
		}
		index = end
	}
	names := make([]string, 0, len(report))
	for name := range report {
		names = append(names, name)
	}
	sort.Strings(names)
	entries := make([]ReportEntry, 0, len(names))
	for _, name := range names {
		entries = append(entries, report[name])
	}
	return RenderResult{Text: output.String(), Report: entries}
}

func ReferencedNames(text string) []string {
	seen := make(map[string]bool)
	for index := 0; index < len(text); {
		name, _, _, end, ok := tokenAt(text, index)
		if !ok {
			index++
			continue
		}
		seen[name] = true
		index = end
	}
	names := make([]string, 0, len(seen))
	for name := range seen {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

func tokenAt(text string, index int) (name, modifier, original string, end int, ok bool) {
	if text[index] == '$' {
		if index+1 >= len(text) {
			return
		}
		if text[index+1] == '{' {
			close := strings.IndexByte(text[index+2:], '}')
			if close < 0 {
				return
			}
			close += index + 2
			expression := text[index+2 : close]
			modifier = ""
			if strings.HasSuffix(expression, ":t") {
				expression = strings.TrimSuffix(expression, ":t")
				modifier = ":t"
			}
			if !validName(expression) {
				return "", "", "", 0, false
			}
			return expression, modifier, text[index : close+1], close + 1, true
		}
		cursor := index + 1
		if !nameStart(text[cursor]) {
			return
		}
		for cursor < len(text) && nameCharacter(text[cursor]) {
			cursor++
		}
		name = text[index+1 : cursor]
		if !validName(name) {
			return "", "", "", 0, false
		}
		if cursor < len(text) && text[cursor] == ':' && powerShellScope(name) {
			return "", "", "", 0, false
		}
		return name, "", text[index:cursor], cursor, true
	}
	if text[index] == '%' && index+2 < len(text) && nameStart(text[index+1]) {
		cursor := index + 2
		for cursor < len(text) && nameCharacter(text[cursor]) {
			cursor++
		}
		if cursor >= len(text) || text[cursor] != '%' {
			return
		}
		name = text[index+1 : cursor]
		if !validName(name) {
			return "", "", "", 0, false
		}
		return name, "", text[index : cursor+1], cursor + 1, true
	}
	return
}

func validName(name string) bool {
	if name == "" || !nameStart(name[0]) {
		return false
	}
	for index := 1; index < len(name); index++ {
		if !nameCharacter(name[index]) {
			return false
		}
	}
	return true
}

func nameStart(value byte) bool {
	return value == '_' || value >= 'a' && value <= 'z'
}

func nameCharacter(value byte) bool {
	return nameStart(value) || value >= '0' && value <= '9'
}

func powerShellScope(name string) bool {
	switch name {
	case "env", "script", "global", "local", "private":
		return true
	}
	return false
}

func pathTail(value string) string {
	value = filepath.Base(strings.ReplaceAll(value, `\`, "/"))
	return value
}
