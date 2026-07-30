package shellstate

import (
	"os"
	"strings"

	"github.com/curtyuan/equipment-ii/src/internal/port"
)

const Header = "ii-shell-state-v1"

type File struct {
	values map[string]port.ShellValue
}

func NewFile(path string) (*File, error) {
	state := &File{values: make(map[string]port.ShellValue)}
	if path == "" {
		return state, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	fields := strings.Split(string(data), "\x00")
	if len(fields) == 1 && fields[0] == "" {
		return state, nil
	}
	if len(fields) < 2 || fields[0] != Header {
		return nil, os.ErrInvalid
	}
	for index := 1; index+2 < len(fields); index += 3 {
		state.values[fields[index]] = port.ShellValue{
			Present: fields[index+1] == "1",
			Value:   fields[index+2],
		}
	}
	return state, nil
}

func (f *File) Lookup(name string) port.ShellValue {
	return f.values[name]
}
