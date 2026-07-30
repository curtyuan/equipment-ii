package payload

import (
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

type SelectionResult struct {
	Action  string
	Payload PayloadResult
}

type Selector struct {
	catalog  *Catalog
	service  *Service
	selector port.PayloadSelector
}

func NewSelector(catalog *Catalog, service *Service, selector port.PayloadSelector) *Selector {
	return &Selector{catalog: catalog, service: service, selector: selector}
}

func (s *Selector) Select(category, query string) (SelectionResult, error) {
	paths, err := s.catalog.List(category)
	if err != nil {
		return SelectionResult{}, err
	}
	items := make([]port.PayloadSelectionItem, 0, len(paths))
	for _, path := range paths {
		document, err := s.catalog.Read(path)
		if err != nil {
			return SelectionResult{}, err
		}
		var preview strings.Builder
		if document.Description != "" {
			preview.WriteString("[description]\n")
			preview.WriteString(document.Description)
			preview.WriteString("\n--------------------------------------------------------------------------------\n")
		}
		preview.WriteString(document.Body)
		items = append(items, port.PayloadSelectionItem{Path: path, Preview: preview.String()})
	}
	selection, err := s.selector.SelectPayload(items, category, query)
	if err != nil {
		return SelectionResult{}, err
	}
	if selection.Action == "q" {
		return SelectionResult{}, port.ErrSelectionCanceled
	}
	rendered, err := s.service.Render(selection.Path)
	if err != nil {
		return SelectionResult{}, err
	}
	return SelectionResult{Action: selection.Action, Payload: rendered}, nil
}
