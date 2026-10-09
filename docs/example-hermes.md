# Example: run the Hermes agent

[User guide](README.md) > Example: run the Hermes agent

[Hermes](https://github.com/NousResearch/hermes-agent) is an AI agent from
Nous Research. It has a CLI and a gateway for chat apps such as Telegram and
Slack. This example runs its gateway as a Koala service VM, from the
official image. Because the agent runs its tools inside the VM, they reach
only what the VM is granted.

Tested with Koala 0.1.0-preview.4 and `docker.io/nousresearch/hermes-agent:latest`
at digest `sha256:7e36c10955df…` (Hermes 0.21.6), on 2026-10-09.

## What to know about the image

The image works in a lean VM without changes, but four things need care:

- **Its user is `root` by name.** A lean VM takes numeric user IDs only
  ([profiles](profiles.md#lean-vms)), so a VM that uses the image's user
  fails to start with `EXEC_START_FAILED`, and `koala exec` fails with
  `INVALID_ARGUMENT`. Set `"user": "0"` in the spec, and pass `--user` to
  `koala exec`.
- **It has no default command.** With no arguments it starts the
  interactive `hermes` CLI, which needs a terminal. A service VM must run
  `gateway run`.
- **It is large.** About 1 GB to download and 3 GB on disk, so it needs a
  bigger disk and more memory than the lean defaults.
- **Its own init does not run.** In Koala, Hermes is not PID 1, so it
  skips its process supervisor and logs a warning saying so. The gateway
  runs without it. The optional web dashboard (port 9119) does not start,
  and a crashed gateway is not restarted inside the VM.

Hermes keeps its configuration, keys, sessions and memory in `/opt/data`.
Put a volume there, so they survive when the VM is stopped or recreated.

## Create the VM

Create a volume for Hermes's data:

```sh
koala volume create hermes-data --size 2GiB --wait
```

Save this definition as `hermes.json`:

```json
{"apiVersion": "koala.dev/v1alpha1", "kind": "VirtualMachine", "spec": {
  "name": "hermes", "mode": "service", "profile": "lean",
  "image": {"kind": "oci", "reference": "docker.io/nousresearch/hermes-agent:latest", "platform": "linux/arm64"},
  "resources": {"vcpus": 2, "memoryMiB": 2048, "diskMiB": 6144},
  "process": {"user": "0", "arguments": ["gateway", "run"],
              "environment": {"API_SERVER_ENABLED": "true", "API_SERVER_HOST": "0.0.0.0"}},
  "network": {"internet": true, "allow": [],
              "publish": [{"protocol": "tcp", "hostAddress": "127.0.0.1", "hostPort": 8642, "guestPort": 8642}]},
  "shares": [],
  "volumes": [{"name": "hermes-data", "destination": "/opt/data", "readOnly": false}],
  "secrets": []}}
```

- `"user": "0"` runs the image's start-up as root. It sets up `/opt/data`,
  then runs the gateway as its own `hermes` user (UID 10000).
- `"arguments": ["gateway", "run"]` starts the gateway instead of the CLI.
- The two `API_SERVER_` variables turn on the gateway's OpenAI-compatible
  API and make it listen on the VM's network, so the published port can
  reach it. It is published on your Mac's `127.0.0.1` only.
- Internet access is on, because Hermes calls its model provider and chat
  platforms. Nothing on your Mac or your LAN is reachable from the VM.

Create and start it:

```sh
koala config validate -f hermes.json
koala create -f hermes.json --wait
koala start hermes --wait
```

The first start takes longer, because Koala fetches and prepares the
image.

## Set up Hermes

Run Hermes's commands as its own user, with `HOME` set:

```sh
koala exec -it --user 10000:10000 --env HOME=/opt/data hermes -- hermes setup
```

- `--user 10000:10000` is the `hermes` user, who owns `/opt/data`. Files
  written as root would be unreadable to the gateway.
- `--env HOME=/opt/data` is needed because `koala exec` does not set `HOME`,
  and the `hermes` command stops without it.

`hermes setup` is an interactive wizard: it asks for a model provider and
its API key, and for chat platforms. It writes them to `/opt/data`. You can
also set the model alone with `hermes model`.

Restart the VM so the gateway reads the new configuration:

```sh
koala stop hermes --wait
koala start hermes --wait
```

The same `exec` options work for other commands:

```sh
koala exec -it --user 10000:10000 --env HOME=/opt/data hermes -- hermes chat
koala exec -it --user 10000:10000 --env HOME=/opt/data hermes -- /bin/bash
```

## Check the gateway

From your Mac:

```sh
curl -s http://127.0.0.1:8642/health
```

```text
{"status": "ok", "platform": "hermes-agent", "version": "0.21.6"}
```

The rest of the API needs a key. On its first start, the image generates
one and stores it in `/opt/data/.env` as `API_SERVER_KEY`. Read it, and
send it as a bearer token:

```sh
KEY=$(koala exec --user 0 hermes -- sed -n 's/^API_SERVER_KEY=//p' /opt/data/.env)
curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:8642/v1/models
```

A request without the key gets `401`.

- A key in `/opt/data/.env` overrides an `API_SERVER_KEY` environment
  variable, including one given as a Koala [secret](secrets.md). To use your
  own key, change it in `.env`.
- Until a model provider is set up, chat requests succeed but the reply
  says Hermes is not connected to a provider.

See the gateway's output with `koala logs hermes`.

## Keys and what the agent can reach

- Hermes stores your model and chat-platform keys in `/opt/data/.env`, on
  the `hermes-data` volume. They stay on that volume, not in a Koala secret,
  and remain after the VM is deleted. `koala volume rm hermes-data` removes
  them.
- The agent can use those keys from inside the VM, and can send anything it
  reads to the internet. Give the VM only the shares it needs. Read-only
  shares are the default.
- To let it work on a project, share the directory:
  `"shares": [{"source": "/Users/me/project", "destination": "/workspace", "readOnly": true}]`.
  Make it read-write only if the agent should change it.
- Leave Hermes's command backend on `local`, the default. The VM is the
  sandbox. The `docker` backend needs Docker, which a lean VM does not have.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| `koala start` fails with `EXEC_START_FAILED` | The spec has no `"user": "0"`. Fix the file, then `koala rm hermes --wait` and create the VM again. The volume is kept. |
| `koala exec` fails with `INVALID_ARGUMENT` | Add `--user 0`, or `--user 10000:10000` for `hermes` commands. |
| `HOME: unbound variable` | Add `--env HOME=/opt/data`. |
| `koala logs hermes` shows the chat screen, and port 8642 does not answer | The VM runs the CLI. Add `"arguments": ["gateway", "run"]`, then `koala stop hermes --wait`, `koala update hermes -f hermes.json --wait` and start it. |
| `curl` gets `401` with your key | The key in `/opt/data/.env` is the one in use. Read it as shown above. |
| `RESOURCE_ADMISSION_FAILED` | Your Mac is short of memory or disk. See [troubleshooting](troubleshooting.md#resources-and-storage). If it still fails after memory is freed, run `koala system stop`, then `koala system start`, with no VMs running. |
