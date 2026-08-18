#!/usr/bin/env python3
"""Bridge from the Omarchy panel to the aismell bibliography service."""

from __future__ import annotations

import json
import subprocess
import sys
import unicodedata
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen

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


def _normal_tokens(value: str) -> set[str]:
    normalized = unicodedata.normalize("NFKD", str(value or "")).encode("ascii", "ignore").decode().lower()
    return {token for token in "".join(character if character.isalnum() else " " for character in normalized).split() if len(token) > 2}


def _overlap(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / max(len(left), len(right))


def _openalex_lookup(entry: dict[str, Any]) -> tuple[str, float, dict[str, Any] | None]:
    identifier = str(entry.get("identifier") or "")
    if identifier.startswith("doi:"):
        params = {"filter": f"doi:https://doi.org/{identifier[4:]}", "per-page": "3"}
    else:
        query = " ".join(filter(None, [str(entry.get("title") or ""), str(entry.get("authorPrefix") or "")]))
        params = {"search": query[:500], "per-page": "3"}
    url = "https://api.openalex.org/works?" + urlencode(params)
    request = Request(url, headers={"Accept": "application/json", "User-Agent": "ai-bibliography-check/1.0"})
    try:
        with urlopen(request, timeout=12) as response:
            payload = json.load(response)
    except Exception:
        return "unavailable", 0.0, None

    candidates = payload.get("results") if isinstance(payload, dict) else []
    ranked = []
    for candidate in candidates or []:
        title = str(candidate.get("title") or "")
        authors = "; ".join(
            str(item.get("author", {}).get("display_name") or "")
            for item in candidate.get("authorships", [])[:2]
        )
        year = candidate.get("publication_year")
        doi = str(candidate.get("doi") or "")
        if identifier.startswith("doi:"):
            score = 1.0 if identifier[4:].lower() in doi.lower() else 0.0
        else:
            score = (
                _overlap(_normal_tokens(str(entry.get("title") or "")), _normal_tokens(title)) * 0.72
                + _overlap(_normal_tokens(str(entry.get("authorPrefix") or "")), _normal_tokens(authors)) * 0.18
                + (0.10 if str(entry.get("year") or "")[:4] == str(year or "")[:4] else 0.0)
            )
        ranked.append((score, {
            "source": "OpenAlex",
            "title": title,
            "author": authors,
            "year": year,
            "doi": doi or None,
            "url": candidate.get("primary_location", {}).get("landing_page_url") or candidate.get("id"),
        }))
    if not ranked:
        return "empty", 0.0, None
    score, match = max(ranked, key=lambda item: item[0])
    return ("found" if score >= 0.72 else "possible" if score >= 0.60 else "not-found"), round(score, 2), match if score >= 0.60 else None


def _merge_local_openalex(report: dict[str, Any]) -> None:
    lookup = report.get("lookup")
    if not isinstance(lookup, dict):
        return
    entries = report.get("entries") or []
    results = lookup.get("results") or []
    for result, entry in zip(results, entries):
        sources = result.get("sources") or []
        openalex = next((source for source in sources if source.get("source") == "OpenAlex"), None)
        if not openalex or openalex.get("status") != "unavailable":
            continue
        status, score, match = _openalex_lookup(entry)
        openalex.update({"status": "responded" if status != "unavailable" else "unavailable", "transport": "local-helper"})
        if status in {"found", "possible"} and (result.get("status") in {"not-found", "unavailable"} or score > float(result.get("score") or 0)):
            result["status"] = status
            result["score"] = score
            result["match"] = match
    lookup["transportFallback"] = "local OpenAlex fallback used when the Worker could not reach OpenAlex"


def check_payload(text: str) -> dict[str, object]:
    if not text.strip():
        return {"ok": False, "errorCode": "empty"}
    if len(text) > MAX_CHARS:
        return {"ok": False, "errorCode": "too-long"}

    result = _post_check(text)
    if not result or not isinstance(result.get("score"), int) or not isinstance(result.get("findings"), list):
        return {"ok": False, "errorCode": "check-unavailable"}
    _merge_local_openalex(result)
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
