package payload

import (
	"reflect"
	"testing"
)

type catalogStore struct {
	paths []string
	text  map[string]string
}

func (s catalogStore) List() ([]string, error) { return s.paths, nil }
func (s catalogStore) Read(path string) (string, error) {
	return s.text[path], nil
}

func TestCatalogCategories(t *testing.T) {
	catalog := NewCatalog(catalogStore{paths: []string{
		"shell/linux/a", "shell/windows/b", "script/linux/c", "xss/d",
	}})
	tests := []struct {
		category string
		want     []string
	}{
		{"shell", []string{"shell/linux/a", "shell/windows/b"}},
		{"linux", []string{"shell/linux/a", "script/linux/c"}},
		{"xss", []string{"xss/d"}},
	}
	for _, test := range tests {
		got, err := catalog.List(test.category)
		if err != nil || !reflect.DeepEqual(got, test.want) {
			t.Fatalf("List(%q) = %#v, %v; want %#v", test.category, got, err, test.want)
		}
	}
}

func TestCatalogReferencedNames(t *testing.T) {
	catalog := NewCatalog(catalogStore{
		paths: []string{"one", "two"},
		text: map[string]string{
			"one": "$rhost ${file:t}",
			"two": "%rhost% $domain",
		},
	})
	got, err := catalog.ReferencedNames()
	want := []string{"domain", "file", "rhost"}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Fatalf("ReferencedNames = %#v, %v; want %#v", got, err, want)
	}
}
