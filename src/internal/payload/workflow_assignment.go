package payload

import (
	"regexp"
	"sort"
	"strings"
)

var workflowPaneID = regexp.MustCompile(`^%[0-9]+$`)

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

func (a *LaneAssignments) Lane(pane string) string {
	return a.paneLane[pane]
}

func (a *LaneAssignments) Source(lane string) string {
	return a.source[lane]
}

func (a *LaneAssignments) Bindings() map[string]string {
	result := make(map[string]string, len(a.lanePane))
	for lane, pane := range a.lanePane {
		result[lane] = pane
	}
	return result
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

func ParseLaneMemory(value string) map[string]string {
	result := make(map[string]string)
	used := make(map[string]bool)
	for _, line := range strings.Split(value, "\n") {
		lane, pane, ok := strings.Cut(line, "=")
		if !ok || !laneName.MatchString(lane) || !workflowPaneID.MatchString(pane) ||
			used[pane] {
			continue
		}
		result[lane] = pane
		used[pane] = true
	}
	return result
}

func DetectInitialAssignments(lanes []string, panes []WorkflowPane, origin string, memory string) *LaneAssignments {
	assignments := NewLaneAssignments()
	available := make(map[string]WorkflowPane, len(panes))
	for _, pane := range panes {
		if pane.ID != "" && !pane.Dead {
			available[pane.ID] = pane
		}
	}
	remembered := ParseLaneMemory(memory)
	for _, lane := range lanes {
		pane := remembered[lane]
		if _, ok := available[pane]; pane != "" && ok && assignments.paneLane[pane] == "" {
			assignments.Assign(lane, pane, "remembered")
		}
	}
	for _, lane := range lanes {
		if assignments.Pane(lane) != "" {
			continue
		}
		role := strings.SplitN(lane, "-", 2)[0]
		if role == "kali" && origin != "" && assignments.paneLane[origin] == "" {
			if _, ok := available[origin]; ok {
				assignments.Assign(lane, origin, "detected")
				continue
			}
		}
		if role == "remote" {
			for _, pane := range panes {
				if pane.ID == origin || assignments.paneLane[pane.ID] != "" ||
					!remoteCommand(pane.Command) {
					continue
				}
				if _, ok := available[pane.ID]; !ok {
					continue
				}
				assignments.Assign(lane, pane.ID, "detected")
				break
			}
		}
		if assignments.Pane(lane) != "" {
			continue
		}
		for _, pane := range panes {
			if _, ok := available[pane.ID]; ok && assignments.paneLane[pane.ID] == "" {
				assignments.Assign(lane, pane.ID, "detected")
				break
			}
		}
	}
	return assignments
}

func MergeLaneMemory(existing string, current map[string]string) string {
	merged := ParseLaneMemory(existing)
	for lane, pane := range current {
		for other, otherPane := range merged {
			if other != lane && otherPane == pane {
				delete(merged, other)
			}
		}
		merged[lane] = pane
	}
	assignments := NewLaneAssignments()
	for lane, pane := range merged {
		assignments.Assign(lane, pane, "remembered")
	}
	return assignments.Memory()
}

func remoteCommand(command string) bool {
	switch command {
	case "nc", "ncat", "netcat", "socat", "ssh", "python", "python3",
		"pwsh", "powershell", "cmd.exe":
		return true
	}
	return false
}
