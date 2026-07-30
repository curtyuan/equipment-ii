package variables

import (
	"errors"
	"testing"
)

type fakeWriter struct {
	path string
	data []byte
	err  error
}

func (w *fakeWriter) WriteAtomic(path string, data []byte) (string, error) {
	w.path = path
	w.data = append([]byte(nil), data...)
	return "/absolute/" + path, w.err
}

func TestOutputMatchesLegacyZshQuotingAndOrder(t *testing.T) {
	writer := &fakeWriter{}
	outputter := NewOutputter(fakeEnvironment{lines: []string{
		"ii_plain=value",
		"ii_space=two words",
		"ii_quote=a'b",
		"ii_lines=line1\nline2",
		"ii_empty=",
		"unrelated=ignored",
	}}, writer)

	count, path, _, err := outputter.Write("vars.env")
	if err != nil {
		t.Fatal(err)
	}
	want := "plain='value'\nspace='two words'\nquote='a'\\''b'\nlines='line1\nline2'\n"
	if count != 4 || path != "/absolute/vars.env" || string(writer.data) != want {
		t.Fatalf("count=%d path=%q data=%q", count, path, writer.data)
	}
}

func TestOutputDoesNotReplaceFileWhenSessionReadFails(t *testing.T) {
	want := errors.New("tmux failed")
	writer := &fakeWriter{}
	_, _, _, got := NewOutputter(fakeEnvironment{err: want}, writer).Write(".env")
	if !errors.Is(got, want) {
		t.Fatalf("error=%v, want %v", got, want)
	}
	if writer.path != "" {
		t.Fatal("writer called after session read failure")
	}
}
