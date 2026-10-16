# Keys on your Mac (the broker)

[User guide](README.md) > Keys on your Mac (the broker)

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
- **A credential** is a key the broker stores in your login keychain. It
  never enters a VM. See `koala credential`.
- **A policy** is a JSON file. It names one service, which credential to add,
  the allowed requests, and limits. See `koala policy`.
- **A broker grant** in a VM's spec names a policy. Inside the VM the
  service is `http://NAME.broker.koala.internal/`. The traffic stays on your
  Mac, so plain HTTP is fine, and it works with `"internet": false`.

## Set it up

1. **Create a policy from a template.** `koala policy templates` lists them:
   `openai` (OpenAI and services with the same API), `anthropic`, for bots
   `telegram`, `slack` and `discord` (see [Chat platforms](#chat-platforms)),
   and `github` (see [GitHub](#github)).

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
     API under `/v1`. For one under another path, such as Groq, see
     [Write your own policy](#write-your-own-policy).
   - `--credential NAME` uses a key you already stored, by its name.

   `koala policy inspect openai-main` shows what the policy allows, and
   `--json` prints the policy itself.

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
koala credential set my-api
koala policy add -f my-api.json
```

A policy you edit this way keeps its `template` record. `koala policy
upgrade` would replace your edits, and shows them first.

**For example, Groq.** Its API has the OpenAI shape, but under
`/openai/v1`, not `/v1`. Print the `openai` template's policy for it, and
change `/v1` to `/openai/v1`: in the three rules, and in the VM's
`OPENAI_BASE_URL`:

```sh
koala policy create groq --template openai --origin https://api.groq.com \
  --model llama-3.3-70b-versatile --print | sed 's#/v1#/openai/v1#g' > groq.json
koala policy validate -f groq.json
koala credential set groq
koala policy add -f groq.json
```

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
- **GitHub Enterprise Server** isn't supported yet.

## What a policy controls

- **One service,** in `upstream.origin`. HTTPS only, except `http://` to a
  model server on your own Mac (`127.0.0.1`, `localhost`). The broker never
  follows redirects.
- **The key,** in `auth`, with the credential's name. It is sent in one of
  these ways:
  - `bearer`;
  - a named `header` (such as `x-api-key`);
  - `basic`;
  - a `query` parameter;
  - `authorization` with a `type`, such as Discord's `Bot`;
  - the URL `path`, at a rule segment `PREFIX{credential}`, as in
    Telegram's `/bot{credential}/sendMessage`. Every rule then has one
    such segment. The VM's own text in that place is replaced, never sent.
    `{credential}` is reserved for this: no other policy may use it.
  - `github-app`, with an `appId` and `installationId`, and optionally
    `repositories` and `permissions`. The credential is the App's key, and
    requests carry a one-hour token minted from it.
- **Requests:**
  - `rules` lists the allowed method and path pairs. A `{name}` segment can
    be limited to listed values with `params`, and `query` lists the allowed
    query parameters. A last segment `{name*}` matches the rest of the path,
    such as a file's path. Everything else is refused.
  - `requestHeaders` lists the headers passed through. `Authorization`,
    cookies and forwarding headers never pass.
  - `body` limits the size and content types. `fieldAllow` can pin
    top-level JSON fields, for example the `model`, to listed values.
- **Responses:** only `responseHeaders` come back. A response that contains
  the key is refused, including partway through a stream: as is, base64,
  hex, or percent-encoded as in a URL.
- **Limits** per VM, in `perVM`: requests per minute, concurrent requests,
  response size, and total and idle time. A grant can set lower `limits`,
  never higher.
- **Environment** for the VM, in `guestEnvironment`. `{grant}` is replaced by
  the grant's name.

## Day to day

```sh
koala policy list                 # policies, their templates, and whether they are disabled
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
- **After you upgrade Koala,** macOS may ask once whether the new
  `koala-broker` may use its keychain items. Allow it.
- **The app must let you set its API address**, as most AI SDKs and agents
  do (for example with `OPENAI_BASE_URL`). An app that insists on holding a
  real key can only use a [secret](secrets.md).
