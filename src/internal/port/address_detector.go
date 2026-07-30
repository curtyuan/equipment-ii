package port

type AddressDetector interface {
	InterfaceIPv4(name string) (string, error)
}
