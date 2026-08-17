#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -f "$config_home/hypr/hyprland.lua" ]]; then
  bindings_file="$config_home/hypr/bindings.lua"
  begin="-- ai bibliography check: begin"
  end="-- ai bibliography check: end"
  binding="o.bind(\"SUPER + SHIFT + B\", \"bibliography check\", \"omarchy-shell shell summon io.github.brm-src.ai-bibliography-check '{}'\")"
else
  bindings_file="$config_home/hypr/bindings.conf"
  begin="# ai bibliography check: begin"
  end="# ai bibliography check: end"
  binding="bindd = SUPER SHIFT, B, bibliography check, exec, omarchy-shell shell summon io.github.brm-src.ai-bibliography-check '{}'"
fi

python3 - "$bindings_file" "$begin" "$end" "$binding" "${1:-}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
begin, end, binding, mode = sys.argv[2:]
text = path.read_text(encoding="utf-8") if path.exists() else ""
block = "\n".join([begin, binding, end, ""])
pattern = re.compile(re.escape(begin) + r"\n.*?" + re.escape(end) + r"\n?", re.DOTALL)
updated = pattern.sub("", text)
if mode != "--remove":
    updated = updated.rstrip("\n") + ("\n" if updated else "") + block
path.parent.mkdir(parents=True, exist_ok=True)
temporary = path.with_name(path.name + ".ai-bibliography-check.tmp")
temporary.write_text(updated, encoding="utf-8")
temporary.replace(path)
PY

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi

if [[ "${1:-}" == "--remove" ]]; then
  printf 'Shortcut removed.\n'
else
  printf 'Ready: Super + Shift + B.\n'
fi
