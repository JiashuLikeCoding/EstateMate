#!/usr/bin/env bash
set -euo pipefail

# Jiashu's iPhone UDID (auto from xctrace list devices)
UDID="00008140-001615061A33001C"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_device.sh" "$UDID"
