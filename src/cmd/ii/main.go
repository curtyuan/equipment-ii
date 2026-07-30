package main

import (
	"os"

	clipboardadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/clipboard"
	filesystemadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/filesystem"
	fzfadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/fzf"
	networkadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/network"
	shellopsadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/shellops"
	shellstateadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/shellstate"
	tmuxadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/tmux"
	"github.com/curtyuan/equipment-ii/src/internal/cli"
)

var version = "dev"

func main() {
	shellState, err := shellstateadapter.NewFile(os.Getenv("II_SHELL_STATE_FILE"))
	if err != nil {
		_, _ = os.Stderr.WriteString("ii: invalid parent-shell state channel\n")
		os.Exit(1)
	}
	payloadRoot := os.Getenv("II_PAYLOAD_DIR")
	if payloadRoot == "" {
		configRoot, err := os.UserConfigDir()
		if err == nil {
			payloadRoot = configRoot + "/ii/payloads"
		}
	}
	sessionEnvironment := tmuxadapter.NewSessionEnvironment()
	selector := fzfadapter.NewMulti()
	clipboard := clipboardadapter.New(sessionEnvironment)
	app := cli.New(version, cli.ColorEnabled(os.Stdout, os.Getenv), cli.Dependencies{
		Environment:     sessionEnvironment,
		AtomicWriter:    filesystemadapter.NewAtomicFileWriter(),
		Shell:           shellopsadapter.NewFile(os.Getenv("II_SHELL_OPS_FILE"), os.Getenv("II_SHELL_EXEC_FILE")),
		ExportCase:      os.Getenv("II_EXPORT_CASE"),
		ShellState:      shellState,
		AddressDetector: networkadapter.NewInterfaceAddress(),
		AutoDetect:      os.Getenv("II_AUTO_DETECT_LHOST"),
		DetectInterface: os.Getenv("II_AUTO_DETECT_LHOST_INTERFACE"),
		Stdin:           os.Stdin,
		Panes:           sessionEnvironment,
		Selector:        selector,
		Clipboard:       clipboard,
		PayloadStore:    filesystemadapter.NewPayloadStore(payloadRoot),
		PayloadWriter:   filesystemadapter.NewPayloadWriter(),
		TmuxIntegration: sessionEnvironment,
	})
	os.Exit(app.Run(os.Args[1:], os.Stdout, os.Stderr))
}
