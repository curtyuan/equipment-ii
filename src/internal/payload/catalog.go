package payload

import (
	"errors"
	"sort"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

var ErrNoPayloads = errors.New("ii: no payloads found")

type Catalog struct {
	store port.PayloadStore
}

func NewCatalog(store port.PayloadStore) *Catalog {
	return &Catalog{store: store}
}

func (c *Catalog) List(category string) ([]string, error) {
	paths, err := c.store.List()
	if err != nil {
		return nil, err
	}
	filtered := make([]string, 0, len(paths))
	for _, path := range paths {
		if categoryMatches(path, category) {
			filtered = append(filtered, path)
		}
	}
	if len(filtered) == 0 {
		return nil, ErrNoPayloads
	}
	return filtered, nil
}

func (c *Catalog) Read(path string) (Document, error) {
	text, err := c.store.Read(path)
	if err != nil {
		return Document{}, err
	}
	return ParseDocument(text), nil
}

func (c *Catalog) ReferencedNames() ([]string, error) {
	paths, err := c.store.List()
	if err != nil {
		return nil, err
	}
	seen := make(map[string]bool)
	for _, path := range paths {
		text, err := c.store.Read(path)
		if err != nil {
			return nil, err
		}
		for _, name := range ReferencedNames(text) {
			seen[name] = true
		}
	}
	names := make([]string, 0, len(seen))
	for name := range seen {
		names = append(names, name)
	}
	sort.Strings(names)
	return names, nil
}

func categoryMatches(path, category string) bool {
	category = strings.ToLower(category)
	lower := strings.ToLower(path)
	switch category {
	case "", "all":
		return true
	case "shell", "script", "sqli", "xss":
		return strings.HasPrefix(lower, category+"/")
	case "linux", "windows":
		return strings.HasPrefix(lower, category+"/") ||
			strings.Contains(lower, "/"+category+"/") ||
			strings.HasSuffix(lower, "/"+category)
	default:
		return strings.Contains(lower, category)
	}
}
