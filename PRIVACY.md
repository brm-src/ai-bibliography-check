# Privacy notes

`ai bibliography check` is a local Omarchy interface with an online analysis action.

## What stays local

- The plugin reads the Wayland primary selection or clipboard only to prefill the editor.
- The pasted bibliography and report remain in memory inside the running Quickshell process.
- The plugin does not create a history file, cache, database, KV namespace, R2 object, or local state file for text.

## What leaves the computer

When the user presses `check` / `revisar`, the current text is sent over HTTPS to the public aismell bibliography Worker. The Worker performs structural checks and runs the aismell analyzer over the first 3,000 characters.

The Worker has no application storage for submitted text and returns `Cache-Control: no-store`. Cloudflare still handles the request as infrastructure, so this tool is not appropriate for passwords, private keys, regulated information, confidential client material, or text that must stay offline. Cloudflare's service and retention policies apply to infrastructure outside this repository.

The plugin does not request an API key, install packages, request elevated privileges, execute downloaded code, or send desktop telemetry.
