#!/usr/bin/env python3
"""Generate skills/koala/reference/commands.md from a real `koala` binary's help.

  scripts/skill-commands.py [KOALA]   (default: koala on PATH)

Every usage line and option in the page is the CLI's own text, so the skill
never teaches syntax the installed Koala doesn't accept.
"""
import re
import subprocess
import sys
from pathlib import Path

KOALA = sys.argv[1] if len(sys.argv) > 1 else "koala"
OUT = Path(__file__).resolve().parent.parent / "skills/koala/reference/commands.md"


def help_of(words):
    result = subprocess.run([KOALA, *words, "--help"], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return (result.stdout or result.stderr).rstrip()


def subcommands(text):
    block = re.search(r"^Commands:\n((?:  .*\n?)+)", text, re.M)
    return [] if not block else [line.split()[0] for line in block.group(1).splitlines()
                                 if line.startswith("  ") and not line.startswith("    ")]


def section(words):
    text = help_of(words)
    out = [f"### `koala {' '.join(words)}`", "", "```text", text, "```", ""]
    for sub in subcommands(text):
        out += section([*words, sub])
    return out


def main():
    version = subprocess.run([KOALA, "--version"], capture_output=True, text=True).stdout.strip()
    top = help_of([])
    commands = []
    for line in top.splitlines():
        match = re.match(r"^  ([a-z]+)(?: \([a-z, ]+\))?\s{2,}\S", line)
        if match:
            commands.append(match.group(1))
    lines = ["# Koala commands", "",
             f"Generated from `{version} --help` by `scripts/skill-commands.py`; don't edit by hand.",
             "When the installed Koala is newer, its own `koala COMMAND --help` wins.", "",
             "## `koala`", "", "```text", top, "```", ""]
    for command in commands:
        lines += section([command])
    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT} ({len(commands)} commands, {OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
