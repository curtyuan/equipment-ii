package payload

import (
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type inputEnvironment struct{ lines []string }

func (e inputEnvironment) Read() (port.EnvironmentRead, error) {
	return port.EnvironmentRead{Lines: e.lines}, nil
}

func TestInputRendererUsesTmuxState(t *testing.T) {
	renderer := NewInputRenderer(
		inputEnvironment{lines: []string{"ii_rhost=tmux", "ii_lhost=session"}},
	)
	result, diagnostic, err := renderer.Render("echo $rhost $lhost")
	if err != nil || diagnostic != "" || result.Text != "echo tmux session" {
		t.Fatalf("result=%+v diagnostic=%q err=%v", result, diagnostic, err)
	}
}
