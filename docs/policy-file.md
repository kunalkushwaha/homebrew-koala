# Reference: the broker policy file

[User guide](README.md) > Reference: the broker policy file

Every field of a broker policy, what it does, and the rules no policy can change. To learn by doing, see [Tutorial 4: Decide what an agent can reach](tutorial-policy.md); for how the broker fits together, see [Keys on your Mac (the broker)](broker.md).

## The policy file

A policy is a JSON file, `"version": 2`. Koala reads no other version. A
policy an earlier Koala made from a template (`"version": 1`) is refused
until you run `koala policy upgrade NAME --yes`, which makes it again from
the template, keeping its key, service, pin, groups and models. One written
by hand is refused; write it again in this form.

```json
{
  "version": 2,
  "name": "azure-chat",
  "upstream": {"origin": "https://acme.openai.azure.com/openai"},
  "keys": {"main": "azure-key"},
  "add": [
    {"header": "api-key", "value": "{key:main}"},
    {"query": "api-version", "value": "2024-10-21"}
  ],
  "rules": [{"method": "POST", "path": "/deployments/{deployment}/chat/completions",
             "params": {"deployment": ["gpt-4-1-mini"]}}],
  "requestHeaders": ["content-type", "accept"],
  "responseHeaders": ["content-type", "x-request-id"],
  "body": {"maxKiB": 4096, "contentTypes": ["application/json"]},
  "perVM": {"requestsPerMinute": 60, "concurrency": 4, "responseMiB": 64,
            "timeoutSeconds": 600, "idleSeconds": 120}
}
```

- **One service,** in `upstream.origin`: `https://host[:port]`, with an
  optional fixed path such as `/api`, which goes before every allowed path
  (the rules match the VM's own path, `/v1/...`; the service is sent
  `/api/v1/...`). The path has at most 8 segments of `A-Z a-z 0-9 . _ ~ -`.
  `tlsPinSHA256` trusts only one certificate. The broker never follows
  redirects.
- **Plain HTTP:** `http://` to this computer (`127.0.0.1`, `localhost` or
  `::1`) needs nothing more. To another host, such as a GPU machine on your
  network, add `"plainHTTP": true` to `upstream`, and use no keys.
- **`keys`** names the credentials the policy uses, up to 8, each by a name
  of its own (`main` here). Store each with `koala credential set NAME`;
  `koala policy add` says which are missing. A policy with no `keys` sends
  no key.
- **`add`** lists what the broker adds to every request, up to 16: a
  `header` or a `query` parameter, and its `value`. A value is text with
  `{key:NAME}` where a key goes, or `{key:NAME|base64}` (as Basic
  authentication needs for `user:password`). A value with no key is a fixed
  value the broker sets, such as `api-version`. Examples:
  - a bearer token: `{"header": "authorization", "value": "Bearer {key:main}"}`;
  - Discord's bot token: `{"header": "authorization", "value": "Bot {key:main}"}`;
  - a named header: `{"header": "x-api-key", "value": "{key:main}"}`;
  - two keys at once: one in a header, another in the query;
  - an attribution header, as OpenRouter asks for:
    `{"header": "x-title", "value": "my-agent"}`.
- **A key in the path** goes in a rule's segment, `PREFIX{key:NAME}`, as in
  Telegram's `/bot{key:bot}/sendMessage`. The VM's own text in that place is
  replaced, never sent.
- **Requests:**
  - `rules` lists the allowed method and path pairs. A `{name}` segment can
    be limited to listed values with `params`, and `query` lists the allowed
    query parameters. A last segment `{name*}` matches the rest of the path,
    such as a file's path. Everything else is refused.
  - `requestHeaders` and `responseHeaders` are a list of the headers that
    pass, or `{"allow": [...], "deny": [...]}`. A list keeps the default deny
    list: `authorization`, `cookie`, `forwarded`, `proxy-*` and
    `x-forwarded-*` sent, and `set-cookie`, `www-authenticate`,
    `proxy-authenticate` and `location` returned. Your own `deny` replaces
    it, so `"deny": []` lets you allow cookies. HTTP's own framing headers
    never pass.
  - `body` limits the size and content types. `fieldAllow` can pin
    top-level JSON fields, for example the `model`, to listed values.
- **Responses:** only the allowed response headers come back. A response
  that contains a key is refused, including partway through a stream: as is,
  base64, hex, or percent-encoded as in a URL.
- **Limits** per VM, in `perVM`: requests per minute, concurrent requests,
  response size, and total and idle time. A grant can set lower `limits`,
  never higher. Values above the usual ranges (more than 64 requests at a
  time, or more than an hour a request) are allowed and shown as warnings by
  `validate`, `add` and `inspect`; they stay within sane bounds (a week, at
  most 4,096 at a time).
- **Environment** for the VM, in `guestEnvironment`. `{grant}` is replaced by
  the grant's name.

## Minting tokens

**`mint`** makes short-lived tokens from a key, up to 4 minters. `kind`
picks the code that signs; for now, `github-app`. `{mint:NAME}` in an `add`
value puts that minter's current token there. Everything else is in the
file:

```json
"keys": {"app": "gh-app-key"},
"mint": {"github": {"kind": "github-app", "key": "app",
                    "appId": "123456", "installationId": 7890123,
                    "repositories": ["app"], "permissions": {"contents": "read"},
                    "request": {"method": "POST",
                                "path": "/app/installations/{installationId}/access_tokens",
                                "headers": {"accept": "application/vnd.github+json",
                                            "x-github-api-version": "2022-11-28"}},
                    "answer": {"status": 201, "token": "token", "expiresAt": "expires_at"},
                    "reserved": ["/app", "/installation"]}},
"add": [{"header": "authorization", "value": "Bearer {mint:github}"}]
```

- `key` is the key it signs with, which is never sent anywhere else.
- `request` is the token request, on the policy's own origin (after its
  path, with its pinned certificate). `{installationId}` and `{appId}` are
  filled in. The kind adds the signature (`authorization`), `user-agent`
  and, for `github-app`, a JSON body of `repositories` and `permissions`.
- `answer` gives the success status and the names of the token's and the
  expiry's fields (an ISO 8601 time, at most two hours away for
  `github-app`).
- `reserved` lists path prefixes a VM can never reach, whatever the rules
  say. The token request's own path is always reserved.

## Rules the file can't change

Three rules hold whatever the policy says:
1. **A key goes only where the policy puts it.** The VM can't send a
   header or query parameter that `add` sets, and never receives a key. A
   minter's key is never sent at all, and no rule may reach a minter's
   token request or reserved paths.
2. **A key is never sent in cleartext over a network:** with plain HTTP, only
   to this computer.
3. **A response that contains a key is cut off** (any of the policy's keys,
   in any of the forms above), and redirects are never followed.

HTTP's own framing headers (`host`, `content-length`, `transfer-encoding`,
`connection`, `upgrade` and the like) are always the broker's, and can't be
allowed or added. Minting needs `https`.
