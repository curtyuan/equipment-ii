package cli

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"
)

func (c *CLI) runClipboard(args []string, stdout, stderr io.Writer) int {
	for _, arg := range args[1:] {
		if arg == "-h" || arg == "--help" || arg == "help" {
			fmt.Fprint(stdout, clipboardHelp)
			return 0
		}
	}
	action := "backend"
	if len(args) > 1 {
		action = args[1]
	}
	switch action {
	case "backend":
		if len(args) > 3 {
			fmt.Fprintln(stderr, "ii: usage: ii clip backend [auto|BACKEND]")
			return 2
		}
		if len(args) == 2 {
			backend, err := c.clipboardBackend.EffectiveBackend()
			if err != nil {
				fmt.Fprintln(stderr, err)
				return 1
			}
			fmt.Fprintf(stdout, "context: %s\nbackend: %s\n", c.clipboardBackend.Context(), backend)
			return 0
		}
		if args[2] == "auto" {
			for _, name := range []string{"II_CLIP_BACKEND", "II_CLIP_CMD"} {
				if err := c.environment.Unset(name); err != nil {
					fmt.Fprintln(stderr, err)
					return 1
				}
				if err := c.shell.Unset(name); err != nil {
					fmt.Fprintln(stderr, err)
					return 1
				}
			}
			fmt.Fprintln(stdout, "clipboard backend: auto")
			return 0
		}
		if err := c.environment.Set("II_CLIP_BACKEND", args[2]); err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		if err := c.environment.Unset("II_CLIP_CMD"); err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		if err := c.shell.Export("II_CLIP_BACKEND", args[2]); err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		if err := c.shell.Unset("II_CLIP_CMD"); err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		fmt.Fprintf(stdout, "clipboard backend: %s\n", args[2])
		return 0
	case "doctor":
		return c.runClipboardDoctor(stdout, stderr)
	default:
		fmt.Fprintf(stderr, "ii: unknown clip command: %s\n", action)
		return 2
	}
}

func (c *CLI) runClipboardDoctor(stdout, stderr io.Writer) int {
	backend, err := c.clipboardBackend.EffectiveBackend()
	if err != nil {
		backend = ""
	}
	fmt.Fprintf(stdout, "context: %s\ntmux: %s\ndisplay: %s\nssh_connection: %s\nssh_client: %s\nssh_tty: %s\nconfigured_backend: %s\nconfigured_cmd: %s\neffective_backend: %s\n\n",
		c.clipboardBackend.Context(), os.Getenv("TMUX"), os.Getenv("DISPLAY"),
		os.Getenv("SSH_CONNECTION"), os.Getenv("SSH_CLIENT"), os.Getenv("SSH_TTY"),
		os.Getenv("II_CLIP_BACKEND"), os.Getenv("II_CLIP_CMD"), backend)
	token := fmt.Sprintf("ii-clip-test-%d", time.Now().Unix())
	if err = c.clipboard.Copy(token); err != nil {
		fmt.Fprintln(stderr, "ii: test copy failed")
	} else {
		fmt.Fprintf(stdout, "copied test token: %s\n", token)
	}
	reader := bufio.NewReader(c.stdin)
	fmt.Fprint(stdout, "Did this reach the desired clipboard? [y/N] ")
	answer, _ := reader.ReadString('\n')
	if strings.EqualFold(strings.TrimSpace(answer), "y") {
		return 0
	}
	suggested := "tmux"
	if c.clipboardBackend.Context() == "ssh" {
		suggested = "osc52"
	} else if os.Getenv("DISPLAY") != "" {
		if _, lookErr := exec.LookPath("xclip"); lookErr == nil {
			suggested = "xclip-both"
		}
	}
	fmt.Fprintf(stdout, "Use %s for this tmux session? [y/N] ", suggested)
	answer, _ = reader.ReadString('\n')
	if !strings.EqualFold(strings.TrimSpace(answer), "y") {
		return 1
	}
	return c.runClipboard([]string{"clip", "backend", suggested}, stdout, stderr)
}
