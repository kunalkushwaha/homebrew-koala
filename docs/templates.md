# VM templates for agents

[User guide](README.md) > VM templates for agents

A **VM template** sets an agent up in one command. One template holds
everything the agent needs:
- its VM: the image, resources, command, network and published ports;
- the [broker](broker.md) policies that keep its API keys on your Mac;
- its volumes, for data that outlives the VM;
- the setup to run inside the VM once it is up.

```sh
koala template list                     # the templates
koala template inspect hermes           # what one makes, and its parameters
koala create hermes --template hermes   # make it
koala template update                   # get newer templates, when you want them
```

The built-in template is `hermes`, the [Hermes agent](example-hermes.md).
Its file is `examples/hermes/template.json` in Koala's Homebrew tap. You can
also [write your own](#your-own-templates). An agent without a template is
set up with `koala create` flags, as the [OpenClaw example](example-openclaw.md)'s
script does.

## What `koala create --template` does

1. **It checks everything first.** It renders the template on your Mac,
   then checks the manager:
   - the VM name is free;
   - any policy of the same name is identical;
   - anything the VM uses that the template doesn't create exists.

   If something is wrong, it stops, and nothing has changed.
2. **It shows the plan:**
   - the VM;
   - everything the VM can reach (internet, broker grants, published
     ports, volumes, shared directories);
   - the keys, policies and volumes it creates or reuses;
   - the setup commands.
3. **It asks** `Continue? [y/N]`. With `--yes`, it doesn't ask.
4. **It makes it all:**
   - It asks for any missing key, without echoing it, and stores the key in
     your login keychain, as `koala policy create` does.
   - It stores the policies, creates the volumes and the VM, then starts
     the VM. The first start downloads the image, which can take a while.
   - It waits until the agent is ready, runs the setup commands in the VM
     (their output is shown), and restarts the VM if the template asks for
     that.
5. **It prints** `hermes is running`, and the template's notes: where the
   agent listens, and how to use it.

The plan for the built-in `hermes` template looks like this:

```text
Template hermes v1 (built in): The Hermes agent's gateway, with its model key on your Mac and no internet
Parameters: credential=hermes-openai image=docker.io/nousresearch/hermes-agent:latest model=gpt-4.1-mini origin=https://api.openai.com port=8642 tls-pin=
It will make:
  VM hermes: docker.io/nousresearch/hermes-agent:latest, lean service, 2 CPUs, 2048 MiB memory, 6144 MiB disk
    publish tcp 127.0.0.1:8642 -> 8642 (loopback)
    volume hermes-data -> /opt/data (rw)
    internet off
    broker openai -> policy hermes-openai
  credential hermes-openai: koala asks for the key
  policy hermes-openai: openai v1, https://api.openai.com, models gpt-4.1-mini, key hermes-openai
  volume hermes-data: 2048 MiB, new
  then waits, up to 300 s, until this succeeds in the VM: curl -fsS -m 2 -o /dev/null http://127.0.0.1:8642/health
  runs in the VM: hermes config set model.provider custom
  ...
  then restarts the VM
  and leaves the VM running.
Continue? [y/N]
```

## Parameters

A template's parameters are its settings. `koala template inspect`
lists them, with their defaults. Set one with `--set NAME=VALUE`, repeated
for each:

```sh
# Another model
koala create hermes --template hermes --set model=gpt-4.1

# Another OpenAI-compatible provider
koala create hermes --template hermes --set origin=https://api.mistral.ai --set model=mistral-small-latest

# A second Hermes, on another port
koala create hermes-2 --template hermes --set port=8643
```

- **Names are derived from the VM's name.** `koala create hermes-2` makes
  the policy `hermes-2-openai`, the key `hermes-2-openai` and the volume
  `hermes-2-data`.
- **To share one stored key between agents,** name it: `--set
  credential=openai`.
- **`--cpus`, `--memory` and `--disk`** change the VM's resources, as with
  `koala create`.
- **To change anything else,** [copy the template](#your-own-templates), or
  change the VM afterwards with `koala edit`.

Parameters are not secret. The plan shows them, and they end up in the VM's
definition and its policies. Never pass a key with `--set`: keys come from
the prompt, or from stdin with `--value-stdin`, which sets the template's
one key.

## What is reused

- **A volume that exists** is used as it is, with its data. So after
  `koala stop hermes --wait` and `koala rm hermes`, running the same
  `koala create` again gives a new VM with the old data.
- **A policy that exists and is identical** is reused. One that differs is
  refused: see it with `koala policy inspect`, and remove it with `koala
  policy rm` if you no longer need it.
- **A key that is stored** is used without asking. With `--value-stdin`,
  the key from stdin replaces it.

## If a step fails

`koala create --template` stops at the first step that fails. It doesn't
undo anything. It says:
- what it did before stopping;
- the commands that would finish the job by hand;
- the commands that remove what this run made (`koala stop`, `koala rm`,
  `koala volume rm`, `koala policy rm`, `koala credential rm`).

Ctrl-C stops it the same way.

## Your own templates

Start from a built-in template:

```sh
koala template inspect hermes --json > my-agent.json
# edit my-agent.json
koala template inspect ./my-agent.json
koala create my-agent --template ./my-agent.json
```

A template is a JSON file:

```json
{"format": 1, "name": "my-agent", "version": 1, "description": "What it runs",
 "parameters": {"port": {"description": "The port on your Mac", "type": "integer", "default": 8080}},
 "policies": [{"name": "{{vm}}-openai", "template": "openai", "models": ["gpt-4.1-mini"]}],
 "volumes": [{"name": "{{vm}}-data", "size": "1GiB"}],
 "vm": {"mode": "service", "image": {"kind": "oci", "reference": "docker.io/example/my-agent:1", "platform": "linux/arm64"},
        "network": {"internet": false,
                    "allow": [{"kind": "broker", "name": "openai", "policy": "{{vm}}-openai"}],
                    "publish": [{"protocol": "tcp", "hostAddress": "127.0.0.1", "hostPort": "{{port}}", "guestPort": 8080}]},
        "volumes": [{"name": "{{vm}}-data", "destination": "/data", "readOnly": false}]},
 "setup": {"ready": {"command": ["test", "-d", "/data"], "timeoutSeconds": 60},
           "commands": [{"command": ["my-agent", "init"]}], "restart": false},
 "notes": ["It listens on http://127.0.0.1:{{port}}"]}
```

- **`vm`** is a VM spec, as in a `koala create -f` file ([Jobs and
  VMs](vms.md#persistent-vms-from-a-spec-file-koala-create--f)), without its
  `name`.
  - The mode is `service` or `environment`.
  - Koala adds labels that name the template (`koala inspect` shows them).
- **`policies`** are made from built-in [policy templates](broker.md#set-it-up):
  - `template` and `name` are required;
  - `credential`, `origin`, `tlsPin`, `groups` and `models` are optional,
    as the flags of `koala policy create`.

  Each policy must be used by one of the VM's broker grants.
- **`volumes`** are created if missing, with `size` in `koala volume
  create`'s form. Each must be one of the VM's volumes.
- **`setup`** runs once, inside the VM, after its first start:
  - `ready` is retried every 2 seconds until it succeeds, for up to
    `timeoutSeconds`;
  - each of `commands` must then succeed;
  - `restart` restarts the VM afterwards.

  Each command is a list of arguments, not a shell line. Add `user` to run
  one as another guest user.
- **`parameters`** each have a `description`, an optional `type`
  (`string` or `integer`) and an optional `default`. A parameter with no
  default must be set.
  - `{{NAME}}` in any value is replaced by the parameter's value, and
    `{{vm}}` by the VM's name.
  - A value that is exactly `"{{port}}"`, for an integer parameter, becomes
    a number.
  - Replaced text is never read again for `{{`.
- **`notes`** are printed at the end.

Koala checks a template strictly before using it. Unknown fields and
references to parameters that don't exist are errors, given with the place
in the file, such as `at /vm/network/publish/0/hostPort`.

## Newer templates

Templates come with Koala, and newer ones can be published between
releases. `koala template update` downloads them, with the
[policy templates](broker.md#set-it-up) (which `koala policy templates`
lists):

```sh
koala template update
```

```text
updated the templates from https://raw.githubusercontent.com/kunalkushwaha/homebrew-koala/main/
serial 7, signed by koala-release-1
  vm hermes v2: replaces built-in v1
  policy openai v1: same as built-in
```

- **Until a template changes, nothing changes.** Each line says `same as
  built-in`, and your koala keeps using its own copy, so `template list`
  shows no `(downloaded)`.
- **It runs only when you ask.** Koala never fetches templates on its own.
- **It keeps only what Koala's release key signed.** The templates' index
  is signed with the key that signs Koala's releases. Your koala checks it
  against the key in its own installation, then checks each file against
  the index. If any check fails, nothing changes.
- **It never goes back.** An index older than the one you have is refused.
- **A downloaded template is used when its version is higher** than the one
  built into your koala.
  - `koala template list` and `koala policy templates` mark it
    `(downloaded)`.
  - A VM made from it has the label `koala.dev/template-source: downloaded`.
- **What you already made doesn't change.** A policy made from an older
  template is updated with `koala policy upgrade`, which shows the change
  first ([Day to day](broker.md#day-to-day)).
- **The templates are kept in `~/Library/Application Support/Koala/templates`**,
  and checked again each time koala uses them. If they were changed, koala
  says so, ignores them and uses its built-ins. `koala template update`
  downloads them again.
- **`--source URL`** reads another copy of Koala's Homebrew tap:
  - an `https://` address;
  - `http://` on this Mac only (`127.0.0.1`, `::1` or `localhost`);
  - a folder, as `file:///path/to/homebrew-koala/`.

  The signature is still required, so a copy can't change what you get.
- **It needs a released koala** (Homebrew or a release archive), which
  carries the release key. A koala built from source has none, and refuses.

## Safety

- **Read the plan, especially for a template from a file.** A template can
  ask for anything a VM definition can: internet access, your Mac's
  services, directories from your Mac, published ports on your LAN. The
  plan lists all of it before anything changes.
- **A template can also use what you already have.** A broker policy or a
  volume that the VM uses, but the template doesn't make, is named in the
  plan as `yours, not made by this template`. Such a VM can use that
  policy's key, or that volume's data.
- **Templates run nothing on your Mac.** Setup commands run inside the VM,
  as `koala exec` would run them.
- **A downloaded template is as safe as Koala's review of it.** The
  signature proves it was published with Koala's releases. The plan still
  shows everything it asks for before anything changes.
- **Keys never appear in a template.** They come from the prompt or stdin,
  and stay in your login keychain. The VM gets broker grants, not keys.
