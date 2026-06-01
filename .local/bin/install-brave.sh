#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

curl -fsS https://dl.brave.com/install.sh | sh
