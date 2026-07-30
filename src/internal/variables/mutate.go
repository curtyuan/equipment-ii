package variables

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

var variableName = regexp.MustCompile(`^[a-z_][a-z0-9_]*$`)

type Mutator struct {
	environment port.EnvironmentWriter
	shell       port.ShellOperations
	exportCase  string
}

func NewMutator(environment port.EnvironmentWriter, shell port.ShellOperations, exportCase string) *Mutator {
	return &Mutator{environment: environment, shell: shell, exportCase: strings.ToLower(exportCase)}
}

func NormalizeName(raw string) (string, error) {
	name := strings.ToLower(strings.TrimPrefix(strings.TrimSpace(raw), "export "))
	name = strings.TrimPrefix(name, "ii_")
	switch name {
	case "r":
		name = "rhost"
	case "l":
		name = "lhost"
	case "d":
		name = "domain"
	case "user", "username":
		name = "usert"
	case "passwd", "password":
		name = "passt"
	}
	if !variableName.MatchString(name) {
		return "", fmt.Errorf("ii: invalid variable name: %s", raw)
	}
	return "ii_" + name, nil
}

func (m *Mutator) Set(raw, value string) (string, error) {
	name, err := NormalizeName(raw)
	if err != nil {
		return "", err
	}
	if err = m.environment.Set(name, value); err != nil {
		return "", err
	}
	if err = m.export(strings.TrimPrefix(name, "ii_"), value); err != nil {
		return "", err
	}
	return strings.TrimPrefix(name, "ii_") + "=" + value, nil
}

func (m *Mutator) SetStored(raw, value string) (string, error) {
	name, err := NormalizeName(raw)
	if err != nil {
		return "", err
	}
	if err = m.environment.Set(name, value); err != nil {
		return "", err
	}
	return strings.TrimPrefix(name, "ii_") + "=" + value, nil
}

func (m *Mutator) SetInteractive(raw, value string, sync bool) (string, error) {
	if !sync {
		return m.SetStored(raw, value)
	}
	line, err := m.Set(raw, value)
	if err != nil {
		return "", err
	}
	if err = m.shell.SetSyncHook(true); err != nil {
		return "", err
	}
	return line, nil
}

func (m *Mutator) Unset(raw string) (string, error) {
	name, err := NormalizeName(raw)
	if err != nil {
		return "", err
	}
	if err = m.environment.Unset(name); err != nil {
		return "", err
	}
	shellName := strings.TrimPrefix(name, "ii_")
	for _, candidate := range []string{name, shellName, strings.ToUpper(shellName)} {
		if err = m.shell.Unset(candidate); err != nil {
			return "", err
		}
	}
	return shellName, nil
}

func (m *Mutator) export(name, value string) error {
	switch m.exportCase {
	case "", "lower":
		return m.shell.Export(name, value)
	case "upper":
		return m.shell.Export(strings.ToUpper(name), value)
	case "both":
		if err := m.shell.Export(name, value); err != nil {
			return err
		}
		return m.shell.Export(strings.ToUpper(name), value)
	default:
		return fmt.Errorf("ii: invalid II_EXPORT_CASE: %s", m.exportCase)
	}
}
