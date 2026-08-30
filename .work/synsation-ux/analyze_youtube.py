#!/usr/bin/env python3
"""Analyze public YouTube videos with Gemini and save evidence incrementally."""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

DEFAULT_MODEL = "gemini-3.7-flash"
DEFAULT_PILOT_ID = "c-G-p7REUd0"
YOUTUBE_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")

PROMPT = r"""
Analyze the supplied video itself using both its audio and sampled visual frames. Do not use
the title, general knowledge, search snippets, or assumptions as substitutes for evidence.
Return JSON only, matching the structure below. Use MM:SS timestamps. If speech is unclear,
write "[unclear]" and explain the uncertainty. Never invent missing words or visual details.

{
  "source_identity": {"video_id": "...", "source_url": "..."},
  "analysis_coverage": {
    "audio_analyzed": true,
    "visuals_analyzed": true,
    "timestamp_ranges_reviewed": ["MM:SS-MM:SS"],
    "limitations": ["..."]
  },
  "transcript": [
    {"start": "MM:SS", "end": "MM:SS", "speech": "faithful transcript or [unclear]"}
  ],
  "visual_demonstrations": [
    {
      "timestamp": "MM:SS",
      "observation": "Concrete visible UI, cursor/touch action, state, labels, layout, and change",
      "before": "What is visibly shown before, or null",
      "after": "What is visibly shown after, or null",
      "certainty": "high|medium|low"
    }
  ],
  "creator_derived_lessons": [
    {
      "timestamps": ["MM:SS"],
      "creator_statement_paraphrase": "What the creator says, not analyst inference",
      "visual_evidence": "What the video visibly demonstrates",
      "ux_problem": "...",
      "recommended_change": "...",
      "specific_visual_or_interaction_change": "...",
      "creator_reasoning": "...",
      "applicable_context": "...",
      "stated_exceptions": "... or none stated",
      "claim_type": "usability|accessibility|aesthetic preference|mixed|unclear",
      "uncertainties": ["..."]
    }
  ],
  "analyst_interpretation": {
    "interpretation": "Separate synthesis; do not attribute this to the creator",
    "inferences_not_shown_or_said": ["..."]
  },
  "spot_check_visuals": [
    {"timestamp": "MM:SS", "observation": "Specific visible fact a human can verify"},
    {"timestamp": "MM:SS", "observation": "A second specific visible fact a human can verify"}
  ],
  "overall_uncertainties": ["..."]
}

Include at least two concrete timestamped visual observations in both visual_demonstrations
and spot_check_visuals. The transcript must cover all intelligible spoken content. Keep
creator statements separate from analyst interpretation. Do not add independent UX advice.
""".strip()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_youtube_url(url: str) -> tuple[str, str]:
    parsed = urlparse(url.strip())
    host = (parsed.hostname or "").lower()
    video_id = ""
    if host in {"youtube.com", "www.youtube.com", "m.youtube.com"} and parsed.path == "/watch":
        video_id = parse_qs(parsed.query).get("v", [""])[0]
    elif host == "youtu.be":
        video_id = parsed.path.lstrip("/").split("/", 1)[0]
    elif host in {"youtube.com", "www.youtube.com", "m.youtube.com"}:
        match = re.match(r"^/(?:shorts|embed)/([^/]+)", parsed.path)
        if match:
            video_id = match.group(1)
    if not YOUTUBE_ID.fullmatch(video_id):
        raise ValueError(f"Unsupported or invalid public YouTube URL: {url}")
    return f"https://www.youtube.com/watch?v={video_id}", video_id


def load_manifest(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    unique: dict[str, dict[str, Any]] = {}
    for item in payload["videos"]:
        canonical, video_id = normalize_youtube_url(item["original_url"])
        if item.get("video_id") != video_id or item.get("canonical_url") != canonical:
            raise ValueError(f"Manifest identity mismatch for {item.get('title', video_id)}")
        unique.setdefault(video_id, item)
    if len(unique) != payload.get("video_count"):
        raise ValueError("Manifest video_count does not match normalized unique URLs")
    return list(unique.values())


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def serialize_response(response: Any) -> Any:
    if hasattr(response, "model_dump"):
        return response.model_dump(mode="json", exclude_none=False)
    if hasattr(response, "to_json_dict"):
        return response.to_json_dict()
    return {"output_text": getattr(response, "output_text", None), "repr": repr(response)}


def parse_output(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    result = json.loads(cleaned)
    required = {"analysis_coverage", "transcript", "visual_demonstrations", "creator_derived_lessons", "analyst_interpretation", "spot_check_visuals", "overall_uncertainties"}
    missing = sorted(required - result.keys())
    if missing:
        raise ValueError(f"Model JSON is missing required fields: {', '.join(missing)}")
    if len(result.get("spot_check_visuals", [])) < 2 or len(result.get("visual_demonstrations", [])) < 2:
        raise ValueError("Model response lacks two timestamped visual observations")
    coverage = result.get("analysis_coverage", {})
    if coverage.get("audio_analyzed") is not True or coverage.get("visuals_analyzed") is not True:
        raise ValueError("Model did not confirm both audio and visual analysis")
    return result


def output_text(response: Any) -> str:
    text = getattr(response, "output_text", None)
    if not text:
        raise ValueError("Gemini response contained no output_text")
    return text


def call_gemini(video: dict[str, Any], model: str, attempts: int) -> Any:
    try:
        from google import genai
        from google.genai import errors
    except ImportError as exc:
        raise RuntimeError("Official Google Gen AI SDK is absent; install requirements.txt in the local venv") from exc

    client = genai.Client()
    try:
        for attempt in range(1, attempts + 1):
            try:
                return client.interactions.create(
                    model=model,
                    input=[
                        {"type": "video", "uri": video["canonical_url"]},
                        {"type": "text", "text": PROMPT},
                    ],
                )
            except errors.APIError as exc:
                retryable = exc.code == 429 or (isinstance(exc.code, int) and exc.code >= 500)
                if not retryable or attempt == attempts:
                    raise
                delay = 10 * (2 ** (attempt - 1)) + random.uniform(0, 2)
                print(f"Gemini returned {exc.code}; retrying in about {delay:.0f}s ({attempt}/{attempts})", file=sys.stderr)
                time.sleep(delay)
    finally:
        client.close()


def process_video(root: Path, selected: dict[str, Any], model: str, attempts: int, force: bool) -> str:
    result_dir = root / "analysis" / "youtube" / selected["video_id"]
    status_path = result_dir / "status.json"
    result_path = result_dir / "extraction.json"
    if result_path.exists() and not force:
        print(f"Skipping completed video: {selected['video_id']} ({result_path})")
        return "skipped"

    status = {
        "video_id": selected["video_id"],
        "source_url": selected["canonical_url"],
        "original_url": selected["original_url"],
        "title": selected["title"],
        "model": model,
        "status": "processing",
        "started_at": utc_now(),
        "attempt_limit": attempts,
    }
    atomic_json(status_path, status)
    try:
        response = call_gemini(selected, model, attempts)
        atomic_json(result_dir / "raw-response.json", serialize_response(response))
        text = output_text(response)
        extraction = parse_output(text)
        model_source_identity = extraction.get("source_identity")
        extraction["source_identity"] = {
            "video_id": selected["video_id"],
            "source_url": selected["canonical_url"],
        }
        if model_source_identity != extraction["source_identity"]:
            extraction["model_reported_source_identity"] = model_source_identity
        extraction["workspace_source"] = {
            "video_id": selected["video_id"],
            "original_url": selected["original_url"],
            "canonical_url": selected["canonical_url"],
            "title": selected["title"],
            "category": selected["category"],
            "series_part": selected["series_part"],
            "model": model,
            "processed_at": utc_now(),
        }
        atomic_json(result_path, extraction)
        status.update({"status": "succeeded", "completed_at": utc_now(), "extraction": str(result_path)})
        atomic_json(status_path, status)
        print(f"Completed {selected['video_id']}: {result_path}")
        return "succeeded"
    except Exception as exc:
        status.update({"status": "failed", "failed_at": utc_now(), "error_type": type(exc).__name__, "error": str(exc)})
        atomic_json(status_path, status)
        print(f"Failed {selected['video_id']}: {type(exc).__name__}: {exc}", file=sys.stderr)
        return "failed"


def main() -> int:
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=root / "youtube-videos.json")
    parser.add_argument("--video-id", help=f"single video ID; defaults to pilot {DEFAULT_PILOT_ID}")
    parser.add_argument("--all", action="store_true", help="process all remaining manifest videos sequentially")
    parser.add_argument("--pilot-confirmed", action="store_true", help="required safety gate for --all")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--attempts", type=int, default=3)
    parser.add_argument("--delay-seconds", type=float, default=5.0)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    videos = load_manifest(args.manifest)
    if args.all and args.video_id:
        parser.error("use either --all or --video-id, not both")
    if args.all and not args.pilot_confirmed:
        parser.error("--all requires --pilot-confirmed after the human has approved the pilot")
    if not 1 <= args.attempts <= 3:
        parser.error("--attempts must be between 1 and 3")
    if not 0 <= args.delay_seconds <= 300:
        parser.error("--delay-seconds must be between 0 and 300")

    if args.all:
        selected_videos = videos
    else:
        requested_id = args.video_id or DEFAULT_PILOT_ID
        selected = next((item for item in videos if item["video_id"] == requested_id), None)
        if selected is None:
            parser.error(f"video ID {requested_id!r} is not in the manifest")
        selected_videos = [selected]

    if args.dry_run:
        print(json.dumps({
            "mode": "dry-run",
            "model": args.model,
            "request_count": len(selected_videos),
            "requests_are_sequential": True,
            "video_inputs": [
                {"type": "video", "uri": item["canonical_url"], "video_id": item["video_id"]}
                for item in selected_videos
            ],
            "prompt_position": "after each video input",
            "output_root": str(root / "analysis" / "youtube"),
        }, indent=2))
        return 0

    if not os.environ.get("GEMINI_API_KEY"):
        parser.error("GEMINI_API_KEY is absent; set it locally without writing it to this workspace")
    if os.environ.get("GEMINI_USAGE_MODE") != "free-tier":
        parser.error("Set GEMINI_USAGE_MODE=free-tier only after confirming the API project has billing disabled")

    failures = 0
    consecutive_failures = 0
    for index, selected in enumerate(selected_videos):
        outcome = process_video(root, selected, args.model, args.attempts, args.force)
        if outcome == "failed":
            failures += 1
            consecutive_failures += 1
            if consecutive_failures >= 3:
                print("Stopping after three consecutive video failures.", file=sys.stderr)
                break
        elif outcome == "succeeded":
            consecutive_failures = 0
        if index < len(selected_videos) - 1 and outcome != "skipped" and args.delay_seconds:
            time.sleep(args.delay_seconds)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
