#!/usr/bin/env python3
"""Writes the release notes for one version to stdout: .github/release-notes.md with the version and that version's CHANGELOG.md section."""
import re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
version = sys.argv[1].lstrip("v")
log = (root / "CHANGELOG.md").read_text()
m = re.search(r"^## " + re.escape(version) + r"[^\n]*\n(.*?)(?=^## |\Z)", log, re.S | re.M)
if not m:
    sys.exit(f"CHANGELOG.md has no '## {version}' section")
print((root / ".github/release-notes.md").read_text().replace("{{VERSION}}", version).replace("{{CHANGES}}", m.group(1).strip()))
