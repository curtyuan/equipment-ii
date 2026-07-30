package variables

import (
	"fmt"
	"sort"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type PaneLoadResult struct {
	Lines                               []string
	Loaded, Dispatched, Skipped, Failed int
}

type AllPaneLoader struct {
	panes    port.PaneController
	selector port.MultiSelector
	loader   *Loader
}

func NewAllPaneLoader(panes port.PaneController, selector port.MultiSelector, loader *Loader) *AllPaneLoader {
	return &AllPaneLoader{panes: panes, selector: selector, loader: loader}
}

func (a *AllPaneLoader) Run(currentPane string) (PaneLoadResult, error) {
	session, window, err := a.panes.CurrentSessionWindow()
	if err != nil {
		return PaneLoadResult{}, err
	}
	panes, err := a.panes.List(window)
	if err != nil {
		return PaneLoadResult{}, err
	}
	sort.SliceStable(panes, func(i, j int) bool {
		left := !panes[i].Dead && !panes[i].InMode && panes[i].Command == "zsh"
		right := !panes[j].Dead && !panes[j].InMode && panes[j].Command == "zsh"
		return left && !right
	})
	items := make([]port.SelectionItem, 0, len(panes))
	initial := make(map[string]port.Pane, len(panes))
	for _, pane := range panes {
		status := "active program"
		switch {
		case pane.Dead:
			status = "dead pane"
		case pane.InMode:
			status = "tmux mode"
		case pane.Command == "zsh":
			status = "likely ready"
		case pane.Command == "ssh":
			status = "remote session"
		}
		current := ""
		if pane.ID == currentPane {
			current = "current"
		}
		display := fmt.Sprintf("%-5s %-8s %-14s %-18s %s", pane.ID, current, pane.Command, status, pane.Path)
		items = append(items, port.SelectionItem{ID: pane.ID, Display: display, Preselected: status == "likely ready"})
		initial[pane.ID] = pane
	}
	selected, err := a.selector.Select(items)
	if err != nil {
		return PaneLoadResult{}, err
	}
	chosen := make(map[string]bool, len(selected))
	for _, id := range selected {
		chosen[id] = true
	}
	result := PaneLoadResult{Lines: []string{"Load summary", ""}}
	for _, pane := range panes {
		if !chosen[pane.ID] {
			result.Lines = append(result.Lines, fmt.Sprintf("%-5s skipped by user", pane.ID))
			result.Skipped++
			continue
		}
		current, snapshotErr := a.panes.Snapshot(pane.ID)
		if snapshotErr != nil {
			result.Lines = append(result.Lines, fmt.Sprintf("%-5s failed: pane disappeared", pane.ID))
			result.Failed++
			continue
		}
		original := initial[pane.ID]
		if current.Session != session || current.Window != window ||
			current.Dead != original.Dead || current.InMode != original.InMode ||
			current.Command != original.Command {
			result.Lines = append(result.Lines, fmt.Sprintf("%-5s failed: pane state changed (%s)", pane.ID, current.Command))
			result.Failed++
			continue
		}
		if current.Dead {
			result.Lines = append(result.Lines, fmt.Sprintf("%-5s failed: dead pane", pane.ID))
			result.Failed++
			continue
		}
		if pane.ID == currentPane {
			if _, _, loadErr := a.loader.Load(); loadErr != nil {
				result.Lines = append(result.Lines, fmt.Sprintf("%-5s failed: local load failed", pane.ID))
				result.Failed++
			} else {
				result.Lines = append(result.Lines, fmt.Sprintf("%-5s loaded locally", pane.ID))
				result.Loaded++
			}
		} else if sendErr := a.panes.SendLoad(pane.ID); sendErr != nil {
			result.Lines = append(result.Lines, fmt.Sprintf("%-5s failed: dispatch failed", pane.ID))
			result.Failed++
		} else {
			result.Lines = append(result.Lines, fmt.Sprintf("%-5s dispatched", pane.ID))
			result.Dispatched++
		}
	}
	result.Lines = append(result.Lines, "", fmt.Sprintf("%d loaded locally, %d dispatched, %d skipped, %d failed",
		result.Loaded, result.Dispatched, result.Skipped, result.Failed))
	return result, nil
}
