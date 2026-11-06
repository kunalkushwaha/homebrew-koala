# Tutorial 4: Decide what an agent can reach

[User guide](README.md) > Tutorial 4: Decide what an agent can reach

A VM with internet off can reach a service only through Koala's **broker**,
and only as a **policy** allows. In about fifteen minutes you will:
- write a policy by hand;
- check it before you use it;
- watch the broker refuse what it doesn't allow;
- allow one refused request and keep refusing another;
- switch the policy off and on.

The service is [Ollama](https://ollama.com) on your Mac. The policy lets a
VM list your models and generate with one of them, but not download,
inspect or delete models.

**You'll learn:** `koala policy validate`, `koala policy test`,
`koala policy add`, `koala policy list`, `koala policy inspect`,
`koala create --broker`, `koala policy suggest`, `koala policy status`,
`koala policy disable`, `koala policy enable` and `koala policy rm`.

Every command and every output on this page comes from a real run. IDs,
times, your models and the model's words will differ.

## Before you start

- Koala is installed and running ([Tutorial 1](tutorial-first-vm.md)).
- Ollama is running on your Mac with the model `gemma4:12b`
  (`ollama pull gemma4:12b`). To use another model, change its name
  wherever this page writes `gemma4:12b`.

## Step 1: Write the policy

Save this as `ollama-use.json`:

<!-- tutorial: file ollama-use.json -->
```json
{
  "version": 2,
  "name": "ollama-use",
  "upstream": {"origin": "http://127.0.0.1:11434"},
  "rules": [
    {"method": "GET",  "path": "/api/tags"},
    {"method": "POST", "path": "/api/generate"}
  ],
  "body": {
    "maxKiB": 64,
    "contentTypes": ["application/json"],
    "fieldAllow": {"model": ["gemma4:12b"]}
  },
  "requestHeaders": ["accept", "content-type", "user-agent"],
  "responseHeaders": ["content-type"],
  "perVM": {"requestsPerMinute": 30, "concurrency": 2, "responseMiB": 16,
            "timeoutSeconds": 300, "idleSeconds": 60},
  "guestEnvironment": {"OLLAMA_HOST": "http://{grant}.broker.koala.internal"}
}
```

| Part | What it says |
|---|---|
| `upstream.origin` | The one service: Ollama on this Mac. A service on this Mac needs no key, so there are no `keys`. |
| `rules` | The only requests that pass: list the models, and generate. Everything else is refused. |
| `body.fieldAllow` | Generate only with `gemma4:12b`. |
| `requestHeaders`, `responseHeaders` | The headers that may pass each way. |
| `perVM` | Limits for each VM: 30 requests a minute, 2 at a time, and so on. |
| `guestEnvironment` | Set in the VM, so tools there find the broker. `{grant}` becomes the grant's name. |

Every part except `keys`, `add` and `guestEnvironment` is required. See
[what a policy controls](policy-file.md#the-policy-file) for all of them.

## Step 2: Check it before you use it

`koala policy validate` checks a file and changes nothing. A mistake is
caught with its place. Here is the policy with one misspelt field:

<!-- tutorial: file broken.json -->
```json
{"version": 2, "name": "broken", "upstream": {"origin": "http://127.0.0.1:11434"},
 "rules": [{"method": "GET", "path": "/api/tags"}],
 "body": {"maxKiB": 64, "contentTypes": ["application/json"]},
 "reqeustHeaders": ["accept"], "responseHeaders": ["content-type"],
 "perVM": {"requestsPerMinute": 30, "concurrency": 2, "responseMiB": 16, "timeoutSeconds": 300, "idleSeconds": 60}}
```

<!-- tutorial: fails -->
```console
$ koala policy validate -f broken.json
koala: invalid policy: policy: unknown field reqeustHeaders
```

```console
$ koala policy validate -f ollama-use.json
valid policy ollama-use
```

`koala policy test` says whether a request would pass, and why, without
sending anything:

```console
$ koala policy test -f ollama-use.json GET /api/tags
GET /api/tags: allowed by ollama-use
  rule       1, GET /api/tags
  sent to    http://127.0.0.1:11434/api/tags
  not tested the VM's grant, rate limits, the key and the service's answer; nothing was sent
$ koala policy test -f ollama-use.json POST /api/generate --model gemma4:12b
POST /api/generate: allowed by ollama-use
  rule       2, POST /api/generate
  sent to    http://127.0.0.1:11434/api/generate
  fields     model gemma4:12b: allowed
  not tested the VM's grant, rate limits, the key and the service's answer; nothing was sent
```

It exits 1 for a request the policy refuses, so you can script it:

<!-- tutorial: fails -->
```console
$ koala policy test -f ollama-use.json POST /api/generate --model other-model
POST /api/generate: refused by ollama-use (403 field_not_allowed)
  why        model other-model isn't allowed; allowed: gemma4:12b
  not tested the VM's grant, rate limits, the key and the service's answer; nothing was sent
$ koala policy test -f ollama-use.json POST /api/pull
POST /api/pull: refused by ollama-use (403 not_allowed)
  why        no rule allows POST /api/pull
  rules      GET  /api/tags
             POST /api/generate
  not tested the VM's grant, rate limits, the key and the service's answer; nothing was sent
```

## Step 3: Add it

```console
$ koala policy add -f ollama-use.json
policy ollama-use stored
$ koala policy inspect ollama-use
ollama-use
  template   none (written by hand)
  service    http://127.0.0.1:11434
  key        none
  allows     GET  /api/tags
             POST /api/generate
  models     gemma4:12b
  body       up to 64 KiB of application/json
  headers    sent: accept, content-type, user-agent
             returned: content-type
  per VM     30 requests a minute, 2 at a time
             16 MiB a response, 300 s a request, 60 s idle
  in the VM  OLLAMA_HOST=http://{grant}.broker.koala.internal
  state      enabled
```

## Step 4: Give a VM the policy

`--broker NAME=POLICY` grants a VM one policy, under a name of your choice
(here `ollama`). With `--no-internet`, the broker is all it can reach:

```console
$ koala create probe --image docker.io/library/alpine:3 --no-internet --broker ollama=ollama-use --wait
internet off
broker ollama -> policy ollama-use
accepted operation 4700202d-0fcc-455d-8700-8ade26d86ce0 (vm.create)
succeeded 4700202d-0fcc-455d-8700-8ade26d86ce0
$ koala start probe --wait
accepted operation 390c1fb6-ccda-4d92-a8b9-f92946b907ee (vm.start)
succeeded 390c1fb6-ccda-4d92-a8b9-f92946b907ee
$ koala exec probe -- sh -c 'echo $OLLAMA_HOST'
http://ollama.broker.koala.internal
```

What the policy allows works:

```console
$ koala exec probe -- sh -c 'wget -qO- $OLLAMA_HOST/api/tags | head -c 30; echo'
{"models":[{"name":"…
$ koala exec probe -- sh -c 'wget -qO- --header "content-type: application/json" --post-data "{\"model\":\"gemma4:12b\",\"prompt\":\"Reply with exactly: hello from the VM\",\"stream\":false}" $OLLAMA_HOST/api/generate | grep -o "\"response\":\"[^\"]*\""'
"response":"…"
```

(This run's model replied `"response":"hello from the VM"`.)

What it doesn't allow is refused by the broker, and never reaches Ollama:

<!-- tutorial: fails -->
```console
$ koala exec probe -- sh -c 'wget -qO- --header "content-type: application/json" --post-data "{\"model\":\"tinyllama\"}" $OLLAMA_HOST/api/pull'
wget: server returned error: HTTP/1.1 403 Forbidden
koala: execution 09a80368-88c6-4cde-9b7f-ad8003cf87b9 exited (exit 1)
$ koala exec probe -- sh -c 'wget -qO- --header "content-type: application/json" --post-data "{\"model\":\"gemma4:12b\"}" $OLLAMA_HOST/api/show'
wget: server returned error: HTTP/1.1 403 Forbidden
koala: execution 0362ccf4-c8f4-482a-82fc-d1ac8457d155 exited (exit 1)
```

## Step 5: Allow one refused request, keep refusing the other

The broker remembers what it refused. `koala policy suggest` lists those
requests and, for each one, asks whether to add the smallest rule that
would allow it. Here, `/api/show` only reads a model's details, so answer
`y`. `/api/pull` downloads models, so answer `n`:

<!-- tutorial: answer y n -->
```console
$ koala policy suggest ollama-use
Refused by ollama-use since … (kept in the broker's memory)
#  REQUEST         TIMES  LAST   SUGGESTION
1  POST /api/show  1      …  add rule POST /api/show
2  POST /api/pull  1      …  add rule POST /api/pull

Add 1, add rule POST /api/show? [y/N] y
Add 2, add rule POST /api/pull? [y/N] n
policy ollama-use updated: 1 change
  POST /api/show: now allowed by rule 3
```

The change applies at once, with no restart:

```console
$ koala exec probe -- sh -c 'wget -qO /dev/null --header "content-type: application/json" --post-data "{\"model\":\"gemma4:12b\"}" $OLLAMA_HOST/api/show && echo allowed'
allowed
```

`/api/pull` is still refused:

<!-- tutorial: fails -->
```console
$ koala exec probe -- sh -c 'wget -qO- --header "content-type: application/json" --post-data "{\"model\":\"tinyllama\"}" $OLLAMA_HOST/api/pull'
wget: server returned error: HTTP/1.1 403 Forbidden
koala: execution 180059b7-22db-4761-a23c-f2185dd207c2 exited (exit 1)
```

`koala policy status` counts each VM's requests through each grant: those
sent on, those refused, and those in flight:

```console
$ koala policy status
VM     GRANT   POLICY      SENT  REFUSED  ACTIVE
probe  ollama  ollama-use  …
```

## Step 6: Switch the policy off, and on

`koala policy disable` stops a policy at once, cancelling its requests
in flight, and it stays off until you enable it, even across restarts:

```console
$ koala policy disable ollama-use
policy ollama-use disabled
```

Now even what the policy allows is refused, with `503`:

<!-- tutorial: fails -->
```console
$ koala exec probe -- wget -qO /dev/null http://ollama.broker.koala.internal/api/tags
wget: server returned error: HTTP/1.1 503 Service Unavailable
koala: execution 85a687fb-0c72-40e1-b877-3d9e96d28d70 exited (exit 1)
```

```console
$ koala policy enable ollama-use
policy ollama-use enabled
$ koala exec probe -- wget -qO /dev/null http://ollama.broker.koala.internal/api/tags
```

## Clean up

```console
$ koala stop probe --wait
accepted operation 248306f1-8d5c-45b8-b837-e64da5467a49 (vm.stop)
succeeded 248306f1-8d5c-45b8-b837-e64da5467a49
$ koala rm probe --wait
accepted operation 0e90d65b-d22a-4ee9-a670-80ceb3eb755a (vm.remove)
succeeded 0e90d65b-d22a-4ee9-a670-80ceb3eb755a
$ koala policy rm ollama-use
removed policy ollama-use
$ rm ollama-use.json broken.json
```

## What you learned

| Command | What it does |
|---|---|
| `koala policy validate -f FILE` | Check a policy file; changes nothing |
| `koala policy test -f FILE METHOD PATH [--model M]` | Would this request pass, and why? Sends nothing |
| `koala policy add -f FILE` | Store a policy, or replace one of the same name |
| `koala policy inspect NAME` | Everything a policy allows, in words |
| `koala create … --broker NAME=POLICY` | Give a VM a policy |
| `koala policy suggest NAME` | Review what was refused; allow it one by one |
| `koala policy status` | Requests and refusals per VM |
| `koala policy disable NAME` / `enable NAME` | Stop a policy at once, and restart it |
| `koala policy rm NAME` | Remove a policy |

## Next

**Next tutorial:** [Tutorial 5: Secrets and keys](tutorial-secrets.md).

More on this page's topics:

- [Keys on your Mac (the broker)](broker.md): keys and where the broker
  puts them, headers, limits and minted tokens.
- [Tutorial 2: Run an AI agent safely](tutorial-agent.md): a policy made
  for you by a template.
