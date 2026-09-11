#!/usr/bin/env python3
"""Appends one JSON line per SubagentStart/SubagentStop hook event to logs/routing.jsonl.

Prints nothing: hook stdout is injected into the model's context.
"""
import datetime
import json
import os
import sys

log = os.path.join(os.environ.get("CODEX_HOME", os.path.expanduser("~/.codex")), "logs", "routing.jsonl")
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

row = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "event": d.get("hook_event_name"),
    "agent_type": d.get("agent_type"),
    "model": d.get("model"),
    "agent_id": d.get("agent_id"),
    "session_id": d.get("session_id"),
    "turn_id": d.get("turn_id"),
    "cwd": d.get("cwd"),
}
if d.get("hook_event_name") == "SubagentStop":
    row["last_message_chars"] = len(d.get("last_assistant_message") or "")

os.makedirs(os.path.dirname(log), exist_ok=True)
with open(log, "a", encoding="utf-8") as f:
    f.write(json.dumps(row, ensure_ascii=False) + "\n")
