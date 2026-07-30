package payload

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type Output struct {
	writer port.PayloadWriter
}

func NewOutput(writer port.PayloadWriter) *Output {
	return &Output{writer: writer}
}

func (o *Output) Write(text, spec string) (string, error) {
	return o.writer.WritePayload(OutputPath(spec), text)
}

func OutputPath(spec string) string {
	if spec == "" {
		return "/www/p/att.txt"
	}
	if strings.HasSuffix(spec, "/") {
		return filepath.Join(strings.TrimSuffix(spec, "/"), "att.txt")
	}
	if info, err := os.Stat(spec); err == nil && info.IsDir() {
		return filepath.Join(spec, "att.txt")
	}
	if filepath.IsAbs(spec) || strings.HasPrefix(spec, "./") ||
		strings.HasPrefix(spec, "../") || strings.ContainsRune(spec, filepath.Separator) {
		return spec
	}
	return filepath.Join("/www", spec)
}
