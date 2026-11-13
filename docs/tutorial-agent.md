# Tutorial 2: Run an AI agent safely

[User guide](README.md) > Tutorial 2: Run an AI agent safely

In about fifteen minutes you will run the Hermes AI agent in its own VM,
ask it a question, and check for yourself what it can and can't reach:
- its model, only through Koala's broker;
- the internet, not at all;
- your API key, never inside the VM.

Then you remove it all.

**You'll learn:** `koala template list`, `koala template inspect`,
`koala create --template`, `koala policy inspect`, `koala exec`,
`koala policy status`, `koala volume rm` and `koala policy rm`.

Every command and every output on this page comes from a real run. IDs,
times and the model's answer will differ on your Mac.

## Before you start

- Koala is installed and running ([Tutorial 1](tutorial-first-vm.md)).
- A model for the agent. **One of:**
  - **An OpenAI API key.**
  - **A model on your Mac with [Ollama](https://ollama.com).** Nothing
    leaves your Mac, and you need no key. The model must support tool
    calls; this page uses `gemma4:12b`
    (`ollama pull gemma4:12b`, about 8 GB).

## Step 1: Find the agent's template

A **template** sets an agent up in one command: its VM, the rules for what
it may ask for, a volume for its data, and its configuration.

```console
$ koala template list
VM templates (koala create NAME --template T)
NAME    VERSION  DESCRIPTION
hermes  v1       The Hermes agent's gateway in its own VM; its model through the broker, no internet

Policy templates (koala policy create NAME --template T)
NAME       VERSION  SERVICE
anthropic  v2       api.anthropic.com
discord    v2       discord.com
github     v2       api.github.com
openai     v2       api.openai.com
slack      v2       slack.com
telegram   v2       api.telegram.org

Details: koala template inspect T, koala policy templates NAME
```

See exactly what the `hermes` template will make, before it makes anything:

```console
$ koala template inspect hermes
hermes v1 (built in): The Hermes agent's gateway in its own VM; its model through the broker, no
  internet

Parameters (set with --set NAME=VALUE):
  credential  The stored key to use; koala asks for it if it is missing (default: <VM>-openai)
  image       The Hermes image (default: docker.io/nousresearch/hermes-agent:latest)
  model       The model's name at your provider (default: gpt-4.1-mini)
  origin      Your provider, if not OpenAI: one with the same API under /v1 (default:
              https://api.openai.com)
  port        The port on this computer for the gateway's API (default: 8642)
  tls-pin     Trust only this certificate of the provider's (its SHA-256) (default: none)

koala create hermes --template hermes makes:
  VM hermes: docker.io/nousresearch/hermes-agent:latest, lean service, 2 CPUs, 2048 MiB memory,
    6144 MiB disk
    publish tcp 127.0.0.1:8642 -> 8642 (loopback)
    volume hermes-data -> /opt/data (rw)
    internet off
    broker openai -> policy hermes-openai
  policy hermes-openai: openai v2, https://api.openai.com, models gpt-4.1-mini, key hermes-openai
  volume hermes-data: 2048 MiB
  then waits, up to 300 s, until this succeeds in the VM:
    curl -fsS -m 2 -o /dev/null http://127.0.0.1:8642/health
  runs in the VM: hermes config set model.provider custom
  runs in the VM: hermes config set model.base_url http://openai.broker.koala.internal/v1
  runs in the VM: hermes config set model.default gpt-4.1-mini
  runs in the VM: hermes config set model.api_key koala-brokered
  then restarts the VM

Then it prints:
  The gateway's API is on http://127.0.0.1:8642; check it with: curl -s http://127.0.0.1:8642/health
  Its API key: koala exec hermes -- sed -n 's/^API_SERVER_KEY=//p' /opt/data/.env
  Ask Hermes: koala exec hermes -- hermes chat -q "Hello"
  Hermes keeps its configuration, sessions and memory on the volume hermes-data.
```

Read the plan's indented lines under `VM hermes`: they are everything the
VM is given.
- `internet off`.
- One port on your Mac's loopback address only (`127.0.0.1`).
- A volume for its data.
- `broker openai -> policy hermes-openai`: the one service it may use, and
  only as that **policy** allows.

## Step 2: Create the agent

This page names the agent `agent`. The name is yours to choose; the
template names the agent's policy and volume after it (`agent-openai`,
`agent-data`).

**With an OpenAI key:** Koala shows the plan, asks before it changes
anything, then asks for your key. The key goes into your login keychain, not
into the VM. macOS may ask whether `koala-broker` may use it: choose
**Always Allow**.

<!-- tutorial: skip -->
```console
$ koala create agent --template hermes
```

**With Ollama on your Mac,** point the template at it. A model on this
computer needs no key:

```console
$ koala create agent --template hermes --set origin=http://127.0.0.1:11434 --set model=gemma4:12b --yes
Template hermes v1 (built in): The Hermes agent's gateway in its own VM; its model through the
  broker, no internet
Parameters: image=docker.io/nousresearch/hermes-agent:latest model=gemma4:12b
  origin=http://127.0.0.1:11434 port=8642
It will make:
  VM agent: docker.io/nousresearch/hermes-agent:latest, lean service, 2 CPUs, 2048 MiB memory,
    6144 MiB disk
    publish tcp 127.0.0.1:8642 -> 8642 (loopback)
    volume agent-data -> /opt/data (rw)
    internet off
    broker openai -> policy agent-openai
  policy agent-openai: openai v2, http://127.0.0.1:11434, models gemma4:12b, no key
  volume agent-data: 2048 MiB, new
  then waits, up to 300 s, until this succeeds in the VM:
    curl -fsS -m 2 -o /dev/null http://127.0.0.1:8642/health
  runs in the VM: hermes config set model.provider custom
  runs in the VM: hermes config set model.base_url http://openai.broker.koala.internal/v1
  runs in the VM: hermes config set model.default gemma4:12b
  runs in the VM: hermes config set model.api_key koala-brokered
  then restarts the VM
  and leaves the VM running.
creating volume agent-data
creating VM agent
starting VM agent (the first start fetches the image)
waiting until the VM is ready (up to 300 s)
running in agent: hermes config set model.provider custom
✓ Set model.provider = custom in /opt/data/config.yaml
running in agent: hermes config set model.base_url http://openai.broker.koala.internal/v1
✓ Set model.base_url = http://openai.broker.koala.internal/v1 in /opt/data/config.yaml
running in agent: hermes config set model.default gemma4:12b
✓ Set model.default = gemma4:12b in /opt/data/config.yaml
running in agent: hermes config set model.api_key koala-brokered
✓ Set model.api_key = koal...ered in /opt/data/config.yaml
restarting VM agent
waiting until the VM is ready (up to 300 s)
agent is running (template hermes v1)
The gateway's API is on http://127.0.0.1:8642; check it with: curl -s http://127.0.0.1:8642/health
Its API key: koala exec agent -- sed -n 's/^API_SERVER_KEY=//p' /opt/data/.env
Ask Hermes: koala exec agent -- hermes chat -q "Hello"
Hermes keeps its configuration, sessions and memory on the volume agent-data.
```

`--yes` skips the question before creating; leave it out to be asked. The
first start downloads the agent's image (about 1.1 GB), so it takes a few
minutes.

```console
$ koala list
ID                                    NAME                 MODE         STATE              GEN
…
117cfa2f-773f-48df-8ff5-7c746186f796  agent                service      Running            1
```

`service` means the VM runs the agent's own process, its gateway. If that
process ends, the VM stops; Koala doesn't restart it.

## Step 3: Ask it something

```console
$ koala exec agent -- hermes chat -Q -q "In one short sentence: what is a virtual machine?"
…
session_id: local-c5875d600a036d1f45cea6e1caa482d2223c826c25c0210da6fd061a6d6fe36b
…
```

The answer is the model's, so yours will differ, and it may come before or
after Hermes's `session_id` line. This run's was: *"A
virtual machine is a software-based emulation of a physical computer that
allows a single piece of hardware to run multiple independent operating
systems."*

The agent's gateway also listens on your Mac, on the loopback address only:

```console
$ curl -s http://127.0.0.1:8642/health
{"status": "ok", "platform": "hermes-agent", "version": "…"}
```

## Step 4: Check what it can't reach

**No key in the VM.** The agent sees placeholders. Koala's broker, on your
Mac, adds the real key (if there is one) to each request the policy allows:

```console
$ koala exec agent -- sh -c 'env | grep ^OPENAI | sort'
OPENAI_API_KEY=koala-brokered
OPENAI_BASE_URL=http://openai.broker.koala.internal/v1
```

**No internet.** Nothing outside the broker resolves:

<!-- tutorial: fails -->
```console
$ koala exec agent -- curl -sS -m 5 https://example.com
curl: (6) Could not resolve host: example.com
koala: execution fcd27566-6ea3-4c83-92ea-40477e0c92cf exited (exit 6)
```

**Only what the policy allows.** This is the whole list of what the agent
may ask the model service for:

```console
$ koala policy inspect agent-openai
agent-openai
  template   openai v2 (groups: chat, models)
  service    http://127.0.0.1:11434
  key        none
  allows     POST /v1/chat/completions
             GET  /v1/models
             GET  /v1/models/{model}
  models     gemma4:12b
  body       up to 4 MiB of application/json
  headers    sent: accept, content-type, user-agent, x-stainless-arch, x-stainless-lang,
               x-stainless-os, x-stainless-package-version, x-stainless-retry-count,
               x-stainless-runtime, x-stainless-runtime-version
             returned: content-type, retry-after, x-ratelimit-limit-requests,
               x-ratelimit-remaining-requests, x-ratelimit-reset-requests, x-request-id
  per VM     60 requests a minute, 4 at a time
             64 MiB a response, 600 s a request, 120 s idle
  in the VM  OPENAI_API_KEY=koala-brokered
             OPENAI_BASE_URL=http://{grant}.broker.koala.internal/v1
  state      enabled
```

- **Three kinds of request,** and only the model `gemma4:12b`. A request
  for anything else gets `403` from the broker and never reaches the service.
- **`key none`,** because the model is on this Mac. With OpenAI, this line
  names your stored key, and `adds` shows where the broker puts it.

To see what the broker let through and what it refused:

```console
$ koala policy status
VM     GRANT   POLICY        SENT  REFUSED  ACTIVE
agent  openai  agent-openai  …
```

To decide what to allow when the broker refuses something, see
[Keys on your Mac (the broker)](broker.md#learn-from-refusals).

## Step 5: Clean up

Remove the VM, then the agent's data volume and its policy:

```console
$ koala stop agent --wait
accepted operation c598accd-b070-4423-a368-50e80714e899 (vm.stop)
succeeded c598accd-b070-4423-a368-50e80714e899
$ koala rm agent --wait
accepted operation bd099121-67f5-4189-8d2f-df51b091b558 (vm.remove)
succeeded bd099121-67f5-4189-8d2f-df51b091b558
$ koala volume rm agent-data --wait
accepted operation 9c129d53-ff3b-4668-a6cf-730c966f9d17 (volume.delete)
succeeded 9c129d53-ff3b-4668-a6cf-730c966f9d17
$ koala policy rm agent-openai
removed policy agent-openai
```

The volume holds the agent's configuration, sessions and memory; keep it if
you want them for a new agent. **If you used an OpenAI key,** delete it from
your keychain too:

<!-- tutorial: skip -->
```console
$ koala credential rm agent-openai
```

The agent's image stays downloaded, so a new agent starts faster.

## What you learned

| Command | What it does |
|---|---|
| `koala template list` / `inspect T` | See the agent templates, and exactly what one makes |
| `koala create NAME --template T [--set K=V]` | An agent's VM, policy, volume and setup in one command |
| `koala policy inspect NAME` | Everything an agent may ask a service for |
| `koala policy status` | What the broker let through and refused, per VM |
| `koala volume rm NAME` / `koala policy rm NAME` | Remove the agent's data and its policy |
| `koala credential rm NAME` | Remove a stored API key |

## Next

**Next tutorial:** [Tutorial 3: Give a VM your data, not your Mac](tutorial-data.md).

More on this page's topics:

- [Keys on your Mac (the broker)](broker.md): write your own policy, and
  allow what the broker refused.
- [VM templates for agents](templates.md): template parameters, and your
  own templates.
- [Run the Hermes agent](example-hermes.md): its gateway, chat platforms,
  and keeping its data.
