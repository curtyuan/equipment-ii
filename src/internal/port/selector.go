package port

import "errors"

var ErrSelectionCanceled = errors.New("selection canceled")

type SelectionItem struct {
	ID          string
	Display     string
	Preselected bool
}

type InteractiveSelection struct {
	Action string
	ID     string
}

type PayloadSelectionItem struct {
	Path    string
	Preview string
}

type PayloadSelection struct {
	Action string
	Path   string
}

type PayloadSelector interface {
	SelectPayload(items []PayloadSelectionItem, category, query string) (PayloadSelection, error)
}

type InteractiveSelector interface {
	SelectVariable(items []SelectionItem) (InteractiveSelection, error)
	Input(prompt, initial string) (string, error)
}

type MultiSelector interface {
	Select(items []SelectionItem) ([]string, error)
}

type SingleSelector interface {
	Available() error
	SelectOne(items []SelectionItem) (string, error)
}

type Selector interface {
	MultiSelector
	SingleSelector
	InteractiveSelector
	PayloadSelector
}
