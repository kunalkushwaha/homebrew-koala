# Keys on your Mac (the broker)

[User guide](README.md) > Keys on your Mac (the broker)

**Learn by doing:** [Tutorial 4: Decide what an agent can reach](tutorial-policy.md).

An AI agent usually needs an API key: for a model provider, GitHub or a cloud
service. A [secret](secrets.md) puts that key inside the VM, where anything
running there can read it and send it anywhere. With the **broker**, the key
stays on your Mac.

- The VM gets a **broker grant** instead of the key.
- Requests go to the broker on your Mac, which adds the key and sends them to
  the one service you allowed.
- A broker **policy** decides which requests are allowed, and how many.

A compromised agent can still use the access you granted, within your
limits, but it can't steal the key.

## How it fits together

- **`koala-broker`** runs on your Mac in the macOS App Sandbox. The Koala
  manager starts it when a VM first needs it. It has no listening port: each
  VM reaches it only through its own private channel.
- **A credential** is a key the broker stores in your login keychain (on
  Linux, in its own encrypted files). It never enters a VM. See `koala credential`.
- **A policy** is a JSON file. It names one service, which credential to add,
  the allowed requests, and limits. See `koala policy`.
- **A broker grant** in a VM's spec names a policy. Inside the VM the
  service is `http://NAME.broker.koala.internal/`. The traffic stays on your
  Mac, so plain HTTP is fine, and it works with `"internet": false`.

## Set it up

1. **Create a policy from a template.** `koala policy templates` lists them:
   `openai` (OpenAI and services with the same API), `anthropic`, for bots
   `telegram`, `slack` and `discord` (see [Chat platforms](#chat-platforms)),
   and `github` (see [GitHub](#github)). `koala policy templates openai`
   shows one: what it is for, how it sends the key, its groups, and the
   command to use it.

   ```sh
   koala policy create openai-main --template openai --model gpt-4.1-mini
   ```

   - It asks for the API key, stored for the broker in your login keychain.
     The key is read from the prompt, or from stdin with `--value-stdin`,
     and never accepted as an argument.
   - The policy allows the template's usual requests (for `openai`: chat
     completions and the model list), and with `--model`, only the models
     you name.
   - `--allow chat,models,embeddings` picks other groups of requests from
     the template.
   - `--origin https://api.mistral.ai` uses another service with the same
     API under `/v1`. One whose API is under a longer path takes that path
     in the origin: `--origin https://openrouter.ai/api` (OpenRouter, whose
     API is at `/api/v1`) or `--origin https://api.groq.com/openai` (Groq).
   - `--origin http://127.0.0.1:11434` uses a model server on this computer,
     such as Ollama or LM Studio. It takes no key: the policy is made
     without one, and nothing is asked. A key is never sent over `http://`.
   - `--credential NAME` uses a key you already stored, by its name.

   `koala policy inspect openai-main` shows what the policy allows, and
   `--json` prints the policy itself. `koala policy test` checks one request
   against it, as the broker would, without sending anything:

   ```sh
   koala policy test openai-main POST /v1/chat/completions --model gpt-4.1-mini
   ```

   It names the rule that allows the request, or says why it's refused and
   what the policy allows instead. It exits 0 if allowed and 1 if refused.

2. **Grant it to the VM**, with no secrets and, if the agent needs nothing
   else, no internet:

   ```json
   "network": {"internet": false,
               "allow": [{"kind": "broker", "name": "openai", "policy": "openai-main"}],
               "publish": []},
   "secrets": []
   ```

3. **Use it from the VM.** The policy's `guestEnvironment` is set for every
   process in the VM, so OpenAI-compatible SDKs and agents that read
   `OPENAI_BASE_URL` work unchanged. The placeholder key is not secret:

   ```sh
   koala exec agent -- sh -c 'echo $OPENAI_BASE_URL'
   ```

Some agents also need their own settings. For a complete example, see
[Example: run the Hermes agent](example-hermes.md).

### Write your own policy

For a service no template covers, or to change what a template allows,
start from a template's policy, edit it, then add it:

```sh
koala policy create my-api --template openai --print > my-api.json
koala policy validate -f my-api.json
koala policy test -f my-api.json POST /v1/chat/completions --model gpt-4.1-mini
koala credential set my-api
koala policy add -f my-api.json
```

A policy you edit this way keeps its `template` record. `koala policy
upgrade` would replace your edits, and shows them first.

### Learn from refusals

To try this step by step, see
[Tutorial 4](tutorial-policy.md#step-5-allow-one-refused-request-keep-refusing-the-other).

You don't need to know every request an agent makes. Start with a strict
policy, run the agent, then see what the broker refused:

```sh
koala policy suggest openai-main
```

```
Refused by openai-main since 11:38 (kept in the broker's memory)
#  REQUEST                               TIMES  LAST   SUGGESTION
1  GET /v1/items/5678 +1                 2      11:39  add rule GET /v1/items/{id}
2  POST /v1/chat/completions (model mo…  1      11:39  allow model model-b
3  GET /v1/models?limit                  1      11:39  add rule GET /v1/models?limit
4  POST /v1/embeddings                   2      11:38  add rule POST /v1/embeddings

Add 1, add rule GET /v1/items/{id}? [y/N] y
Add 2, allow model model-b? [y/N] n
Add 3, add rule GET /v1/models?limit? [y/N] y
Add 4, add rule POST /v1/embeddings? [y/N] y
policy openai-main updated: 3 changes
  GET /v1/items/5678: now allowed by rule 2
  GET /v1/items/1234: now allowed by rule 2
  GET /v1/models?limit: now allowed by rule 3
  POST /v1/embeddings: now allowed by rule 4
```

IDs in a path (numbers, UUIDs) become a parameter, so `/v1/items/1234` and
`/v1/items/5678` are one suggestion; you see the rule before saying yes.

- Each row is the smallest change that would allow those requests. In a
  terminal, it asks about each, saves the ones you approve, and tests those
  requests again. Running VMs
  get the change at once; no restart.
- Nothing is allowed without your yes. It asks only when its input and
  output are a terminal; otherwise, or with `--json`, it lists them and says
  nothing was changed.
- The broker keeps refused requests in memory while it runs: the method,
  the path, the names of query parameters (not their values), and the
  refused value of a field the policy pins, such as the model. Nothing else
  from the request, and nothing on disk. They're gone when the broker stops
  (an upgrade, `koala system stop`, logout or a restart); stopping a VM
  doesn't clear them.

## Chat platforms

A bot's token can stay on your Mac too. Three templates cover the requests
bots usually make:

```sh
koala policy create telegram-bot --template telegram   # asks for the bot token
koala policy create slack-bot --template slack         # the bot token, xoxb-…
koala policy create discord-bot --template discord     # the bot token
koala create bot --image docker.io/library/python:3.12-alpine --no-internet \
  --broker tg=telegram-bot --wait
```

The app in the VM gets a placeholder token and the broker's address, in the
variables below, where `GRANT` is the grant's name (`tg` above). They are not
standard names, so tell the app to use them:

| Template | The address (base URL) | The placeholder token |
| --- | --- | --- |
| `telegram` | `TELEGRAM_BASE_URL`: `http://GRANT.broker.koala.internal/bot`; for files, `TELEGRAM_BASE_FILE_URL` | `TELEGRAM_BOT_TOKEN`: `0:koala-brokered` |
| `slack` | `SLACK_API_URL`: `http://GRANT.broker.koala.internal/api/` | `SLACK_BOT_TOKEN`: `xoxb-koala-brokered` |
| `discord` | `DISCORD_API_URL`: `http://GRANT.broker.koala.internal/api/v10` | `DISCORD_BOT_TOKEN`: `koala-brokered` |

For example, with python-telegram-bot:

```python
import os
from telegram.ext import Application

app = (Application.builder()
       .token(os.environ["TELEGRAM_BOT_TOKEN"])
       .base_url(os.environ["TELEGRAM_BASE_URL"])
       .base_file_url(os.environ["TELEGRAM_BASE_FILE_URL"])
       .build())
```

With slack_sdk, use `WebClient(token=os.environ["SLACK_BOT_TOKEN"],
base_url=os.environ["SLACK_API_URL"])`.

What each template covers:

- **Telegram:** receiving updates by long polling (`getUpdates`) and sending
  messages: the default groups, `updates` and `messages`. `--allow
  updates,messages,files` adds getting and sending files, and `commands`
  adds the bot's command menu. Long polling works with the VM's internet
  off. Webhooks, which Telegram sends to a public address, are not part of
  this.
- **Slack:** the Web API, for posting, updating and deleting messages and
  reading conversations (`messages` and `read`). `reactions` is available
  with `--allow`.

  **Socket Mode** needs the app-level token (`xapp-…`), in a policy of its
  own:
  1. Create it: `koala policy create slack-app --template slack --allow
     socket-mode`.
  2. Grant it under another name.
  3. Point the Socket Mode client's Web API address at that grant. In
     slack_sdk, that is the `web_client` you give `SocketModeClient`.

  The WebSocket that follows connects straight to Slack, with a one-time
  ticket rather than the token. So it needs the VM's internet on.
- **Discord:** the REST API: the bot's identity, and posting, editing,
  deleting and reading messages in channels.

  **The Gateway** is the WebSocket through which most bot libraries receive
  messages. The token travels inside it, where the broker can't add it. A
  bot that needs the Gateway can't keep its token on your Mac.

Good to know:

- **How the key is sent:**
  - Telegram's goes in the URL path (`/bot<TOKEN>/…`).
  - Slack's is a bearer token.
  - Discord's is sent as `Authorization: Bot <TOKEN>`.

  The app's placeholder is never sent on.
- **A bot can reach every chat or channel it belongs to.** Limit that in
  the platform's own settings. For Discord, a policy you write can also
  limit `{channel}` to listed IDs with `params`.
- **Two grants made from one template set the same variables,** and the
  later grant's values win. Give the app the other grant's address
  yourself, as in the Socket Mode case.

## GitHub

Instead of a personal access token, the broker can hold a **GitHub App's**
private key. For each request, it uses a token that the App mints:
- valid for one hour;
- limited to the repositories and permissions you choose.

The VM never sees the key or the tokens.

1. **Create a GitHub App,** in GitHub's settings under Developer settings.
   - Give it the permissions your agent needs.
   - Install it on the repositories it should reach.
   - Download its private key (a `.pem` file).
   - Note the App ID, and the installation ID: the number at the end of the
     installation's settings address.
2. **Create the policy.** The key is read from stdin and converted for the
   keychain:

   ```sh
   koala policy create gh --template github --app-id 123456 \
     --installation-id 7890123 --repo acme/app --value-stdin < app.private-key.pem
   koala create agent --image docker.io/library/python:3.12-alpine --no-internet \
     --broker gh=gh --wait
   ```

3. **In the VM,** point the GitHub client at `$GITHUB_API_URL`
   (`http://GRANT.broker.koala.internal`). Give it any placeholder token,
   which the broker replaces:

   ```sh
   curl -H "Authorization: Bearer koala-brokered" "$GITHUB_API_URL/repos/acme/app"
   ```

**What the template allows:**
- **`read`** (the default): the repository, its files, commits, branches,
  pull requests and issues, and their comments.
- **`issues-write`:** open and edit issues, and comment on them.
- **`pulls-write`:** open, edit and review pull requests, and comment on
  them.

**The token's permissions follow the groups:**
- `read` asks for metadata, contents, issues and pull requests, read-only;
- `issues-write` adds write access to issues;
- `pulls-write` adds write access to pull requests.

With `--repo`, the token covers only those repositories, and the broker
refuses others before GitHub sees them.

**Good to know:**
- **Tokens are minted on the first request,** reused, and minted again
  shortly before they expire. If GitHub refuses one (for example, revoked),
  the next request gets a new one.
- **The App's own endpoints,** minting and revoking tokens, can never be
  reached from a VM.
- **A response that contains the token is refused:** as is, or in base64,
  for example inside a file's content.
- **`git` and `gh` aren't covered yet.** They talk to `github.com` themselves
  and need a token in the VM. For now, use a [secret](secrets.md) for them.
- **Page with `?page=`.** GitHub's `Link` header names `api.github.com`,
  which a client following it can't reach through the broker.
- **GitHub Enterprise Server:** add `--origin https://HOST/api/v3`. Tokens
  are minted there too, since the origin's path goes before the token
  request's path.- **The token request is written in the policy,** under `mint`: see
  [Minting tokens](policy-file.md#minting-tokens).

## The policy file

A policy is a JSON file, `"version": 2`. Every field, minting tokens, and the
rules no policy can change are in [the policy file reference](policy-file.md).
To write one by hand, step by step, see
[Tutorial 4: Decide what an agent can reach](tutorial-policy.md).

## Day to day

```sh
koala policy list                 # policies, their templates, and whether each is loaded or disabled
koala policy check                # read the keys again; says why a policy isn't loaded
koala policy test openai-main GET /v1/models   # would the broker allow it? nothing is sent
koala policy suggest openai-main  # what was refused, and add what you approve
koala policy status               # per-VM request counts (no content)
koala policy disable openai-main  # stop it at once; in-flight requests are cancelled
koala policy enable openai-main
koala policy upgrade openai-main  # after a Koala or template update: show, then apply with --yes
koala policy add -f openai-main.json   # replace; applies at once
koala policy rm openai-main            # VMs lose access at once; their next start fails
koala credential rm openai-main
```

- **Templates improve with Koala releases,** and with `koala template
  update` ([Newer templates](templates.md#newer-templates)). When a newer
  version of a policy's template is available, `koala policy list` says so. `koala
  policy upgrade` shows the change, keeping your key, service, models and
  groups, and applies it only with `--yes`.
- **A disable holds** until you enable the policy again, including across
  manager and broker restarts.
- **A VM whose grant names a missing or disabled policy** doesn't start, and
  fails with `GRANT_REQUIRED`.
- **If the broker stops unexpectedly,** the manager restarts it. Running VMs
  keep their grants and don't need a restart, though requests during those
  few seconds fail.
- **The broker keeps an audit log** with metadata only: which VM, which
  rule, the status and timings, never request or response content.

## Limits and good practice

- **Grant the least you can:** only the paths the agent needs, with a pinned
  `model`, and low limits.
- **The broker protects the key, not the work.** Anything the agent sends in
  an allowed request reaches the service, and anything the service returns
  reaches the agent.
- **Another process on your Mac can't use a VM's channel,** because there is
  no port to connect to. Policies and keys belong to your macOS user.
- **After you upgrade Koala,** macOS asks once whether the new
  `koala-broker` may use each key: the keychain trusts the program that
  stored a key, and each release is a new program to macOS. Choose **Always
  Allow** (it may ask for your login password).
  - `koala system install` reads the keys right after an upgrade, so the
    prompts appear while you are there. It then lists any policy that still
    didn't load, with the reason.
  - Koala waits up to 45 seconds for your answer. An approval given later
    still applies: the policy loads when you allow it.
  - If you chose **Deny**, or missed the prompt, run `koala policy check`:
    macOS asks again, and it lists any policy that still didn't load, with
    the reason.
- **The app must let you set its API address**, as most AI SDKs and agents
  do (for example with `OPENAI_BASE_URL`). An app that insists on holding a
  real key can only use a [secret](secrets.md).
