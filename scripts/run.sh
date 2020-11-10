#!/bin/bash
NAME=$(echo "${PWD##*/}" | tr _ -)
TAG=$(echo "$1" | tr _/ -)

if [ -z "$TAG" ]; then
	TAG="latest"
fi

docker run \
	--net=host \
	-it \
    --rm \
	"${NAME}:${TAG}"