package filesystem

import (
	"fmt"
	"os"
	"path/filepath"
)

type PayloadWriter struct{}

func NewPayloadWriter() *PayloadWriter { return &PayloadWriter{} }

func (w *PayloadWriter) WritePayload(path, text string) (string, error) {
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	parent := filepath.Dir(absolute)
	if err = os.MkdirAll(parent, 0o755); err != nil {
		return "", fmt.Errorf("ii: failed to create output directory: %s", parent)
	}
	if err = os.WriteFile(absolute, []byte(text), 0o600); err != nil {
		return "", fmt.Errorf("ii: failed to write output file: %s", absolute)
	}
	return absolute, nil
}
