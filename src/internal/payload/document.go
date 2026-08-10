package payload

import "strings"

type Class string

const (
	ClassLegacy            Class = "legacy"
	ClassWorkflowCandidate Class = "workflow-candidate"
)

type Document struct {
	Class       Class
	Description string
	Body        string
	Raw         string
}

func ParseDocument(text string) Document {
	text = strings.ReplaceAll(text, "\r\n", "\n")
	lines := strings.Split(text, "\n")
	description := ""
	if len(lines) > 0 && strings.HasPrefix(lines[0], "# description:") {
		description = strings.TrimSpace(strings.TrimPrefix(lines[0], "# description:"))
		lines = lines[1:]
	}
	class := ClassLegacy
	for _, line := range lines {
		if strings.HasPrefix(strings.TrimSpace(line), "# flow:") {
			class = ClassWorkflowCandidate
			break
		}
	}
	if class == ClassLegacy {
		for index, line := range lines {
			if strings.HasPrefix(line, "# stage:") {
				label := strings.TrimSpace(strings.TrimPrefix(line, "# stage:"))
				if label == "" {
					label = "stage"
				}
				lines[index] = "# --- " + label + " ---"
			}
		}
	}
	body := strings.Join(lines, "\n")
	if class == ClassLegacy {
		body = strings.TrimRight(body, "\n")
	}
	return Document{
		Class:       class,
		Description: description,
		Body:        body,
		Raw:         text,
	}
}
