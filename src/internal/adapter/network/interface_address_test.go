package network

import "testing"

func TestParseIPv4(t *testing.T) {
	output := "7: tun0    inet 10.20.30.40/24 brd 10.20.30.255 scope global tun0\n"
	if got := parseIPv4(output); got != "10.20.30.40" {
		t.Fatalf("parseIPv4()=%q", got)
	}
	if got := parseIPv4("7: tun0    inet6 ::1/128"); got != "" {
		t.Fatalf("parseIPv4(inet6)=%q", got)
	}
}
