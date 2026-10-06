"""Load KEY=value lines from the repo's .env into os.environ (values already set win).
Import it first in every script so the same command works from systemd and from a session."""
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RUNS = os.path.join(ROOT, "runs", "twin")
os.makedirs(RUNS, exist_ok=True)

if os.path.exists(os.path.join(ROOT, ".env")):
    for line in open(os.path.join(ROOT, ".env")):
        m = re.match(r"^([A-Za-z_]\w*)=(.*)$", line.rstrip("\n"))
        if m:
            os.environ.setdefault(m.group(1), m.group(2).strip().strip("\"'"))

# python.org builds on macOS ship without a CA bundle
if "SSL_CERT_FILE" not in os.environ and os.path.exists("/etc/ssl/cert.pem"):
    os.environ["SSL_CERT_FILE"] = "/etc/ssl/cert.pem"
