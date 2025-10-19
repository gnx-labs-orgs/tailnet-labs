# syntax=docker/dockerfile:1

################################################################################
#                               Stage 1: Builder
################################################################################

# (1) Use debian:bookworm as the base image for the builder stage
FROM debian:bookworm AS builder

# (2) Install apt dependencies 
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        debian-keyring \
        debian-archive-keyring \
        apt-transport-https \
        build-essential \
        gcc \
        file \
        procps \
        ruby \
        wget \
    && rm -rf /var/lib/apt/lists/*

# (3) Download and install the latest Golang
RUN wget https://go.dev/dl/go1.25.3.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.25.3.linux-amd64.tar.gz \
    && rm go1.25.3.linux-amd64.tar.gz

# (3) Add Golang to PATH
ENV PATH="/usr/local/go/bin:$PATH"

# (4) Install xcaddy
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg \
 && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-xcaddy.list \
 && apt-get update \
 && apt-get install -y xcaddy \
 && rm -rf /var/lib/apt/lists/*

# (5) Initialize plugin list
ARG PLUGINS=""

# (6) Build caddy with plugins
RUN if [ -n "$PLUGINS" ]; then \
    echo "Building custom caddy with plugins: $PLUGINS"; \
    PLUGIN_ARGS=""; \
    for plugin in $PLUGINS; do \
      PLUGIN_ARGS="$PLUGIN_ARGS --with $plugin"; \
    done; \
    xcaddy build $PLUGIN_ARGS; \
  else \
    echo "No plugins specified. Building default caddy"; \
    xcaddy build; \
  fi
  

################################################################################
#                          Stage 2: Final minimal image
################################################################################
# (1) Use debian:bookworm as the base image for the final stage
FROM debian:bookworm

# (2) Install apt dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      iptables \
      ca-certificates \
      curl \
      vim \
      # Debugging tools
      iputils-ping \
      dnsutils \
      openresolv \
    && rm -rf /var/lib/apt/lists/*

# (3) Install Tailscale
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null \
 && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends tailscale \
 && rm -rf /var/lib/apt/lists/*

# (4) Copy the custom caddy binary from the builder stage
COPY --from=builder /caddy /usr/bin/caddy

# (5) Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# (6) Set the entrypoint script as executable
RUN chmod +x /entrypoint.sh

# (7) Mount volumes for persistent data
VOLUME ["/etc/caddy", "/tailscale"]

# (8) Set the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]

# (9) Set the default command to display the caddy version
CMD ["caddy", "version"]
