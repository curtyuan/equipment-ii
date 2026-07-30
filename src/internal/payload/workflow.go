package payload

import (
	"fmt"
	"regexp"
	"strings"
)

var laneName = regexp.MustCompile(`^(kali|remote)-[[:alnum:]][[:alnum:]_-]*$`)

type WorkflowStage struct {
	Shell   string
	Title   string
	Lane    string
	Advance string
	Body    string
	Line    int
}

type Workflow struct {
	Version     string
	Description string
	Notes       []string
	Lanes       []string
	Stages      []WorkflowStage
}

type WorkflowError struct {
	Path    string
	Line    int
	Message string
}

func (e *WorkflowError) Error() string {
	return fmt.Sprintf("ii: workflow parse error: %s:%d: %s", e.Path, e.Line, e.Message)
}

func ParseWorkflow(path, text string) (Workflow, error) {
	lines := strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	workflow := Workflow{}
	flowSeen := false
	stageOpen := false
	stageHasCommand := false
	firstStageSeen := false
	var current WorkflowStage
	var body []string
	seenLanes := make(map[string]bool)

	fail := func(line int, message string) (Workflow, error) {
		return Workflow{}, &WorkflowError{Path: path, Line: line, Message: message}
	}
	closeStage := func() {
		current.Body = strings.Join(body, "\n")
		workflow.Stages = append(workflow.Stages, current)
	}

	for index := 0; index < len(lines); {
		lineNumber := index + 1
		line := lines[index]
		trimmed := strings.TrimSpace(line)
		if !stageOpen {
			if lineNumber == 1 && strings.HasPrefix(trimmed, "# description:") {
				workflow.Description = strings.TrimSpace(strings.TrimPrefix(trimmed, "# description:"))
				index++
				continue
			}
			if strings.HasPrefix(trimmed, "# flow:") {
				if flowSeen {
					return fail(lineNumber, "duplicate flow marker")
				}
				version := strings.TrimSpace(strings.TrimPrefix(trimmed, "# flow:"))
				if version != "1" {
					if version == "" {
						version = "[empty]"
					}
					return fail(lineNumber, "unsupported flow version: "+version)
				}
				flowSeen = true
				workflow.Version = "1"
				index++
				continue
			}
			if strings.HasPrefix(trimmed, "# note:") {
				if !flowSeen {
					return fail(lineNumber, "note must follow the flow marker")
				}
				note := strings.TrimSpace(strings.TrimPrefix(trimmed, "# note:"))
				if note == "" {
					return fail(lineNumber, "note must not be empty")
				}
				workflow.Notes = append(workflow.Notes, note)
				index++
				continue
			}
			if strings.HasPrefix(trimmed, "# stage:") {
				if !flowSeen {
					return fail(lineNumber, "stage appears before the flow marker")
				}
				spec := strings.TrimSpace(strings.TrimPrefix(trimmed, "# stage:"))
				parts := strings.Split(spec, "|")
				if len(parts) != 2 || strings.TrimSpace(parts[0]) == "" || strings.TrimSpace(parts[1]) == "" {
					return fail(lineNumber, "stage requires SHELL | TITLE")
				}
				if index+2 >= len(lines) {
					return fail(lineNumber, "stage is missing lane and advance directives")
				}
				laneLine := strings.TrimSpace(lines[index+1])
				if !strings.HasPrefix(laneLine, "# lane:") {
					return fail(lineNumber+1, "lane must immediately follow stage")
				}
				lane := strings.TrimSpace(strings.TrimPrefix(laneLine, "# lane:"))
				if !laneName.MatchString(lane) {
					if lane == "" {
						lane = "[empty]"
					}
					return fail(lineNumber+1, "invalid lane name: "+lane)
				}
				advanceLine := strings.TrimSpace(lines[index+2])
				if !strings.HasPrefix(advanceLine, "# advance:") {
					return fail(lineNumber+2, "advance must immediately follow lane")
				}
				advance := strings.TrimSpace(strings.TrimPrefix(advanceLine, "# advance:"))
				if advance != "confirm" {
					if advance == "" {
						advance = "[empty]"
					}
					return fail(lineNumber+2, "unsupported advance mode: "+advance)
				}
				if !seenLanes[lane] {
					if len(workflow.Lanes) == 3 {
						return fail(lineNumber+1, "more than three distinct lanes")
					}
					seenLanes[lane] = true
					workflow.Lanes = append(workflow.Lanes, lane)
				}
				current = WorkflowStage{
					Shell: strings.TrimSpace(parts[0]), Title: strings.TrimSpace(parts[1]),
					Lane: lane, Advance: advance, Line: lineNumber,
				}
				body = nil
				stageOpen = true
				stageHasCommand = false
				firstStageSeen = true
				index += 3
				continue
			}
			if trimmed == "" {
				index++
				continue
			}
			if strings.HasPrefix(trimmed, "#") {
				if flowSeen {
					return fail(lineNumber, "unknown workflow metadata or comment before first stage")
				}
				index++
				continue
			}
			return fail(lineNumber, "executable text appears before the first stage")
		}

		if strings.HasPrefix(trimmed, "# stage:") {
			if !stageHasCommand {
				return fail(current.Line, "stage body is empty")
			}
			closeStage()
			stageOpen = false
			continue
		}
		for _, prefix := range []string{"# flow:", "# lane:", "# advance:", "# note:", "# description:"} {
			if strings.HasPrefix(trimmed, prefix) {
				return fail(lineNumber, "workflow metadata is misplaced inside a stage body")
			}
		}
		body = append(body, line)
		if trimmed != "" && !strings.HasPrefix(trimmed, "#") {
			stageHasCommand = true
		}
		index++
	}

	if !flowSeen {
		return fail(1, "missing flow marker")
	}
	if !firstStageSeen || !stageOpen {
		return fail(max(1, len(lines)), "workflow has no stages")
	}
	if !stageHasCommand {
		return fail(current.Line, "stage body is empty")
	}
	closeStage()
	return workflow, nil
}
