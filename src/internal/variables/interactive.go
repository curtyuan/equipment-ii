package variables

import (
	"errors"
	"os"
	"sort"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

const AddVariableID = "add new variable"

type InteractiveResult struct {
	Line    string
	Repeat  bool
	CopyErr error
}

type Interactive struct {
	environment port.EnvironmentReader
	selector    port.InteractiveSelector
	clipboard   port.Clipboard
	mutator     *Mutator
}

func NewInteractive(environment port.EnvironmentReader, selector port.InteractiveSelector, clipboard port.Clipboard, mutator *Mutator) *Interactive {
	return &Interactive{environment: environment, selector: selector, clipboard: clipboard, mutator: mutator}
}

func (i *Interactive) Run() (InteractiveResult, string, error) {
	items, values, diagnostic, err := i.items()
	if err != nil {
		return InteractiveResult{}, diagnostic, err
	}
	selection, err := i.selector.SelectVariable(items)
	if err != nil {
		return InteractiveResult{}, diagnostic, err
	}
	if selection.Action == "q" {
		return InteractiveResult{}, diagnostic, port.ErrSelectionCanceled
	}
	if selection.ID == AddVariableID {
		line, err := i.add()
		return InteractiveResult{Line: line, Repeat: selection.Action == "y"}, diagnostic, err
	}
	value, ok := values[selection.ID]
	if !ok {
		return InteractiveResult{}, diagnostic, errors.New("ii: invalid variable selection")
	}
	if selection.Action == "i" {
		line, err := i.edit(selection.ID, value)
		return InteractiveResult{Line: line, Repeat: true}, diagnostic, err
	}
	copyErr := i.clipboard.Copy(value)
	line := "copied " + selection.ID
	if copyErr != nil {
		line = "selected " + selection.ID + "; clipboard copy failed"
	}
	return InteractiveResult{Line: line, Repeat: selection.Action == "y", CopyErr: copyErr}, diagnostic, nil
}

func (i *Interactive) items() ([]port.SelectionItem, map[string]string, string, error) {
	read, err := i.environment.Read()
	if err != nil {
		return nil, nil, "", err
	}
	values := make(map[string]string)
	custom := make([]string, 0)
	for _, line := range read.Lines {
		name, value, ok := parseLine(line)
		if !ok {
			continue
		}
		name = strings.TrimPrefix(name, "ii_")
		values[name] = value
		custom = append(custom, name)
	}
	names := append(append([]string{}, DefaultVariableNames...), custom...)
	seen := make(map[string]bool)
	populated, empty := []port.SelectionItem{}, []port.SelectionItem{}
	for _, name := range names {
		name = strings.ToLower(name)
		if seen[name] {
			continue
		}
		seen[name] = true
		item := port.SelectionItem{ID: name, Display: oneLine(values[name])}
		if values[name] != "" {
			populated = append(populated, item)
		} else {
			empty = append(empty, item)
		}
	}
	sort.SliceStable(populated, func(a, b int) bool { return populated[a].ID < populated[b].ID })
	items := append(populated, empty...)
	items = append(items, port.SelectionItem{ID: AddVariableID, Display: "Create or update a variable. Empty values are stored but skipped by ii load."})
	return items, values, read.Diagnostic, nil
}

func (i *Interactive) add() (string, error) {
	raw, present := os.LookupEnv("II_ADD_VAR_FILTER")
	var err error
	if !present {
		raw, err = i.selector.Input("ii add name> ", "")
	}
	if err != nil || raw == "" {
		return "", err
	}
	name, err := NormalizeName(raw)
	if err != nil {
		return "", err
	}
	value, present := os.LookupEnv("II_ADD_VALUE_FILTER")
	if !present {
		value, err = i.selector.Input(strings.TrimPrefix(name, "ii_")+" value> ", "")
	}
	if err != nil {
		return "", err
	}
	return i.mutator.SetInteractive(name, value, os.Getenv("II_SYNC_LOADED_VARS") == "1")
}

func (i *Interactive) edit(name, current string) (string, error) {
	value, present := os.LookupEnv("II_EDIT_VALUE_FILTER")
	var err error
	if !present {
		value, err = i.selector.Input(name+" value> ", current)
	}
	if err != nil {
		return "", err
	}
	return i.mutator.SetInteractive(name, value, os.Getenv("II_SYNC_LOADED_VARS") == "1")
}

func oneLine(value string) string {
	value = strings.ReplaceAll(value, "\n", " ")
	if len(value) > 72 {
		return value[:72]
	}
	return value
}

var DefaultVariableNames = []string{
	"domain", "lhost", "rhost", "lport", "rport",
	"user1", "pass1", "user2", "pass2", "user3", "pass3",
	"user4", "pass4", "user5", "pass5", "cuser", "cpass",
	"tuser", "tpass", "directs",
}
