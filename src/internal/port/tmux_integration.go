package port

type TmuxIntegrationStatus struct {
	Server       string
	AliasState   string
	PrefixLegacy bool
}

type TmuxIntegration interface {
	IntegrationStatus(helper string, schema int) (TmuxIntegrationStatus, error)
}
