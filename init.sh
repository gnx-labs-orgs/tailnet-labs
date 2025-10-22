#!/usr/bin/env bash
set -euo pipefail

TAILSCALE_STATE="/tailnet/tailscaled.state"
TAILSCALE_SOCKET="/var/run/tailnet/tailscaled.sock"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-tailnet-labs}"
TAILNET_NAME="${TAILNET_NAME:-tailnet.gnx}"
CADDY_WATCH="${CADDY_WATCH:-true}"

trap 'pkill -TERM tailscaled 2>/dev/null || true' EXIT

mkdir -p /var/run/tailnet /tailnet
tailscaled --state="$TAILSCALE_STATE" --socket="$TAILSCALE_SOCKET" --tun=userspace-networking &
for i in {1..20}; do [ -S "$TAILSCALE_SOCKET" ] && break; sleep 0.5; done

cat >/etc/resolv.conf <<EOF
nameserver ${DNS_NS1:-100.100.100.100}
nameserver ${DNS_NSl:-127.0.0.11}
search ${TAILNET_NAME} local
options ndots:0
EOF

if ! tailscale status 2>/dev/null | grep -q '100\.'; then
  [ -n "${TAILSCALE_AUTHKEY:-}" ] && \
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$TAILSCALE_HOSTNAME" || \
    echo "⚠️  No auth key, skipping tailnet up"
fi

