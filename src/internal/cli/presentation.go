package cli

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
	"github.com/curtyuan/equipment-ii/src/internal/terminal"
)

func ColorEnabled(output io.Writer, getenv func(string) string) bool {
	if getenv("NO_COLOR") != "" || getenv("TERM") == "dumb" {
		return false
	}
	switch strings.ToLower(getenv("II_COLOR")) {
	case "always":
		return true
	case "never":
		return false
	}
	file, ok := output.(*os.File)
	if !ok {
		return false
	}
	info, err := file.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

func Color(code int, text string, enabled bool) string {
	if !enabled {
		return text
	}
	return fmt.Sprintf("\x1b[%dm%s\x1b[0m", code, text)
}

func printPayloadReport(report []payload.ReportEntry, color bool, output io.Writer) {
	for _, entry := range report {
		switch entry.Source {
		case payload.SourceSession:
			fmt.Fprintf(output, "%s used from ii: %s\n", entry.Name, entry.Value)
		case payload.SourceMissing:
			fmt.Fprintln(output, Color(31, fmt.Sprintf("%s unresolved: kept as %s", entry.Name, entry.Value), color))
		}
	}
}

func (c *CLI) copySelectedPayload(result payload.PayloadResult, stdout, stderr io.Writer) int {
	for index, stage := range result.Stages {
		if index > 0 {
			fmt.Fprintf(stdout, "\nStage %d/%d ready for copy\nPress y to copy, n/Esc to abort. ", index+1, len(result.Stages))
			answer, _ := terminal.ReadKey(c.stdin)
			fmt.Fprintln(stdout, answer)
			if !strings.EqualFold(strings.TrimSpace(answer), "y") {
				fmt.Fprintln(stdout, "workflow copy cancelled")
				return 1
			}
		}
		if err := c.clipboard.Copy(stage.Text); err != nil {
			fmt.Fprintf(stderr, "ii: clipboard copy failed for workflow stage %d\n", index+1)
			return 1
		}
		fmt.Fprintf(stdout, "stage %d/%d copied successfully\n", index+1, len(result.Stages))
	}
	return 0
}
