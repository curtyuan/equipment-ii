package variables

import (
	"errors"
	"reflect"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type fakeEnvironment struct {
	lines []string
	err   error
}

func (f fakeEnvironment) Read() (port.EnvironmentRead, error) {
	return port.EnvironmentRead{Lines: f.lines}, f.err
}

func TestListMatchesLegacyOrderingFilteringAndEmptyPolicy(t *testing.T) {
	lister := NewLister(fakeEnvironment{lines: []string{
		"other=value",
		"ii_rhost=192.0.2.20",
		"ii_lhost=192.0.2.10",
		"ii_empty=",
		"ii_bad-name=ignored",
		"ii_note=a=b",
	}})

	got, _, err := lister.List("HOST")
	if err != nil {
		t.Fatal(err)
	}
	want := []Entry{
		{Name: "lhost", Value: "192.0.2.10"},
		{Name: "rhost", Value: "192.0.2.20"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("List() = %#v, want %#v", got, want)
	}
}

func TestListPreservesValueAfterFirstEquals(t *testing.T) {
	lister := NewLister(fakeEnvironment{lines: []string{"ii_note=a=b"}})
	got, _, err := lister.List("")
	if err != nil {
		t.Fatal(err)
	}
	want := []Entry{{Name: "note", Value: "a=b"}}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("List() = %#v, want %#v", got, want)
	}
}

func TestListReturnsEnvironmentError(t *testing.T) {
	want := errors.New("failed")
	_, _, got := NewLister(fakeEnvironment{err: want}).List("")
	if !errors.Is(got, want) {
		t.Fatalf("error = %v, want %v", got, want)
	}
}
