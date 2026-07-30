package payload

import (
	"fmt"
	"sort"
	"strings"
)

type PayloadResult struct {
	Path        string
	Description string
	Class       Class
	Text        string
	Report      []ReportEntry
	Workflow    *Workflow
	Stages      []RenderResult
}

type Service struct {
	catalog  *Catalog
	resolver Resolver
}

func NewService(catalog *Catalog, resolver Resolver) *Service {
	return &Service{catalog: catalog, resolver: resolver}
}

func (s *Service) Render(path string) (PayloadResult, error) {
	document, err := s.catalog.Read(path)
	if err != nil {
		return PayloadResult{}, err
	}
	result := PayloadResult{
		Path: path, Description: document.Description, Class: document.Class,
	}
	if document.Class == ClassLegacy {
		rendered := Render(document.Body, s.resolver)
		result.Text = rendered.Text
		result.Report = rendered.Report
		return result, nil
	}
	workflow, err := ParseWorkflow(path, document.Raw)
	if err != nil {
		return PayloadResult{}, err
	}
	laneOrdinal := make(map[string]int)
	for index, lane := range workflow.Lanes {
		laneOrdinal[lane] = index + 1
	}
	report := make(map[string]ReportEntry)
	var display strings.Builder
	for index, stage := range workflow.Stages {
		rendered := Render(stage.Body, s.resolver)
		result.Stages = append(result.Stages, rendered)
		if index > 0 {
			display.WriteString("\n\n")
		}
		fmt.Fprintf(&display, "# --- lane%d: %s | %s | %s ---\n",
			laneOrdinal[stage.Lane], stage.Lane, stage.Shell, stage.Title)
		display.WriteString(rendered.Text)
		for _, entry := range rendered.Report {
			current, ok := report[entry.Name]
			if !ok || current.Source == SourceMissing {
				report[entry.Name] = entry
			}
		}
	}
	result.Text = display.String()
	result.Report = sortedReport(report)
	result.Workflow = &workflow
	return result, nil
}

func sortedReport(report map[string]ReportEntry) []ReportEntry {
	names := make([]string, 0, len(report))
	for name := range report {
		names = append(names, name)
	}
	sort.Strings(names)
	entries := make([]ReportEntry, 0, len(names))
	for _, name := range names {
		entries = append(entries, report[name])
	}
	return entries
}
