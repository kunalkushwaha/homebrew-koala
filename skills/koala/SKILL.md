---
name: koala
description: Run AI agents, untrusted code, CLI tools, services and dev environments in isolated Linux VMs on the user's Mac or Linux machine with Koala (the `koala` command). Use when the user wants to sandbox an agent or a script, keep an agent's API keys out of its VM (the broker), limit what a workload can reach on the network, share a folder with a VM, run a published agent template such as Hermes, or find out why Koala refused something.
---

# Koala

Koala runs each Linux workload in its own lightweight VM, with its own kernel,
disk and network, on macOS (Apple silicon) or Linux (KVM). A workload gets
**only the access the user grants**. Koala's main use is running AI agents
safely: the agent can't read the user's files, can't steal their API keys,
and reaches only what it's allowed to.

Check what is installed first: `koala --version`. **`koala COMMAND --help` is
the authority** for options: this skill describes 0.1.0-rc.2, and newer
releases add options (see "Newer versions" below).

## The mental model

- **A VM** is made from an OCI image (`--image`, the *lean* profile: one
  container image, a minimal init) or a catalog entry (`--catalog
  ubuntu-24.04`, the *full* profile: systemd and Docker Engine).
- **Modes:**
  - `koala run`: a **job**, a command in a throwaway VM that is removed when
    it ends;
  - `--mode environment` (the default): a VM that stays up for `koala exec`;
  - `--mode service`: its process is the VM's main process, restarted with it.
- **The manager** is a per-user background service (`koala system ...`) that
  keeps VMs running after the terminal closes. No `sudo`.
- **Access is granted at create time,** and `koala create` prints the plan
  (internet, grants, ports, volumes, mounts, secrets) before it changes
  anything. Read the plan back to the user.

| The VM gets | Granted by |
|---|---|
| The internet | On by default for `create`; `--no-internet` turns it off |
| A host folder | `--mount /host/dir:/guest/dir` (read-only; `:rw` for read-write) |
| Persistent storage | `--volume NAME:/path` (survives the VM) |
| A port on the host | `--publish 127.0.0.1:8080:80` (localhost unless an address says otherwise) |
| An API key, without the key | `--broker GRANT=POLICY`: the VM calls `http://GRANT.broker.koala.internal/`, and the broker on the host adds the key |
| A secret inside the VM | `--secret-env NAME=VAR` or `--secret-file NAME=/path` (the value is then in the VM) |
| A service on the host | `--host-service ADDR:PORT` |

## Rules for the assistant

1. **Prefer the broker to secrets for API keys.** A secret is readable by
   anything in the VM; with the broker the key never enters it. Use a secret
   only for tokens no policy template covers, and say so.
2. **Never put a key or a token on a command line,** in an image, a VM
   definition or an environment variable. `koala credential set NAME` and
   `koala secret set NAME` read it from a prompt (the user types it) or from
   stdin with `--value-stdin`.
3. **Grant the least access.** Start agents with `--no-internet` plus the
   broker grants they need. Mounts are read-only unless the user asks for
   write access to that folder; never mount the home directory.
4. **Show the plan, and ask before widening access:** turning the internet
   on, a read-write mount, a LAN-facing `--publish 0.0.0.0:...`, or a new
   broker policy group.
5. **Don't destroy data unasked.** `koala rm` keeps volumes, but `koala
   volume rm`, `koala system uninstall --purge` and `koala image prune` delete
   things for good. Confirm first, and never stop or uninstall the user's
   manager to "fix" something without asking.
6. **When Koala refuses something,** read the one-line message: it says what
   happened, what changed (usually "nothing was changed") and the command
   that fixes it. Don't work around a refusal by granting more than needed.

## Core workflows

**A one-off command in a throwaway VM:**
```sh
koala run --image docker.io/library/alpine:3 -- uname -a
koala run -it --image docker.io/library/python:3.12-slim -- python3
```

**A VM to work in:**
```sh
koala create dev --image docker.io/library/python:3.12-slim --mount "$PWD:/work" --wait
koala start dev --wait
koala exec dev -- python3 /work/script.py
koala exec -it dev -- /bin/sh
koala stop dev --wait
```

**An agent whose model key stays on the host:**
```sh
koala policy create openai-main --template openai --model gpt-4.1-mini   # asks for the key
koala create agent --image IMAGE --no-internet --broker openai=openai-main --wait
```
Inside the VM the agent uses `OPENAI_BASE_URL=http://openai.broker.koala.internal/v1`
and the placeholder key `OPENAI_API_KEY=koala-brokered`: the broker on the
host adds the real key, and only to the requests the policy allows. Pass
these as `--env` or set them in the agent's config; they are not secrets.

**A published agent template** (VM, policies, volumes and setup in one
command):
```sh
koala template list
koala template inspect hermes
koala create hermes --template hermes
```

**Look after VMs:** `koala list`, `koala inspect VM`, `koala logs VM`,
`koala stats`, `koala events`, `koala cp FILE VM:/path`, `koala rm VM --wait`.

More: [reference/recipes.md](reference/recipes.md) (step-by-step recipes),
[reference/commands.md](reference/commands.md) (every command),
[reference/safety.md](reference/safety.md) (what Koala protects against, and
what it doesn't).

## When something goes wrong

- **The manager isn't running** (`manager unavailable`): `koala system
  start`. First install: `koala system install`.
- **A request the broker refused:** `koala policy suggest POLICY` lists the
  refused requests and offers the smallest change that allows each.
  `koala policy test POLICY METHOD PATH [--model M]` checks one request
  without sending it.
- **A connection or request Koala refused:** `koala events --vm VM` lists
  what Koala did with the VM and what it refused. Grant the specific access
  that's missing; don't turn the internet on to "make it work".
- **A VM that won't start:** `koala inspect VM` shows the failure and its
  reason; `koala console VM` shows the boot.
- The user guide: https://kunalkushwaha.github.io/homebrew-koala/guide/
  (troubleshooting: .../guide/troubleshooting/).

## Newer versions

Check `koala --version` and `--help` before using these:

- **0.1.0-rc.3:** `koala create NAME --template T --internet` (or
  `--no-internet`) overrides a template's internet setting.
- **Domain grants (planned):** `--no-internet --domain pypi.org` lets a VM
  reach only the named hosts, over TLS. Public suffixes such as `*.co.uk` are
  refused.
