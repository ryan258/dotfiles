#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch_from_script "$@"
