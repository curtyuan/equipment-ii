package variables

import (
	"errors"
	"sort"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

var ErrNoMatch = errors.New("no matched")

type Getter struct {
	environment port.EnvironmentReader
	selector    port.SingleSelector
	clipboard   port.Clipboard
}

func NewGetter(environment port.EnvironmentReader, selector port.SingleSelector, clipboard port.Clipboard) *Getter {
	return &Getter{environment: environment, selector: selector, clipboard: clipboard}
}

func (g *Getter) Get(filter string) (value, diagnostic string, copyErr error, err error) {
	if err = g.selector.Available(); err != nil {
		return "", "", nil, err
	}
	read, err := g.environment.Read()
	if err != nil {
		return "", "", nil, err
	}
	filter = shortcutFilter(filter)
	var matches []Entry
	for _, line := range read.Lines {
		name, value, ok := parseLine(line)
		if ok && strings.Contains(strings.ToLower(name), strings.ToLower(filter)) {
			matches = append(matches, Entry{Name: strings.TrimPrefix(name, "ii_"), Value: value})
		}
	}
	sort.Slice(matches, func(i, j int) bool { return matches[i].Name < matches[j].Name })
	if len(matches) == 0 {
		return "", read.Diagnostic, nil, ErrNoMatch
	}
	selected := matches[0]
	if len(matches) > 1 {
		items := make([]port.SelectionItem, 0, len(matches))
		for _, match := range matches {
			items = append(items, port.SelectionItem{ID: match.Name, Display: match.Name + "\t" + match.Value})
		}
		id, selectErr := g.selector.SelectOne(items)
		if selectErr != nil {
			return "", read.Diagnostic, nil, selectErr
		}
		for _, match := range matches {
			if match.Name == id {
				selected = match
				break
			}
		}
	}
	copyErr = g.clipboard.Copy(selected.Value)
	return selected.Value, read.Diagnostic, copyErr, nil
}

func shortcutFilter(filter string) string {
	switch strings.ToLower(filter) {
	case "r":
		return "RHOST"
	case "l":
		return "LHOST"
	case "d":
		return "DOMAIN"
	default:
		return filter
	}
}
