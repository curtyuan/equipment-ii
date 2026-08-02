package payload

import (
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type VariableResolver struct {
	session map[string]string
}

// NewSessionVariableResolver intentionally uses tmux as the sole state source
// for combo workflows and the tmux input popup.
func NewSessionVariableResolver(environment port.EnvironmentReader) (*VariableResolver, string, error) {
	read, err := environment.Read()
	if err != nil {
		return nil, "", err
	}
	session := make(map[string]string)
	for _, line := range read.Lines {
		name, value, ok := strings.Cut(line, "=")
		if !ok || !strings.HasPrefix(name, "ii_") || value == "" {
			continue
		}
		session[strings.TrimPrefix(name, "ii_")] = value
	}
	return &VariableResolver{session: session}, read.Diagnostic, nil
}

func (r *VariableResolver) Resolve(name string) (Value, bool) {
	if value := r.session[name]; value != "" {
		return Value{Value: value, Source: SourceSession}, true
	}
	return Value{}, false
}
