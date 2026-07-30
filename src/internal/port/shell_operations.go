package port

type ShellOperations interface {
	Export(name, value string) error
	Unset(name string) error
	Chdir(path string) error
	SetSyncHook(enabled bool) error
	ExecuteScript(script string) error
}
