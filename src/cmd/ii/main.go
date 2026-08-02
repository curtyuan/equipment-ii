package main

import (
	"os"

	clipboardadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/clipboard"
	filesystemadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/filesystem"
	tmuxadapter "github.com/curtyuan/equipment-ii/src/internal/adapter/tmux"
	"github.com/curtyuan/equipment-ii/src/internal/cli"
)

func main() {
	payloadRoot := os.Getenv("II_PAYLOAD_DIR")
	if payloadRoot == "" {
		configRoot, err := os.UserConfigDir()
		if err == nil {
			payloadRoot = configRoot + "/ii/payloads"
		}
	}
	sessionEnvironment := tmuxadapter.NewSessionEnvironment()
	clipboard := clipboardadapter.New(sessionEnvironment)
	app := cli.New(cli.ColorEnabled(os.Stdout, os.Getenv), cli.Dependencies{
		Environment:     sessionEnvironment,
		Stdin:           os.Stdin,
		Panes:           sessionEnvironment,
		Clipboard:       clipboard,
		PayloadStore:    filesystemadapter.NewPayloadStore(payloadRoot),
		WorkflowRuntime: sessionEnvironment,
	})
	os.Exit(app.Run(os.Args[1:], os.Stdout, os.Stderr))
}
