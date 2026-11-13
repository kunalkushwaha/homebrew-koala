# Koala commands

Generated from `koala 0.1.0-rc.3 --help` by `scripts/skill-commands.py`; don't edit by hand.
When the installed Koala is newer, its own `koala COMMAND --help` wins.

## `koala`

```text
Usage:  koala [OPTIONS] COMMAND

Run AI agents and other Linux workloads, each in its own VM on your Mac.

Common commands:
  run              Run a command in a new job VM
  create           Create a VM
  start            Start a VM
  stop             Stop a VM
  exec             Run a command in a running VM
  list (ls, ps)    List VMs
  logs             Show a VM's or a command's output
  cp               Copy files between your Mac and a VM

More VM commands:
  inspect          Show a VM's details
  rm               Delete a VM
  edit             Change a stopped VM's definition in your editor
  update           Change a stopped VM's definition
  attach           Reattach to a running command
  console          Show a VM's serial console
  stats            Show what running VMs use
  events           Show VM events

Management commands:
  template         See the VM templates for agents, and update them
  volume           Manage volumes
  image            Manage images
  registry         Log in to registries
  secret           Manage secrets for VMs
  credential       Manage keys the broker uses on this Mac
  policy           Manage what VMs may ask the broker to do
  execution        Inspect or cancel commands
  operation        Follow a change koala accepted
  system           Install and run Koala
  config           Check VM definition files
  runtime          Manage VM runtimes

Global options:
      --json           Print JSON, for scripts
      --wait           Return only when a change has finished
      --timeout S      Wait at most S seconds (default 600)
      --socket PATH    Use the manager at this socket
  -h, --help           Show help
      --version        Print the version

Run 'koala COMMAND --help' for more information on a command.
```

### `koala run`

```text
Usage:  koala run [OPTIONS] --image REF -- COMMAND [ARG...]

Run a command in a new job VM.

Creates a job VM from the image, runs COMMAND in it and streams its output. The
VM is removed when the command ends, and koala exits with the command's exit
status.

Options:
      --image REF           The OCI image to run (required)
  -i                        Send your stdin to the command
  -t                        Give the command a terminal
      --profile P           The runtime profile
      --cpus N              Virtual CPUs (default 1)
      --memory MiB          Memory in MiB (default 512)
      --disk MiB            Disk size in MiB (default 1024)
      --timeout S           Kill the command after S seconds (exit status 124)
      --detach              Start the command, print its ID and return
      --result-file PATH    Write the result as JSON
      --json                With --detach or --result-file: print JSON
      --rm                  Accepted for familiarity: job VMs are always removed

Examples:
  koala run --image docker.io/library/alpine:3 -- uname -a
  koala run -it --image docker.io/library/alpine:3 -- /bin/sh
```

### `koala create`

```text
Usage:  koala create NAME (--image REF | --catalog NAME) [OPTIONS] [-- ARG...]
        koala create -f FILE [--wait]
        koala create NAME --template T [--set NAME=VALUE]... [--yes]

Create a VM.

Creates a VM from an image or catalog entry, or from a VM definition file. It
prints the access the VM is given (internet, grants, ports, volumes, mounts,
secrets) first. Arguments after -- replace the image's command. With --template,
it also creates the template's broker policies and volumes, asks for any missing
key, then starts the VM and sets it up; it shows all of that and asks before
changing anything.

Options:
  -f, --file FILE               Create from a VM definition file
      --template T              Create from a VM template: a name (koala
                                template list) or a file
      --set NAME=VALUE          With --template: set a template parameter.
                                Repeatable.
      --value-stdin             With --template: read the one missing key from
                                stdin
      --yes                     With --template: don't ask before creating
      --internet                With --template: give the VM internet access,
                                whatever the template says
      --image REF               An OCI image (lean profile)
      --catalog NAME            A Koala catalog entry (full profile)
      --profile P               The runtime profile: lean or full
      --mode M                  job, service or environment (default
                                environment)
      --cpus N                  Virtual CPUs (default 1; 2 with the full
                                profile)
      --memory MiB              Memory in MiB (default 256; 1024 with the full
                                profile)
      --disk MiB                Disk size in MiB (default 1024; 8192 with the
                                full profile)
      --publish SPEC            Publish a guest port on your Mac:
                                [ADDR:]HOST:GUEST[/tcp|/udp]. Repeatable.
      --volume SPEC             Attach a volume: NAME:/path[:ro]. Repeatable.
      --mount SPEC              Share a Mac directory, read-only unless :rw:
                                /host:/guest[:rw]. Repeatable.
      --env KEY=VALUE           Set a variable for the VM's process. Repeatable.
      --user U                  Run the process as this guest user
      --workdir DIR             Start the process in this guest directory
      --entrypoint PATH         Replace the image's entrypoint
      --no-internet             No internet access; grants still apply. Also
                                with --template.
      --broker GRANT=POLICY     Reach a broker policy at
                                GRANT.broker.koala.internal. Repeatable.
      --host-service SPEC       Reach a service on your Mac:
                                ADDR:PORT[,PORT][/udp]. Repeatable.
      --domain NAME[:PORTS]     With --no-internet: reach this host (pypi.org,
                                *.example.com) over TLS, port 443 unless given.
                                Repeatable.
      --secret-env NAME=VAR     Give a secret as a variable. Repeatable.
      --secret-file NAME=/PATH
                                Give a secret as a file. Repeatable.
      --wait                    Return only when the change has finished
      --timeout S               With --wait: give up after S seconds (default
                                600)

Examples:
  koala create dev --image docker.io/library/alpine:3 --wait
  koala create dev --image docker.io/library/alpine:3 --volume data:/data --wait
  koala create bot --image alpine --no-internet --broker ai=openai-main
  koala create dev --image alpine --no-internet --domain pypi.org
  koala create svc --image alpine --mode service --wait -- sleep 3600
  koala create -f web.json --wait
  koala create hermes --template hermes --set model=gpt-4.1-mini
  koala create hermes --template hermes --internet
```

### `koala start`

```text
Usage:  koala start VM [--wait]

Start a VM.

Options:
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)

Examples:
  koala start dev --wait
```

### `koala stop`

```text
Usage:  koala stop VM [--wait]

Stop a VM.

Options:
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)

Examples:
  koala stop dev --wait
```

### `koala exec`

```text
Usage:  koala exec [OPTIONS] VM -- COMMAND [ARG...]

Run a command in a running VM.

Streams the command's output, and exits with its exit status. With -t, Ctrl-]
then d detaches and leaves the command running; reattach with koala attach.

Options:
  -i                        Send your stdin to the command
  -t                        Give the command a terminal
      --user U              Run as this guest user
      --workdir DIR         Start in this guest directory
      --env KEY=VALUE       Set a variable. Repeatable.
      --timeout S           Kill the command after S seconds (exit status 124)
      --result-file PATH    Write the result as JSON
      --json                With --result-file: print JSON

Examples:
  koala exec dev -- ls /
  koala exec -it dev -- /bin/sh
```

### `koala list`

```text
Usage:  koala list [--json]

List VMs.

Aliases:
  koala ls, koala ps

Options:
      --json    Print JSON

Examples:
  koala list
```

### `koala logs`

```text
Usage:  koala logs VM [--execution ID | --serial] [--run ID] [--follow]

Show a VM's or a command's output.

Without --execution or --serial, shows the output of the VM's main command.

Options:
      --execution ID    The output of this command
      --serial          The VM's serial console
      --run ID          From this run of the VM, with --execution or --serial
      --follow          Keep printing new output
      --json            Print JSON

Examples:
  koala logs web --follow
  koala logs dev --serial
```

### `koala cp`

```text
Usage:  koala cp [OPTIONS] SRC DST

Copy files between your Mac and a VM.

One side is VM:/absolute/path. DST names the new file or directory, and must not
exist unless --replace is given.

Options:
      --replace                 Replace DST if it exists
      --transfer-helper PATH    Use this koala-transfer helper
      --json                    Print JSON

Examples:
  koala cp ./src dev:/work/src
  koala cp dev:/work/out.txt ./out.txt
```

### `koala inspect`

```text
Usage:  koala inspect VM [--json | --export]

Show a VM's details.

Options:
      --json      Print JSON
      --export    Print the VM's definition, for create -f

Examples:
  koala inspect dev
  koala inspect --export web > web.json
```

### `koala rm`

```text
Usage:  koala rm VM [--wait]

Delete a VM.

Volumes attached to the VM are kept.

Options:
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)

Examples:
  koala rm dev --wait
```

### `koala edit`

```text
Usage:  koala edit VM [--wait]

Change a stopped VM's definition in your editor.

Opens the VM's definition in $VISUAL or $EDITOR (default vi), then checks and
applies it. If it cannot be applied, the file is kept for koala update.

Options:
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)

Examples:
  koala edit web --wait
```

### `koala update`

```text
Usage:  koala update VM -f FILE [--wait]

Change a stopped VM's definition.

Options:
  -f, --file FILE    The new VM definition
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)

Examples:
  koala update web -f web.json --wait
```

### `koala attach`

```text
Usage:  koala attach [OPTIONS] EXECUTION

Reattach to a running command.

Options:
      --no-stdin            Show the output only; don't send stdin
      --cursor N            Resume the output after sequence number N
      --result-file PATH    Write the result as JSON

Examples:
  koala attach EXECUTION_ID
```

### `koala console`

```text
Usage:  koala console VM [--follow]

Show a VM's serial console.

Options:
      --follow    Keep printing new output
      --json      Print JSON

Examples:
  koala console dev
```

### `koala stats`

```text
Usage:  koala stats [VM] [--follow]

Show what running VMs use.

Without a VM, a table of every running VM. CPU, memory and processes are
reported by each guest and not verified; disk and network are measured by the
host.

Options:
      --follow    Refresh every 2 seconds until Ctrl-C
      --json      Print JSON

Examples:
  koala stats
  koala stats dev
```

### `koala events`

```text
Usage:  koala events [--vm VM] [--follow]

Show VM events.

Options:
      --vm VM     Only this VM's events
      --follow    Keep printing new events
      --json      Print JSON

Examples:
  koala events --vm dev --follow
```

### `koala template`

```text
Usage:  koala template COMMAND

See the VM templates for agents, and update them.

Commands:
  list (ls)    List the VM and policy templates
  inspect      Show what a VM template creates
  update       Download the latest VM and policy templates

Run 'koala template COMMAND --help' for more information on a command.
```

### `koala template list`

```text
Usage:  koala template list

List the VM and policy templates.

Aliases:
  koala template ls

A VM template describes everything an agent needs: its VM, broker policies,
volumes and setup; use one with koala create NAME --template T. A policy
template is one service's policy; use one with koala policy create NAME
--template T. Templates from koala template update are marked (downloaded).

Options:
      --json    Print JSON

Examples:
  koala template list
```

### `koala template inspect`

```text
Usage:  koala template inspect T|FILE [--set NAME=VALUE]... [--json]

Show what a VM template creates.

Shows the template's parameters, and what koala create would make from it: the
VM and what it can reach, the policies, volumes and setup. --json prints the
template itself, to copy and change.

Options:
      --set NAME=VALUE    Set a parameter, as koala create would. Repeatable.
      --json              Print JSON

Examples:
  koala template inspect hermes
  koala template inspect hermes --json
```

### `koala template update`

```text
Usage:  koala template update [--source URL]

Download the latest VM and policy templates.

Fetches the templates published with Koala's releases, only when you run it.
They are kept only if their index is signed with the release key of this koala,
and is not older than the one you have. A downloaded template is used when its
version is higher than the built-in one. Nothing changes if any check fails.
Needs a released koala (Homebrew or a release archive).

Options:
      --source URL    Fetch from here: https://…, http:// on this Mac, or
                      file:///… (default: the homebrew-koala repository)
      --json          Print JSON

Examples:
  koala template update
```

### `koala volume`

```text
Usage:  koala volume COMMAND

Manage volumes.

Commands:
  create       Create a volume
  list (ls)    List volumes
  rm           Delete a volume

Run 'koala volume COMMAND --help' for more information on a command.
```

### `koala volume create`

```text
Usage:  koala volume create NAME --size SIZE

Create a volume.

Options:
      --size SIZE    Like 512MiB or 10GiB, from 128 MiB to 1 TiB (required)
      --json         Print JSON

Examples:
  koala volume create data --size 10GiB
```

### `koala volume list`

```text
Usage:  koala volume list

List volumes.

Aliases:
  koala volume ls

Options:
      --json    Print JSON

Examples:
  koala volume list
```

### `koala volume rm`

```text
Usage:  koala volume rm NAME

Delete a volume.

Examples:
  koala volume rm data
```

### `koala image`

```text
Usage:  koala image COMMAND

Manage images.

Commands:
  pull         Download an image
  list (ls)    List images
  prune        Remove images no VM uses

Run 'koala image COMMAND --help' for more information on a command.
```

### `koala image pull`

```text
Usage:  koala image pull REF [--registry-login ID]

Download an image.

Options:
      --registry-login ID    Use this login, from koala registry login
      --wait                 Return only when the change has finished
      --timeout S            With --wait: give up after S seconds (default 600)

Examples:
  koala image pull docker.io/library/alpine:3 --wait
```

### `koala image list`

```text
Usage:  koala image list

List images.

Aliases:
  koala image ls, koala images

Options:
      --json    Print JSON

Examples:
  koala image list
```

### `koala image prune`

```text
Usage:  koala image prune [--wait]

Remove images no VM uses.

Options:
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)

Examples:
  koala image prune --wait
```

### `koala registry`

```text
Usage:  koala registry COMMAND

Log in to registries.

Commands:
  login     Store a registry login
  logout    Delete a registry login

Run 'koala registry COMMAND --help' for more information on a command.
```

### `koala registry login`

```text
Usage:  koala registry login REGISTRY --username USER [--password-stdin]

Store a registry login.

Prints the login ID that image pull --registry-login takes. The password is read
from a prompt, or from stdin with --password-stdin; it is never accepted as an
argument.

Options:
      --username USER     The registry user (required)
      --password-stdin    Read the password from stdin
      --json              Print JSON

Examples:
  koala registry login ghcr.io --username me
  koala registry login ghcr.io --username me --password-stdin < password.txt
```

### `koala registry logout`

```text
Usage:  koala registry logout LOGIN_ID

Delete a registry login.

Examples:
  koala registry logout LOGIN_ID
```

### `koala secret`

```text
Usage:  koala secret COMMAND

Manage secrets for VMs.

Commands:
  set        Store a secret for VMs
  inspect    Show a secret's details, never its value
  rm         Delete a secret

Run 'koala secret COMMAND --help' for more information on a command.
```

### `koala secret set`

```text
Usage:  koala secret set NAME [--value-stdin]

Store a secret for VMs.

The value is read from a prompt, or from stdin with --value-stdin; it is never
accepted as an argument.

Options:
      --value-stdin    Read the value from stdin, byte for byte
      --json           Print JSON

Examples:
  koala secret set agent-token
  koala secret set agent-token --value-stdin < token.txt
```

### `koala secret inspect`

```text
Usage:  koala secret inspect NAME

Show a secret's details, never its value.

Options:
      --json    Print JSON

Examples:
  koala secret inspect agent-token
```

### `koala secret rm`

```text
Usage:  koala secret rm NAME

Delete a secret.

Examples:
  koala secret rm agent-token
```

### `koala credential`

```text
Usage:  koala credential COMMAND

Manage keys the broker uses on this Mac.

Commands:
  set        Store a key for the broker (it never enters a VM)
  inspect    Show whether a broker key exists, never its value
  rm         Delete a broker key

Run 'koala credential COMMAND --help' for more information on a command.
```

### `koala credential set`

```text
Usage:  koala credential set NAME [--value-stdin]

Store a key for the broker (it never enters a VM).

The broker adds it to requests on this Mac; a VM gets a broker grant, never the
key. The value is read from a prompt, or from stdin with --value-stdin.

Options:
      --value-stdin    Read the value from stdin, byte for byte
      --json           Print JSON

Examples:
  koala credential set openai-main
  koala credential set openai-main --value-stdin < key.txt
```

### `koala credential inspect`

```text
Usage:  koala credential inspect NAME

Show whether a broker key exists, never its value.

Options:
      --json    Print JSON

Examples:
  koala credential inspect openai-main
```

### `koala credential rm`

```text
Usage:  koala credential rm NAME

Delete a broker key.

Examples:
  koala credential rm openai-main
```

### `koala policy`

```text
Usage:  koala policy COMMAND

Manage what VMs may ask the broker to do.

Commands:
  templates    List the policy templates, or show one
  create       Create a broker policy from a template
  upgrade      Update a policy to its template's current version
  add          Add or replace a broker policy
  validate     Check a policy file without adding it
  list (ls)    List broker policies
  inspect      Show what a broker policy allows
  rm           Remove a broker policy
  disable      Stop a policy at once, cancelling its requests
  enable       Re-enable a disabled policy
  status       Show broker use per VM (counters only)
  check        Read the policies' credentials again and say which didn't load
  test         Say whether a policy lets a request through, and why (nothing is
               sent)
  suggest      List what the broker refused under a policy, and offer to allow
               it

Run 'koala policy COMMAND --help' for more information on a command.
```

### `koala policy templates`

```text
Usage:  koala policy templates [NAME]

List the policy templates, or show one.

Each template is a reviewed policy for one service, with named groups of
requests. Without NAME, a table; with NAME, its description, key, groups and how
to use it. Templates from koala template update are marked (downloaded).

Options:
      --json    Print JSON

Examples:
  koala policy templates
  koala policy templates openai
```

### `koala policy create`

```text
Usage:  koala policy create NAME --template T [--model M]... [OPTIONS]

Create a broker policy from a template.

Asks for the key unless the credential (default: NAME) exists. The stored policy
records its template, for koala policy upgrade. --print shows the policy and
stores nothing.

Options:
      --template T           The template (see koala policy templates)
      --model M              Allow only this model; repeat for more
      --allow G,G            The groups of requests to allow (default: the
                             template's)
      --credential C         The broker key to use (default: NAME)
      --origin URL           Another service with the same API under /v1, such
                             as https://api.mistral.ai
      --tls-pin SHA256       Trust only this certificate (SHA-256 of its DER)
      --app-id ID            A GitHub App's ID or client ID (template github)
      --installation-id N    The App's installation (template github)
      --repo OWNER/NAME      Only this repository; repeat for more (template
                             github)
      --value-stdin          Read the key from stdin instead of a prompt
      --replace              Replace an existing policy
      --print                Print the policy instead of storing it
      --json                 Print JSON

Examples:
  koala policy create openai-main --template openai --model gpt-4.1-mini
  koala policy create mistral --template openai --origin https://api.mistral.ai
  koala policy create gh --template github --app-id 12 --installation-id 34
```

### `koala policy upgrade`

```text
Usage:  koala policy upgrade NAME [--yes]

Update a policy to its template's current version.

Keeps the policy's name, key, service, groups and models, and shows what
changes. Nothing changes without --yes.

Options:
      --yes     Apply the change
      --json    Print JSON

Examples:
  koala policy upgrade openai-main
```

### `koala policy add`

```text
Usage:  koala policy add -f FILE

Add or replace a broker policy.

A JSON policy names one upstream, its key and the allowed requests. To start
one, use koala policy create --print. A replaced policy cancels its in-flight
requests.

Options:
  -f, --file FILE    The policy file
      --json         Print JSON

Examples:
  koala policy add -f openai-main.json
```

### `koala policy validate`

```text
Usage:  koala policy validate -f FILE

Check a policy file without adding it.

Options:
  -f, --file FILE    The policy file
      --json         Print JSON

Examples:
  koala policy validate -f openai-main.json
```

### `koala policy list`

```text
Usage:  koala policy list

List broker policies.

Aliases:
  koala policy ls

Options:
      --json    Print JSON

Examples:
  koala policy list
```

### `koala policy inspect`

```text
Usage:  koala policy inspect NAME

Show what a broker policy allows.

With --json, prints the stored policy document instead.

Options:
      --json    Print JSON

Examples:
  koala policy inspect openai-main
  koala policy inspect openai-main --json > openai-main.json
```

### `koala policy rm`

```text
Usage:  koala policy rm NAME

Remove a broker policy.

VMs using it lose access at once; a VM that names it no longer starts.

Examples:
  koala policy rm openai-main
```

### `koala policy disable`

```text
Usage:  koala policy disable NAME

Stop a policy at once, cancelling its requests.

The policy stays disabled until enabled, also across manager and broker
restarts.

Options:
      --json    Print JSON

Examples:
  koala policy disable openai-main
```

### `koala policy enable`

```text
Usage:  koala policy enable NAME

Re-enable a disabled policy.

Options:
      --json    Print JSON

Examples:
  koala policy enable openai-main
```

### `koala policy status`

```text
Usage:  koala policy status

Show broker use per VM (counters only).

Options:
      --json    Print JSON

Examples:
  koala policy status
```

### `koala policy check`

```text
Usage:  koala policy check

Read the policies' credentials again and say which didn't load.

After a Koala upgrade, macOS asks whether the new koala-broker may use each
credential: choose Always Allow. This asks again for any not yet allowed.

Options:
      --json    Print JSON

Examples:
  koala policy check
```

### `koala policy test`

```text
Usage:  koala policy test NAME METHOD TARGET [--model M] [--field K=V]...
        koala policy test -f FILE METHOD TARGET [--model M] [--field K=V]...

Say whether a policy lets a request through, and why (nothing is sent).

Checks the request as the broker would: the rules, the query and the pinned body
fields. Limits, the key and the service's answer aren't tested. Exits 0 if
allowed, 1 if refused.

Options:
  -f FILE            Test a policy file not yet added, instead of a stored
                     policy
      --model M      Send a JSON body with model M
      --field K=V    Send a JSON body with field K set to V (repeatable)
      --json         Print JSON

Examples:
  koala policy test openai-main POST /v1/chat/completions --model gpt-4o-mini
  koala policy test -f my-api.json GET /v1/models
```

### `koala policy suggest`

```text
Usage:  koala policy suggest NAME

List what the broker refused under a policy, and offer to allow it.

The broker keeps the requests it refused in memory while it runs (method, path,
query names, a pinned field's value). In a terminal this asks, for each, whether
to add the smallest change that would allow it; otherwise it only lists them.

Options:
      --json    Print JSON

Examples:
  koala policy suggest openai-main
```

### `koala execution`

```text
Usage:  koala execution COMMAND

Inspect or cancel commands.

Commands:
  inspect    Show a command's status and result
  cancel     Cancel a running command

Run 'koala execution COMMAND --help' for more information on a command.
```

### `koala execution inspect`

```text
Usage:  koala execution inspect EXECUTION

Show a command's status and result.

Options:
      --json    Print JSON

Examples:
  koala execution inspect EXECUTION_ID
```

### `koala execution cancel`

```text
Usage:  koala execution cancel EXECUTION

Cancel a running command.

Options:
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)

Examples:
  koala execution cancel EXECUTION_ID
```

### `koala operation`

```text
Usage:  koala operation COMMAND

Follow a change koala accepted.

Commands:
  inspect    Show a change's status and result, or wait for it

Run 'koala operation COMMAND --help' for more information on a command.
```

### `koala operation inspect`

```text
Usage:  koala operation inspect [--wait] OPERATION

Show a change's status and result, or wait for it.

Without --wait, a command that changes a VM (create, start, stop, rm, update)
returns once koala accepts the change, and prints its operation ID. This shows
whether it is still running, or how it ended and why.

Options:
      --wait         Return only when the change has finished
      --timeout S    With --wait: give up after S seconds (default 600)
      --json         Print JSON

Examples:
  koala operation inspect OPERATION_ID
  koala operation inspect OPERATION_ID --wait
```

### `koala system`

```text
Usage:  koala system COMMAND

Install and run Koala.

Commands:
  install      Install Koala for your user and start it
  uninstall    Remove Koala for your user
  check        Check that this host can run Koala
  info         Show the manager's status
  start        Start the manager
  stop         Stop the manager

Run 'koala system COMMAND --help' for more information on a command.
```

### `koala system install`

```text
Usage:  koala system install [--stop-vms]

Install Koala for your user and start it.

Run it again from a newer release to upgrade. Needs no sudo.

Options:
      --stop-vms                Stop running VMs first (needed to upgrade)
      --root DIR                Install into DIR instead of ~/.koala (for
                                testing)
      --registry-leaf-sha256 HEX
                                Pin the runtime registry's TLS certificate (for
                                testing)
      --json                    Print JSON

Examples:
  koala system install
```

### `koala system uninstall`

```text
Usage:  koala system uninstall [--stop-vms] [--purge --yes]

Remove Koala for your user.

Keeps VMs, volumes, images and runtimes unless --purge is given.

Options:
      --stop-vms    Stop running VMs first
      --purge       Also delete all Koala data and its keychain items
      --yes         Confirm --purge
      --root DIR    The DIR given to system install (for testing)
      --json        Print JSON

Examples:
  koala system uninstall
  koala system uninstall --purge --yes
```

### `koala system check`

```text
Usage:  koala system check

Check that this host can run Koala.

Each failed check says how to fix it. Koala never runs a privileged step itself.

Options:
      --json    Print JSON

Examples:
  koala system check
```

### `koala system info`

```text
Usage:  koala system info

Show the manager's status.

Options:
      --json    Print JSON

Examples:
  koala system info
```

### `koala system start`

```text
Usage:  koala system start

Start the manager.

Options:
      --timeout S    Wait at most S seconds (default 600)

Examples:
  koala system start
```

### `koala system stop`

```text
Usage:  koala system stop [--stop-vms]

Stop the manager.

Options:
      --stop-vms     Stop running VMs first
      --timeout S    Wait at most S seconds (default 600)

Examples:
  koala system stop --stop-vms
```

### `koala config`

```text
Usage:  koala config COMMAND

Check VM definition files.

Commands:
  validate    Check a VM definition file without creating anything

Run 'koala config COMMAND --help' for more information on a command.
```

### `koala config validate`

```text
Usage:  koala config validate -f FILE

Check a VM definition file without creating anything.

Options:
  -f, --file FILE    The VM definition to check (required)

Examples:
  koala config validate -f web.json
```

### `koala runtime`

```text
Usage:  koala runtime COMMAND

Manage VM runtimes.

Commands:
  update    Switch a stopped VM to another runtime bundle

Run 'koala runtime COMMAND --help' for more information on a command.
```

### `koala runtime update`

```text
Usage:  koala runtime update VM --bundle DIGEST [--rollback]

Switch a stopped VM to another runtime bundle.

Options:
      --bundle DIGEST    The runtime bundle to use (required)
      --rollback         Go back to the previous bundle
      --wait             Return only when the change has finished
      --timeout S        With --wait: give up after S seconds (default 600)

Examples:
  koala runtime update dev --bundle sha256:DIGEST --wait
```
