#!/usr/bin/env python3
"""Bridge from the Omarchy panel to the aismell bibliography service."""

from __future__ import annotations

import json
import subprocess
import sys
from typing import Any

MAX_CHARS = 12_000
CHECK_URL = "https://aismell-rewrite.brmcl.workers.dev/bibliography"


def _post_check(text: str) -> dict[str, Any] | None:
    try:
        completed = subprocess.run(
            [
                "curl", "--silent", "--show-error", "--fail-with-body", "--max-time", "25",
                "--request", "POST", CHECK_URL,
                "--header", "Content-Type: application/json",
                "--data-binary", "@-",
            ],
            input=json.dumps({"text": text}, ensure_ascii=False),
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if completed.returncode:
        return None
    try:
        data = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def check_payload(text: str) -> dict[str, object]:
    if not text.strip():
        return {"ok": False, "errorCode": "empty"}
    if len(text) > MAX_CHARS:
        return {"ok": False, "errorCode": "too-long"}

    result = _post_check(text)
    if not result or not isinstance(result.get("score"), int) or not isinstance(result.get("findings"), list):
        return {"ok": False, "errorCode": "check-unavailable"}
    return {"ok": True, "report": result}


def _read_clipboard() -> str:
    for command in (
        ["wl-paste", "--primary", "--no-newline"],
        ["wl-paste", "--no-newline"],
    ):
        try:
            completed = subprocess.run(command, check=False, capture_output=True, text=True, timeout=3)
        except (OSError, subprocess.TimeoutExpired):
            continue
        if completed.returncode == 0 and completed.stdout:
            return completed.stdout
    return ""


def _read_stdin_text() -> str:
    chunks: list[str] = []
    while True:
        character = sys.stdin.read(1)
        if not character or character == "\x1e":
            return "".join(chunks)
        chunks.append(character)


def clipboard_payload() -> dict[str, object]:
    text = _read_clipboard()
    return {"ok": True, "source": text[:MAX_CHARS], "truncated": len(text) > MAX_CHARS}


def main(argv: list[str] | None = None) -> int:
    command = (argv or sys.argv[1:])[:1]
    if command == ["read-clipboard"]:
        payload = clipboard_payload()
    elif command == ["check-stdin"]:
        payload = check_payload(_read_stdin_text())
    else:
        payload = {"ok": False, "errorCode": "invalid-command"}
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
