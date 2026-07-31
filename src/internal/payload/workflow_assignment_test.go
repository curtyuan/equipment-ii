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
