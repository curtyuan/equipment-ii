package payload

import "github.com/curtyuan/equipment-ii/src/internal/port"

type InputRenderer struct {
	environment port.EnvironmentReader
}

func NewInputRenderer(environment port.EnvironmentReader) *InputRenderer {
	return &InputRenderer{environment: environment}
}

func (r *InputRenderer) Render(text string) (RenderResult, string, error) {
	if len(ReferencedNames(text)) == 0 {
		return Render(text, MapResolver{}), "", nil
	}
	resolver, diagnostic, err := NewSessionVariableResolver(r.environment)
	if err != nil {
		return RenderResult{}, diagnostic, err
	}
	return Render(text, resolver), diagnostic, nil
}
