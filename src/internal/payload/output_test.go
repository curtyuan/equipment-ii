package payload

import (
	"path/filepath"
	"testing"
)

func TestOutputPath(t *testing.T) {
	directory := t.TempDir()
	tests := map[string]string{
		"":              "/www/p/att.txt",
		"loot.txt":      "/www/loot.txt",
		"./loot.txt":    "./loot.txt",
		"tmp/loot.txt":  "tmp/loot.txt",
		directory:       filepath.Join(directory, "att.txt"),
		directory + "/": filepath.Join(directory, "att.txt"),
	}
	for input, want := range tests {
		if got := OutputPath(input); got != want {
			t.Fatalf("OutputPath(%q) = %q, want %q", input, got, want)
		}
	}
}
