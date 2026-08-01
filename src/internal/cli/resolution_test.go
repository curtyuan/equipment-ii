package cli

import "testing"

func TestResolveCommand(t *testing.T) {
	tests := []struct {
		name string
		args []string
		want string
	}{
		{"empty", nil, "help"},
		{"version", []string{"version"}, "version"},
		{"top help", []string{"help"}, "help"},
		{"version help", []string{"help", "version"}, "help"},
		{"set command", []string{"set", "rhost", "value"}, "set"},
		{"compact set", []string{"s:rhost=value"}, "set"},
		{"set help", []string{"help", "set"}, "set-help"},
		{"list", []string{"ls", "host"}, "list"},
		{"list help", []string{"help", "list"}, "list"},
		{"v list", []string{"v", "host"}, "list"},
		{"v output", []string{"v", "--out"}, "output"},
		{"vo output", []string{"vo"}, "output"},
		{"voc output", []string{"voc"}, "output"},
		{"v help", []string{"v", "--help"}, "variable-help"},
		{"output help", []string{"help", "v", "--out"}, "output"},
		{"interactive", []string{"interactive"}, "interactive"},
		{"interactive alias", []string{"i"}, "interactive"},
		{"interactive help", []string{"help", "interactive"}, "interactive"},
		{"payload input alias", []string{"pic"}, "payload-input"},
		{"payload input long", []string{"payload", "--input", "--copy"}, "payload-input"},
		{"payload input direct help", []string{"pic", "--help"}, "payload-input"},
		{"payload input nested help", []string{"help", "payload", "--input"}, "payload-input-help"},
		{"payload selection help", []string{"help", "payload"}, "payload-help"},
		{"payload selection", []string{"payload", "linux"}, "payload"},
		{"payload copy alias", []string{"pc", "linux"}, "payload"},
		{"payload execute alias", []string{"pe", "linux"}, "payload"},
		{"payload copy execute alias", []string{"pce", "linux"}, "payload"},
		{"www list", []string{"p", "--www", "ls"}, "www"},
		{"www search", []string{"payload", "www", "search"}, "www"},
		{"www link", []string{"p", "--www", "ln", "source"}, "www"},
		{"www file", []string{"p", "--www", "--file", "source"}, "www"},
		{"www child help", []string{"help", "p", "--www", "ls"}, "www"},
		{"unknown", []string{"wat"}, "unknown"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := Resolve(test.args).Command; got != test.want {
				t.Fatalf("Resolve(%q).Command = %q, want %q", test.args, got, test.want)
			}
		})
	}
}
