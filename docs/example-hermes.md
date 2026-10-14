# Example: run the Hermes agent

[User guide](README.md) > Example: run the Hermes agent

[Hermes](https://github.com/NousResearch/hermes-agent) is an AI agent from
Nous Research. It has a CLI and a gateway for chat apps such as Telegram and
Slack. This example runs its gateway as a Koala service VM, from the
official image. Because the agent runs its tools inside the VM, they reach
only what the VM is granted.

Here the model key stays on your Mac: the VM has no internet access and no
key, and reaches your model provider only through the
[broker](broker.md). To use chat platforms, give the VM internet access and
its keys instead; see [Keys in the VM](#keys-in-the-vm-instead).

Tested on 2026-10-14 with the code of Koala 0.1.0-preview.6 and
`docker.io/nousresearch/hermes-agent:latest` at digest
`sha256:444b42594e7f…` (Hermes 0.21.7). The model was a stand-in
OpenAI-compatible server on the Mac, not a real provider.

## What to know about the image

The image works in a lean VM without changes, but four things need care:

- **It has no default command.** With no arguments it starts the
  interactive `hermes` CLI, which needs a terminal. A service VM must run
  `gateway run`.
- **It is large.** About 1 GB to download and 4 GB unpacked, so it needs
  a bigger disk and more memory than the lean defaults.
- **Its own init does not run.** In Koala, Hermes is not PID 1, so it
  skips its process supervisor and logs a warning saying so. The gateway
  runs without it. The optional web dashboard (port 9119) does not start,
  and a crashed gateway is not restarted inside the VM.
- **Its `hermes` command switches user.** Run as root, which is the image's
  user and the default for `koala exec`, it switches to the image's
  `hermes` user (UID 10000) with `HOME=/opt/data`. Files it writes are then
  readable by the gateway, which runs as `hermes` too.

Hermes keeps its configuration, sessions, memory and any keys you give it
in `/opt/data`.
Put a volume there, so they survive when the VM is stopped or recreated.

## Store the model key on your Mac

Create a broker policy for your model provider from the `openai` template.
It asks for the provider's API key, which stays on your Mac:

```sh
koala policy create hermes-openai --template openai --model gpt-4.1-mini
```

- It allows the requests Hermes made when tested, chat completions and
  the model list, for the model you name. Use your provider's model name,
  here and when you set up Hermes below.
- For another OpenAI-compatible provider, add its address, such as
  `--origin https://api.groq.com`. A provider whose API is not under `/v1`
  needs a policy of your own; see
  [Write your own policy](broker.md#write-your-own-policy).
- `koala policy inspect hermes-openai` shows what the policy allows: the
  service, the requests, the model and the limits.

## Create the VM

Create a volume for Hermes's data:

```sh
koala volume create hermes-data --size 2GiB --wait
```

Create the VM, then start it:

```sh
koala create hermes --image docker.io/nousresearch/hermes-agent:latest --mode service \
  --cpus 2 --memory 2048 --disk 6144 \
  --env API_SERVER_ENABLED=true --env API_SERVER_HOST=0.0.0.0 \
  --no-internet --broker openai=hermes-openai \
  --publish 8642:8642 --volume hermes-data:/opt/data \
  --wait -- gateway run
koala start hermes --wait
```

- `-- gateway run` starts the gateway instead of the CLI. The image's
  start-up runs as root, sets up `/opt/data`, then runs the gateway as
  `hermes`.
- The two `API_SERVER_` variables turn on the gateway's OpenAI-compatible
  API and make it listen on the VM's network, so the published port can
  reach it. It is published on your Mac's `127.0.0.1` only.
- `--no-internet` with one broker grant: the VM can reach your model
  provider through the broker, at `http://openai.broker.koala.internal/`,
  and nothing else. The grant's policy adds the key on your Mac.
- Before creating the VM, `koala create` prints what it will be able to
  reach, and `koala inspect hermes` shows the whole VM.

The first start takes longer, because Koala fetches and prepares the
image.

## Point Hermes at the broker

Set the model, using the broker's address. `koala-brokered` is a
placeholder, not a key: the broker replaces it.

```sh
koala exec hermes -- hermes config set model.provider custom
koala exec hermes -- hermes config set model.base_url http://openai.broker.koala.internal/v1
koala exec hermes -- hermes config set model.default gpt-4.1-mini
koala exec hermes -- hermes config set model.api_key koala-brokered
```

Restart the VM so the gateway reads the new configuration:

```sh
koala stop hermes --wait
koala start hermes --wait
```

Ask Hermes something from the VM:

```sh
koala exec hermes -- hermes chat -q "Hello"
```

## Check the gateway

From your Mac:

```sh
curl -s http://127.0.0.1:8642/health
```

```text
{"status": "ok", "platform": "hermes-agent", "version": "0.21.7"}
```

The rest of the API needs a key. On its first start, the image generates
one and stores it in `/opt/data/.env` as `API_SERVER_KEY`. Read it, and
send it as a bearer token:

```sh
KEY=$(koala exec hermes -- sed -n 's/^API_SERVER_KEY=//p' /opt/data/.env)
curl -s -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d '{"model": "hermes-agent", "messages": [{"role": "user", "content": "Hello"}]}' \
  http://127.0.0.1:8642/v1/chat/completions
```

The answer comes from your model, through the broker. A request without
the key gets `401`.

- A key in `/opt/data/.env` overrides an `API_SERVER_KEY` environment
  variable. To use your own key, change it in `.env`.
- See the gateway's output with `koala logs hermes`, and the broker's
  per-VM request counts with `koala policy status`.

## Keys in the VM instead

Hermes's chat platforms, such as Telegram and Slack, need internet access
and their own keys, which the broker does not handle yet. For them, give
the VM internet access and set Hermes up inside it:

1. Stop the VM and edit its definition:

   ```sh
   koala stop hermes --wait
   koala edit hermes --wait
   ```

   In the editor, set `"internet"` to `true` and `"allow"` to `[]`, then
   save and quit. `koala edit` applies the change.
2. Start it again:

   ```sh
   koala start hermes --wait
   ```

3. Run Hermes's setup wizard, which asks for a model provider and its API
   key, and for chat platforms:

   ```sh
   koala exec -it hermes -- hermes setup
   ```

4. Restart the VM, as above.

`hermes setup` is interactive and was not run for this page. The keys it
asks for are written to `/opt/data/.env`, on the `hermes-data` volume.

## Keys and what the agent can reach

- **With the broker,** the model key never enters the VM. Hermes can use
  it only for the requests the policy allows, within its limits. Anything
  the agent sends in those requests reaches your provider, and anything the
  provider returns reaches the agent.
- **With internet off,** the VM reaches nothing but the broker grant: not
  the internet, your Mac or your LAN.
- **Keys in the VM** stay in `/opt/data/.env`, on the `hermes-data`
  volume, and remain after the VM is deleted. `koala volume rm hermes-data`
  removes them. The agent can use them from inside the VM, and with
  internet on it can send anything it reads anywhere.
- **Shares:** give the VM only the ones it needs. Read-only shares are the
  default. To let it work on a project, share the directory:
  `"shares": [{"source": "/Users/me/project", "destination": "/workspace", "readOnly": true}]`.
  Make it read-write only if the agent should change it.
- Leave Hermes's command backend on `local`, the default. The VM is the
  sandbox. The `docker` backend needs Docker, which a lean VM does not have.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| `koala start` fails with `GRANT_REQUIRED` | The policy the grant names is missing or disabled. Check `koala policy list`. |
| Hermes answers that the API rejected your key, and the provider said `HTTP 403` with `"source":"koala-broker"` | The broker refused the request. With `not_allowed`, Hermes is not set up for the broker yet: run the four `hermes config set` commands, then restart the VM. With `field_not_allowed`, Hermes asked for a model that is not in the policy's `fieldAllow`. |
| `koala logs hermes` shows the chat screen, and port 8642 does not answer | The VM runs the CLI: it was created without `-- gateway run`. Run `koala stop hermes --wait` and `koala edit hermes --wait`, set `"arguments"` to `["gateway", "run"]` under `"process"`, then start it. |
| `curl` gets `401` with your key | The key in `/opt/data/.env` is the one in use. Read it as shown above. |
| `RESOURCE_ADMISSION_FAILED` | Your Mac is short of memory or disk. See [troubleshooting](troubleshooting.md#resources-and-storage). |
