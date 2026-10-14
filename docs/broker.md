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
   `openai` (OpenAI and services with the same API) and `anthropic`.

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
   - `--origin https://api.groq.com` uses another service with the same API.
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

## What a policy controls

- **One service,** in `upstream.origin`. HTTPS only, except `http://` to a
  model server on your own Mac (`127.0.0.1`, `localhost`). The broker never
  follows redirects.
- **The key,** in `auth`: `bearer`, a named `header` (such as `x-api-key`),
  `basic`, or a `query` parameter, plus the credential's name.
- **Requests:**
  - `rules` lists the allowed method and path pairs. A `{name}` segment can
    be limited to listed values with `params`, and `query` lists the allowed
    query parameters. Everything else is refused.
  - `requestHeaders` lists the headers passed through. `Authorization`,
    cookies and forwarding headers never pass.
  - `body` limits the size and content types. `fieldAllow` can pin
    top-level JSON fields, for example the `model`, to listed values.
- **Responses:** only `responseHeaders` come back. A response that contains
  the key (as is, base64 or hex) is refused, including partway through a
  stream.
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
koala policy upgrade openai-main  # after a Koala upgrade: show, then apply with --yes
koala policy add -f openai-main.json   # replace; applies at once
koala policy rm openai-main            # VMs lose access at once; their next start fails
koala credential rm openai-main
```

- **Templates improve with Koala releases.** When a newer version of a
  policy's template is available, `koala policy list` says so. `koala
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
