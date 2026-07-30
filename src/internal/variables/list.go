package variables

import (
	"sort"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type Entry struct {
	Name  string
	Value string
}

type Lister struct {
	environment port.EnvironmentReader
}

func NewLister(environment port.EnvironmentReader) *Lister {
	return &Lister{environment: environment}
}

func (l *Lister) List(pattern string) ([]Entry, string, error) {
	read, err := l.environment.Read()
	if err != nil {
		return nil, "", err
	}
	lines := read.Lines
	sort.Strings(lines)

	filter := strings.ToLower(pattern)
	entries := make([]Entry, 0, len(lines))
	for _, line := range lines {
		name, value, ok := parseLine(line)
		if !ok || value == "" {
			continue
		}
		shellName := strings.TrimPrefix(name, "ii_")
		if filter != "" && !strings.Contains(strings.ToLower(shellName), filter) {
			continue
		}
		entries = append(entries, Entry{Name: shellName, Value: value})
	}
	return entries, read.Diagnostic, nil
}

func parseLine(line string) (string, string, bool) {
	name, value, ok := strings.Cut(line, "=")
	if !ok || !strings.HasPrefix(name, "ii_") {
		return "", "", false
	}
	for _, character := range strings.TrimPrefix(name, "ii_") {
		if (character < 'a' || character > 'z') &&
			(character < '0' || character > '9') &&
			character != '_' {
			return "", "", false
		}
	}
	return name, value, true
}
