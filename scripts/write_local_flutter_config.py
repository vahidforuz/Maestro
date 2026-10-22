"""Write ignored Flutter --dart-define files from the running local Supabase CLI."""

from __future__ import annotations

import json
import subprocess
import urllib.parse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / "maestro-mobile"
result = subprocess.run(
    ["npx", "--yes", "supabase", "status", "-o", "env"],
    cwd=ROOT,
    capture_output=True,
    text=True,
    check=True,
)
values = dict(
    line.split("=", 1)
    for line in result.stdout.splitlines()
    if "=" in line and not line.startswith("#")
)
url = values["API_URL"].strip('"')
key = values["PUBLISHABLE_KEY"].strip('"')
parsed = urllib.parse.urlparse(url)
if parsed.hostname not in {"localhost", "127.0.0.1"} or parsed.port != 54321:
    raise SystemExit("Refusing to write config for a non-local Supabase URL")

for platform, host in (("web", "127.0.0.1"), ("windows", "127.0.0.1"),
                       ("android", "10.0.2.2")):
    file = MOBILE / f".local.flutter.{platform}.json"
    config = {
        "SUPABASE_URL": f"http://{host}:{parsed.port}",
        "SUPABASE_PUBLISHABLE_KEY": key,
    }
    file.write_text(json.dumps(config, indent=2) + "\n")
    file.chmod(0o600)
    print(f"Wrote {file.relative_to(ROOT)} (public key only)")
