package cli

import (
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type fakeSessionEnvironment struct{}

func (fakeSessionEnvironment) Read() (port.EnvironmentRead, error) {
	return port.EnvironmentRead{}, nil
}
func (fakeSessionEnvironment) Set(string, string) error { return nil }
func (fakeSessionEnvironment) Unset(string) error       { return nil }

type fakePanes struct{}

func (fakePanes) CurrentSessionWindow() (string, string, error) { return "$1", "@1", nil }
func (fakePanes) List(string) ([]port.Pane, error)              { return nil, nil }
func (fakePanes) Snapshot(string) (port.Pane, error)            { return port.Pane{}, nil }
func (fakePanes) SendLoad(string) error                         { return nil }
func (fakePanes) SendLiteral(string, string, string) error      { return nil }

type fakePayloadStore struct{}

func (fakePayloadStore) List() ([]string, error)     { return nil, nil }
func (fakePayloadStore) Read(string) (string, error) { return "", nil }

type fakeClipboard struct{}

func (fakeClipboard) Copy(string) error { return nil }

func newTestCLI() *CLI {
	return New(false, Dependencies{
		Environment:  fakeSessionEnvironment{},
		Stdin:        strings.NewReader(""),
		Clipboard:    fakeClipboard{},
		PayloadStore: fakePayloadStore{},
	})
}
