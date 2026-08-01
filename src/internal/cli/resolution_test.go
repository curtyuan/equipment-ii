package cli

import "testing"

func TestRoute(t *testing.T) {
	tests := []struct {
		name string
		args []string
		want string
	}{
		{"empty", nil, RouteGo},
		{"version", []string{"version"}, RouteGo},
		{"top help", []string{"help"}, RouteGo},
		{"version help", []string{"help", "version"}, RouteGo},
		{"set command", []string{"set", "rhost", "value"}, RouteGo},
		{"compact set", []string{"s:rhost=value"}, RouteGo},
		{"set help", []string{"help", "set"}, RouteGo},
		{"list", []string{"ls", "host"}, RouteGo},
		{"list help", []string{"help", "list"}, RouteGo},
		{"v list", []string{"v", "host"}, RouteGo},
		{"v output", []string{"v", "--out"}, RouteGo},
		{"vo output", []string{"vo"}, RouteGo},
		{"voc output", []string{"voc"}, RouteGo},
		{"v help", []string{"v", "--help"}, RouteGo},
		{"output help", []string{"help", "v", "--out"}, RouteGo},
		{"interactive", []string{"interactive"}, RouteGo},
		{"interactive alias", []string{"i"}, RouteGo},
		{"interactive help", []string{"help", "interactive"}, RouteGo},
		{"payload input alias", []string{"pic"}, RouteGo},
		{"payload input long", []string{"payload", "--input", "--copy"}, RouteGo},
		{"payload input direct help", []string{"pic", "--help"}, RouteGo},
		{"payload input nested help", []string{"help", "payload", "--input"}, RouteGo},
		{"payload selection help", []string{"help", "payload"}, RouteGo},
		{"payload selection", []string{"payload", "linux"}, RouteGo},
		{"payload copy alias", []string{"pc", "linux"}, RouteGo},
		{"payload execute alias", []string{"pe", "linux"}, RouteGo},
		{"payload copy execute alias", []string{"pce", "linux"}, RouteGo},
		{"www list", []string{"p", "--www", "ls"}, RouteGo},
		{"www search", []string{"payload", "www", "search"}, RouteGo},
		{"www link", []string{"p", "--www", "ln", "source"}, RouteGo},
		{"www file", []string{"p", "--www", "--file", "source"}, RouteGo},
		{"www child help", []string{"help", "p", "--www", "ls"}, RouteGo},
		{"unknown", []string{"wat"}, RouteGo},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := Route(test.args); got != test.want {
				t.Fatalf("Route(%q) = %q, want %q", test.args, got, test.want)
			}
		})
	}
}
