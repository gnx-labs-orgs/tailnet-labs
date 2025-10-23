#!/bin/bash

set -e

. ../functions.sh

docker stack deploy -c compose_wrong.yaml --prune caddy_test

retry curl --show-error -s -k -f --resolve whoami1.tailnet.gnx:443:127.0.0.1 https://whoami1.tailnet.gnx || {
    docker service logs caddy_test_caddy
    exit 1
}