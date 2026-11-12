#!/usr/bin/env python3
"""Check every `koala` command in the skill against a real koala binary.

  scripts/test-skill.py [KOALA]

Each command line in skills/koala/SKILL.md and reference/recipes.md runs with
--socket pointing at nothing, so no manager is touched and nothing changes:
the CLI either refuses the syntax (a usage error, exit 2: FAIL) or gets as far
as needing the manager (PASS). One PASS or FAIL line each, then RESULT.
"""
import re
import subprocess
import sys
from pathlib import Path

KOALA = sys.argv[1] if len(sys.argv) > 1 else "koala"
ROOT = Path(__file__).resolve().parent.parent / "skills/koala"
PLACEHOLDERS = {"IMAGE": "docker.io/library/alpine:3", "EXECUTION": "0e8f7c1a-1111-4222-8333-444455556666",
                "POLICY": "openai-main", "VM": "dev", "$PWD": "/tmp"}


def commands():
    for path in (ROOT / "SKILL.md", ROOT / "reference/recipes.md"):
        for block in re.findall(r"```sh\n(.*?)```", path.read_text(), re.S):
            for line in block.splitlines():
                line = line.split("   #")[0].strip()
                if line.startswith("koala "):
                    yield path.name, line


def main():
    results = []
    for source, line in commands():
        text = line
        for key, value in PLACEHOLDERS.items():
            text = re.sub(rf"(?<![A-Za-z_]){re.escape(key)}(?![A-Za-z_])", value, text)
        words = subprocess.run(["sh", "-c", f'for w in {text[len("koala "):]}; do printf "%s\\0" "$w"; done'],
                               capture_output=True).stdout.decode().split("\0")[:-1]
        try:
            run = subprocess.run([KOALA, "--socket", "/tmp/koala-skill-test-none.sock", *words],
                                 stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=20)
            output = (run.stdout + run.stderr).strip()
            # A command meant for the user's own terminal (-it, a key prompt)
            # is refused here only for want of one: its syntax was accepted.
            interactive = any(m in output for m in ("needs a terminal", "no terminal for the prompt"))
            usage = not interactive and (run.returncode == 2 or "for more information" in output)
        except subprocess.TimeoutExpired:
            output, usage, interactive = "timed out", True, False
        results.append(not usage)
        print(("FAIL " if usage else "PASS ") + f"{source}: {line}"
              + (" (syntax accepted; needs a terminal)" if interactive else "")
              + (f" -- {output[:200]}" if usage else ""))
    print(f"RESULT {sum(results)} passed, {len(results) - sum(results)} failed")
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
