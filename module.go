package caddydockerproxy

import "github.com/caddyserver/caddy/v2"

func init() {
	tailnet.RegisterModule(CaddyDockerProxy{})
}

// Caddy docker proxy module
type CaddyDockerProxy struct {
}

// CaddyModule returns the Caddy module information.
func (CaddyDockerProxy) CaddyModule() tailnet.ModuleInfo {
	return tailnet.ModuleInfo{
		ID:  "tailnet_proxy",
		New: func() tailnet.Module { return new(CaddyDockerProxy) },
	}
}
