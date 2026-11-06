# Tutorial 7: Look after your VMs

[User guide](README.md) > Tutorial 7: Look after your VMs

Once a VM is running, you need to see what it's doing, follow long work,
change it, and keep your disk tidy. In about fifteen minutes you will do
each of these with a small service that prints a line every two seconds.

**You'll learn:** `koala logs`, `koala stats`, `koala events`,
`koala console`, `koala run --detach`, `koala attach`,
`koala execution inspect`, `koala execution cancel`, `koala inspect --export`,
`koala update`, `koala edit`, `koala system stop`, `koala image list` and
`koala image prune`.

Every command and every output on this page comes from a real run. IDs,
times and figures will differ.

## Before you start

Koala is installed and running ([Tutorial 1](tutorial-first-vm.md)). Make
the service, with no internet:

```console
$ koala create ticker --image docker.io/library/alpine:3 --mode service --no-internet --wait -- sh -c 'i=0; while true; do i=$((i+1)); echo "tick $i"; sleep 2; done'
internet off
accepted operation 1ad9cff9-fef5-48cb-9bb4-9f0678bdfe4e (vm.create)
succeeded 1ad9cff9-fef5-48cb-9bb4-9f0678bdfe4e
$ koala start ticker --wait
accepted operation 75d9b6c4-6c5f-4ee2-b5c4-332928f4c5f6 (vm.start)
succeeded 75d9b6c4-6c5f-4ee2-b5c4-332928f4c5f6
```

## Watch it

**Its output.** `koala logs` shows what the service's main command has
printed so far. Add `--follow` to keep watching (Ctrl-C to stop):

```console
$ sleep 5; koala logs ticker
tick 1
tick 2
…
```

**What it uses.** `koala stats` gives one line per running VM. Add a name for
the details, and `--follow` to refresh every two seconds:

```console
$ koala stats
…
ticker  …
CPU %, MEMORY and PIDS are reported by each guest (not verified); DISK and NET I/O by the host.
$ koala stats ticker
ticker (…)
  state      Running, run …
  started    …
  memory     256 MiB for the guest, plus 192 MiB host overhead, reserved by the manager
  disk       1 GiB for growth, reserved by the manager
…
```

The guest's own figures come from inside the VM, so they're reported, not
verified. Disk and network are measured on your Mac.

**What happened to it.** `koala events` lists what Koala did with a VM and
what it refused:

```console
$ koala events --vm ticker
…
… vm.started            vm …
…
```

**How it booted.** If a VM won't start properly, its serial console shows
the kernel's and Koala's own boot messages:

```console
$ koala console ticker | grep 'koala-init as init'
[…] Run /sbin/koala-init as init process
```

## Follow long work

`koala run --detach` starts a job and returns at once. With `--json`, it
prints the execution's ID on stdout; keep it in a variable:

```console
$ EXEC=$(koala run --detach --json --image docker.io/library/alpine:3 -- sh -c 'for i in 1 2 3; do echo "step $i"; sleep 2; done' | sed -n 's/.*"executionId":"\([^"]*\)".*/\1/p')
started; follow it with: koala attach dccc81f6-2f04-48c9-b3ab-9c0a0fc108bf
$ echo $EXEC
dccc81f6-2f04-48c9-b3ab-9c0a0fc108bf
```

`koala attach` shows its output from the start, and follows it to the end.
You can attach as often as you like, and closing your terminal doesn't stop
the job:

```console
$ koala attach $EXEC
step 1
step 2
step 3
$ koala execution inspect $EXEC
execution dccc81f6-2f04-48c9-b3ab-9c0a0fc108bf
  state      exited with code 0
  vm         deadec08-4798-410c-8c27-0bc46b868b1f, run 7ed5723b-21a1-459a-ad16-220d8dfd864e
  kind       primary
  started    …
  finished   … (after … s)
  logs       complete
```

To stop work you no longer want:

```console
$ EXEC=$(koala run --detach --json --image docker.io/library/alpine:3 -- sleep 600 | sed -n 's/.*"executionId":"\([^"]*\)".*/\1/p')
started; follow it with: koala attach d4a4dd78-c77a-479f-80c3-21279ce77b85
$ sleep 5; koala execution cancel $EXEC --wait
accepted operation 04b3c2ef-9120-476b-bd62-4f233571297b
succeeded 04b3c2ef-9120-476b-bd62-4f233571297b
$ koala execution inspect $EXEC
execution d4a4dd78-c77a-479f-80c3-21279ce77b85
  state      killed by signal 15
  vm         98151d82-1dad-4f0c-91fb-ce10dcb1fe93, run 2ba5b381-8175-42c3-8eca-fbcb46a8cb94
  kind       primary
  started    …
  finished   … (after … s)
  logs       complete
```

A job's VM is removed when its command ends, cancelled or not.

## Stopping the manager

The manager won't stop under running VMs; it names them instead:

<!-- tutorial: fails -->
```console
$ koala system stop
koala: refusing to stop the manager with live VMs: ticker; use --stop-vms
```

`koala system stop --stop-vms` stops them first. You rarely need to stop the
manager: VMs and their commands keep running when you close your terminal.

## Change a stopped VM

A stopped VM's resources, network, shares and secrets can change; its image
and profile can't (make a new VM for those). `koala edit ticker` opens it in your editor. To
make the change in a script instead, export the definition, edit the file,
and apply it:

```console
$ koala stop ticker --wait
accepted operation 7011fb37-9f63-4e3e-8260-f650b00edd14 (vm.stop)
succeeded 7011fb37-9f63-4e3e-8260-f650b00edd14
$ koala inspect ticker --export > ticker.json
$ sed -i.bak 's/"memoryMiB":256/"memoryMiB":512/' ticker.json && rm ticker.json.bak
$ koala update ticker -f ticker.json --wait
internet off
accepted operation 9419e0f5-caef-4e40-9ec8-9a871e21fce1 (vm.spec)
succeeded 9419e0f5-caef-4e40-9ec8-9a871e21fce1
```

`GEN` counts the definition's changes, and `inspect` shows the new memory:

```console
$ koala list
ID                                    NAME                 MODE         STATE              GEN
…
82e5c018-1b4f-4138-82d9-73697a7d58fb  ticker               service      Stopped            2
$ koala inspect ticker | grep resources
  resources  1 vCPU, 512 MiB memory, 1 GiB disk
```

## Keep your disk tidy

Downloaded images stay, so new VMs start fast. `koala image list` shows them:

```console
$ koala image list
…
registry-1.docker.io/library/alpine:3  sha256:…  linux/…
…
```

`koala image prune` removes **every** image that no VM uses, including ones
you'll want again, which are then downloaded anew. Run it when you need the
space:

<!-- tutorial: skip -->
```console
$ koala image prune --wait
```

## Clean up

```console
$ koala rm ticker --wait
accepted operation 98c92aea-2c76-4be7-a58b-ce264039f2d9 (vm.remove)
succeeded 98c92aea-2c76-4be7-a58b-ce264039f2d9
$ rm ticker.json
```

## What you learned

| Command | What it does |
|---|---|
| `koala logs VM [--follow]` | The main command's output |
| `koala stats [VM] [--follow]` | What running VMs use |
| `koala events [--vm VM] [--follow]` | What Koala did with a VM, and what it refused |
| `koala console VM` | The VM's boot and kernel messages |
| `koala run --detach …` | Start a job and return |
| `koala attach EXECUTION` | Follow a command's output, from the start |
| `koala execution inspect EXECUTION` | How a command ended |
| `koala execution cancel EXECUTION` | Stop a command |
| `koala edit VM` / `koala inspect VM --export` + `koala update VM -f FILE` | Change a stopped VM |
| `koala system stop [--stop-vms]` | Stop the manager; refuses under running VMs |
| `koala image list` / `koala image prune` | See and remove downloaded images |

## Next

**Next tutorial:** [Tutorial 8: Images, registries, and a full Linux with Docker](tutorial-images.md).

More on this page's topics:

- [Working inside a VM](working-in-vms.md): terminals, exit codes, and logs
  of earlier runs.
- [Troubleshooting](troubleshooting.md): error codes and what to do.
- [Limits and behaviour](limits.md): logout, sleep and restarts.
