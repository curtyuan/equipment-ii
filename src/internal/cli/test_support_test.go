package cli

import (
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
	wwwdomain "github.com/curtyuan/equipment-ii/src/internal/www"
)

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
func (fakePanes) SendLiteral(string, string, string) error      { return nil }

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
func (fakeSelector) SelectDirectory([]wwwdomain.Entry) (wwwdomain.Entry, error) {
	return wwwdomain.Entry{}, port.ErrSelectionCanceled
}
func (fakeSelector) SelectEntry([]wwwdomain.Entry, string) (wwwdomain.Entry, error) {
	return wwwdomain.Entry{}, port.ErrSelectionCanceled
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
	return New("0.2.4", false, Dependencies{
		Environment: fakeSessionEnvironment{}, AtomicWriter: fakeAtomicFileWriter{},
		Shell: fakeShellOperations{}, ExportCase: "lower", ShellState: fakeShellState{},
		AddressDetector: fakeAddressDetector{}, Stdin: strings.NewReader(""),
		Panes: fakePanes{}, Selector: fakeSelector{}, Clipboard: fakeClipboard{},
		PayloadStore: fakePayloadStore{}, PayloadWriter: fakePayloadWriter{},
		TmuxIntegration: fakeTmuxIntegration{},
		WebStore:        &fakeWebStore{},
		WebSelector:     fakeSelector{},
	})
}

type fakeWebStore struct{}

func (*fakeWebStore) RequireRoot(path string) (string, error)           { return path, nil }
func (*fakeWebStore) ResolveSource(path string, _ bool) (string, error) { return path, nil }
func (*fakeWebStore) MakeDir(string) error                              { return nil }
func (*fakeWebStore) Entries(string, bool) ([]wwwdomain.Entry, error)   { return nil, nil }
func (*fakeWebStore) Symlink(string, string) error                      { return nil }
