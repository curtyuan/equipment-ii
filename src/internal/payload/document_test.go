package payload

import "testing"

func TestParseLegacyDocumentMetadata(t *testing.T) {
	document := ParseDocument("# description: transfer\r\n# stage: receive\r\necho ok\r\n")
	if document.Class != ClassLegacy || document.Description != "transfer" ||
		document.Body != "# --- receive ---\necho ok" {
		t.Fatalf("unexpected document: %#v", document)
	}
}

func TestParseDocumentDetectsWorkflowCandidate(t *testing.T) {
	document := ParseDocument("# description: flow\n# flow: 1\n# stage: zsh | run\n")
	if document.Class != ClassWorkflowCandidate || document.Description != "flow" {
		t.Fatalf("unexpected document: %#v", document)
	}
}
