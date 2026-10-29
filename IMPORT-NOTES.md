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

```bash
cp config.example.toml config.toml     # then add your API keys
pip install -r requirements.txt        # or: uv sync
python main.py                         # or: streamlit run webui/Main.py
```

## Repository tooling (added during import)

| File | Purpose |
|---|---|
| `scripts/verify-import.sh` | read-only completeness check for an import |
| `scripts/make-clean-zip.sh` / `.ps1` | build an upload-ready zip, excluding dependencies and builds |
| `scripts/fetch-resources.sh` / `.ps1` | restore the excluded binary assets |

## Notes on the original upload problem

Drag-and-drop into a browser drops nested folders and dot-files. A 134 MB zip
cannot be committed — GitHub rejects anything over 100 MB per file. The imported
tree is **8 MB** of real source; the other 198 MB was fonts, music and
dependencies.
