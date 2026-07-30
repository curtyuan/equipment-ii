package payload

import "testing"

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
