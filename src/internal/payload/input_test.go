package payload

import (
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type inputShell map[string]port.ShellValue

func (s inputShell) Lookup(name string) port.ShellValue { return s[name] }

type inputEnvironment struct{ lines []string }

func (e inputEnvironment) Read() (port.EnvironmentRead, error) {
	return port.EnvironmentRead{Lines: e.lines}, nil
}

func TestInputRendererPreservesShellPrecedence(t *testing.T) {
	renderer := NewInputRenderer(
		inputShell{"rhost": {Present: true, Value: "shell"}},
		inputEnvironment{lines: []string{"ii_rhost=tmux", "ii_lhost=session"}},
	)
	result, diagnostic, err := renderer.Render("echo $rhost $lhost")
	if err != nil || diagnostic != "" || result.Text != "echo shell session" {
		t.Fatalf("result=%+v diagnostic=%q err=%v", result, diagnostic, err)
	}
}
