package cli

import (
	"strings"
	"testing"

	"github.com/curtyuan/equipment-ii/src/internal/payload"
)

func TestPrintPayloadReportColorsAndBoldsVariableNames(t *testing.T) {
	report := []payload.ReportEntry{
		{Name: "rhost", Value: "192.0.2.1", Source: payload.SourceSession},
		{Name: "missing", Value: "$missing", Source: payload.SourceMissing},
	}
	var output strings.Builder
	printPayloadReport(report, true, &output)
	want := "\x1b[1;32mrhost\x1b[0m used from ii: 192.0.2.1\n" +
		"\x1b[1;31mmissing\x1b[0m unresolved: kept as $missing\n"
	if output.String() != want {
		t.Fatalf("report = %q, want %q", output.String(), want)
	}
}

func TestPrintPayloadReportRemainsPlainWhenColorIsDisabled(t *testing.T) {
	report := []payload.ReportEntry{{Name: "rhost", Value: "value", Source: payload.SourceSession}}
	var output strings.Builder
	printPayloadReport(report, false, &output)
	if output.String() != "rhost used from ii: value\n" {
		t.Fatalf("report = %q", output.String())
	}
}
