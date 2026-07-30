package network

import (
	"errors"
	"fmt"
	"os/exec"
	"strings"
)

type InterfaceAddress struct {
	lookPath func(string) (string, error)
	command  func(string, ...string) *exec.Cmd
}

func NewInterfaceAddress() *InterfaceAddress {
	return &InterfaceAddress{lookPath: exec.LookPath, command: exec.Command}
}

func (a *InterfaceAddress) InterfaceIPv4(name string) (string, error) {
	if _, err := a.lookPath("ip"); err != nil {
		return "", errors.New("ii: required command not found: ip")
	}
	output, err := a.command("ip", "-4", "-o", "addr", "show", "dev", name).CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message != "" {
			return "", errors.New(message)
		}
		return "", err
	}
	value := parseIPv4(string(output))
	if value != "" {
		return value, nil
	}
	return "", fmt.Errorf("ii: no IPv4 address found on interface: %s", name)
}

func parseIPv4(output string) string {
	fields := strings.Fields(output)
	for index, field := range fields {
		if field == "inet" && index+1 < len(fields) {
			return strings.SplitN(fields[index+1], "/", 2)[0]
		}
	}
	return ""
}
