"""MkDocs hook: adapt the user guide in docs/ for the website without editing it.

The guide is exported from Koala's source repository and must stay readable on
GitHub, so each page starts with a breadcrumb line such as
"[User guide](README.md) > Networking". The website has its own navigation, so
the breadcrumb is dropped here, at build time.
"""
import re

BREADCRUMB = re.compile(r"^\[User guide\]\(README\.md\) > .*\n\n?", re.M)


def on_page_markdown(markdown, page, **kwargs):
    if page.file.src_uri.startswith("guide/"):
        return BREADCRUMB.sub("", markdown, count=1)
    return markdown
