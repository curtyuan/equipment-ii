package port

type Clipboard interface {
	Copy(text string) error
}

type ClipboardBackend interface {
	Clipboard
	EffectiveBackend() (string, error)
	Context() string
}
