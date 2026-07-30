package terminal

import (
	"errors"
	"strings"
	"testing"
)

func TestReadPayloadInputStream(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
		err   error
	}{
		{name: "single line", input: "echo ok\n", want: "echo ok"},
		{name: "multiline eof", input: "one\ntwo\n", want: "one\ntwo"},
		{name: "finish line", input: "one\ntwo\n:w\nignored\n", want: "one\ntwo"},
		{name: "cancel", input: "one\n:q\n", err: ErrCancelled},
		{name: "force cancel", input: ":q!\n", err: ErrCancelled},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := ReadPayloadInput(strings.NewReader(test.input), &strings.Builder{})
			if !errors.Is(err, test.err) || got != test.want {
				t.Fatalf("got=%q err=%v want=%q err=%v", got, err, test.want, test.err)
			}
		})
	}
}

func TestStripFinishLine(t *testing.T) {
	if got := stripFinishLine("one\ntwo\n:w"); got != "one\ntwo" {
		t.Fatalf("got %q", got)
	}
}
