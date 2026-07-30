package cli

type Resolution struct {
	Owner   string
	Command string
}

func Resolve(args []string) Resolution {
	return Resolution{
		Owner:   resolveOwner(args),
		Command: resolveCommand(args),
	}
}

func Route(args []string) string {
	return Resolve(args).Owner
}
