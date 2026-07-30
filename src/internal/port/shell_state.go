package port

type ShellValue struct {
	Value   string
	Present bool
}

type ShellState interface {
	Lookup(name string) ShellValue
}
