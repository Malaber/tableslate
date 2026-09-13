from __future__ import annotations

import json
import sys
from pathlib import Path


summary_path = Path(sys.argv[1])
minimum = float(sys.argv[2])
payload = json.loads(summary_path.read_text())
coverage = float(payload["data"][0]["totals"]["lines"]["percent"])
print(f"TableSlateCore line coverage: {coverage:.2f}% (minimum {minimum:.2f}%)")
if coverage + 1e-9 < minimum:
    raise SystemExit(1)
