# Handoff prompt

Copy the prompt below into Codex on the laptop after opening this workspace.

---

Continue the existing `synsation-ux` workspace on this laptop. Execute the work rather than only describing a plan.

First read any applicable `AGENTS.md`, then read `README.md`, `analysis/pilot-report.md`, `analysis/extraction-template.md`, `youtube-videos.json`, and the completed pilot artifacts under `analysis/youtube/c-G-p7REUd0/`. Read the available `skill-creator` guidance because the eventual deliverable is a Codex skill, but do not create or register the skill prematurely.

Current verified state:

- The manifest contains 24 normalized unique public YouTube videos.
- Gemini successfully processed pilot `c-G-p7REUd0` using audio and visual video input.
- The user accepted the pilot and requested continuation on this laptop.
- Exactly 1/24 videos has a successful extraction; 23 remain.
- No creator-derived skill exists or is registered.

Inspect the laptop environment and recreate an isolated Python environment from `requirements.txt`. Check the current official Gemini YouTube video-input documentation before making API requests. Read `GEMINI_API_KEY` from the local `.env` without printing or logging it. Confirm the project remains billing-disabled/free-tier; do not enable billing or incur paid usage without explicit approval.

Run the tests and dry runs first. Then resume the remaining videos with the existing sequential, resumable workflow (`analyze_youtube.py --all --pilot-confirmed`). Each request must contain one actual typed YouTube video input, not a URL pasted into prose. Preserve raw responses, statuses, transcripts, timestamped visual observations, creator-derived lessons, uncertainties, and separate analyst/model interpretation. Skip completed results, handle rate limits conservatively, and stop after repeated failures. Do not substitute search snippets or generic UX knowledge for failed video analysis.

After processing, audit every successful extraction. Report exact successful, failed, inaccessible, and remaining counts. Flag questionable transcriptions, visual claims, contradictions, aesthetic preferences, unsupported accessibility claims, and anything requiring human review. Every creator-derived principle must link to a successful video URL and timestamp.

Only after that evidence audit, deduplicate and organize the supported lessons into a concise reusable Codex skill. Keep detailed principles/examples in focused references with source attribution; keep raw videos/model outputs outside the installed skill. Clearly distinguish the creator's statements, independently verified UX guidance, and your synthesis. Do not universalize context-dependent advice. Validate the skill with the available validator and test it on a representative interface task. Preserve unrelated repository changes and do not publish anything publicly.

At handoff, report the skill location, invocation, exact video coverage, gaps, and how to resume or add videos later.

---
