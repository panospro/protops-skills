# Synsation UX video-analysis workspace

Portable workspace for grounding a future UX/UI Codex skill in Katherine Gilligan / `synsation_` videos. It uses user-supplied public YouTube URLs as actual Gemini video inputs. Instagram tooling and downloaded dependencies are intentionally excluded.

## Current state

- 24 normalized, unique YouTube videos in `youtube-videos.json`.
- 1 video successfully analyzed with audio and visuals: `c-G-p7REUd0`, Build for Good UX Part 3.
- The user accepted the pilot and requested laptop continuation.
- 23 videos remain.
- No creator-derived skill has been created or registered.

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

The batch runner skips existing successful extractions, waits five seconds between attempted videos, retries only 429/server errors up to three times, and stops after three consecutive video failures.

## Evidence layout

- `analysis/youtube/<video-id>/raw-response.json`: complete Gemini interaction response.
- `analysis/youtube/<video-id>/extraction.json`: parsed transcript, visual demonstrations, creator lessons, and separate model interpretation.
- `analysis/youtube/<video-id>/status.json`: resumable processing state.
- `analysis/extraction-template.md`: human-readable evidence requirements.
- `analysis/pilot-report.md`: pilot lessons, spot-checks, and known limitations.

Do not create or register the skill until the available collection has been processed, failures and gaps are reported, and creator-derived principles can be traced to successful per-video evidence. Never claim coverage beyond successful records.
