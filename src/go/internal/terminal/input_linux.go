package terminal

import (
	"bufio"
	"errors"
	"io"
	"os"
	"strings"
	"syscall"
	"unicode/utf8"
	"unsafe"
)

var ErrCancelled = errors.New("input cancelled")

func ReadPayloadInput(reader io.Reader, output io.Writer) (string, error) {
	file, ok := reader.(*os.File)
	if !ok || !isTerminal(file) {
		return readStream(reader)
	}
	return readInteractive(file, output)
}

func ReadKey(reader io.Reader) (string, error) {
	file, ok := reader.(*os.File)
	closeFile := false
	if !ok || !isTerminal(file) {
		tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
		if err != nil {
			buffered := bufio.NewReader(reader)
			value, readErr := buffered.ReadString('\n')
			return strings.TrimSpace(value), readErr
		}
		file = tty
		closeFile = true
	}
	if closeFile {
		defer file.Close()
	}
	fd := int(file.Fd())
	original, err := getTermios(fd)
	if err != nil {
		return "", err
	}
	raw := *original
	raw.Lflag &^= syscall.ICANON | syscall.ECHO
	raw.Cc[syscall.VMIN] = 1
	raw.Cc[syscall.VTIME] = 0
	if err = setTermios(fd, &raw); err != nil {
		return "", err
	}
	defer setTermios(fd, original)
	var value [1]byte
	_, err = file.Read(value[:])
	if err != nil {
		return "", err
	}
	return string(value[:]), nil
}

func readStream(reader io.Reader) (string, error) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 16*1024*1024)
	var lines []string
	for scanner.Scan() {
		line := scanner.Text()
		switch line {
		case ":w":
			return strings.Join(lines, "\n"), nil
		case ":q", ":q!":
			return "", ErrCancelled
		default:
			lines = append(lines, line)
		}
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	return strings.Join(lines, "\n"), nil
}

func readInteractive(file *os.File, output io.Writer) (text string, resultErr error) {
	fd := int(file.Fd())
	original, err := getTermios(fd)
	if err != nil {
		return "", err
	}
	raw := *original
	raw.Lflag &^= syscall.ICANON | syscall.ECHO
	raw.Cc[syscall.VMIN] = 1
	raw.Cc[syscall.VTIME] = 0
	if err := setTermios(fd, &raw); err != nil {
		return "", err
	}
	defer func() {
		if restoreErr := setTermios(fd, original); resultErr == nil && restoreErr != nil {
			resultErr = restoreErr
		}
	}()

	var input strings.Builder
	var value [1]byte
	for {
		if _, err := file.Read(value[:]); err != nil {
			return "", err
		}
		switch value[0] {
		case '\r', '\n', 4:
			_, _ = io.WriteString(output, "\r\n")
			text = input.String()
			if text == ":q" || text == ":q!" {
				return "", ErrCancelled
			}
			return stripFinishLine(text), nil
		case 3:
			_, _ = io.WriteString(output, "\r\n")
			return "", ErrCancelled
		case 8, 127:
			current := input.String()
			if current == "" {
				continue
			}
			_, size := utf8.DecodeLastRuneInString(current)
			input.Reset()
			input.WriteString(current[:len(current)-size])
			_, _ = io.WriteString(output, "\b \b")
		case 27:
			next, available, err := readAvailableByte(fd, file)
			if err != nil {
				return "", err
			}
			if available && (next == '\r' || next == '\n') {
				input.WriteByte('\n')
				_, _ = io.WriteString(output, "\r\n")
				continue
			}
			_, _ = io.WriteString(output, "\r\n")
			return "", ErrCancelled
		default:
			input.WriteByte(value[0])
			_, _ = output.Write(value[:])
		}
	}
}

func stripFinishLine(input string) string {
	if input == ":w" {
		return ""
	}
	return strings.TrimSuffix(input, "\n:w")
}

func isTerminal(file *os.File) bool {
	_, err := getTermios(int(file.Fd()))
	return err == nil
}

func getTermios(fd int) (*syscall.Termios, error) {
	var value syscall.Termios
	_, _, errno := syscall.Syscall6(
		syscall.SYS_IOCTL,
		uintptr(fd),
		uintptr(syscall.TCGETS),
		uintptr(unsafe.Pointer(&value)),
		0, 0, 0,
	)
	if errno != 0 {
		return nil, errno
	}
	return &value, nil
}

func setTermios(fd int, value *syscall.Termios) error {
	_, _, errno := syscall.Syscall6(
		syscall.SYS_IOCTL,
		uintptr(fd),
		uintptr(syscall.TCSETS),
		uintptr(unsafe.Pointer(value)),
		0, 0, 0,
	)
	if errno != 0 {
		return errno
	}
	return nil
}

func readAvailableByte(fd int, file *os.File) (byte, bool, error) {
	var readSet syscall.FdSet
	readSet.Bits[fd/64] |= int64(1) << uint(fd%64)
	timeout := syscall.Timeval{Usec: 150000}
	ready, err := syscall.Select(fd+1, &readSet, nil, nil, &timeout)
	if err != nil {
		return 0, false, err
	}
	if ready == 0 {
		return 0, false, nil
	}
	var next [1]byte
	if _, err := file.Read(next[:]); err != nil {
		return 0, false, err
	}
	return next[0], true, nil
}
