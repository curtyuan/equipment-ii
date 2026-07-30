package tmux

import (
	"fmt"
	"sort"
	"strconv"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

const (
	integrationMarker = "@ii_integration_marker"
	integrationNotice = "@ii_integration_conflict_notice"
)

func (s *SessionEnvironment) EnsureIntegration(helper, version string, schema int, force bool) (string, error) {
	if s.getenv("TMUX") == "" {
		return "", nil
	}
	if _, err := s.lookPath("tmux"); err != nil {
		return "", nil
	}

	aliases, iiIndex, err := s.integrationAliases()
	if err != nil {
		return "", err
	}
	marker, _ := s.output("show-option", "-gqv", integrationMarker)
	markerIndex := markerField(marker, "index")
	command := aliasCommand(helper, version)
	expectedMarker := fmt.Sprintf("version=%d index=%s helper=%s", schema, markerIndex, helper)

	if markerIndex != "" && marker == expectedMarker {
		index, parseErr := strconv.Atoi(markerIndex)
		if parseErr == nil && aliases[index] == command {
			return "", s.finishIntegrationInstall()
		}
	}

	if iiIndex >= 0 {
		owned := strconv.Itoa(iiIndex) == markerIndex && ownedAlias(aliases[iiIndex])
		if owned || force {
			return "", s.installIntegration(iiIndex, command, helper, schema)
		}
		expectedNotice := fmt.Sprintf("version=%d helper=%s", schema, helper)
		notice, _ := s.output("show-option", "-gqv", integrationNotice)
		if notice == expectedNotice {
			return "", nil
		}
		if err := s.run("set-option", "-gq", integrationNotice, expectedNotice); err != nil {
			return "", err
		}
		return "ii: tmux command alias 'ii' is already defined; ii popup alias was not installed\n" +
			"ii: set II_TMUX_INTEGRATION_FORCE=1 to replace it, or II_TMUX_INTEGRATION=0 to silence this notice\n", nil
	}

	return "", s.installIntegration(freeAliasIndex(aliases), command, helper, schema)
}

func (s *SessionEnvironment) integrationAliases() (map[int]string, int, error) {
	options, err := s.output("show-options", "-s", "command-alias")
	if err != nil {
		return nil, -1, err
	}
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
	return aliases, iiIndex, nil
}

func (s *SessionEnvironment) installIntegration(index int, command, helper string, schema int) error {
	if err := s.run("set-option", "-s", fmt.Sprintf("command-alias[%d]", index), command); err != nil {
		return err
	}
	marker := fmt.Sprintf("version=%d index=%d helper=%s", schema, index, helper)
	if err := s.run("set-option", "-gq", integrationMarker, marker); err != nil {
		return err
	}
	_ = s.run("set-option", "-gu", integrationNotice)
	return s.finishIntegrationInstall()
}

func (s *SessionEnvironment) finishIntegrationInstall() error {
	binding, _ := s.output("list-keys", "-T", "prefix", ":")
	if legacyBindingOwned(binding) {
		if err := s.run("bind-key", "-T", "prefix", ":", "command-prompt"); err != nil {
			return err
		}
	}
	_ = s.run("set-option", "-gu", "@ii_colon_binding")
	_ = s.run("set-option", "-gu", "@ii_colon_binding_saved")
	sessions, _ := s.output("list-sessions", "-F", "#{session_id}")
	for _, session := range strings.Fields(sessions) {
		_ = s.run("set-option", "-qu", "-t", session, "@ii_dispatch_enabled")
	}
	return nil
}

func aliasCommand(helper, version string) string {
	return "ii=display-popup -EE -T 'ii pie " + version +
		"' -w 90% -h 90% -d '#{pane_current_path}' " + shellQuote(helper) + " __tmux_popup execute"
}

func shellQuote(value string) string {
	if value != "" && !strings.ContainsAny(value, " \t\r\n'\"\\$`;&|()<>*?[]{}!") {
		return value
	}
	return "'" + strings.ReplaceAll(value, "'", `'\''`) + "'"
}

func ownedAlias(value string) bool {
	return strings.HasPrefix(value, "ii=display-popup") &&
		(strings.Contains(value, "ii-tmux-input") ||
			strings.Contains(value, "ii-tmux-pice") ||
			strings.Contains(value, "__tmux_popup"))
}

func freeAliasIndex(aliases map[int]string) int {
	indexes := make([]int, 0, len(aliases))
	for index := range aliases {
		indexes = append(indexes, index)
	}
	sort.Ints(indexes)
	next := 100
	for _, index := range indexes {
		if index == next {
			next++
		}
	}
	return next
}

func legacyBindingOwned(binding string) bool {
	return strings.Contains(binding, `if-shell -F "##{==:%1,ii pice}"`) &&
		strings.Contains(binding, "display-popup") &&
		strings.Contains(binding, "ii-tmux-pice")
}

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
				strings.Contains(aliases[iiIndex], "ii-tmux-pice") ||
				strings.Contains(aliases[iiIndex], "__tmux_popup")) {
			state = "stale"
		} else {
			state = "conflict"
		}
	} else if markerIndex != "" {
		state = "stale"
	}
	prefixLegacy := legacyBindingOwned(binding)
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
