# X agent

A Koala example. It runs a normal browser (Chromium) in a VM; you sign in to
X through a live view on your Mac. A small agent in the same VM reads your
timeline and searches, and asks a model what's worth a reply. It drafts by
default, and posts only what you approve, at a person's pace, within
guardrails.

> X's terms restrict automating its website, and X can limit or suspend
> automated accounts. Use a separate account. X's official API is the
> sanctioned way to automate.

The full walk-through is the user guide's
[Example: an X agent](../../docs/example-x-agent.md).

## Quick start

```sh
./x-agent.sh up                       # with Ollama on this Mac (or: up --broker POLICY)
./x-agent.sh password                 # then open the live view up printed, and sign in to x.com
./x-agent.sh check                    # what the agent reads, and your handle
cp settings/dry-run.json my-settings.json   # set "me"; adjust persona, sources, model
./x-agent.sh config my-settings.json  # starts the agent: drafts only
./x-agent.sh drafts                   # numbered drafts, beside the posts they answer
./x-agent.sh approve 2 5              # post only these two replies, as they are
./x-agent.sh down                     # remove the VM (down --forget also removes your sign-in)
```

Needs Koala 0.1.0-preview.7 or later, and the folder outside Desktop,
Documents and Downloads, which macOS protects.

## Files

| File | What it is |
| --- | --- |
| `x-agent.sh` | The commands above. They use the `koala` CLI. |
| `vm/start.sh` | The VM's main command: it installs Chromium on the first start, then runs the screen, the live view, Chromium and the agent, and stops them in order. |
| `agent/xagent.py` | The agent: read, ask the model, guard, act. |
| `agent/settings.py` | Installs settings, lists drafts and approves them (run in the VM by `x-agent.sh`). |
| `agent/check.py` | One read of the timeline, to compare with what you see. |
| `settings/dry-run.json` | A starting point: drafts only, low limits, about microVMs and sandboxing. |
