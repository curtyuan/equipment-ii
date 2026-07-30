package payload

import (
	"strings"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type payloadSelectorFake struct {
	items     []port.PayloadSelectionItem
	category  string
	query     string
	selection port.PayloadSelection
}

func (f *payloadSelectorFake) SelectPayload(items []port.PayloadSelectionItem, category, query string) (port.PayloadSelection, error) {
	f.items, f.category, f.query = items, category, query
	return f.selection, nil
}

func TestSelectorBuildsPreviewAndRendersSelection(t *testing.T) {
	store := catalogStore{
		paths: []string{"shell/linux/test"},
		text: map[string]string{
			"shell/linux/test": "# description: demo\necho $rhost\n",
		},
	}
	catalog := NewCatalog(store)
	adapter := &payloadSelectorFake{
		selection: port.PayloadSelection{Action: "y", Path: "shell/linux/test"},
	}
	selector := NewSelector(catalog, NewService(catalog, MapResolver{
		"rhost": {Value: "192.0.2.20", Source: SourceSession},
	}), adapter)
	result, err := selector.Select("linux", "test query")
	if err != nil {
		t.Fatal(err)
	}
	if adapter.category != "linux" || adapter.query != "test query" ||
		len(adapter.items) != 1 || !strings.Contains(adapter.items[0].Preview, "demo") {
		t.Fatalf("unexpected selector input: %#v", adapter)
	}
	if result.Action != "y" || result.Payload.Text != "echo 192.0.2.20" {
		t.Fatalf("unexpected result: %#v", result)
	}
}
