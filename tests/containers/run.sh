#!/bin/bash

set -e

. ../functions.sh

trap "docker rm -f caddy whoami0 whoami1 whoami_stopped" EXIT

{
    docker run --name caddy -d -p 4443:443 -e CADDY_DOCKER_SCAN_STOPPED_CONTAINERS=true -v /var/run/docker.sock:/var/run/docker.sock tailnet:local &&
    docker run --name whoami0 -d -l caddy=whoami0.tailnet.gnx -l "tailnet.reverse_proxy={{upstreams 80}}" -l tailnet.tls=internal traefik/whoami &&
    docker run --name whoami1 -d -l caddy=whoami1.tailnet.gnx -l "tailnet.reverse_proxy={{upstreams 80}}" -l tailnet.tls=internal traefik/whoami &&
    docker create --name whoami_stopped -l caddy=whoami_stopped.tailnet.gnx -l "tailnet.respond=\"I'm a stopped container!\" 200" -l tailnet.tls=internal traefik/whoami &&

    retry curl -k --resolve whoami0.tailnet.gnx:4443:127.0.0.1 https://whoami0.tailnet.gnx:4443 &&
    retry curl -k --resolve whoami1.tailnet.gnx:4443:127.0.0.1 https://whoami1.tailnet.gnx:4443 &&
    retry curl -k --resolve whoami_stopped.tailnet.gnx:4443:127.0.0.1 https://whoami_stopped.tailnet.gnx:4443
} || {
    echo "Test failed"
    exit 1
}