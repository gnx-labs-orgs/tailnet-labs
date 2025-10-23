#!/usr/bin/env bash
set -euo pipefail

TAILSCALE_STATE="/var/lib/tailscale/tailscaled.state"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-tailnet-labs}"
TAILNET_NAME="${TAILNET_NAME:-tailnet.gnx}"
DNS_NS1="${DNS_NS1:-100.100.100.100}"
DNS_NS2="${DNS_NS2:-127.0.0.11}"

# --- Load secrets ---
if [ -z "${TAILSCALE_AUTHKEY:-}" ] && [ -f "/run/secrets/tailscale_authkey" ]; then
  TAILSCALE_AUTHKEY="$(< /run/secrets/tailscale_authkey)"
fi
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f "/run/secrets/cloudflare_api_token" ]; then
  export CLOUDFLARE_API_TOKEN="$(< /run/secrets/cloudflare_api_token)"
fi

# --- Start tailscaled ---
echo "🌀 Starting Tailscale daemon..."
tailscaled --tun=userspace-networking \
           --socks5-server=localhost:1055 \
           --outbound-http-proxy-listen=localhost:1055 &
TS_PID=$!
sleep 5

# --- DNS config ---
cat >/etc/resolv.conf <<EOF
nameserver ${DNS_NS1}
nameserver ${DNS_NS2}
search ${TAILNET_NAME} local
options ndots:0
EOF

# --- Bring up tailnet ---
if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
  tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$TAILSCALE_HOSTNAME" || \
    echo "⚠️  Failed to bring up Tailscale."
else
  echo "⚠️  No authkey; running unauthenticated."
fi

# --- Start Caddy manually (no systemd) ---
echo "🚀 Starting Caddy..."
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!

# --- Keep container alive ---
wait -n "$TS_PID" "$CADDY_PID"