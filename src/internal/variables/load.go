package variables

import "github.com/curtyuan/equipment-ii/src/internal/port"

type Loader struct {
	environment port.EnvironmentReader
	mutator     *Mutator
}

func NewLoader(environment port.EnvironmentReader, mutator *Mutator) *Loader {
	return &Loader{environment: environment, mutator: mutator}
}

func (l *Loader) Load() (int, string, error) {
	read, err := l.environment.Read()
	if err != nil {
		return 0, "", err
	}
	count := 0
	for _, line := range read.Lines {
		name, value, ok := parseLine(line)
		if !ok || value == "" {
			continue
		}
		if err = l.mutator.export(name[3:], value); err != nil {
			return count, read.Diagnostic, err
		}
		count++
	}
	return count, read.Diagnostic, nil
}
