package port

type AtomicFileWriter interface {
	WriteAtomic(path string, data []byte) (absolutePath string, err error)
}
