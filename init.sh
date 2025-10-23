#!/usr/bin/env bash
set -euo pipefail

TAILSCALE_STATE="/tailnet/tailscaled.state"
TAILSCALE_SOCKET="/var/run/tailnet/tailscaled.sock"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-tailnet-labs}"
TAILNET_NAME="${TAILNET_NAME:-tailnet.gnx}"

DNS_NS1="${DNS_NS1:-100.100.100.100}"
DNS_NSl="${DNS_NSl:-127.0.0.11}"

# Load secrets from Docker secrets if available
if [ -z "${TAILSCALE_AUTHKEY:-}" ] && [ -f "/run/secrets/tailscale_authkey" ]; then
  TAILSCALE_AUTHKEY="$(< /run/secrets/tailscale_authkey)"
fi
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f "/run/secrets/cloudflare_api_token" ]; then
  export CLOUDFLARE_API_TOKEN="$(< /run/secrets/cloudflare_api_token)"
fi

mkdir -p /var/run/tailnet /tailnet

tailscaled --state="$TAILSCALE_STATE" --socket="$TAILSCALE_SOCKET" --tun=userspace-networking & 
TAILSCALED_PID=$!

trap 'kill -TERM "$TAILSCALED_PID" 2>/dev/null || true' SIGTERM SIGINT EXIT

# Wait for socket to appear (~10 s)
for i in $(seq 1 20); do
  [ -S "$TAILSCALE_SOCKET" ] && break
  sleep 0.5
done

cat >/etc/resolv.conf <<EOF
nameserver ${DNS_NS1}
nameserver ${DNS_NSl}
search ${TAILNET_NAME} local
options ndots:0
EOF

# Authenticate if key available (no leak)
if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
  tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$TAILSCALE_HOSTNAME" || true
else
  echo "⚠️  TAILSCALE_AUTHKEY not provided; tailscale will remain unauthenticated."
fi

wait "$TAILSCALED_PID"