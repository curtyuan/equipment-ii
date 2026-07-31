package payload

import (
	"fmt"
)

type WorkflowStageView struct {
	Index      int
	Count      int
	Lane       string
	Ordinal    int
	Pane       WorkflowPane
	Shell      string
	Title      string
	Text       string
	Report     []ReportEntry
	Notes      []string
	AfterFirst bool
}

type WorkflowStageConfirmer interface {
	ConfirmWorkflowStage(stage WorkflowStageView) (bool, error)
}

type WorkflowStageClipboard interface {
	Copy(text string) error
}

type WorkflowStageReporter interface {
	WorkflowClipboardFailed(index int, err error)
	WorkflowStageSent(index, count int, pane string)
}

type WorkflowRunner struct {
	coordinator *WorkflowCoordinator
	runtime     WorkflowRuntime
	confirmer   WorkflowStageConfirmer
	clipboard   WorkflowStageClipboard
}

func NewWorkflowRunner(
	coordinator *WorkflowCoordinator, runtime WorkflowRuntime,
	confirmer WorkflowStageConfirmer, clipboard WorkflowStageClipboard,
) *WorkflowRunner {
	return &WorkflowRunner{
		coordinator: coordinator, runtime: runtime, confirmer: confirmer, clipboard: clipboard,
	}
}

func (r *WorkflowRunner) Run(
	workflow Workflow, rendered []RenderResult, state WorkflowSession, copyStages bool,
) error {
	if len(rendered) != len(workflow.Stages) {
		return fmt.Errorf("ii: workflow rendered stage count does not match parsed stages")
	}
	ordinals := make(map[string]int, len(workflow.Lanes))
	for index, lane := range workflow.Lanes {
		ordinals[lane] = index + 1
	}
	for index, stage := range workflow.Stages {
		paneID := state.Assignments.Pane(stage.Lane)
		pane, err := r.runtime.WorkflowPaneSnapshot(paneID)
		if err != nil {
			return fmt.Errorf("ii: workflow target pane is no longer valid: %s", paneID)
		}
		view := WorkflowStageView{
			Index: index + 1, Count: len(workflow.Stages), Lane: stage.Lane,
			Ordinal: ordinals[stage.Lane], Pane: pane, Shell: stage.Shell,
			Title: stage.Title, Text: rendered[index].Text, Report: rendered[index].Report,
			Notes: workflow.Notes, AfterFirst: index > 0,
		}
		confirmed, err := r.confirmer.ConfirmWorkflowStage(view)
		if err != nil {
			return err
		}
		if !confirmed {
			return fmt.Errorf("ii: workflow execution aborted before stage %d", index+1)
		}
		if err = r.coordinator.Revalidate(workflow, state); err != nil {
			return fmt.Errorf(
				"ii: workflow aborted; stage %d and later stages were not sent: %w",
				index+1, err,
			)
		}
		if copyStages && r.clipboard != nil {
			if copyErr := r.clipboard.Copy(rendered[index].Text); copyErr != nil {
				if reporter, ok := r.confirmer.(WorkflowStageReporter); ok {
					reporter.WorkflowClipboardFailed(index+1, copyErr)
				}
			}
		}
		if err = r.runtime.SendWorkflowStage(state.Session, paneID, rendered[index].Text); err != nil {
			return fmt.Errorf(
				"ii: workflow aborted while sending stage %d; later stages were not sent: %w",
				index+1, err,
			)
		}
		if reporter, ok := r.confirmer.(WorkflowStageReporter); ok {
			reporter.WorkflowStageSent(index+1, len(workflow.Stages), paneID)
		}
	}
	return nil
}
