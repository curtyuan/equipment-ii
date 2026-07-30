package cli

import (
	"bytes"
	"strings"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func TestRoute(t *testing.T) {
	tests := []struct {
		name string
		args []string
		want string
	}{
		{"empty", nil, RouteGo},
		{"version", []string{"version"}, RouteGo},
		{"top help", []string{"help"}, RouteGo},
		{"version help", []string{"help", "version"}, RouteGo},
		{"set command", []string{"set", "rhost", "value"}, RouteGo},
		{"compact set", []string{"s:rhost=value"}, RouteGo},
		{"set help", []string{"help", "set"}, RouteGo},
		{"list", []string{"ls", "host"}, RouteGo},
		{"list help", []string{"help", "list"}, RouteGo},
		{"v list", []string{"v", "host"}, RouteGo},
		{"v output", []string{"v", "--out"}, RouteGo},
		{"vo output", []string{"vo"}, RouteGo},
		{"voc output", []string{"voc"}, RouteGo},
		{"v help", []string{"v", "--help"}, RouteGo},
		{"output help", []string{"help", "v", "--out"}, RouteGo},
		{"interactive", []string{"interactive"}, RouteGo},
		{"interactive alias", []string{"i"}, RouteGo},
		{"interactive help", []string{"help", "interactive"}, RouteGo},
		{"payload remains legacy", []string{"pic"}, RouteLegacy},
		{"unknown", []string{"wat"}, RouteGo},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := Route(test.args); got != test.want {
				t.Fatalf("Route(%q) = %q, want %q", test.args, got, test.want)
			}
		})
	}
}

func TestVersion(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"version"}, &stdout, &stderr)
	if status != 0 || stdout.String() != "ii 0.2.4\n" || stderr.Len() != 0 {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
}

func TestUnknownCommand(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"wat"}, &stdout, &stderr)
	if status != 2 {
		t.Fatalf("status=%d, want 2", status)
	}
	if stderr.String() != "ii: unknown command: wat\n" {
		t.Fatalf("stderr=%q", stderr.String())
	}
	if stdout.String() != topHelp {
		t.Fatal("unknown command did not print top-level help")
	}
}

type fakeSessionEnvironment struct{}

func (fakeSessionEnvironment) Read() (port.EnvironmentRead, error) {
	return port.EnvironmentRead{}, nil
}
func (fakeSessionEnvironment) Set(string, string) error { return nil }
func (fakeSessionEnvironment) Unset(string) error       { return nil }

type fakeAtomicFileWriter struct{}

func (fakeAtomicFileWriter) WriteAtomic(path string, data []byte) (string, error) {
	return "/absolute/" + path, nil
}

type fakeShellOperations struct{}

func (fakeShellOperations) Export(string, string) error { return nil }
func (fakeShellOperations) Unset(string) error          { return nil }
func (fakeShellOperations) Chdir(string) error          { return nil }
func (fakeShellOperations) SetSyncHook(bool) error      { return nil }
func (fakeShellOperations) ExecuteScript(string) error  { return nil }

type fakeShellState struct{}

func (fakeShellState) Lookup(string) port.ShellValue { return port.ShellValue{} }

type fakeAddressDetector struct{}

func (fakeAddressDetector) InterfaceIPv4(string) (string, error) { return "192.0.2.10", nil }

type fakePanes struct{}

func (fakePanes) CurrentSessionWindow() (string, string, error) { return "$1", "@1", nil }
func (fakePanes) List(string) ([]port.Pane, error)              { return nil, nil }
func (fakePanes) Snapshot(string) (port.Pane, error)            { return port.Pane{}, nil }
func (fakePanes) SendLoad(string) error                         { return nil }

type fakeTmuxIntegration struct{}

func (fakeTmuxIntegration) IntegrationStatus(string, int) (port.TmuxIntegrationStatus, error) {
	return port.TmuxIntegrationStatus{}, nil
}
func (fakeTmuxIntegration) EnsureIntegration(string, string, int, bool) (string, error) {
	return "", nil
}

type fakeSelector struct{}

func (fakeSelector) Select([]port.SelectionItem) ([]string, error)  { return nil, nil }
func (fakeSelector) Available() error                               { return nil }
func (fakeSelector) SelectOne([]port.SelectionItem) (string, error) { return "", nil }
func (fakeSelector) SelectVariable([]port.SelectionItem) (port.InteractiveSelection, error) {
	return port.InteractiveSelection{}, nil
}
func (fakeSelector) Input(string, string) (string, error) { return "", nil }
func (fakeSelector) SelectPayload([]port.PayloadSelectionItem, string, string) (port.PayloadSelection, error) {
	return port.PayloadSelection{}, nil
}

type fakePayloadStore struct{}

func (fakePayloadStore) List() ([]string, error)     { return nil, nil }
func (fakePayloadStore) Read(string) (string, error) { return "", nil }

type fakePayloadWriter struct{}

func (fakePayloadWriter) WritePayload(path, text string) (string, error) {
	return "/absolute/" + path, nil
}

type fakeClipboard struct{}

func (fakeClipboard) Copy(string) error                 { return nil }
func (fakeClipboard) EffectiveBackend() (string, error) { return "tmux", nil }
func (fakeClipboard) Context() string                   { return "local" }

func newTestCLI() *CLI {
	return New("0.2.4", false, fakeSessionEnvironment{}, fakeAtomicFileWriter{}, fakeShellOperations{}, "lower", fakeShellState{}, fakeAddressDetector{}, "", "", strings.NewReader(""), fakePanes{}, fakeSelector{}, fakeClipboard{}, fakePayloadStore{}, fakePayloadWriter{}, fakeTmuxIntegration{})
}

func TestColorizeAliases(t *testing.T) {
	got := ColorizeAliases("Aliases:\n  h, -h    note\n  none\n\nBody\n", true)
	if !strings.Contains(got, "  \x1b[36mh, -h\x1b[0m    note\n") {
		t.Fatalf("unexpected colored help: %q", got)
	}
	if !strings.Contains(got, "  none\n") {
		t.Fatalf("none alias should remain plain: %q", got)
	}
}

func TestListHelpDoesNotReadSession(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"help", "ls"}, &stdout, &stderr)
	if status != 0 || stdout.String() != listHelp || stderr.Len() != 0 {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
}

func TestVariableOutputUsageDoesNotReadSession(t *testing.T) {
	var stdout, stderr bytes.Buffer
	status := newTestCLI().Run([]string{"vo", "one", "two"}, &stdout, &stderr)
	if status != 2 || stdout.Len() != 0 ||
		stderr.String() != "ii: usage: ii v --out [PATH] | ii vo [PATH]\n" {
		t.Fatalf("status=%d stdout=%q stderr=%q", status, stdout.String(), stderr.String())
	}
}

func TestVariableHelpRoutes(t *testing.T) {
	tests := []struct {
		args []string
		want string
	}{
		{[]string{"v", "--help"}, variableHelp},
		{[]string{"help", "v"}, variableHelp},
		{[]string{"vo", "--help"}, variableOutputHelp},
		{[]string{"help", "v", "--out"}, variableOutputHelp},
	}
	for _, test := range tests {
		var stdout, stderr bytes.Buffer
		status := newTestCLI().Run(test.args, &stdout, &stderr)
		if status != 0 || stdout.String() != test.want || stderr.Len() != 0 {
			t.Fatalf("args=%q status=%d stdout=%q stderr=%q", test.args, status, stdout.String(), stderr.String())
		}
	}
}
