#!/bin/bash

set -e

. ../functions.sh

docker stack deploy -c compose.yaml --prune caddy_test

retry curl --show-error -s -k -f --resolve whoami0.tailnet.gnx:443:127.0.0.1 https://whoami0.tailnet.gnx &&
retry curl --show-error -s -k -f --resolve whoami1.tailnet.gnx:443:127.0.0.1 https://whoami1.tailnet.gnx &&
retry curl --show-error -s -k -f --resolve whoami2.tailnet.gnx:443:127.0.0.1 https://whoami2.tailnet.gnx &&
retry curl --show-error -s -k -f --resolve whoami3.tailnet.gnx:443:127.0.0.1 https://whoami3.tailnet.gnx &&
retry curl --show-error -s -k -f --resolve whoami4.tailnet.gnx:443:127.0.0.1 https://whoami4.tailnet.gnx &&
retry curl --show-error -s -k -f --resolve echo0.tailnet.gnx:443:127.0.0.1 https://echo0.tailnet.gnx/sourcepath/something || {
    docker service logs caddy_test_caddy
    exit 1
}
