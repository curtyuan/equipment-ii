package cli

import (
	"io"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type CLI struct {
	color             bool
	stdin             io.Reader
	environment       port.Environment
	payloads          *payload.Catalog
	clipboard         port.Clipboard
	inputRenderer     *payload.InputRenderer
	panes             port.PaneController
	workflowRuntime   payload.WorkflowRuntime
	workflowSelector  payload.WorkflowLaneSelector
	workflowConfirmer payload.WorkflowStageConfirmer
}

type Dependencies struct {
	Environment     port.Environment
	Stdin           io.Reader
	Panes           port.PaneController
	Clipboard       port.Clipboard
	PayloadStore    port.PayloadStore
	WorkflowRuntime payload.WorkflowRuntime
}

func New(color bool, dependencies Dependencies) *CLI {
	return &CLI{
		color:           color,
		stdin:           dependencies.Stdin,
		environment:     dependencies.Environment,
		payloads:        payload.NewCatalog(dependencies.PayloadStore),
		clipboard:       dependencies.Clipboard,
		inputRenderer:   payload.NewInputRenderer(dependencies.Environment),
		panes:           dependencies.Panes,
		workflowRuntime: dependencies.WorkflowRuntime,
	}
}

func (c *CLI) Run(args []string, stdout, stderr io.Writer) int {
	return c.runInternal(args, stdout, stderr)
}
