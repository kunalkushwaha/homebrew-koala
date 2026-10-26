# OpenClaw

A Koala example. It runs [OpenClaw](https://openclaw.ai)'s gateway in a VM:
- with no internet access;
- with your model provider's API key on your computer, reached through Koala's
  broker;
- with OpenClaw's state on a volume;
- with its Control UI on `127.0.0.1`.

> **Tested on Linux and macOS** (2026-10-26: Koala 0.1.0-preview.14 on
> Linux, 0.1.0-preview.15 on an Apple silicon Mac; OpenClaw 2026.10.7).

The full walk-through, with what to check if something doesn't work, is the
user guide's
[Example: run OpenClaw](../../docs/example-openclaw.md).

## Run it

```sh
./openclaw.sh up                  # asks for your API key once; prints the gateway token: keep it
open http://127.0.0.1:18789       # sign in with the gateway token
./openclaw.sh approve             # only if OpenClaw asks: the devices waiting
./openclaw.sh approve ID          # approve your browser
./openclaw.sh logs                # the gateway's output
./openclaw.sh down                # remove the VM (down --forget also removes its state)
```

- `up --model M` picks another model.
- `up --origin URL` picks another OpenAI-compatible provider.
- `up --port N` picks another port for the Control UI.

You need Koala 0.1.0-preview.6 or later, and an OpenAI-compatible API key.
On a Mac, keep this folder outside Desktop, Documents and Downloads: macOS
protects those folders, and the VM reads this one.

## Files

| File | What it is |
| --- | --- |
| `openclaw.sh` | The commands above. They use the `koala` CLI. |
| `vm/start.sh` | The VM's main command. It runs OpenClaw's own onboarding on the first start, then the gateway, as the user `node`. |
