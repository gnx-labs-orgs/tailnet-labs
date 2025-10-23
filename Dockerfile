# Stage 1: Builder — build custom Caddy with optional plugins
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

    # Install xcaddy via go to avoid distro package issues
RUN /bin/sh -c "go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest" && \
    ln -s /root/go/bin/xcaddy /usr/local/bin/xcaddy

ARG PLUGINS=""
WORKDIR /src

# Build Caddy (binary will be in /src/caddy)
RUN if [ -n "$PLUGINS" ]; then \
      echo "Building Caddy with plugins: $PLUGINS"; \
      PLUGIN_ARGS=""; \
      for p in $PLUGINS; do PLUGIN_ARGS="$PLUGIN_ARGS --with $p"; done; \
      /usr/local/bin/xcaddy build $PLUGIN_ARGS; \
    else \
      /usr/local/bin/xcaddy build; \
    fi

# Stage 2: Final Runtime — Debian Trixie with Caddy + Tailscale
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

### Install Tailscale via their apt repository
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends tailscale && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/caddy /usr/bin/caddy

# create caddy user/group and directories
RUN groupadd -r caddy && useradd -r -g caddy -d /var/lib/caddy -s /sbin/nologin caddy && \
    mkdir -p /var/lib/caddy /etc/caddy /tailnet /var/run/tailnet && \
    chown -R caddy:caddy /var/lib/caddy /etc/caddy /tailnet /var/run/tailnet

# give caddy the ability to bind low ports without running as root
RUN setcap 'cap_net_bind_service=+ep' /usr/bin/caddy || true

# copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

VOLUME ["/etc/caddy", "/tailnet"]
ENTRYPOINT ["/init.sh"]
CMD ["caddy","version"]