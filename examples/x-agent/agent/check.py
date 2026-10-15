#!/usr/bin/env python3
"""One read of X's timeline with the agent's own code and its default
(X's) selectors, to compare with what you see in the live view. Run in the
VM while no agent runs; it uses a tab of its own and closes it.

  python3 check.py XAGENT [URL]

Prints the page's address, whether it looks signed out, the signed-in handle
(from X's profile link), and each post read: ID, author, time and the start
of its text. A post with no time is likely an ad."""
import importlib.util
import json
import os
import sys
import tempfile

XAGENT = sys.argv[1]
URL = sys.argv[2] if len(sys.argv) > 2 else "https://x.com/home"
CONFIG = os.path.join(tempfile.mkdtemp(), "config.json")
json.dump({}, open(CONFIG, "w"))
sys.argv = [XAGENT, CONFIG]  # xagent reads its config's path at import
spec = importlib.util.spec_from_file_location("xagent", XAGENT)
x = importlib.util.module_from_spec(spec)
spec.loader.exec_module(x)
config = x.load_config()
s = config["selectors"]

with x.sync_playwright() as p:
    page = p.chromium.connect_over_cdp("http://127.0.0.1:9222").contexts[0].new_page()
    try:
        page.goto(URL, wait_until="domcontentloaded")
        try:
            page.wait_for_selector(s["post"], timeout=20000)
        except Exception:  # noqa: BLE001 - reported below as 0 posts
            pass
        print("url:", page.url)
        print("signed out:", x.signed_out(page, config))
        link = page.locator('a[data-testid="AppTabBar_Profile_Link"]')
        print("handle:", (link.first.get_attribute("href") or "").strip("/") if link.count() else None)
        posts = x.read_posts(page, config)
        print(f"articles: {page.locator(s['post']).count()}, read: {len(posts)}, "
              f"reply buttons: {page.locator(s['post'] + ' ' + s['reply']).count()}")
        for post in posts:
            print(f"{post['id']}  @{post['author']}  time={post['time']}  {post['text'][:70]!r}")
    finally:
        page.close()
