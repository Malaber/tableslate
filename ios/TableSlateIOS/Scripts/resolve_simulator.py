from __future__ import annotations

import json
import sys
from pathlib import Path


inventory = json.loads(Path(sys.argv[1]).read_text())
wanted = sys.argv[2]
matches = [
    device
    for devices in inventory.get("devices", {}).values()
    for device in devices
    if device.get("name") == wanted and device.get("isAvailable", False)
]
if not matches:
    raise SystemExit(f"No available simulator named {wanted!r}")
print(matches[-1]["udid"])
