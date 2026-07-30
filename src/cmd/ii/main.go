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
	app := cli.New(
		version,
		cli.ColorEnabled(os.Stdout, os.Getenv),
		sessionEnvironment,
		filesystemadapter.NewAtomicFileWriter(),
		shellopsadapter.NewFile(os.Getenv("II_SHELL_OPS_FILE"), os.Getenv("II_SHELL_EXEC_FILE")),
		os.Getenv("II_EXPORT_CASE"),
		shellState,
		networkadapter.NewInterfaceAddress(),
		os.Getenv("II_AUTO_DETECT_LHOST"),
		os.Getenv("II_AUTO_DETECT_LHOST_INTERFACE"),
		os.Stdin,
		sessionEnvironment,
		fzfadapter.NewMulti(),
		clipboardadapter.New(sessionEnvironment),
		filesystemadapter.NewPayloadStore(payloadRoot),
		filesystemadapter.NewPayloadWriter(),
		sessionEnvironment,
	)
	os.Exit(app.Run(os.Args[1:], os.Stdout, os.Stderr))
}
