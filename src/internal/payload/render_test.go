package payload

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fixtureAssignments(raw string, source Source) MapResolver {
	values := MapResolver{}
	if raw == "-" {
		return values
	}
	for _, assignment := range strings.Split(raw, ";") {
		name, value, ok := strings.Cut(assignment, "=")
		if ok && value != "" {
			values[name] = Value{Value: value, Source: source}
		}
	}
	return values
}

func TestSharedRenderFixture(t *testing.T) {
	path := filepath.Join("..", "..", "..", "test", "fixtures", "payload-render.tsv")
	file, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) != 6 {
			t.Fatalf("invalid shared fixture line: %q", line)
		}
		name, input, shellRaw, tmuxRaw, ordinaryWant, comboWant := fields[0], fields[1], fields[2], fields[3], fields[4], fields[5]
		t.Run(name, func(t *testing.T) {
			tmuxValues := fixtureAssignments(tmuxRaw, SourceSession)
			ordinary := MapResolver{}
			for key, value := range tmuxValues {
				ordinary[key] = value
			}
			for key, value := range fixtureAssignments(shellRaw, SourceShell) {
				ordinary[key] = value
			}
			if got := Render(input, ordinary).Text; got != ordinaryWant {
				t.Fatalf("ordinary Render() = %q, want %q", got, ordinaryWant)
			}
			if got := Render(input, tmuxValues).Text; got != comboWant {
				t.Fatalf("combo Render() = %q, want %q", got, comboWant)
			}
		})
	}
	if err := scanner.Err(); err != nil {
		t.Fatal(err)
	}
}

func TestRenderSupportedTokensAndPrecedence(t *testing.T) {
	resolver := MapResolver{
		"rhost": {Value: "192.0.2.20", Source: SourceShell},
		"file":  {Value: `C:\share\tool.exe`, Source: SourceSession},
	}
	input := `$rhost ${rhost} %rhost% ${file:t} $missing $RHOST $env:Path`
	got := Render(input, resolver)
	want := `192.0.2.20 192.0.2.20 192.0.2.20 tool.exe $missing $RHOST $env:Path`
	if got.Text != want {
		t.Fatalf("Render text = %q, want %q", got.Text, want)
	}
	if len(got.Report) != 3 ||
		got.Report[0].Name != "file" || got.Report[0].Source != SourceSession ||
		got.Report[1].Name != "missing" || got.Report[1].Source != SourceMissing ||
		got.Report[2].Name != "rhost" || got.Report[2].Source != SourceShell {
		t.Fatalf("unexpected report: %#v", got.Report)
	}
}

func TestRenderLeavesMalformedTokensUnchanged(t *testing.T) {
	input := `$ ${broken $Mixed ${name:-x} %missing $global:value`
	if got := Render(input, MapResolver{}).Text; got != input {
		t.Fatalf("Render = %q, want unchanged %q", got, input)
	}
}

func TestReferencedNames(t *testing.T) {
	got := ReferencedNames(`$rhost ${file:t} %rhost% $env:Path $UPPER`)
	if len(got) != 2 || got[0] != "file" || got[1] != "rhost" {
		t.Fatalf("ReferencedNames = %#v", got)
	}
}
