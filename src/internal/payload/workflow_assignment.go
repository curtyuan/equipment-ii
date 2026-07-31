package payload

import (
	"sort"
	"strings"
)

type LaneAssignments struct {
	lanePane map[string]string
	paneLane map[string]string
	source   map[string]string
}

func NewLaneAssignments() *LaneAssignments {
	return &LaneAssignments{
		lanePane: make(map[string]string),
		paneLane: make(map[string]string),
		source:   make(map[string]string),
	}
}

func (a *LaneAssignments) Assign(lane, pane, source string) {
	oldPane := a.lanePane[lane]
	otherLane := a.paneLane[pane]
	if oldPane == pane {
		a.source[lane] = source
		return
	}
	if otherLane != "" && otherLane != lane {
		if oldPane != "" {
			a.lanePane[otherLane] = oldPane
			a.paneLane[oldPane] = otherLane
			a.source[otherLane] = "manual"
		} else {
			delete(a.lanePane, otherLane)
			delete(a.source, otherLane)
		}
	} else if oldPane != "" {
		delete(a.paneLane, oldPane)
	}
	a.lanePane[lane] = pane
	a.paneLane[pane] = lane
	a.source[lane] = source
}

func (a *LaneAssignments) Toggle(lane, pane string) {
	if a.lanePane[lane] == pane {
		delete(a.lanePane, lane)
		delete(a.source, lane)
		delete(a.paneLane, pane)
		return
	}
	a.Assign(lane, pane, "manual")
}

func (a *LaneAssignments) Pane(lane string) string {
	return a.lanePane[lane]
}

func (a *LaneAssignments) Complete(lanes []string) bool {
	seen := make(map[string]bool, len(lanes))
	for _, lane := range lanes {
		pane := a.lanePane[lane]
		if pane == "" || seen[pane] {
			return false
		}
		seen[pane] = true
	}
	return true
}

func (a *LaneAssignments) Memory() string {
	lanes := make([]string, 0, len(a.lanePane))
	for lane := range a.lanePane {
		lanes = append(lanes, lane)
	}
	sort.Strings(lanes)
	var lines []string
	for _, lane := range lanes {
		lines = append(lines, lane+"="+a.lanePane[lane])
	}
	return strings.Join(lines, "\n")
}
