package payload

import "testing"

func TestLaneAssignmentsSwapOccupiedPane(t *testing.T) {
	assignments := NewLaneAssignments()
	assignments.Assign("kali-main", "%1", "initial")
	assignments.Assign("remote-main", "%2", "initial")
	assignments.Assign("kali-main", "%2", "manual")

	if got := assignments.Pane("kali-main"); got != "%2" {
		t.Fatalf("kali-main pane = %q", got)
	}
	if got := assignments.Pane("remote-main"); got != "%1" {
		t.Fatalf("remote-main pane = %q", got)
	}
	if !assignments.Complete([]string{"kali-main", "remote-main"}) {
		t.Fatal("swapped assignments are not complete")
	}
}

func TestLaneAssignmentsToggleAndMemory(t *testing.T) {
	assignments := NewLaneAssignments()
	assignments.Toggle("remote-main", "%2")
	assignments.Toggle("kali-main", "%1")
	if got := assignments.Memory(); got != "kali-main=%1\nremote-main=%2" {
		t.Fatalf("Memory = %q", got)
	}
	assignments.Toggle("kali-main", "%1")
	if assignments.Complete([]string{"kali-main", "remote-main"}) {
		t.Fatal("unassigned lane reported complete")
	}
}

func TestParseLaneMemoryRejectsMalformedAndDuplicateBindings(t *testing.T) {
	got := ParseLaneMemory("kali-main=%1\nbad=%2\nremote-main=no\nremote-copy=%1\nremote-main=%3")
	if len(got) != 2 || got["kali-main"] != "%1" || got["remote-main"] != "%3" {
		t.Fatalf("ParseLaneMemory = %#v", got)
	}
}

func TestDetectInitialAssignmentsUsesMemoryOriginAndRemoteCommand(t *testing.T) {
	panes := []WorkflowPane{
		{ID: "%1", Command: "zsh"},
		{ID: "%2", Command: "pwsh"},
		{ID: "%3", Command: "zsh"},
	}
	assignments := DetectInitialAssignments(
		[]string{"kali-main", "remote-main", "kali-extra"},
		panes, "%1", "kali-extra=%3\nremote-main=%99",
	)
	if assignments.Pane("kali-extra") != "%3" ||
		assignments.Pane("kali-main") != "%1" ||
		assignments.Pane("remote-main") != "%2" {
		t.Fatalf("bindings = %#v", assignments.Bindings())
	}
}

func TestMergeLaneMemoryPreservesUnrelatedValidBindings(t *testing.T) {
	got := MergeLaneMemory(
		"kali-old=%1\nremote-old=%2",
		map[string]string{"kali-main": "%2"},
	)
	if got != "kali-main=%2\nkali-old=%1" {
		t.Fatalf("MergeLaneMemory = %q", got)
	}
}

func TestDetectInitialAssignmentsSkipsDeadPanes(t *testing.T) {
	panes := []WorkflowPane{
		{ID: "%1", Command: "zsh", Dead: true},
		{ID: "%2", Command: "ssh", Dead: true},
		{ID: "%3", Command: "zsh"},
	}
	assignments := DetectInitialAssignments(
		[]string{"kali-main", "remote-main"}, panes, "%1", "remote-main=%2",
	)
	if assignments.Pane("kali-main") != "%3" || assignments.Pane("remote-main") != "" {
		t.Fatalf("bindings = %#v", assignments.Bindings())
	}
}
