# Synsation UX video-analysis workspace

Portable workspace for grounding a future UX/UI Codex skill in Katherine Gilligan / `synsation_` videos. It uses user-supplied public YouTube URLs as actual Gemini video inputs. Instagram tooling and downloaded dependencies are intentionally excluded.

## Current state

- 24 normalized, unique YouTube videos in `youtube-videos.json`.
- All 24 videos successfully analyzed with audio and visuals. Good-UX parts 1–10 and 13 (plus the pilot) used `gemini-3.7-flash`; parts 11, 12, 14–16, the 4 dark-side videos, and the 4 standalone loading videos used `gemini-3.6-flash` after the 3.7-flash free-tier buckets were exhausted (each extraction records its model in `workspace_source`). Part 1 (`w90jr50IvKw`) was recovered locally from its saved raw response after an invalid-escape parse failure; its `status.json` records the provenance.
- Free-tier facts learned the hard way: quota is per-model per-day (`generate_content_free_tier_requests`, limit 20 on flash models, resets midnight Pacific), and the SDK's hidden internal retry layer multiplies request spend unless disabled (see `call_gemini`).

Read `analysis/pilot-report.md` and the pilot directory before continuing. Every creator-derived lesson must retain a source URL and timestamp. Keep model/analyst interpretation separate from creator statements.

## Laptop setup

Use Python 3.11+ in an isolated environment:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest -v test_analyze_youtube.py
```

Create a local `.env` containing `GEMINI_API_KEY=...`. Do not commit it, print it, or paste it into chat. Use a Google AI Studio project with billing disabled unless the user separately approves spending.

Run a no-cost local request-shape check:

```bash
.venv/bin/python analyze_youtube.py --dry-run
.venv/bin/python analyze_youtube.py --all --pilot-confirmed --dry-run
```

Load the key and resume the remaining videos sequentially:

```bash
set -a
source .env
set +a
export GEMINI_USAGE_MODE=free-tier
.venv/bin/python analyze_youtube.py --all --pilot-confirmed
unset GEMINI_API_KEY GEMINI_USAGE_MODE
```

The batch runner skips existing successful extractions, waits five seconds between attempted videos (tune with `--delay-seconds`), retries only server (5xx) errors up to three times, fails fast on 429 to preserve the daily free-tier budget, and stops after three consecutive video failures. The SDK's own hidden retry layer (up to 3 extra requests per call on 408/409/429/5xx) is disabled in `call_gemini`, so one attempt costs exactly one request.

## Evidence layout

- `analysis/youtube/<video-id>/raw-response.json`: complete Gemini interaction response.
- `analysis/youtube/<video-id>/extraction.json`: parsed transcript, visual demonstrations, creator lessons, and separate model interpretation.
- `analysis/youtube/<video-id>/status.json`: resumable processing state.
- `analysis/extraction-template.md`: human-readable evidence requirements.
- `analysis/pilot-report.md`: pilot lessons, spot-checks, and known limitations.

The production skill lives in the repo at `plugins/good-ux/` (registered in the marketplace) and is installed for Codex at `~/.codex/skills/good-ux/`. Per the user's direction, the installed copies carry no video URLs, part numbers, or creator attribution — the full evidence trail (per-rule source video + timestamps) remains recoverable from `analysis/youtube/*/extraction.json` here, and an attributed draft of the references exists at `skill/good-ux/` in this workspace. Validation on a representative interface task is still pending.
