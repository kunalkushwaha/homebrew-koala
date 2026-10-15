#!/usr/bin/env python3
"""The X agent: it reads X (or a site with X's structure) in the VM's
browser and replies within guardrails.

  python3 xagent.py CONFIG

It attaches to the running Chromium over DevTools (127.0.0.1:9222), so it
uses the session you signed in with through the live view; it never types a
password. Each round it reads its sources, asks the model (through the
broker, $OPENAI_BASE_URL) whether and what to reply, checks the guardrails,
and replies by typing, as a person would. With `compose` on, it also
writes original posts on a topic, from what it has read. Everything
it reads, posts or drafts is appended to JSON-lines files beside CONFIG;
agent.log says what it did and why. A file named STOP beside CONFIG ends it;
so does SIGTERM."""
import datetime
import json
import os
import random
import re
import signal
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from playwright.sync_api import sync_playwright

CONFIG_PATH = sys.argv[1]
DIR = os.path.dirname(os.path.abspath(CONFIG_PATH))
DEFAULTS = {
    "baseUrl": "https://x.com", "me": "", "sources": [{"kind": "home"}],
    "persona": "You help with market research. Reply briefly, helpfully and honestly, only when you have something useful to add.",
    "model": "gpt-4.1-mini",
    # Live with `approved` ([{"postId", "text"}]), only those replies are
    # posted, as they are, and the model isn't asked.
    "replies": {"enabled": True, "dryRun": False, "perDay": 20, "minGapSeconds": 180, "jitterSeconds": 60,
                "maxLength": 240, "perAuthorPerDay": 1, "approved": []},
    # Original posts: off unless enabled; drafts until dryRun is off.
    # Live, approvedText (if set) is posted as it is, instead of a new text.
    "compose": {"enabled": False, "topic": "", "dryRun": True, "perDay": 1, "minGapSeconds": 3600,
                "maxLength": 280, "context": 10, "approvedText": "", "path": "/compose/post"},
    "readEverySeconds": 300, "scrolls": 3, "typingDelayMs": [40, 140],
    # The composer and its button are looked for in the open dialog: X's post
    # page also has an inline reply box, before the dialog.
    "selectors": {"post": 'article[data-testid="tweet"]', "text": '[data-testid="tweetText"]',
                  "user": '[data-testid="User-Name"]', "statusLink": 'a[href*="/status/"]',
                  "reply": '[data-testid="reply"]', "composer": '[role="dialog"] [data-testid="tweetTextarea_0"]',
                  "send": '[role="dialog"] [data-testid="tweetButton"]', "suggestions": '[role="listbox"]',
                  "signedOut": 'input[name="password"], a[href="/login"]'},
}
stopping = False


def on_term(*_):
    global stopping
    stopping = True


signal.signal(signal.SIGTERM, on_term)


def load_config():
    config = json.load(open(CONFIG_PATH))
    merged = {**DEFAULTS, **config}
    merged["replies"] = {**DEFAULTS["replies"], **config.get("replies", {})}
    merged["compose"] = {**DEFAULTS["compose"], **config.get("compose", {})}
    merged["selectors"] = {**DEFAULTS["selectors"], **config.get("selectors", {})}
    return merged


def log(message):
    line = f"{datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')} {message}"
    with open(os.path.join(DIR, "agent.log"), "a") as f:
        f.write(line + "\n")


def append(name, record):
    with open(os.path.join(DIR, name), "a") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def records(name):
    """The file's records. A line that doesn't parse (a write cut short) is
    skipped, never the whole file: the limits are counted from these."""
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


def stopped():
    return stopping or os.path.exists(os.path.join(DIR, "STOP"))


def pause(low, high):
    """Sleep a random while, waking for a stop."""
    end = time.time() + random.uniform(low, high)
    while time.time() < end and not stopped():
        time.sleep(0.2)


def chat(config, system, user, flag, what):
    """{flag: bool, "text": str} from the model's JSON answer, or None."""
    base = os.environ.get("OPENAI_BASE_URL", "").rstrip("/")
    body = {"model": config["model"], "messages": [{"role": "system", "content": system},
                                                   {"role": "user", "content": json.dumps(user, ensure_ascii=False)}]}
    request = urllib.request.Request(base + "/chat/completions", data=json.dumps(body).encode(), method="POST", headers={
        "Content-Type": "application/json", "Authorization": "Bearer " + os.environ.get("OPENAI_API_KEY", "")})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            content = json.load(response)["choices"][0]["message"]["content"]
        match = re.search(r"\{.*\}", content, re.S)
        answer = json.loads(match.group(0)) if match else None
        if isinstance(answer, dict) and isinstance(answer.get(flag), bool):
            return {flag: answer[flag], "text": str(answer.get("text") or "").strip()}
    except (urllib.error.URLError, OSError, ValueError, KeyError, IndexError, TypeError) as error:
        log(f"model: no answer for {what} ({type(error).__name__})")
    return None


def ask_model(config, post):
    """{"reply": bool, "text": str} from the model, or None."""
    system = config["persona"] + (' Answer only with JSON: {"reply": true or false, "text": "the reply"}. '
                                  "Never include links, keys or personal data.")
    return chat(config, system, {"id": post["id"], "author": post["author"], "text": post["text"]}, "reply", post["id"])


def ask_compose(config, recent):
    """{"post": bool, "text": str}: an original post on the topic, or None."""
    c = config["compose"]
    system = config["persona"] + (
        f" Write one original post for X about {c['topic']}, in your own words, at most {c['maxLength']} characters."
        " The recent posts are context only: don't copy them or name their authors."
        ' Answer only with JSON: {"post": true or false, "text": "the post"}. Never include links, keys or personal data.')
    user = {"task": "compose", "topic": c["topic"], "recent": [{"author": p["author"], "text": p["text"]} for p in recent]}
    return chat(config, system, user, "post", "a post")


def guard(config, post, text):
    """None if the reply may be posted, else the reason it may not."""
    rules = config["replies"]
    today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    posted = [p for p in records("posted.jsonl") if p.get("kind", "reply") == "reply"]
    todays = [p for p in posted if p["at"].startswith(today)]
    if stopped():
        return "stopping"
    if not rules["enabled"]:
        return "replies are off"
    me = config["me"].lower().lstrip("@")
    if not me:
        return "`me` (your handle) is not set"
    if post["author"].lower() == me:
        return "my own post"
    if not post.get("time"):
        return "an ad (no time)"
    if any(p["postId"] == post["id"] for p in posted):
        return "already replied to this post"
    posting = not rules["dryRun"]  # the posting limits don't hold back drafts
    if posting and len(todays) >= rules["perDay"]:
        return f"the daily limit ({rules['perDay']}) is reached"
    if posting and sum(1 for p in todays if p["author"].lower() == post["author"].lower()) >= rules["perAuthorPerDay"]:
        return f"already replied to @{post['author']} today"
    if not text:
        return "the reply is empty"
    if len(text) > rules["maxLength"]:
        return f"the reply is too long ({len(text)} > {rules['maxLength']})"
    return None


def guard_post(config, text):
    """None if an original post may be written (drafted, in dryRun), else
    why not. With text None, only the limits are checked."""
    c = config["compose"]
    today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    posts = [p for p in records("posted.jsonl") if p.get("kind") == "post"]
    if stopped():
        return "stopping"
    if not c["enabled"]:
        return "posting is off"
    if not config["me"].strip().lstrip("@"):
        return "`me` (your handle) is not set"
    if c["dryRun"]:
        drafts = [d for d in records("drafts.jsonl") if d.get("kind") == "post" and d["at"].startswith(today)]
        if len(drafts) >= c["perDay"]:
            return f"today's drafts ({c['perDay']}) are written"
    else:
        if sum(1 for p in posts if p["at"].startswith(today)) >= c["perDay"]:
            return f"the daily post limit ({c['perDay']}) is reached"
        if time.time() - max((p["epoch"] for p in posts), default=0) < c["minGapSeconds"]:
            return "too soon after the last post"
    if text is None:
        return None
    if not text:
        return "the post is empty"
    if len(text) > c["maxLength"]:
        return f"the post is too long ({len(text)} > {c['maxLength']})"
    if re.search(r"https?://|www\.", text, re.I):
        return "the post has a link"
    if any(p["text"] == text for p in posts):
        return "this text was already posted"
    return None


def read_posts(page, config):
    s = config["selectors"]
    posts = []
    for element in page.locator(s["post"]).all():
        try:
            link = element.locator(s["statusLink"]).first.get_attribute("href", timeout=2000) or ""
            match = re.search(r"/([A-Za-z0-9_]+)/status/(\d+)", link)
            if not match:
                continue
            text = element.locator(s["text"]).first.inner_text(timeout=2000) if element.locator(s["text"]).count() else ""
            stamp = element.locator("time").first.get_attribute("datetime", timeout=2000) if element.locator("time").count() else None
            posts.append({"id": match.group(2), "author": match.group(1), "text": text, "time": stamp,
                          "url": urllib.parse.urljoin(config["baseUrl"], f"/{match.group(1)}/status/{match.group(2)}")})
        except Exception:  # noqa: BLE001 - one odd post never stops the round
            continue
    return posts


def source_url(config, source):
    base = config["baseUrl"].rstrip("/")
    if source["kind"] == "home":
        return base + "/home"
    if source["kind"] == "search":
        return base + "/search?" + urllib.parse.urlencode({"q": source["query"], "f": "live"})
    if source["kind"] == "user":
        return base + "/" + source["handle"].lstrip("@")
    raise ValueError(source)


def signed_out(page, config):
    return page.locator(config["selectors"]["signedOut"]).count() > 0 or "/login" in page.url


def settle(page):
    """Let the page finish loading before acting, as a person waits for it:
    X's page loads scripts after it appears. A page that never goes
    quiet (X streams) is acted on after the limit."""
    try:
        page.wait_for_load_state("load", timeout=20000)
        page.wait_for_load_state("networkidle", timeout=10000)
    except Exception:  # noqa: BLE001 - a limit, not a failure
        pass
    pause(2, 4)


def reply(page, config, post, text):
    """Open the post, type the reply and click Post. Raises if Post was not
    clicked; then nothing was sent."""
    s = config["selectors"]
    page.goto(post["url"], wait_until="domcontentloaded")
    settle(page)
    # A reply's page shows the posts above it in its thread first: act on the
    # article whose own link is this post's.
    article = page.locator(s["post"]).filter(has=page.locator(f'a[href$="/status/{post["id"]}"]')).first
    article.wait_for(timeout=20000)
    pause(1, 2.5)
    article.locator(s["reply"]).first.click()
    type_and_send(page, config, text)


def write_post(page, config, text):
    """Open the compose dialog, type the post and click Post. Raises if Post
    was not clicked; then nothing was sent."""
    page.goto(config["baseUrl"].rstrip("/") + config["compose"]["path"], wait_until="domcontentloaded")
    settle(page)
    type_and_send(page, config, text)


def type_and_send(page, config, text):
    """Type into the open dialog's composer key by key, then click Post."""
    s = config["selectors"]
    composer = page.locator(s["composer"]).first
    composer.wait_for(timeout=20000)
    composer.click()
    low, high = config["typingDelayMs"]
    for character in text:
        if stopped():  # never leave a text half-typed and then post it
            page.keyboard.press("Escape")
            raise RuntimeError("stopping while typing; nothing was posted")
        page.keyboard.type(character)
        time.sleep(random.uniform(low, high) / 1000)
    pause(0.8, 2)
    # A hashtag or mention at the end leaves X's suggestions open, and their
    # layer covers Post. Escape closes them, and only them.
    suggestions = page.locator(s["suggestions"])
    if suggestions.count() and suggestions.first.is_visible():
        page.keyboard.press("Escape")
        suggestions.first.wait_for(state="hidden", timeout=5000)
    # Post only what was meant: nothing may have changed the text.
    if " ".join(composer.inner_text(timeout=5000).split()) != " ".join(text.split()):
        raise RuntimeError("the composer doesn't hold the text as typed; nothing was posted")
    if stopped():
        page.keyboard.press("Escape")
        raise RuntimeError("stopping before Post; nothing was posted")
    page.locator(s["send"]).first.click()


def evidence(page, what):
    """What the site shows when a post isn't confirmed: its messages (alerts,
    toasts) in the log, and a screenshot beside the settings."""
    try:
        messages = [m.inner_text(timeout=2000)[:200] for m in
                    page.locator('[role="alert"], [role="alertdialog"], [data-testid="toast"]').all()]
        name = f"unconfirmed-{int(time.time())}.png"
        page.screenshot(path=os.path.join(DIR, name))
        log(f"{what}: the site shows {messages or 'no message'}; screenshot {name}")
    except Exception as error:  # noqa: BLE001 - evidence only
        log(f"{what}: no evidence ({type(error).__name__})")


def confirmed(page, config):
    """Whether the composer closed after Post, as it does once the site has
    the reply."""
    try:
        page.locator(config["selectors"]["composer"]).first.wait_for(state="detached", timeout=20000)
        return True
    except Exception:  # noqa: BLE001 - a timeout: the site may still have it
        return False


def decide(considered, post, outcome):
    """A final decision about a post, kept across restarts (decisions.jsonl)."""
    considered.add(post["id"])
    append("decisions.jsonl", {"id": post["id"], "author": post["author"], "outcome": outcome, "at": time.time()})


def round_once(page, config, considered, pending):
    """Read every source, then act on what is new. False if signed out."""
    seen = {r["id"] for r in records("tweets.jsonl")}
    fresh = []
    for source in config["sources"]:
        if stopped():
            return True
        page.goto(source_url(config, source), wait_until="domcontentloaded")
        pause(1.5, 3)
        if signed_out(page, config):
            log("signed out: waiting for sign-in (use the live view)")
            return False
        for _ in range(config["scrolls"]):
            for post in read_posts(page, config):
                if post["id"] not in seen:
                    seen.add(post["id"])
                    append("tweets.jsonl", {**post, "source": source, "readAt": time.time()})
                    fresh.append(post)
            page.mouse.wheel(0, random.randint(500, 900))
            pause(1.5, 4)
    log(f"read {len(fresh)} new posts")
    if not config["replies"]["enabled"]:
        return True  # reading only: no model call per post (compose may still post)
    if config["replies"]["approved"] and not config["replies"]["dryRun"]:
        reply_approved(page, config, considered)
        return True  # with approvals, only what you approved is posted
    for post in [r for r in records("tweets.jsonl") if r["id"] not in considered]:
        if stopped():
            break
        if post["author"].lower() == config["me"].lower().lstrip("@"):
            decide(considered, post, "my own post"); continue
        if not post.get("time"):  # X's ads have no time
            decide(considered, post, "an ad (no time)"); continue
        answer = pending.get(post["id"]) or ask_model(config, post)
        if answer is None:
            continue  # asked again next round
        if not answer["reply"]:
            decide(considered, post, "the model chose not to reply")
            log(f"skip {post['id']} (@{post['author']}): the model chose not to reply")
            continue
        reason = guard(config, post, answer["text"])
        if reason:
            log(f"no reply to {post['id']} (@{post['author']}): {reason}")
            # Limits that pass with time (the day, the author) leave the post
            # open, with the model's answer kept, so it is not asked again.
            if reason.startswith(("the daily limit", "already replied to @", "stopping", "replies are off")):
                pending[post["id"]] = answer
            else:
                decide(considered, post, reason)
            continue
        if config["replies"]["dryRun"]:
            append("drafts.jsonl", {"postId": post["id"], "author": post["author"], "text": answer["text"],
                                    "at": datetime.datetime.now(datetime.timezone.utc).isoformat()})
            decide(considered, post, "drafted")
            log(f"draft for {post['id']} (@{post['author']}), dry run")
            continue
        if not send_reply(page, config, considered, post, answer["text"]):
            break
    return True


def send_reply(page, config, considered, post, text):
    """After the minimum gap, reply and record it. False if stopped."""
    last = max((p["epoch"] for p in records("posted.jsonl")), default=0)
    wait = last + config["replies"]["minGapSeconds"] - time.time()
    if wait > 0:
        pause(wait, wait + config["replies"]["jitterSeconds"])
        if stopped():
            return False
    try:
        reply(page, config, post, text)
    except Exception as error:  # noqa: BLE001 - logged; Post wasn't clicked, so it is tried again next round
        considered.discard(post["id"])
        log(f"reply to {post['id']} failed: {type(error).__name__}: {str(error).splitlines()[0][:160]}")
        return True
    # Post was clicked. It is recorded now, before any wait, so it counts
    # against the limits and is never sent again, even if the site never
    # confirms it: a missed reply is better than a double one.
    record = {"kind": "reply", "postId": post["id"], "author": post["author"], "text": text,
              "epoch": time.time(), "at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    append("posted.jsonl", record)
    decide(considered, post, "replied")
    if confirmed(page, config):
        log(f"replied to {post['id']} (@{post['author']}): {len(text)} characters")
    else:
        append("unconfirmed.jsonl", record)
        evidence(page, f"reply to {post['id']}")
        log(f"replied to {post['id']} (@{post['author']}): Post was clicked, but the reply was not confirmed "
            "(the composer stayed open); counted as posted, never sent again")
    return True


def reply_approved(page, config, considered):
    """Live with `replies.approved`: each approved reply, as it is, once,
    within the guard. The model isn't asked."""
    tweets = {t["id"]: t for t in records("tweets.jsonl")}
    for item in config["replies"]["approved"]:
        if stopped():
            return
        post, text = tweets.get(str(item.get("postId"))), str(item.get("text") or "").strip()
        if post is None:
            log(f"approved reply to {item.get('postId')}: that post hasn't been read")
            continue
        reason = guard(config, post, text)
        if reason == "already replied to this post":
            continue
        if reason:
            log(f"no approved reply to {post['id']} (@{post['author']}): {reason}")
            continue
        if not send_reply(page, config, considered, post, text):
            return


def compose_once(page, config):
    """An original post on the topic, within guard_post."""
    c = config["compose"]
    if not c["enabled"] or stopped():
        return
    reason = guard_post(config, None)
    if reason:
        return  # a limit: nothing to ask the model
    approved = c["approvedText"].strip()
    if approved and not c["dryRun"]:
        text = approved  # what you approved, as it is
    else:
        me = config["me"].lower().lstrip("@")
        recent = [t for t in records("tweets.jsonl") if t["author"].lower() != me][-c["context"]:]
        answer = ask_compose(config, recent)
        if answer is None:
            return
        if not answer["post"]:
            log("no post: the model chose not to")
            return
        text = answer["text"]
    reason = guard_post(config, text)
    if reason:
        log(f"no post: {reason}")
        return
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    if c["dryRun"]:
        append("drafts.jsonl", {"kind": "post", "text": text, "at": now})
        log(f"draft post ({len(text)} characters), dry run")
        return
    try:
        write_post(page, config, text)
    except Exception as error:  # noqa: BLE001 - logged; Post wasn't clicked
        log(f"post failed: {type(error).__name__}: {str(error).splitlines()[0][:160]}")
        return
    record = {"kind": "post", "postId": None, "author": config["me"].lstrip("@"), "text": text,
              "epoch": time.time(), "at": now}
    append("posted.jsonl", record)  # at the click, as replies are
    if confirmed(page, config):
        log(f"posted ({len(text)} characters)")
    else:
        append("unconfirmed.jsonl", record)
        evidence(page, "post")
        log("posted: Post was clicked, but the post was not confirmed (the composer stayed open); "
            "counted, never sent again")


def main():
    log("start")
    considered = {d["id"] for d in records("decisions.jsonl")}
    pending = {}
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
        context = browser.contexts[0]
        page = context.new_page()  # its own tab; the live view's tab stays yours
        # "Leave the page?" would hold every later navigation: leave. Others: no.
        page.on("dialog", lambda dialog: dialog.accept() if dialog.type == "beforeunload" else dialog.dismiss())
        while not stopped():
            config = load_config()  # changes apply from the next round
            try:
                if round_once(page, config, considered, pending):
                    compose_once(page, config)
            except Exception as error:  # noqa: BLE001 - logged; the next round tries again
                log(f"round failed: {type(error).__name__}: {str(error).splitlines()[0][:160]}")
            pause(config["readEverySeconds"] * 0.8, config["readEverySeconds"] * 1.2)
        page.close()
    log("stop file" if os.path.exists(os.path.join(DIR, "STOP")) else "stop: SIGTERM")


if __name__ == "__main__":
    main()
