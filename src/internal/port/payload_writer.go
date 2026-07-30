package port

type PayloadWriter interface {
	WritePayload(path, text string) (absolutePath string, err error)
}
