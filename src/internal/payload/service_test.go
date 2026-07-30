package payload

import "testing"

func TestServiceRendersLegacyAndWorkflow(t *testing.T) {
	store := catalogStore{
		paths: []string{"legacy", "flow"},
		text: map[string]string{
			"legacy": "# description: test\n# stage: run\necho $rhost\n",
			"flow":   "# flow: 1\n# stage: zsh | first\n# lane: kali-main\n# advance: confirm\necho $rhost\n",
		},
	}
	service := NewService(NewCatalog(store), MapResolver{
		"rhost": {Value: "192.0.2.20", Source: SourceSession},
	})
	legacy, err := service.Render("legacy")
	if err != nil || legacy.Text != "# --- run ---\necho 192.0.2.20" {
		t.Fatalf("legacy = %#v, %v", legacy, err)
	}
	flow, err := service.Render("flow")
	if err != nil || flow.Text != "# --- lane1: kali-main | zsh | first ---\necho 192.0.2.20" ||
		len(flow.Stages) != 1 {
		t.Fatalf("flow = %#v, %v", flow, err)
	}
}
