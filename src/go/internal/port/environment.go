package port

// EnvironmentRead is a snapshot of the tmux session environment. Diagnostic
// preserves a non-fatal tmux message when the legacy pipeline would have
// returned success after printing it.
type EnvironmentRead struct {
	Lines      []string
	Diagnostic string
}

type EnvironmentReader interface {
	Read() (EnvironmentRead, error)
}

type EnvironmentWriter interface {
	Set(name, value string) error
	Unset(name string) error
}

type Environment interface {
	EnvironmentReader
	EnvironmentWriter
}
