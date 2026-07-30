package payload

import "github.com/curtyuan/equipment-ii/src/internal/port"

type InputRenderer struct {
	shell       port.ShellState
	environment port.EnvironmentReader
}

func NewInputRenderer(shell port.ShellState, environment port.EnvironmentReader) *InputRenderer {
	return &InputRenderer{shell: shell, environment: environment}
}

func (r *InputRenderer) Render(text string) (RenderResult, string, error) {
	resolver, diagnostic, err := NewVariableResolver(r.shell, r.environment)
	if err != nil {
		return RenderResult{}, diagnostic, err
	}
	return Render(text, resolver), diagnostic, nil
}
