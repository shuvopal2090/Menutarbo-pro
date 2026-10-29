# Import notes

## What this repository contains

The **MoneyPrinterTurbo** source at commit
`dd5ee71a0fbbb2c06401a7a4401bc83830a7c4d1` (2026-10-27), imported
byte-for-byte from the Google Drive folder `MoneyPrinterTurbo-main`.

Verification: 35 files were compared by MD5 against the `harry0703/MoneyPrinterTurbo`
Git repository. **35/35 matched, 0 mismatches.**

| Path | What it is |
|---|---|
| `app/` | backend: controllers, services, models, config, utils |
| `webui/` | Streamlit frontend (`Main.py`, styles, i18n) |
| `main.py`, `cli.py` | entrypoints |
| `test/` | pytest suite |
| `docs/`, `*.md` | documentation (EN / JA / ZH) |
| `Dockerfile*`, `docker-compose*.yml` | container setup |
| `config.example.toml` | config template — copy to `config.toml` |
| `scripts/` | helper scripts |

## What is NOT in this repository

`resource/fonts/*.ttc` and `resource/songs/*.mp3` — **206 MB** of binary assets
(4 subtitle fonts, 29 background-music tracks). They exceed GitHub's usable repo
size and Arena's artifact limits, so they are listed in `.gitignore`.

The app needs them at runtime for subtitles and background music. Restore with:

```bash
bash scripts/fetch-resources.sh
```

```powershell
.\scripts\fetch-resources.ps1
```

Both pull the exact same commit from upstream, so the files match this source.

The 5 small `.ttf` fonts and `resource/public/index.html` **are** included.

## Running it

### One command (recommended)

```bash
bash scripts/setup.sh
```

```powershell
.\scripts\setup.ps1
```

Creates the virtualenv, installs dependencies, writes `config.toml`, downloads
the 206 MB of runtime assets, and runs a preflight check. Safe to re-run — every
step is skipped when already satisfied.

Options: `--skip-resources` / `-SkipResources` to skip the asset download,
`--force` / `-Force` to rebuild the virtualenv.

### Start

```bash
python scripts/run.py web      # WebUI -> http://localhost:8501
python scripts/run.py api      # API   -> http://localhost:8080/docs
```

### Manual

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp config.example.toml config.toml                  # then add API keys
python main.py                                      # or: streamlit run webui/Main.py
```

### Preflight check

```bash
python scripts/doctor.py
```

Verifies Python version, dependencies, ffmpeg, config, runtime assets and free
ports. Exit code 0 = ready. Use it whenever something "doesn't start" — it names
the actual cause instead of leaving you with a stack trace.

## Things that already work, so you don't have to fix them

| Concern | Status |
|---|---|
| **ffmpeg** | Not needed. `imageio-ffmpeg` ships a static binary; the doctor confirms it resolves. |
| **config.toml** | Auto-created from `config.example.toml` on first run. Never commit it — it holds keys. |
| **Python version** | Needs 3.11+. The setup scripts detect it and refuse to continue otherwise. |
| **Windows** | Full path: `setup.ps1` → `run.py`. If scripts are blocked: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`. |
| **Remote/container use** | `run.py` sets the Streamlit flags (`enableCORS`, `enableXsrfProtection`, bind `0.0.0.0`) needed for a browser not on localhost. |

## Repository tooling (added during import)

| File | Purpose |
|---|---|
| `scripts/setup.sh` / `setup.ps1` | one-command bootstrap: venv, deps, config, assets, check |
| `scripts/doctor.py` | preflight diagnosis — run this first when something fails |
| `scripts/run.py` | launcher for WebUI and API with the correct flags |
| `scripts/verify-import.sh` | read-only completeness check for an import |
| `scripts/fetch-resources.sh` / `.ps1` | restore the excluded binary assets |
| `scripts/make-clean-zip.sh` / `.ps1` | build an upload-ready zip, excluding dependencies and builds |

## Notes on the original upload problem

Drag-and-drop into a browser drops nested folders and dot-files. A 134 MB zip
cannot be committed — GitHub rejects anything over 100 MB per file. The imported
tree is **8 MB** of real source; the other 198 MB was fonts, music and
dependencies.
