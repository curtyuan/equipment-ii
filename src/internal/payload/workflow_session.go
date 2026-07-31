package payload

import "fmt"

type WorkflowSession struct {
	Session     string
	OriginPane  string
	Panes       []WorkflowPane
	Memory      string
	Assignments *LaneAssignments
}

type WorkflowCoordinator struct {
	runtime WorkflowRuntime
}

func NewWorkflowCoordinator(runtime WorkflowRuntime) *WorkflowCoordinator {
	return &WorkflowCoordinator{runtime: runtime}
}

func (c *WorkflowCoordinator) Prepare(workflow Workflow) (WorkflowSession, error) {
	session, origin, err := c.runtime.CurrentWorkflowSession()
	if err != nil {
		return WorkflowSession{}, err
	}
	panes, err := c.runtime.WorkflowPanes(session)
	if err != nil {
		return WorkflowSession{}, err
	}
	memory, err := c.runtime.ReadWorkflowMemory(session)
	if err != nil {
		return WorkflowSession{}, err
	}
	return WorkflowSession{
		Session: session, OriginPane: origin, Panes: panes, Memory: memory,
		Assignments: DetectInitialAssignments(workflow.Lanes, panes, origin, memory),
	}, nil
}

func (c *WorkflowCoordinator) Save(state WorkflowSession) error {
	value := MergeLaneMemory(state.Memory, state.Assignments.Bindings())
	return c.runtime.WriteWorkflowMemory(state.Session, value)
}

func (c *WorkflowCoordinator) Revalidate(workflow Workflow, state WorkflowSession) error {
	seen := make(map[string]bool, len(workflow.Lanes))
	for _, lane := range workflow.Lanes {
		paneID := state.Assignments.Pane(lane)
		if paneID == "" || seen[paneID] {
			return fmt.Errorf("ii: workflow lane target is missing or duplicated: %s", lane)
		}
		seen[paneID] = true
		pane, err := c.runtime.WorkflowPaneSnapshot(paneID)
		if err != nil || pane.ID != paneID || pane.Session != state.Session || pane.Dead {
			return fmt.Errorf("ii: workflow target pane is no longer valid: %s", paneID)
		}
	}
	return nil
}
