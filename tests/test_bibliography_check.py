"""Tests for the bibliography service bridge."""

import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

import bibliography_check
from bibliography_check import check_payload, main


BIBLIOGRAPHY = "[1] García, M. (2024). Manual de investigación. https://doi.org/10.1234/demo"


class BibliographyCheckTests(unittest.TestCase):
    def test_posts_only_after_local_validation(self):
        sent = {}

        def fake_post(text):
            sent["text"] = text
            return {"score": 100, "findings": [], "entryCount": 1}

        with patch.object(bibliography_check, "_post_check", side_effect=fake_post):
            self.assertEqual(check_payload(BIBLIOGRAPHY), {
                "ok": True,
                "report": {"score": 100, "findings": [], "entryCount": 1},
            })
        self.assertEqual(sent, {"text": BIBLIOGRAPHY})

    def test_rejects_empty_and_oversized_text_without_network(self):
        with patch.object(bibliography_check, "_post_check", side_effect=AssertionError("network call")):
            self.assertEqual(check_payload(" "), {"ok": False, "errorCode": "empty"})
            self.assertEqual(check_payload("x" * 12_001), {"ok": False, "errorCode": "too-long"})

    def test_does_not_claim_success_for_bad_service_response(self):
        with patch.object(bibliography_check, "_post_check", return_value={"error": "unavailable"}):
            self.assertEqual(check_payload(BIBLIOGRAPHY), {"ok": False, "errorCode": "check-unavailable"})

    def test_uses_local_openalex_fallback_when_worker_cannot_reach_it(self):
        report = {
            "score": 100,
            "findings": [],
            "entries": [{"number": 1, "title": "Manual de investigación", "authorPrefix": "García, M.", "year": "2024", "identifier": "doi:10.1234/demo"}],
            "lookup": {
                "results": [{
                    "entry": 1,
                    "status": "found",
                    "score": 0.9,
                    "sources": [{"source": "Crossref", "status": "responded"}, {"source": "OpenAlex", "status": "unavailable"}],
                    "match": {"source": "Crossref", "title": "Manual de investigación"},
                }],
            },
        }
        with patch.object(bibliography_check, "_post_check", return_value=report), \
             patch.object(bibliography_check, "_openalex_lookup", return_value=("found", 1.0, {"source": "OpenAlex", "title": "Manual de investigación"})):
            payload = check_payload(BIBLIOGRAPHY)
        result = payload["report"]["lookup"]["results"][0]
        self.assertEqual(result["match"]["source"], "OpenAlex")
        self.assertEqual(result["sources"][1]["status"], "responded")
        self.assertEqual(result["sources"][1]["transport"], "local-helper")

        output = io.StringIO()
        with patch.object(bibliography_check, "_read_clipboard", return_value=BIBLIOGRAPHY), \
             patch.object(bibliography_check, "_post_check", side_effect=AssertionError("opening must not call service")), \
             redirect_stdout(output):
            self.assertEqual(main(["read-clipboard"]), 0)
        self.assertEqual(json.loads(output.getvalue()), {
            "ok": True,
            "source": BIBLIOGRAPHY,
            "truncated": False,
        })

    def test_checks_text_received_on_standard_input(self):
        output = io.StringIO()
        with patch.object(sys, "stdin", io.StringIO(BIBLIOGRAPHY + "\x1e")), \
             patch.object(bibliography_check, "_post_check", return_value={"score": 88, "findings": [], "entryCount": 1}), \
             redirect_stdout(output):
            self.assertEqual(main(["check-stdin"]), 0)
        payload = json.loads(output.getvalue())
        self.assertEqual(payload["report"]["score"], 88)


if __name__ == "__main__":
    unittest.main()
