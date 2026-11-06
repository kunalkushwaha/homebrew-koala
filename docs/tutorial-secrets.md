# Tutorial 5: Secrets and keys

[User guide](README.md) > Tutorial 5: Secrets and keys

Koala keeps two kinds of sensitive values in your login keychain, and they
behave in opposite ways:

| | A **secret** | A **credential** (broker key) |
|---|---|---|
| For | A value the VM itself must have, such as its database password | An API key a service needs, such as an OpenAI key |
| Enters the VM? | **Yes:** as a file, a variable, or both, and only in VMs you grant it to | **Never:** the broker adds it to allowed requests, on your Mac |
| Commands | `koala secret set / inspect / rm` | `koala credential set / inspect / rm` |

In about ten minutes you will store one of each, give them to VMs, and see
the difference for yourself.

**You'll learn:** `koala secret set`, `koala secret inspect`,
`koala create --secret-file` and `--secret-env`, `koala secret rm`,
`koala credential set`, `koala credential inspect`,
`koala policy create --credential` and `koala credential rm`.

Every command and every output on this page comes from a real run. The
values here are made up; use your own.

## Before you start

Koala is installed and running ([Tutorial 1](tutorial-first-vm.md)).

## Step 1: Store a secret

`koala secret set` asks for the value without showing it as you type:

<!-- tutorial: skip -->
```console
$ koala secret set demo-token
```

Or pipe it in, from a password manager for example. Use `printf %s`, not
`echo`, so that no newline is added to the value:

```console
$ printf %s 'not-a-real-token-123' | koala secret set demo-token --value-stdin
secret demo-token version 7e73f5bd-8f32-4619-a1f5-3cd65ba41afc (20 bytes, updated …)
$ koala secret inspect demo-token
demo-token
  value      20 bytes, never shown
  version    7e73f5bd-8f32-4619-a1f5-3cd65ba41afc
  updated    …
```

Koala never prints a value, and never takes one as a command argument,
where it would end up in your shell history.

## Step 2: Give the secret to one VM

Grant it when you create the VM: as a file, as a variable, or both.

```console
$ koala create with-secret --image docker.io/library/alpine:3 --no-internet --secret-file demo-token=/run/secrets/demo-token --secret-env demo-token=DEMO_TOKEN --wait
internet off
secret demo-token -> $DEMO_TOKEN
secret demo-token -> file /run/secrets/demo-token
accepted operation 59a7444a-b384-4840-95d4-0cadbd5097d4 (vm.create)
succeeded 59a7444a-b384-4840-95d4-0cadbd5097d4
$ koala start with-secret --wait
accepted operation d2d09369-f3cb-4584-becb-632b8ba31f85 (vm.start)
succeeded d2d09369-f3cb-4584-becb-632b8ba31f85
```

Inside the VM, the value is there:

```console
$ koala exec with-secret -- sh -c 'cat /run/secrets/demo-token; echo'
not-a-real-token-123
$ koala exec with-secret -- sh -c 'echo "DEMO_TOKEN has ${#DEMO_TOKEN} characters"'
DEMO_TOKEN has 20 characters
```

The file is readable only by root, and it lives in memory (`tmpfs`), never
on the VM's disk:

```console
$ koala exec with-secret -- sh -c 'ls -l /run/secrets/; mount | grep /run/secrets'
total 4
-r--------    1 root     root            20 … demo-token
tmpfs on /run/secrets type tmpfs (rw,nosuid,nodev,noexec,relatime,size=8192k,mode=700)
```

A file is safer than a variable: programs pass their variables on to every
child process, and they show up in crash reports. Use `--secret-env` only
for a program that can't read a file.

`koala inspect` lists every secret a VM was given:

```console
$ koala inspect with-secret
with-secret (20a49604-651d-436d-a380-4448ade18135)
  state      Running
  mode       environment, lean profile
  image      docker.io/library/alpine:3
             … digest sha256:1829893486be…
  resources  1 vCPU, 256 MiB memory, 1 GiB disk
  command    the image's
  user       the image's
  internet   off
  grants     none
  published  none
  volumes    none
  shares     none
  secrets    demo-token as $DEMO_TOKEN
             demo-token as the file /run/secrets/demo-token
  run        f8321f5c-c52d-4af8-8798-eaccf9fd3f03
  spec       generation 1; cleanup: retain
```

A VM you didn't grant it to gets nothing:

```console
$ koala create without --image docker.io/library/alpine:3 --no-internet --wait
internet off
accepted operation c37eb0ad-c2a4-4196-8be0-b3f5644949c9 (vm.create)
succeeded c37eb0ad-c2a4-4196-8be0-b3f5644949c9
$ koala start without --wait
accepted operation 05dcfad3-e63e-4b68-b6d9-1969dbbdf020 (vm.start)
succeeded 05dcfad3-e63e-4b68-b6d9-1969dbbdf020
$ koala exec without -- sh -c 'ls /run/secrets 2>&1; echo "DEMO_TOKEN=[$DEMO_TOKEN]"'
ls: /run/secrets: No such file or directory
DEMO_TOKEN=[]
```

## Step 3: Store a key that never enters a VM

An API key for a service is better kept out of the VM altogether. Store it
as a **credential**. Without `--value-stdin`, it asks for the key:

```console
$ printf %s 'sk-not-a-real-key' | koala credential set demo-key --value-stdin
credential demo-key stored for the broker
$ koala credential inspect demo-key
demo-key
  stored     yes, …; never shown
```

On a Mac the key is in your login keychain; on Linux, in the broker's own
encrypted files. A credential is used through a broker **policy**, which says where the key
goes and what it may be used for:

```console
$ koala policy create demo-ai --template openai --model gpt-4.1-mini --credential demo-key
policy demo-ai created from openai v2 (chat, models; model gpt-4.1-mini); using the existing credential demo-key
$ koala policy inspect demo-ai
demo-ai
  template   openai v2 (groups: chat, models)
  service    https://api.openai.com
  key        api: credential demo-key
  adds       header authorization: Bearer <key api>
  allows     POST /v1/chat/completions
             GET  /v1/models
             GET  /v1/models/{model}
  models     gpt-4.1-mini
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

`adds  header authorization: Bearer <key api>`: the broker, on your Mac,
adds the key to each request the policy allows. Give a VM the policy, and
look for the key:

```console
$ koala create with-key --image docker.io/library/alpine:3 --no-internet --broker openai=demo-ai --wait
internet off
broker openai -> policy demo-ai
accepted operation 23ed38c8-f08b-4142-9f73-eb18d472ecae (vm.create)
succeeded 23ed38c8-f08b-4142-9f73-eb18d472ecae
$ koala start with-key --wait
accepted operation 720d7ff4-593a-4026-9d8e-44bdda8920f5 (vm.start)
succeeded 720d7ff4-593a-4026-9d8e-44bdda8920f5
$ koala exec with-key -- sh -c 'env | grep ^OPENAI | sort'
OPENAI_API_KEY=koala-brokered
OPENAI_BASE_URL=http://openai.broker.koala.internal/v1
```

The VM has a placeholder, `koala-brokered`, and an address for the broker.
OpenAI's libraries read these two variables, so an agent works unchanged,
and a compromised VM has no key to steal. (Tutorial 4 shows a policy at
work: [Decide what an agent can reach](tutorial-policy.md).)

## Step 4: Clean up

```console
$ koala stop with-secret --wait
accepted operation 1953259f-0a45-4175-be2d-78169ad5b265 (vm.stop)
succeeded 1953259f-0a45-4175-be2d-78169ad5b265
$ koala rm with-secret --wait
accepted operation ea58eae3-a23d-402a-a1ea-73698395b4f3 (vm.remove)
succeeded ea58eae3-a23d-402a-a1ea-73698395b4f3
$ koala stop without --wait
accepted operation 1323c592-9be6-46c9-b9eb-2c509cd69a1b (vm.stop)
succeeded 1323c592-9be6-46c9-b9eb-2c509cd69a1b
$ koala rm without --wait
accepted operation 09c4231f-b9aa-4f2b-b618-311de5bad728 (vm.remove)
succeeded 09c4231f-b9aa-4f2b-b618-311de5bad728
$ koala stop with-key --wait
accepted operation bd0aa63f-10c4-4a68-81dd-aefec0945579 (vm.stop)
succeeded bd0aa63f-10c4-4a68-81dd-aefec0945579
$ koala rm with-key --wait
accepted operation ec6a881e-3888-4ce2-98d6-7dde52705ccc (vm.remove)
succeeded ec6a881e-3888-4ce2-98d6-7dde52705ccc
$ koala policy rm demo-ai
removed policy demo-ai
$ koala credential rm demo-key
removed credential demo-key
$ koala secret rm demo-token
removed secret demo-token (copies already in guests are not retracted)
```

`koala secret rm` deletes the secret from your keychain, but a VM that
already received it keeps its copy: a value can't be taken back. If a
secret may have leaked, change it at its source too.

## What you learned

| Command | What it does |
|---|---|
| `koala secret set NAME [--value-stdin]` | Store a value for VMs (asks for it, or reads stdin) |
| `koala secret inspect NAME` | Its size, version and time; never the value |
| `koala create … --secret-file NAME=/path` | Give it to a VM as a root-only file in memory |
| `koala create … --secret-env NAME=VAR` | Give it as a variable (prefer a file) |
| `koala secret rm NAME` | Delete it; VMs that had it keep their copy |
| `koala credential set NAME [--value-stdin]` | Store an API key only the broker uses |
| `koala credential inspect NAME` | Whether it exists; never the value |
| `koala policy create NAME --template T --credential C` | A policy that adds that key to allowed requests |
| `koala credential rm NAME` | Delete the key |

## Next

**Next tutorial:** [Tutorial 6: Services and ports](tutorial-services.md).

More on this page's topics:

- [Secrets](secrets.md): limits, spec files, and the macOS prompt after an
  upgrade.
- [Keys on your Mac (the broker)](broker.md): where the broker puts a key,
  and keys for chat platforms and GitHub.
