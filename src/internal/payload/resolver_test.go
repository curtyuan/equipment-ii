package payload

import (
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type resolverShell map[string]port.ShellValue

func (s resolverShell) Lookup(name string) port.ShellValue { return s[name] }

type resolverEnvironment struct {
	read port.EnvironmentRead
}

func (e resolverEnvironment) Read() (port.EnvironmentRead, error) { return e.read, nil }

func TestVariableResolverPrecedence(t *testing.T) {
	resolver, diagnostic, err := NewVariableResolver(
		resolverShell{
			"rhost": {Present: true, Value: "shell"},
			"empty": {Present: true, Value: ""},
		},
		resolverEnvironment{read: port.EnvironmentRead{
			Lines:      []string{"ii_rhost=tmux", "ii_empty=fallback", "ii_lhost=session"},
			Diagnostic: "note",
		}},
	)
	if err != nil || diagnostic != "note" {
		t.Fatalf("NewVariableResolver = %v, %q", err, diagnostic)
	}
	tests := map[string]Value{
		"rhost": {Value: "shell", Source: SourceShell},
		"empty": {Value: "fallback", Source: SourceSession},
		"lhost": {Value: "session", Source: SourceSession},
	}
	for name, want := range tests {
		if got, ok := resolver.Resolve(name); !ok || got != want {
			t.Fatalf("Resolve(%q) = %#v, %v; want %#v", name, got, ok, want)
		}
	}
}
