#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Hector @sudosu404
# SPDX-License-Identifier: AGPL-3.0
#
# init.sh — smart init for tailnet-labs container
# Handles tailscaled lifecycle, DNS, and caddy startup robustly.

set -Eeuo pipefail

# --- Configuration defaults ---
TAILSCALE_STATE_DIR="${TAILSCALE_STATE_DIR:-/tailscale}"
TAILSCALE_SOCKET="${TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
TAILSCALE_STATE_FILE="${TAILSCALE_STATE_FILE:-${TAILSCALE_STATE_DIR}/tailscaled.state}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-tailnet-labs}"
TAILNET_NAME="${TAILNET_NAME:-tailnet}"
DEBUG="${DEBUG:-false}"
CADDY_WATCH="${CADDY_WATCH:-false}"

# --- Logging helpers ---
log() { printf '[init] %s\n' "$*" >&2; }
debug() { [ "$DEBUG" = "true" ] && log "DEBUG: $*"; }

# --- Cleanup ---
cleanup() {
  log "Shutting down tailscaled..."
  pkill -TERM tailscaled 2>/dev/null || true
}
trap cleanup EXIT SIGTERM SIGINT

# --- Start tailscaled ---
log "Starting tailscaled..."
mkdir -p "$(dirname "$TAILSCALE_SOCKET")" "$TAILSCALE_STATE_DIR"
tailscaled \
  --state="${TAILSCALE_STATE_FILE}" \
  --socket="${TAILSCALE_SOCKET}" \
  --tun=userspace-networking &
TAILSCALED_PID=$!

# --- Wait for tailscaled socket readiness ---
log "Waiting for tailscaled socket..."
for i in $(seq 1 30); do
  if [ -S "${TAILSCALE_SOCKET}" ]; then
    debug "tailscaled socket is ready."
    break
  fi
  sleep 0.5
done

# --- DNS Setup (MagicDNS override optional) ---
log "Configuring resolv.conf..."
{
  echo "nameserver 100.100.100.100"
  echo "nameserver 127.0.0.11"
  echo "search ${TAILNET_NAME} local"
  echo "options ndots:0"
} > /etc/resolv.conf

# --- Tailscale login ---
if tailscale status 2>/dev/null | grep -q '100\.'; then
  log "Tailnet already logged in."
else
  log "Tailnet not logged in — attempting tailscale up..."
  if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
    tailscale up --authkey="${TAILSCALE_AUTHKEY}" \
                 --hostname="${TAILSCALE_HOSTNAME}" || {
                   log "tailscale up failed."
                   exit 1
                 }
  else
    log "WARNING: No TAILSCALE_AUTHKEY provided; skipping tailscale up."
  fi
fi

# --- Start Caddy ---
if [ -f /etc/caddy/Caddyfile ]; then
  log "Running Caddy with Caddyfile (watch=${CADDY_WATCH})"
  if [ "${CADDY_WATCH}" = "true" ]; then
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile --watch
  else
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
  fi
else
  log "No /etc/caddy/Caddyfile found; running default."
  exec caddy run
fi