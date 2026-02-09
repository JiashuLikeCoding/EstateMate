#!/usr/bin/env bash
set -euo pipefail

# Jiashu's iPad UDID (auto from xctrace list devices)
UDID="00008027-000331E92EE3002E"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_device.sh" "$UDID"
