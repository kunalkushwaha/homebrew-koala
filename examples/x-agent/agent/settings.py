#!/usr/bin/env python3
"""The X agent's settings and drafts, run in the VM by x-agent.sh.

  settings.py install NEW     check NEW and make it the agent's settings
  settings.py drafts          the drafts, numbered, each beside its post
  settings.py approve N...    go live with only reply drafts N..., as they are
  settings.py approve post    go live with the latest post draft, as it is

The agent's files are in /profile/xagent. Installing settings removes a STOP
file, so the agent starts (or restarts) within 5 s."""
import json
import os
import subprocess
import sys

DIR = "/profile/xagent"
CONFIG = os.path.join(DIR, "config.json")


def records(name):
    out = []
    try:
        with open(os.path.join(DIR, name)) as f:
            for line in f:
                try:
                    out.append(json.loads(line))
                except ValueError:
                    continue
    except OSError:
        pass
    return out


def install(settings):
    me = str(settings.get("me", "")).strip().lstrip("@")
    if not me or me == "YOUR_HANDLE":
        sys.exit('set "me" to your X handle first (x-agent.sh check shows it)')
    os.makedirs(DIR, exist_ok=True)
    with open(CONFIG + ".tmp", "w") as f:
        json.dump(settings, f, indent=2)
    os.replace(CONFIG + ".tmp", CONFIG)
    if os.path.exists(os.path.join(DIR, "STOP")):
        os.remove(os.path.join(DIR, "STOP"))
    subprocess.run(["chown", "-R", "browser:browser", DIR], check=True)
    print("installed: the agent starts within 5 s")


def reply_drafts():
    return [d for d in records("drafts.jsonl") if d.get("kind") != "post"]


def drafts():
    tweets = {t["id"]: t for t in records("tweets.jsonl")}
    posted = records("posted.jsonl")
    replied = {p.get("postId") for p in posted if p.get("kind", "reply") == "reply"}
    texts = {p.get("text") for p in posted if p.get("kind") == "post"}
    replies = reply_drafts()
    if not replies:
        print("no reply drafts yet")
    for n, d in enumerate(replies, 1):
        post = tweets.get(d["postId"], {})
        print(f"[{n}] @{d['author']}  https://x.com/{d['author']}/status/{d['postId']}"
              + ("  (replied)" if d["postId"] in replied else ""))
        print("    post: ", " ".join(str(post.get("text", "")).split())[:240])
        print("    draft:", d["text"])
    for d in [d for d in records("drafts.jsonl") if d.get("kind") == "post"][-3:]:
        print(f"[post] {d['at'][:16]}" + ("  (posted)" if d["text"] in texts else ""))
        print("    draft:", d["text"])


def approve(args):
    settings = json.load(open(CONFIG))
    if args == ["post"]:
        posts = [d for d in records("drafts.jsonl") if d.get("kind") == "post"]
        if not posts:
            sys.exit("no post draft yet")
        settings.setdefault("compose", {}).update(enabled=True, dryRun=False, approvedText=posts[-1]["text"])
        print("approved post:", posts[-1]["text"])
    else:
        replies = reply_drafts()
        try:
            chosen = [replies[int(a) - 1] for a in args]
            if any(int(a) < 1 for a in args) or not chosen:
                raise IndexError
        except (ValueError, IndexError):
            sys.exit(f"choose draft numbers from 1 to {len(replies)} (x-agent.sh drafts)")
        section = settings.setdefault("replies", {})
        section.update(enabled=True, dryRun=False, approved=[{"postId": d["postId"], "text": d["text"]} for d in chosen])
        for d in chosen:
            print(f"approved reply to @{d['author']} ({d['postId']}): {d['text']}")
        if section.get("perDay", 20) < len(chosen):
            print(f"note: replies.perDay is {section['perDay']}, so only {section['perDay']} of these go out today")
    install(settings)


if __name__ == "__main__":
    command, rest = sys.argv[1], sys.argv[2:]
    if command == "install":
        install(json.load(open(rest[0])))
    elif command == "drafts":
        drafts()
    elif command == "approve" and rest:
        approve(rest)
    else:
        sys.exit(__doc__)
