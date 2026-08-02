package payload

import (
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type resolverEnvironment struct{ read port.EnvironmentRead }

func (e resolverEnvironment) Read() (port.EnvironmentRead, error) { return e.read, nil }

func TestSessionVariableResolver(t *testing.T) {
	resolver, diagnostic, err := NewSessionVariableResolver(
		resolverEnvironment{read: port.EnvironmentRead{
			Lines:      []string{"ii_rhost=tmux", "ii_empty=", "OTHER=value"},
			Diagnostic: "note",
		}},
	)
	if err != nil || diagnostic != "note" {
		t.Fatalf("NewSessionVariableResolver = %v, %q", err, diagnostic)
	}
	if got, ok := resolver.Resolve("rhost"); !ok || got != (Value{Value: "tmux", Source: SourceSession}) {
		t.Fatalf("Resolve(rhost) = %#v, %v", got, ok)
	}
	if _, ok := resolver.Resolve("empty"); ok {
		t.Fatal("empty tmux value should be unresolved")
	}
}
