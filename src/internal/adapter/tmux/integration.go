package tmux

import (
	"strconv"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

func (s *SessionEnvironment) IntegrationStatus(helper string, schema int) (port.TmuxIntegrationStatus, error) {
	server, err := s.output("display-message", "-p", "#{socket_path}")
	if err != nil {
		return port.TmuxIntegrationStatus{}, err
	}
	options, err := s.output("show-options", "-s", "command-alias")
	if err != nil {
		return port.TmuxIntegrationStatus{}, err
	}
	marker, _ := s.output("show-option", "-gqv", "@ii_integration_marker")
	binding, _ := s.output("list-keys", "-T", "prefix", ":")

	aliases := make(map[int]string)
	iiIndex := -1
	for _, line := range strings.Split(options, "\n") {
		option, value, ok := strings.Cut(line, " ")
		if !ok || !strings.HasPrefix(option, "command-alias[") {
			continue
		}
		rawIndex := strings.TrimSuffix(strings.TrimPrefix(option, "command-alias["), "]")
		index, parseErr := strconv.Atoi(rawIndex)
		if parseErr != nil {
			continue
		}
		value = strings.Trim(value, `"`)
		aliases[index] = value
		if strings.HasPrefix(value, "ii=") && iiIndex == -1 {
			iiIndex = index
		}
	}
	markerIndex := markerField(marker, "index")
	expectedMarker := "version=" + strconv.Itoa(schema) + " index=" + markerIndex + " helper=" + helper
	state := "missing"
	if iiIndex >= 0 {
		if strconv.Itoa(iiIndex) == markerIndex &&
			marker == expectedMarker &&
			strings.HasPrefix(aliases[iiIndex], "ii=display-popup") &&
			strings.Contains(aliases[iiIndex], helper) {
			state = "installed"
		} else if strconv.Itoa(iiIndex) == markerIndex &&
			strings.HasPrefix(aliases[iiIndex], "ii=display-popup") &&
			(strings.Contains(aliases[iiIndex], "ii-tmux-input") ||
				strings.Contains(aliases[iiIndex], "ii-tmux-pice")) {
			state = "stale"
		} else {
			state = "conflict"
		}
	} else if markerIndex != "" {
		state = "stale"
	}
	prefixLegacy := strings.Contains(binding, `if-shell -F "##{==:%1,ii pice}"`) &&
		strings.Contains(binding, "display-popup") &&
		strings.Contains(binding, "ii-tmux-pice")
	return port.TmuxIntegrationStatus{
		Server: server, AliasState: state, PrefixLegacy: prefixLegacy,
	}, nil
}

func markerField(marker, name string) string {
	for _, field := range strings.Fields(marker) {
		if value, ok := strings.CutPrefix(field, name+"="); ok {
			return value
		}
	}
	return ""
}
