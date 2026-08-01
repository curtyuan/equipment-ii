package port

type ShellOperations interface {
	Export(name, value string) error
	Unset(name string) error
	Chdir(path string) error
	ExecuteScript(script string) error
}
