#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

curl https://rclone.org/install.sh | bash
