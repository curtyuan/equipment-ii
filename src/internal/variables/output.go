package variables

import (
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type Outputter struct {
	environment port.EnvironmentReader
	writer      port.AtomicFileWriter
}

func NewOutputter(environment port.EnvironmentReader, writer port.AtomicFileWriter) *Outputter {
	return &Outputter{environment: environment, writer: writer}
}

func (o *Outputter) Write(path string) (int, string, string, error) {
	read, err := o.environment.Read()
	if err != nil {
		return 0, "", "", err
	}

	var output strings.Builder
	count := 0
	for _, line := range read.Lines {
		name, value, ok := parseLine(line)
		if !ok || value == "" {
			continue
		}
		output.WriteString(strings.TrimPrefix(name, "ii_"))
		output.WriteByte('=')
		output.WriteString(quoteZsh(value))
		output.WriteByte('\n')
		count++
	}

	absolutePath, err := o.writer.WriteAtomic(path, []byte(output.String()))
	if err != nil {
		return 0, "", read.Diagnostic, err
	}
	return count, absolutePath, read.Diagnostic, nil
}

func quoteZsh(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}
