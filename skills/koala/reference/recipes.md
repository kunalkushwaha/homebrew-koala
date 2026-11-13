# Koala recipes

Each recipe is a complete task. The commands are for 0.1.0-rc.3; check
`koala COMMAND --help` on newer releases. Replace `IMAGE`, `VM` and the like
with the user's values, and show the user the plan `koala create` prints
before going on.

## Run a script you don't trust

A throwaway job VM: no access to the user's files, removed when it ends.

```sh
koala run --image docker.io/library/python:3.12-slim -- python3 -c 'print("hello")'
```

To give it one script, and nothing else of the user's (a share is always a
whole directory, so copy the file in instead):

```sh
koala create scratch --image docker.io/library/python:3.12-slim --wait
koala start scratch --wait
koala cp script.py scratch:/tmp/script.py
koala exec scratch -- python3 /tmp/script.py
koala stop scratch --wait
koala rm scratch --wait
```

Add `--no-internet` when the script needs no network. `koala rm` refuses a
running VM: stop it first.

## Let a VM reach only the hosts it needs

With the internet off, `--domain` grants named hosts, over TLS (port 443
unless given). Installing Python packages, for example, needs the index and
the file host:

```sh
koala create pipbox --image docker.io/library/python:3.12-slim --no-internet --domain pypi.org --domain files.pythonhosted.org --wait
koala start pipbox --wait
koala exec pipbox -- pip install --no-cache-dir requests
koala stop pipbox --wait
koala rm pipbox --wait
```

- `koala create` prints the grants (`domain pypi.org:443/tcp`); show them to
  the user.
- Any other host fails, usually as a name that doesn't resolve.
- `*.example.com` grants a domain's hosts. A public suffix (`*.co.uk`,
  `com`) is refused: grant a host under it.
- `--domain` needs `--no-internet`. With the internet on, every host is
  reachable anyway.

## A development environment for a project

A long-lived VM with the project read-write (a share needs the directory's
real path, with no symlinks) and a volume for caches:

```sh
koala create dev --image docker.io/library/node:22 --mount "$PWD:/work:rw" --volume dev-cache:/root/.cache --wait
koala start dev --wait
koala exec -it --workdir /work dev -- bash
```

`koala stop dev --wait` keeps its disk; `koala start dev --wait` brings it
back. `koala rm dev --wait` deletes it but keeps the volume (`koala volume
rm dev-cache` deletes that).

## An AI agent whose API key never enters its VM

1. Create a broker policy from a template. It asks for the key, which goes to
   the login keychain (on Linux, the broker's encrypted files):
   ```sh
   koala policy templates
   koala policy create openai-main --template openai --model gpt-4.1-mini
   ```
   For Anthropic: `--template anthropic`. For a service with OpenAI's API:
   `--template openai --origin https://openrouter.ai/api` (or Groq, Mistral).
   For a local model server: `--origin http://127.0.0.1:11434` (no key).
2. Check a request without sending it:
   ```sh
   koala policy test openai-main POST /v1/chat/completions --model gpt-4.1-mini
   ```
3. Create the agent's VM with the grant, and the internet off:
   ```sh
   koala create agent --image IMAGE --no-internet --broker openai=openai-main --env OPENAI_BASE_URL=http://openai.broker.koala.internal/v1 --env OPENAI_API_KEY=koala-brokered --wait
   koala start agent --wait
   ```
   `koala-brokered` is a placeholder: the broker adds the real key on the
   host, only to requests the policy allows.
4. Watch it: `koala policy status` (counters per VM), and `koala policy
   suggest openai-main` for anything the broker refused.

## A published agent template (Hermes)

```sh
koala template list
koala template inspect hermes
koala create hermes --template hermes
```

`koala create --template` shows everything it will make (the VM, broker
policies, volumes, setup) and asks before changing anything; it asks for any
missing key. `--set NAME=VALUE` sets a template parameter, `--yes` skips the
question in scripts. `koala template update` downloads newer templates.

## A service on a local port

```sh
koala create web --image docker.io/library/nginx:alpine --mode service --publish 127.0.0.1:8080:80 --wait
koala start web --wait
curl http://127.0.0.1:8080/
koala logs web
```

Ports listen on `127.0.0.1` unless the spec names another address; ask
before publishing on the LAN.

## Reach a service on the user's Mac

```sh
koala create client --image docker.io/library/alpine:3 --host-service 127.0.0.1:5432 --wait
```

Inside the VM the service is `host-1.koala.internal:5432`. Only that address
and port are reachable; the LAN and the Mac's other services stay closed.

## A token no policy template covers

When the broker can't hold it (a token the program reads from a file, say),
a secret puts it in the VM. Say so to the user: anything in the VM can read
it.

```sh
koala secret set bot-token
koala create bot --image IMAGE --secret-env bot-token=BOT_TOKEN --wait
```

The value is read from a prompt (or stdin with `--value-stdin`), never from
the command line.

## Copy files in and out

```sh
koala cp report.csv dev:/work/report.csv
koala cp dev:/work/out.json ./out.json
```

## Long jobs

```sh
koala run --detach --json --image docker.io/library/alpine:3 -- sh -c 'sleep 60; echo done'
koala attach EXECUTION
koala execution inspect EXECUTION
koala execution cancel EXECUTION
```

## Find out why something was refused

- **The broker:** `koala policy suggest POLICY` lists refused requests and
  offers the smallest change that allows each one; `koala policy test` checks
  one request.
- **The VM or its network:** `koala events --vm VM` lists what Koala did and
  refused. `koala inspect VM` shows the VM's state and its last failure.
- **Boot:** `koala console VM`.
- **The manager:** `koala system start`; the manager's log is in
  `~/Library/Application Support/Koala/logs/manager.log` on a Mac.

## Clean up

```sh
koala list
koala rm VM --wait
koala volume list
koala image prune
```

Ask before `koala volume rm` or `koala image prune`: both delete data.
