#!/usr/bin/env python3
"""Preflight check — verifies everything the app needs before you run it.

Cross-platform, read-only. Exit code 0 = ready to run, 1 = blocking problem.

Usage:
    python scripts/doctor.py
    python scripts/doctor.py --quiet    # only problems
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Packages the app cannot start without. Kept small on purpose: these are the
# ones that fail loudly and immediately if absent.
CORE_PACKAGES = [
    ("streamlit", "WebUI"),
    ("fastapi", "HTTP API"),
    ("uvicorn", "HTTP API"),
    ("moviepy", "video rendering"),
    ("faster_whisper", "subtitles"),
    ("edge_tts", "text-to-speech"),
    ("toml", "config"),
    ("loguru", "logging"),
    ("imageio_ffmpeg", "bundled ffmpeg"),
]

MIN_PYTHON = (3, 11)

GREEN, YELLOW, RED, DIM, RESET = "\033[32m", "\033[33m", "\033[31m", "\033[2m", "\033[0m"


def _color_enabled() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.name == "nt" and not os.environ.get("WT_SESSION"):
        # Legacy consoles do not render ANSI; modern terminals set WT_SESSION.
        return bool(os.environ.get("TERM_PROGRAM") or os.environ.get("ANSICON"))
    return sys.stdout.isatty()


USE_COLOR = _color_enabled()


def _c(text: str, color: str) -> str:
    return f"{color}{text}{RESET}" if USE_COLOR else text


class Report:
    def __init__(self) -> None:
        self.blocking: list[str] = []
        self.warnings: list[str] = []
        self.passed = 0

    def ok(self, msg: str) -> None:
        self.passed += 1
        print(f"  {_c('OK  ', GREEN)}  {msg}")

    def warn(self, msg: str, fix: str = "") -> None:
        self.warnings.append(msg)
        print(f"  {_c('WARN', YELLOW)}  {msg}")
        if fix:
            print(f"        {_c('-> ' + fix, DIM)}")

    def fail(self, msg: str, fix: str = "") -> None:
        self.blocking.append(msg)
        print(f"  {_c('FAIL', RED)}  {msg}")
        if fix:
            print(f"        {_c('-> ' + fix, DIM)}")


def section(title: str) -> None:
    print(f"\n{title}")


def check_python(rep: Report) -> None:
    section("[1] Python")
    ver = sys.version_info
    human = f"{ver.major}.{ver.minor}.{ver.micro}"
    if (ver.major, ver.minor) >= MIN_PYTHON:
        rep.ok(f"Python {human} ({sys.executable})")
    else:
        rep.fail(
            f"Python {human} is too old — need {MIN_PYTHON[0]}.{MIN_PYTHON[1]}+",
            "install from https://www.python.org/downloads/ (tick 'Add to PATH')",
        )


def check_venv(rep: Report) -> None:
    section("[2] Virtual environment")
    venv = ROOT / ".venv"
    if venv.is_dir():
        inside = Path(sys.prefix).resolve() == venv.resolve()
        if inside:
            rep.ok(f".venv active ({sys.prefix})")
        else:
            rep.warn(
                "a .venv exists but this Python is not running inside it",
                "activate it, or let setup.sh / setup.ps1 handle it",
            )
    else:
        rep.warn("no .venv — run scripts/setup.sh (or setup.ps1 on Windows)")


def check_packages(rep: Report) -> None:
    section("[3] Dependencies")
    missing = []
    for name, purpose in CORE_PACKAGES:
        try:
            spec = importlib.util.find_spec(name)
        except (ImportError, ValueError):
            spec = None
        if spec is None:
            missing.append(name)
        else:
            rep.ok(f"{name} ({purpose})")

    if missing:
        rep.fail(
            f"missing {len(missing)} package(s): {', '.join(missing)}",
            "pip install -r requirements.txt",
        )


def check_ffmpeg(rep: Report) -> None:
    section("[4] ffmpeg")
    system = shutil.which("ffmpeg")
    if system:
        rep.ok(f"system ffmpeg found ({system})")
        return

    # imageio-ffmpeg ships a static binary, which is why a system install is
    # optional. Prefer this path over telling the user to install ffmpeg.
    try:
        import imageio_ffmpeg

        exe = imageio_ffmpeg.get_ffmpeg_exe()
        if exe and Path(exe).is_file():
            rep.ok(f"bundled ffmpeg ({Path(exe).name}) — no system install needed")
            return
    except Exception:  # noqa: BLE001 - any failure means "not available"
        pass

    rep.fail(
        "no ffmpeg available",
        "pip install imageio-ffmpeg  (provides a static binary, no admin rights)",
    )


def check_config(rep: Report) -> None:
    section("[5] Configuration")
    cfg = ROOT / "config.toml"
    example = ROOT / "config.example.toml"

    if not cfg.is_file():
        if example.is_file():
            rep.warn(
                "config.toml not created yet",
                "it is auto-generated on first run, or run scripts/setup.sh",
            )
        else:
            rep.fail("config.example.toml is missing from the repo")
        return

    rep.ok("config.toml present")
    try:
        import toml

        data = toml.loads(cfg.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        rep.fail(f"config.toml cannot be parsed: {exc}", "delete it and re-run setup")
        return

    app = data.get("app", {}) or {}
    provider = app.get("llm_provider") or "(unset)"
    rep.ok(f"llm_provider = {provider}")

    # Count configured keys without printing any secret value.
    filled = 0
    total = 0
    for name, entry in (app.items()):
        if not isinstance(entry, dict):
            continue
        if "api_key" not in entry:
            continue
        total += 1
        value = str(entry.get("api_key") or "").strip()
        if value and not value.startswith("your_") and value.lower() != "none":
            filled += 1

    if total:
        if filled:
            rep.ok(f"{filled} of {total} provider API key(s) configured")
        else:
            rep.warn(
                "no LLM API key configured — the UI runs, but script generation will fail",
                "add a key in WebUI settings, or in config.toml under [app.<provider>]",
            )


def check_resources(rep: Report) -> None:
    section("[6] Runtime assets (fonts + background music)")
    fonts_dir = ROOT / "resource" / "fonts"
    songs_dir = ROOT / "resource" / "songs"

    ttc = sorted(fonts_dir.glob("*.ttc")) if fonts_dir.is_dir() else []
    mp3 = sorted(songs_dir.glob("*.mp3")) if songs_dir.is_dir() else []
    ttf = sorted(fonts_dir.glob("*.ttf")) if fonts_dir.is_dir() else []

    if ttf:
        rep.ok(f"{len(ttf)} .ttf font(s) present")

    # Expected counts in the upstream distribution at this commit.
    if len(ttc) >= 4:
        rep.ok(f"{len(ttc)} subtitle font(s) (.ttc)")
    else:
        rep.warn(
            f"{len(ttc)} of 4 subtitle fonts (.ttc) — Chinese/CJK subtitles will fail",
            "bash scripts/fetch-resources.sh   (or .\\scripts\\fetch-resources.ps1)",
        )

    if len(mp3) >= 29:
        rep.ok(f"{len(mp3)} background music track(s) (.mp3)")
    else:
        rep.warn(
            f"{len(mp3)} of 29 background music tracks (.mp3) — BGM selection is limited",
            "bash scripts/fetch-resources.sh   (or .\\scripts\\fetch-resources.ps1)",
        )


def check_port(rep: Report) -> None:
    section("[7] Ports")
    cfg = ROOT / "config.toml"
    port = 8080
    if cfg.is_file():
        try:
            import toml

            port = int(toml.loads(cfg.read_text(encoding="utf-8")).get("app", {}).get("listen_port", 8080))
        except Exception:  # noqa: BLE001
            pass

    import socket

    for label, p in (("API", port), ("WebUI", 8501)):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(("127.0.0.1", p))
                rep.ok(f"port {p} free ({label})")
            except OSError:
                rep.warn(
                    f"port {p} already in use ({label})",
                    "stop the other process, or change the port in config.toml",
                )


def check_git(rep: Report) -> None:
    section("[8] Repository state")
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode != 0:
            rep.warn("not a git checkout")
        elif result.stdout.strip():
            changed = len(result.stdout.strip().splitlines())
            rep.warn(f"{changed} uncommitted change(s)", "config.toml and .venv are ignored — expected")
        else:
            rep.ok("working tree clean")
    except (OSError, subprocess.SubprocessError):
        rep.warn("git not available")


def main() -> int:
    ap = argparse.ArgumentParser(description="Check that this app can run.")
    ap.add_argument("--quiet", action="store_true", help="only print problems")
    args = ap.parse_args()

    if args.quiet:
        global print  # noqa: A001 - intentional: silence the OK lines
        _real_print = print

        def print(*a, **k):  # type: ignore[misc]
            text = " ".join(str(x) for x in a)
            if "OK  " in text or text.startswith("\n["):
                return
            _real_print(*a, **k)

    print("=" * 52)
    print(" MoneyPrinterTurbo — preflight check")
    print("=" * 52)

    rep = Report()
    check_python(rep)
    check_venv(rep)
    check_packages(rep)
    check_ffmpeg(rep)
    check_config(rep)
    check_resources(rep)
    check_port(rep)
    check_git(rep)

    print("\n" + "=" * 52)
    if rep.blocking:
        print(f" {_c('NOT READY', RED)} — {len(rep.blocking)} blocking issue(s), "
              f"{len(rep.warnings)} warning(s), {rep.passed} passed")
        print("=" * 52)
        return 1
    if rep.warnings:
        print(f" {_c('READY', YELLOW)} — {len(rep.warnings)} warning(s), {rep.passed} passed")
    else:
        print(f" {_c('READY', GREEN)} — all {rep.passed} checks passed")
    print("=" * 52)
    print("\nStart it with:")
    print("  python scripts/run.py web      # WebUI  http://localhost:8501")
    print("  python scripts/run.py api      # API    http://localhost:8080/docs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
