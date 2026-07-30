package port

type Pane struct {
	ID      string
	Session string
	Window  string
	Dead    bool
	InMode  bool
	Command string
	Path    string
	Title   string
}

type PaneController interface {
	CurrentSessionWindow() (session, window string, err error)
	List(window string) ([]Pane, error)
	Snapshot(id string) (Pane, error)
	SendLoad(id string) error
}
