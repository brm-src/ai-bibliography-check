# ai bibliography check

<p align="center">
  <a href="https://www.ko-fi.com/brmcl"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi" /></a>
</p>

[Español](README.es.md)

![ai bibliography check preview](preview.svg)

A bilingual Omarchy / Quickshell panel for reviewing pasted bibliographies before submission. It checks the text you provide for missing authors or years, duplicate DOI/URLs, mixed year styles, formulaic writing signals from aismell, and external catalog matches from Crossref and OpenAlex.

It is an editorial checker, not a forensic AI detector. A catalog match is evidence to inspect, not proof that a source is valid or that every metadata field is correct.

## What it does

- Reads the Wayland primary selection first, then the regular clipboard, to prefill the panel.
- Accepts up to 12,000 characters.
- Groups entries separated by blank lines or recognizable entry markers such as `[1]`, `1.`, or `-`.
- Flags entries without a recognizable author or four-digit publication year.
- Detects repeated DOI/URL identifiers and repeated full entries.
- Warns when the list mixes parenthetical years like `(2024)` with bare years like `2024.`.
- Sends DOI-bearing entries to Crossref and OpenAlex for exact lookup; entries without DOI use title + author + year queries.
- Shows `found`, `possible`, `no match`, or `service unavailable` per entry and identifies the catalog that supplied a match.
- Adds a direct Google Scholar search link for each entry; Google Scholar is opened in the browser instead of scraped by the Worker.
- Sends the first 3,000 characters to the aismell analyzer for formulaic-writing signals; structural checks cover the full pasted text.
- Keeps the original text editable and never modifies the focused application automatically.

## Install

```bash
omarchy plugin add https://github.com/brm-src/ai-bibliography-check.git --enable --yes
```

No administrator privileges are required. The plugin needs Omarchy/Hyprland, Quickshell, Python 3, `curl`, and `wl-paste`.

The optional `Super + Shift + B` shortcut is configured separately:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-bibliography-check/configure-shortcut.sh
```

Remove only that shortcut with:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-bibliography-check/configure-shortcut.sh --remove
```

Remove the plugin with:

```bash
omarchy plugin remove io.github.brm-src.ai-bibliography-check --yes
```

## Use

1. Copy a bibliography or paste it into the panel.
2. Keep one entry per line or separate entries with blank lines.
3. Press `check` / `revisar`.
4. Fix high-severity findings first, then decide whether medium findings actually apply to your citation style.

Press `Escape`, `Super + W`, or click outside the card to close it. The `powered by: aismell` footer opens the project site.

## Privacy and data flow

See [PRIVACY.md](PRIVACY.md).

- Opening the panel reads the primary selection or clipboard only to prefill the editor.
- The plugin does not write bibliography text, reports, or clipboard contents to disk.
- Pressing `check` sends the pasted text over HTTPS to the public aismell Worker.
- The Worker keeps no application database, KV namespace, R2 object, Durable Object, or submitted-text store and responds with `Cache-Control: no-store`.
- Do not paste passwords, private keys, confidential client material, or text that must remain offline.

## Limits you should know

- Crossref and OpenAlex can return a catalog match, but that match still needs human review.
- Entries without a DOI are searched by title + author + year and use a similarity score; a low score is shown as `no match`.
- Google Scholar is available as a direct browser search link; the Worker does not scrape Scholar or bypass its CAPTCHA/rate limits.
- Author recognition is intentionally conservative and can flag valid styles that do not begin with a conventional author string.
- Aismell sees only the first 3,000 characters for linguistic signals; local structural checks cover all 12,000 characters.
- The endpoint requires an internet connection.
- A medium finding is a prompt to inspect, not a verdict.

## Development checks

Run these from the repository root:

```bash
python3 -m unittest discover -s tests -q
python3 -m py_compile bibliography_check.py
bash -n configure-shortcut.sh
qmllint -I /usr/share/omarchy/shell BarButton.qml BibliographyCheck.qml
omarchy plugin validate .
git diff --check
```

## License

MIT. See [LICENSE](LICENSE).
