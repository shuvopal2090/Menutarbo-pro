#!/usr/bin/env python3
"""One launcher for both services, so the right flags are never forgotten.

Usage:
    python scripts/run.py web              # WebUI   (default port 8501)
    python scripts/run.py api              # API     (port from config.toml)
    python scripts/run.py web --port 9000
    python scripts/run.py api --reload     # auto-reload on code changes

Why a launcher: Streamlit needs specific server flags to be reachable from a
browser that is not on localhost (containers, remote boxes, preview proxies).
Passing them by hand is the usual cause of "the UI loads but does nothing".
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _config_port() -> int:
    cfg = ROOT / "config.toml"
    try:
        import toml

        return int(toml.loads(cfg.read_text(encoding="utf-8")).get("app", {}).get("listen_port", 8080))
    except Exception:  # noqa: BLE001
        return 8080


def run_web(host: str, port: int) -> int:
    entry = ROOT / "webui" / "Main.py"
    if not entry.is_file():
        print(f"error: {entry} not found", file=sys.stderr)
        return 1

    cmd = [
        sys.executable,
        "-m",
        "streamlit",
        "run",
        str(entry),
        "--server.address",
        host,
        "--server.port",
        str(port),
        "--server.headless",
        "true",
        # Required when the page is framed or served from another origin.
        "--server.enableCORS",
        "false",
        "--server.enableXsrfProtection",
        "false",
        "--browser.gatherUsageStats",
        "false",
    ]
    print(f"WebUI -> http://localhost:{port}")
    return subprocess.call(cmd, cwd=ROOT)


def run_api(host: str, port: int, reload: bool) -> int:
    main = ROOT / "main.py"
    if not main.is_file():
        print(f"error: {main} not found", file=sys.stderr)
        return 1

    if host != "0.0.0.0" or port != _config_port():
        # main.py reads config.toml; drive uvicorn directly to override.
        cmd = [
            sys.executable,
            "-m",
            "uvicorn",
            "app.asgi:app",
            "--host",
            host,
            "--port",
            str(port),
            "--log-level",
            "warning",
        ]
        if reload:
            cmd.append("--reload")
    else:
        cmd = [sys.executable, str(main)]
        if reload:
            os.environ["MPT_RELOAD"] = "1"

    print(f"API   -> http://localhost:{port}/docs")
    return subprocess.call(cmd, cwd=ROOT)


def main() -> int:
    ap = argparse.ArgumentParser(description="Run the app.")
    ap.add_argument("service", choices=["web", "api"], help="web = Streamlit UI, api = FastAPI")
    ap.add_argument("--host", default="0.0.0.0", help="bind address (default 0.0.0.0)")
    ap.add_argument("--port", type=int, default=None, help="override port")
    ap.add_argument("--reload", action="store_true", help="auto-reload on code changes")
    args = ap.parse_args()

    if args.service == "web":
        return run_web(args.host, args.port or 8501)
    return run_api(args.host, args.port or _config_port(), args.reload)


if __name__ == "__main__":
    sys.exit(main())
