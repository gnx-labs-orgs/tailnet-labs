# syntax=docker/dockerfile:1

################################################################################
# Stage 1: Builder — build custom Caddy with optional plugins
################################################################################
FROM debian:trixie AS builder

# Install build tools and Go
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        build-essential \
        gcc \
        file \
        procps \
        wget \
        xz-utils \
        tar && \
    rm -rf /var/lib/apt/lists/*

ARG GO_VERSION=1.25.3
RUN wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"

# Install xcaddy
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg && \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-xcaddy.list && \
    apt-get update && \
    apt-get install -y xcaddy && \
    rm -rf /var/lib/apt/lists/*

ARG PLUGINS=""
WORKDIR /src
RUN if [ -n "$PLUGINS" ]; then \
      echo "Building Caddy with plugins: $PLUGINS"; \
      PLUGIN_ARGS=""; \
      for p in $PLUGINS; do \
        PLUGIN_ARGS="$PLUGIN_ARGS --with $p"; \
      done; \
      xcaddy build $PLUGIN_ARGS; \
    else \
      echo "Building default Caddy (no extra plugins)"; \
      xcaddy build; \
    fi

################################################################################
# Stage 2: Final Runtime — Debian Trixie with Caddy + Tailscale
################################################################################
FROM debian:trixie-slim AS runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      iptables \
      ca-certificates \
      curl \
      vim \
      iputils-ping \
      dnsutils && \
    rm -rf /var/lib/apt/lists/*

# Install Tailscale via their apt repository (Debian method)
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends tailscale && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/caddy /usr/bin/caddy
COPY init.sh /init.sh
RUN chmod +x /init.sh

VOLUME ["/etc/caddy", "/tailscale"]
ENTRYPOINT ["/init.sh"]
CMD ["caddy","version"]