"""Tests for the bibliography service bridge."""

import io
import json
import sys

import bibliography_check
from bibliography_check import check_payload, main


BIBLIOGRAPHY = "[1] García, M. (2024). Manual de investigación. https://doi.org/10.1234/demo"


def test_posts_only_after_local_validation(monkeypatch):
    sent = {}

    def fake_post(text):
        sent["text"] = text
        return {"score": 100, "findings": [], "entryCount": 1}

    monkeypatch.setattr(bibliography_check, "_post_check", fake_post)
    assert check_payload(BIBLIOGRAPHY) == {
        "ok": True,
        "report": {"score": 100, "findings": [], "entryCount": 1},
    }
    assert sent == {"text": BIBLIOGRAPHY}


def test_rejects_empty_and_oversized_text_without_network(monkeypatch):
    monkeypatch.setattr(
        bibliography_check,
        "_post_check",
        lambda text: (_ for _ in ()).throw(AssertionError("network call")),
    )
    assert check_payload(" ") == {"ok": False, "errorCode": "empty"}
    assert check_payload("x" * 12_001) == {"ok": False, "errorCode": "too-long"}


def test_does_not_claim_success_for_bad_service_response(monkeypatch):
    monkeypatch.setattr(bibliography_check, "_post_check", lambda text: {"error": "unavailable"})
    assert check_payload(BIBLIOGRAPHY) == {"ok": False, "errorCode": "check-unavailable"}


def test_reads_clipboard_without_calling_service(monkeypatch, capsys):
    monkeypatch.setattr(bibliography_check, "_read_clipboard", lambda: BIBLIOGRAPHY)
    monkeypatch.setattr(
        bibliography_check,
        "_post_check",
        lambda text: (_ for _ in ()).throw(AssertionError("opening must not call service")),
    )
    assert main(["read-clipboard"]) == 0
    assert json.loads(capsys.readouterr().out) == {
        "ok": True,
        "source": BIBLIOGRAPHY,
        "truncated": False,
    }


def test_checks_text_received_on_standard_input(monkeypatch, capsys):
    monkeypatch.setattr(sys, "stdin", io.StringIO(BIBLIOGRAPHY + "\x1e"))
    monkeypatch.setattr(
        bibliography_check,
        "_post_check",
        lambda text: {"score": 88, "findings": [], "entryCount": 1},
    )
    assert main(["check-stdin"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["report"]["score"] == 88
