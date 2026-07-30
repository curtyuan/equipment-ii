package cli

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
)

const tmuxIntegrationSchema = 2

func (c *CLI) runTmux(args []string, stdout, stderr io.Writer) int {
	for _, arg := range args[1:] {
		if arg == "-h" || arg == "--help" {
			fmt.Fprint(stdout, tmuxHelp)
			return 0
		}
	}
	if len(args) > 2 || (len(args) == 2 && args[1] != "status") {
		fmt.Fprintln(stderr, "ii: usage: ii tmux status")
		return 2
	}
	pluginDir := os.Getenv("II_PLUGIN_DIR")
	if pluginDir == "" {
		pluginDir = os.Getenv("II_GO_ROOT")
	}
	helper := filepath.Join(pluginDir, "script", "ii-tmux-input")
	status, err := c.tmuxIntegration.IntegrationStatus(helper, tmuxIntegrationSchema)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	configured := "default"
	if os.Getenv("II_TMUX_INTEGRATION") == "0" {
		configured = "disabled"
	} else if os.Getenv("II_TMUX_INTEGRATION_FORCE") == "1" {
		configured = "force"
	}
	fmt.Fprintf(stdout, "server: %s\nconfigured: %s\ncommand alias: %s\ncommand: ii\nhelper: %s\n",
		status.Server, configured, status.AliasState, helper)
	if status.PrefixLegacy {
		fmt.Fprintln(stdout, "Prefix+: legacy ii adapter")
	} else {
		fmt.Fprintln(stdout, "Prefix+: native or user-defined")
	}
	return 0
}
