#!/bin/bash

set -e

docker build -f Dockerfile-nanoserver . \
    --build-arg TARGETPLATFORM=windows/amd64 \
    --build-arg SERVERCORE_VERSION=1809 \
    --build-arg NANOSERVER_VERSION=1809 \
    -t sudosu404/tailnet:ci-nanoserver-1809

docker build -f Dockerfile-nanoserver . \
    --build-arg TARGETPLATFORM=windows/amd64 \
    --build-arg SERVERCORE_VERSION=ltsc2022 \
    --build-arg NANOSERVER_VERSION=ltsc2022 \
    -t sudosu404/tailnet:ci-nanoserver-ltsc2022

if [[ "${GITHUB_REF}" == "refs/heads/master" ]]; then
    echo "Pushing CI images"
    
    docker login -u sudosu404 -p "$DOCKER_PASSWORD"
    docker push sudosu404/tailnet:ci-nanoserver-1809
    docker push sudosu404/tailnet:ci-nanoserver-ltsc2022
fi

if [[ "${GITHUB_REF}" =~ ^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]]; then
    RELEASE_VERSION=$(echo $GITHUB_REF | cut -c11-)

    echo "Releasing version ${RELEASE_VERSION}..."

    docker login -u sudosu404 -p "$DOCKER_PASSWORD"

    PATCH_VERSION=$(echo $RELEASE_VERSION | cut -c2-)
    MINOR_VERSION=$(echo $PATCH_VERSION | cut -d. -f-2)

    docker login -u sudosu404 -p "$DOCKER_PASSWORD"

    # nanoserver-1809
    docker tag sudosu404/tailnet:ci-nanoserver-1809 sudosu404/tailnet:nanoserver-1809
    docker tag sudosu404/tailnet:ci-nanoserver-1809 sudosu404/tailnet:${PATCH_VERSION}-nanoserver-1809
    docker tag sudosu404/tailnet:ci-nanoserver-1809 sudosu404/tailnet:${MINOR_VERSION}-nanoserver-1809
    docker push sudosu404/tailnet:nanoserver-1809
    docker push sudosu404/tailnet:${PATCH_VERSION}-nanoserver-1809
    docker push sudosu404/tailnet:${MINOR_VERSION}-nanoserver-1809

    # nanoserver-ltsc2022
    docker tag sudosu404/tailnet:ci-nanoserver-ltsc2022 sudosu404/tailnet:nanoserver-ltsc2022
    docker tag sudosu404/tailnet:ci-nanoserver-ltsc2022 sudosu404/tailnet:${PATCH_VERSION}-nanoserver-ltsc2022
    docker tag sudosu404/tailnet:ci-nanoserver-ltsc2022 sudosu404/tailnet:${MINOR_VERSION}-nanoserver-ltsc2022
    docker push sudosu404/tailnet:nanoserver-ltsc2022
    docker push sudosu404/tailnet:${PATCH_VERSION}-nanoserver-ltsc2022
    docker push sudosu404/tailnet:${MINOR_VERSION}-nanoserver-ltsc2022
fi
