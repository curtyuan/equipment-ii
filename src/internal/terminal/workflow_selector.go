package terminal

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

type WorkflowSelector struct {
	input   io.Reader
	output  io.Writer
	readKey func(io.Reader) (string, error)
}

func NewWorkflowSelector(input io.Reader, output io.Writer) *WorkflowSelector {
	return &WorkflowSelector{input: input, output: output, readKey: ReadKey}
}

func (s *WorkflowSelector) SelectWorkflowLanes(lanes []string, state *payload.WorkflowSession) error {
	windows := workflowWindows(state.Panes)
	if len(windows) == 0 {
		return fmt.Errorf("ii: no usable panes in session")
	}
	windowIndex := windowIndexForPane(windows, state.Panes, state.OriginPane)
	activeLane := 0
	cursor := ""
	for {
		visible := workflowWindowPanes(state.Panes, windows[windowIndex])
		if len(visible) == 0 {
			return fmt.Errorf("ii: no usable panes in window: %s", windows[windowIndex])
		}
		if !containsPane(visible, cursor) {
			cursor = visible[0].ID
		}
		s.draw(lanes, state, windows[windowIndex], visible, cursor, activeLane)
		key, err := s.readKey(s.input)
		if err != nil {
			return err
		}
		switch key {
		case "q", "\x1b":
			_, _ = fmt.Fprintln(s.output, "\nworkflow assignment aborted")
			return ErrCancelled
		case "\r", "\n":
			if state.Assignments.Complete(lanes) {
				_, _ = fmt.Fprintln(s.output)
				return nil
			}
		case " ":
			state.Assignments.Toggle(lanes[activeLane], cursor)
		case "1", "2", "3":
			index := int(key[0] - '1')
			if index < len(lanes) {
				activeLane = index
				state.Assignments.Assign(lanes[activeLane], cursor, "manual")
			}
		case "j", "l":
			cursor = moveWorkflowCursor(visible, cursor, 1)
		case "k", "h":
			cursor = moveWorkflowCursor(visible, cursor, -1)
		case "]":
			windowIndex = (windowIndex + 1) % len(windows)
		case "[":
			windowIndex = (windowIndex + len(windows) - 1) % len(windows)
		}
	}
}

func (s *WorkflowSelector) draw(
	lanes []string, state *payload.WorkflowSession, window string,
	panes []payload.WorkflowPane, cursor string, activeLane int,
) {
	var screen strings.Builder
	screen.WriteString("\x1b[2J\x1b[H")
	fmt.Fprintf(&screen, "Workflow lane assignment · window %s\n", window)
	screen.WriteString("h/j/k/l move · [/] window · Space toggle active · 1/2/3 assign · Enter confirm · Esc/q abort\n")
	fmt.Fprintf(&screen, "Active: lane%d %s\n\n", activeLane+1, lanes[activeLane])
	screen.WriteString(RenderWorkflowPaneMap(panes, state.Assignments, lanes, cursor, 100, 22))
	screen.WriteByte('\n')
	for index, lane := range lanes {
		pane := state.Assignments.Pane(lane)
		if pane == "" {
			pane = "[unassigned]"
		}
		source := state.Assignments.Source(lane)
		if source == "" {
			source = "manual"
		}
		fmt.Fprintf(&screen, "lane%d %s -> %s (%s)\n", index+1, lane, pane, source)
	}
	_, _ = io.WriteString(s.output, screen.String())
}

func RenderWorkflowPaneMap(
	panes []payload.WorkflowPane, assignments *payload.LaneAssignments,
	lanes []string, cursor string, width, height int,
) string {
	if width < 50 {
		width = 50
	}
	if width > 120 {
		width = 120
	}
	if height < 9 {
		height = 9
	}
	canvas := make([][]rune, height)
	for row := range canvas {
		canvas[row] = make([]rune, width)
		for column := range canvas[row] {
			canvas[row][column] = ' '
		}
	}
	maxX, maxY := 1, 1
	for _, pane := range panes {
		if pane.Left+pane.Width > maxX {
			maxX = pane.Left + pane.Width
		}
		if pane.Top+pane.Height > maxY {
			maxY = pane.Top + pane.Height
		}
	}
	ordinal := make(map[string]int, len(lanes))
	for index, lane := range lanes {
		ordinal[lane] = index + 1
	}
	for _, pane := range panes {
		x := pane.Left * (width - 2) / maxX
		y := 1 + pane.Top*(height-3)/maxY
		paneWidth := pane.Width * (width - 2) / maxX
		paneHeight := pane.Height * (height - 3) / maxY
		if paneWidth < 12 {
			paneWidth = 12
		}
		if paneHeight < 3 {
			paneHeight = 3
		}
		if x+paneWidth >= width {
			paneWidth = width - x - 1
		}
		if y+paneHeight >= height {
			paneHeight = height - y - 1
		}
		lane := assignments.Lane(pane.ID)
		marker := " "
		if pane.ID == cursor {
			marker = ">"
		}
		label := marker + " unassigned"
		if lane != "" {
			label = fmt.Sprintf("%s [%d/lane%d] %s · %s",
				marker, ordinal[lane], ordinal[lane], lane, assignments.Source(lane))
		}
		putWorkflowText(canvas, x, y-1, label)
		drawWorkflowBox(canvas, x, y, paneWidth, paneHeight)
		putWorkflowText(canvas, x+2, y+1, pane.ID+"  "+pane.Command)
	}
	lines := make([]string, 0, height)
	for _, row := range canvas {
		lines = append(lines, strings.TrimRight(string(row), " "))
	}
	return strings.TrimRight(strings.Join(lines, "\n"), "\n") + "\n"
}

func workflowWindows(panes []payload.WorkflowPane) []string {
	seen := make(map[string]bool)
	var windows []string
	for _, pane := range panes {
		if pane.Dead || pane.Window == "" || seen[pane.Window] {
			continue
		}
		seen[pane.Window] = true
		windows = append(windows, pane.Window)
	}
	return windows
}

func workflowWindowPanes(panes []payload.WorkflowPane, window string) []payload.WorkflowPane {
	var visible []payload.WorkflowPane
	for _, pane := range panes {
		if !pane.Dead && pane.Window == window {
			visible = append(visible, pane)
		}
	}
	sort.SliceStable(visible, func(i, j int) bool {
		if visible[i].Top != visible[j].Top {
			return visible[i].Top < visible[j].Top
		}
		if visible[i].Left != visible[j].Left {
			return visible[i].Left < visible[j].Left
		}
		return visible[i].ID < visible[j].ID
	})
	return visible
}

func windowIndexForPane(windows []string, panes []payload.WorkflowPane, paneID string) int {
	for _, pane := range panes {
		if pane.ID == paneID {
			for index, window := range windows {
				if pane.Window == window {
					return index
				}
			}
		}
	}
	return 0
}

func containsPane(panes []payload.WorkflowPane, id string) bool {
	for _, pane := range panes {
		if pane.ID == id {
			return true
		}
	}
	return false
}

func moveWorkflowCursor(panes []payload.WorkflowPane, current string, delta int) string {
	for index, pane := range panes {
		if pane.ID == current {
			return panes[(index+delta+len(panes))%len(panes)].ID
		}
	}
	return panes[0].ID
}

func putWorkflowText(canvas [][]rune, x, y int, value string) {
	if y < 0 || y >= len(canvas) {
		return
	}
	for _, character := range []rune(value) {
		if x >= 0 && x < len(canvas[y]) {
			canvas[y][x] = character
		}
		x++
		if x >= len(canvas[y]) {
			return
		}
	}
}

func drawWorkflowBox(canvas [][]rune, x, y, width, height int) {
	if width < 2 || height < 2 {
		return
	}
	for column := 0; column <= width; column++ {
		putWorkflowText(canvas, x+column, y, "-")
		putWorkflowText(canvas, x+column, y+height, "-")
	}
	for row := 0; row <= height; row++ {
		putWorkflowText(canvas, x, y+row, "|")
		putWorkflowText(canvas, x+width, y+row, "|")
	}
	for _, point := range [][2]int{{x, y}, {x + width, y}, {x, y + height}, {x + width, y + height}} {
		putWorkflowText(canvas, point[0], point[1], "+")
	}
}
