# OpenClaw

A Koala example. It runs [OpenClaw](https://openclaw.ai)'s gateway in a VM:
- with no internet access;
- with your model provider's API key on your Mac, reached through Koala's
  broker;
- with OpenClaw's state on a volume;
- with its Control UI on `127.0.0.1`.

> **Not tested on Koala.** It is written from OpenClaw's documentation of
> its image. Expect to adjust it.

The full walk-through, with what may need changing, is the user guide's
[Example: run OpenClaw](../../docs/example-openclaw.md).

## Run it

```sh
./openclaw.sh up                  # asks for your API key once; prints the gateway token: keep it
open http://127.0.0.1:18789       # sign in with the gateway token
./openclaw.sh approve             # the devices waiting for approval
./openclaw.sh approve ID          # approve your browser
./openclaw.sh logs                # the gateway's output
./openclaw.sh down                # remove the VM (down --forget also removes its state)
```

- `up --model M` picks another model.
- `up --origin URL` picks another OpenAI-compatible provider.
- `up --port N` picks another port for the Control UI.

You need Koala 0.1.0-preview.6 or later, and an OpenAI-compatible API key.
Keep this folder outside Desktop, Documents and Downloads: macOS protects
those folders, and the VM reads this one.

## Files

| File | What it is |
| --- | --- |
| `openclaw.sh` | The commands above. They use the `koala` CLI. |
| `vm/start.sh` | The VM's main command. It runs OpenClaw's own onboarding on the first start, then the gateway, as the user `node`. |
