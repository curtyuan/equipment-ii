package port

type PayloadStore interface {
	List() ([]string, error)
	Read(path string) (string, error)
}
