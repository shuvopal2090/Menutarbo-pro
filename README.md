# Menutarbo-pro

> **Status: source not imported yet.** This repo currently holds only setup files.
> Follow *Adding your project* below, then run the import check.

## Adding your project (ZIP route — recommended)

Drag-and-drop usually loses files, so upload a **single zip** instead:

1. On your computer, zip the **whole project folder** (right-click → *Compress* /
   *Send to › Compressed (zipped) folder*).
   - On macOS, `Command + Shift + .` reveals hidden files first, so `.gitignore`,
     `.env.example` and `.github/` are included.
   - Exclude `node_modules/`, `dist/`, `.next/`, `venv/` — they are rebuilt, and
     they are the main reason big drops fail.
2. Drop the `.zip` into the chat.
3. It gets extracted into this repo, then the check below is run.

## Why drag-and-drop loses files

| Cause | What disappears |
|---|---|
| Browsers drop a folder as *top-level files only* | everything inside `src/`, `components/`, `assets/` |
| Hidden files are skipped | `.gitignore`, `.env`, `.editorconfig`, `.github/` |
| Ignore rules apply to the workspace | `node_modules/`, `dist/`, `build/`, `.next/`, `__pycache__/` |
| Size / MIME limits on drop | large binaries: video, fonts, datasets, archives |
| Empty folders | git cannot store a directory with no files in it |

## Verify nothing is missing

```bash
bash scripts/verify-import.sh
```

Read-only. It reports:

1. how many files git will actually keep
2. files that exist but are **git-ignored** (the usual "it vanished" cause)
3. empty directories
4. files over 5 MB
5. dot-files, `.gitignore`, `.env.example`, `.editorconfig`
6. detected entrypoints (`package.json`, `index.html`, `requirements.txt`, …)
7. any tracked `.env` file — secrets must never be committed

## Alternative: push from your own machine

Best for large projects.

```bash
git clone https://github.com/shuvopal2090/Menutarbo-pro.git
cd Menutarbo-pro
# copy your project files in (keep the existing .gitignore)
git add -A
git status                 # confirm the file list before committing
git commit -m "Import project source"
git push
```

If a file refuses to add, `git check-ignore -v path/to/file` shows which rule is
blocking it.

## Layout

```
.
├── .gitignore              # dependencies, builds, caches, secrets, OS noise
├── README.md
└── scripts/
    └── verify-import.sh    # post-import completeness check
```
