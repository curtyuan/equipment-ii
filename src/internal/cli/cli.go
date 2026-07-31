package cli

import (
	"io"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/port"
	"github.com/curtyuan/equipment-ii/src/internal/variables"
	wwwdomain "github.com/curtyuan/equipment-ii/src/internal/www"
)

const (
	RouteGo     = "go"
	RouteLegacy = "legacy"
)

type CLI struct {
	version           string
	color             bool
	lister            *variables.Lister
	output            *variables.Outputter
	shell             port.ShellOperations
	mutator           *variables.Mutator
	loader            *variables.Loader
	state             port.ShellState
	detector          port.AddressDetector
	autoDetect        bool
	detectInterface   string
	stdin             io.Reader
	environment       port.Environment
	allPanes          *variables.AllPaneLoader
	getter            *variables.Getter
	interactive       *variables.Interactive
	payloads          *payload.Catalog
	payloadSelector   port.PayloadSelector
	clipboard         port.Clipboard
	clipboardBackend  port.ClipboardBackend
	payloadOutput     *payload.Output
	inputRenderer     *payload.InputRenderer
	tmuxIntegration   port.TmuxIntegration
	panes             port.PaneController
	web               *wwwdomain.Service
	webSelector       wwwdomain.Selector
	workflowRuntime   payload.WorkflowRuntime
	workflowPopup     payload.WorkflowPopupLauncher
	workflowSelector  payload.WorkflowLaneSelector
	workflowConfirmer payload.WorkflowStageConfirmer
}

type Dependencies struct {
	Environment     port.Environment
	AtomicWriter    port.AtomicFileWriter
	Shell           port.ShellOperations
	ExportCase      string
	ShellState      port.ShellState
	AddressDetector port.AddressDetector
	AutoDetect      string
	DetectInterface string
	Stdin           io.Reader
	Panes           port.PaneController
	Selector        port.Selector
	Clipboard       port.ClipboardBackend
	PayloadStore    port.PayloadStore
	PayloadWriter   port.PayloadWriter
	TmuxIntegration port.TmuxIntegration
	WebStore        wwwdomain.Store
	WebSelector     wwwdomain.Selector
	WebRoot         string
	WorkflowRuntime payload.WorkflowRuntime
	WorkflowPopup   payload.WorkflowPopupLauncher
}

func New(version string, color bool, dependencies Dependencies) *CLI {
	mutator := variables.NewMutator(dependencies.Environment, dependencies.Shell, dependencies.ExportCase)
	loader := variables.NewLoader(dependencies.Environment, mutator)
	enabled := true
	switch strings.ToLower(dependencies.AutoDetect) {
	case "0", "false", "no", "off", "disabled":
		enabled = false
	}
	if dependencies.DetectInterface == "" {
		dependencies.DetectInterface = "tun0"
	}
	return &CLI{
		version:          version,
		color:            color,
		lister:           variables.NewLister(dependencies.Environment),
		output:           variables.NewOutputter(dependencies.Environment, dependencies.AtomicWriter),
		shell:            dependencies.Shell,
		mutator:          mutator,
		loader:           loader,
		state:            dependencies.ShellState,
		detector:         dependencies.AddressDetector,
		autoDetect:       enabled,
		detectInterface:  dependencies.DetectInterface,
		stdin:            dependencies.Stdin,
		environment:      dependencies.Environment,
		allPanes:         variables.NewAllPaneLoader(dependencies.Panes, dependencies.Selector, loader),
		getter:           variables.NewGetter(dependencies.Environment, dependencies.Selector, dependencies.Clipboard),
		interactive:      variables.NewInteractive(dependencies.Environment, dependencies.Selector, dependencies.Clipboard, mutator),
		payloads:         payload.NewCatalog(dependencies.PayloadStore),
		payloadSelector:  dependencies.Selector,
		clipboard:        dependencies.Clipboard,
		clipboardBackend: dependencies.Clipboard,
		payloadOutput:    payload.NewOutput(dependencies.PayloadWriter),
		inputRenderer:    payload.NewInputRenderer(dependencies.ShellState, dependencies.Environment),
		tmuxIntegration:  dependencies.TmuxIntegration,
		panes:            dependencies.Panes,
		web:              wwwdomain.NewService(dependencies.WebStore, dependencies.WebRoot),
		webSelector:      dependencies.WebSelector,
		workflowRuntime:  dependencies.WorkflowRuntime,
		workflowPopup:    dependencies.WorkflowPopup,
	}
}

func (c *CLI) Run(args []string, stdout, stderr io.Writer) int {
	if status, handled := c.runInternal(args, stdout, stderr); handled {
		return status
	}
	return c.runPublic(args, stdout, stderr)
}
