package payload

type WorkflowPane struct {
	ID      string
	Session string
	Window  string
	Index   int
	Left    int
	Top     int
	Width   int
	Height  int
	Dead    bool
	InMode  bool
	Command string
	Path    string
	Title   string
}

type WorkflowRuntime interface {
	CurrentWorkflowSession() (session, originPane string, err error)
	WorkflowPanes(session string) ([]WorkflowPane, error)
	ReadWorkflowMemory(session string) (string, error)
	WriteWorkflowMemory(session, value string) error
	WorkflowPaneSnapshot(id string) (WorkflowPane, error)
	SendWorkflowStage(session, pane, text string) error
}
