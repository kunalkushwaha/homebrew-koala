# Tutorial 1: Your first VM

[User guide](README.md) > Tutorial 1: Your first VM

In about five minutes you will run a command in a throwaway Linux VM, make
a VM that stays, work inside it, and remove it again. At the end your Mac is
as it was.

**You'll learn:** `koala system info`, `koala run`, `koala create`,
`koala start`, `koala exec`, `koala list`, `koala inspect`, `koala stop`
and `koala rm`.

Every command and every output on this page comes from a real run. IDs and
times will differ on your Mac.

## Before you start

Install Koala, if you haven't yet (see
[Install, upgrade and remove](getting-started.md#installation)):

<!-- tutorial: skip -->
```console
$ brew install kunalkushwaha/koala/koala
$ koala system install
```

## Step 1: Check that Koala is ready

```console
$ koala system info
koala
  version    0.1.0-…
  install    verified, …
  manager    running, build koala-manager
…
```

`manager    running` is what matters: the manager is the background
service that runs your VMs. The `new VMs`, `memory` and `disk` rows say
whether there is room for another VM. If the manager isn't running, start it
with `koala system start`.

## Step 2: Run one command in a throwaway VM

```console
$ koala run --image docker.io/library/alpine:3 -- uname -sm
Linux …
```

Koala started a Linux VM from the Alpine image, ran `uname -sm` in it
(`aarch64` on a Mac, `x86_64` on Linux),
printed its output, and removed the VM. That is a **job**: one command, one
VM, gone afterwards.

- Everything after `--` is the command. It runs in the VM, not on your Mac.
- The first run downloads the image, so it takes longer than later ones.
- You see only the command's own output.

When the command fails, Koala adds one line saying how it ended, and
`koala run` exits with the command's exit status, so scripts can rely on it:

```console
$ koala run --image docker.io/library/alpine:3 -- sh -c 'echo "hello from $(hostname)"; exit 3'; echo "exit status: $?"
hello from …
koala: execution cc7ab5a7-8762-4467-b5c2-0ee5d1dd3e51 exited (exit 3)
exit status: 3
```

## Step 3: Make a VM that stays

A job's VM is gone when its command ends. For a VM you come back to, create
one and start it:

```console
$ koala create hello --image docker.io/library/alpine:3 --wait
internet on
accepted operation df0f92af-7d3a-4ce4-bfd5-712919a7b894 (vm.create)
succeeded df0f92af-7d3a-4ce4-bfd5-712919a7b894
$ koala start hello --wait
accepted operation bc823ef9-5b0e-43b0-8307-0acc8c07ac1e (vm.start)
succeeded bc823ef9-5b0e-43b0-8307-0acc8c07ac1e
```

- `hello` is the VM's name; you use it in every later command.
- `internet on`: this VM can reach the internet. (Your Mac's own services,
  your network and other VMs stay out of reach unless you allow them; see
  [Networking](networking.md).)
- `--wait` returns when the change has finished. Without it, `koala` returns
  as soon as the manager has accepted the request.

## Step 4: Work inside the VM

`koala exec` runs a command in a running VM:

```console
$ koala exec hello -- head -1 /etc/os-release
NAME="Alpine Linux"
```

The VM keeps its files. Write one, then read it back:

```console
$ koala exec hello -- sh -c 'echo "I was here" > /root/note.txt'
$ koala exec hello -- cat /root/note.txt
I was here
```

For an interactive shell, add `-it`, and type `exit` to leave:

<!-- tutorial: skip -->
```console
$ koala exec -it hello -- /bin/sh
/ # cat /root/note.txt
I was here
/ # exit
```

## Step 5: See what you have

```console
$ koala list
ID                                    NAME                 MODE         STATE              GEN
…
0d4d3739-2216-46f0-ab3c-94240a216e4d  hello                environment  Running            1
```

`environment` is the kind of VM `koala create` makes by default: it stays up
until you stop it. Any other VMs you have are listed too.

For one VM's details:

```console
$ koala inspect hello
hello (0d4d3739-2216-46f0-ab3c-94240a216e4d)
  state      Running
  mode       environment, lean profile
  image      docker.io/library/alpine:3
             … digest sha256:1829893486be…
  resources  1 vCPU, 256 MiB memory, 1 GiB disk
  command    the image's
  user       the image's
  internet   on
  grants     none
  published  none
  volumes    none
  shares     none
  secrets    none
  run        ca493860-918c-441a-b23f-21aabc45f946
  spec       generation 1; cleanup: retain
```

`inspect` shows everything the VM was given. Here that is nothing beyond
the internet: no host folders (`shares`), no secrets, no published ports.
A VM gets only what you grant it.

## Step 6: Stop it, and start it again

Stopping a VM keeps its disk. Your note survives:

```console
$ koala stop hello --wait
accepted operation 4f74e9b6-5531-447d-8a9b-921c7027dc47 (vm.stop)
succeeded 4f74e9b6-5531-447d-8a9b-921c7027dc47
$ koala start hello --wait
accepted operation 15fce0e0-ee6d-40a1-803f-fa3c87248a43 (vm.start)
succeeded 15fce0e0-ee6d-40a1-803f-fa3c87248a43
$ koala exec hello -- cat /root/note.txt
I was here
```

## Step 7: Clean up

```console
$ koala stop hello --wait
accepted operation e9d9e46b-ee6a-47b8-8053-3b3669438fbb (vm.stop)
succeeded e9d9e46b-ee6a-47b8-8053-3b3669438fbb
$ koala rm hello --wait
accepted operation eb97d72f-85ed-440a-9092-667967b3799a (vm.remove)
succeeded eb97d72f-85ed-440a-9092-667967b3799a
```

`koala rm` deletes the VM and its disk. `hello` is gone from `koala list`,
and your Mac is as it was before step 2. (The Alpine image stays
downloaded, so the next run starts faster; see [Images](images.md).)

## What you learned

| Command | What it does |
|---|---|
| `koala system info` | Is Koala installed and running, and is there room for a VM? |
| `koala run --image IMAGE -- CMD` | Run one command in a throwaway VM (a job) |
| `koala create NAME --image IMAGE` | Make a VM that stays (an environment) |
| `koala start NAME` / `koala stop NAME` | Start and stop it; its disk is kept |
| `koala exec NAME -- CMD` | Run a command in it (`-it` for a shell) |
| `koala list` / `koala inspect NAME` | See your VMs, and what one was given |
| `koala rm NAME` | Delete a VM and its disk |

## Next

**Next tutorial:** [Tutorial 2: Run an AI agent safely](tutorial-agent.md).

More on this page's topics:

- [Jobs and VMs](vms.md): services, resources, and VMs from a file.
- [Working inside a VM](working-in-vms.md): copying files, logs and
  attaching to commands.
- [VM templates for agents](templates.md): an AI agent in a VM in one
  command.
