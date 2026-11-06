# Tutorial 8: Images, registries, and a full Linux with Docker

[User guide](README.md) > Tutorial 8: Images, registries, and a full Linux with Docker

Koala runs two kinds of VM:
- **Lean:** any OCI image for your computer's architecture (a Docker-style image), with
  nothing else.
- **Full:** Ubuntu with systemd and Docker Engine, for a development box.

In about fifteen minutes you will download an image ahead of time, try both
kinds, run Docker inside a full VM without Docker Desktop, and store a
private registry's login.

**You'll learn:** `koala image pull`, `koala image list`,
`koala create --catalog`, `--profile`, `koala registry login` and
`koala registry logout`.

Every command and every output on this page comes from a real run. IDs,
digests and versions will differ.

## Before you start

Koala is installed and running ([Tutorial 1](tutorial-first-vm.md)).

## Step 1: Download an image ahead of time

`koala run` and `koala create` download an image the first time they need
it. To download it in advance, for example before you go offline:

```console
$ koala image pull docker.io/library/alpine:3.21 --wait
accepted operation 16742c4e-e341-408f-9d88-b2718532fb25 (image.pull)
succeeded 16742c4e-e341-408f-9d88-b2718532fb25
$ koala image list
…
registry-1.docker.io/library/alpine:3.21  sha256:e77b401c86e6d0651b12ca45dea812bdf6ffca3b6e16662b7c116180e56ec9f7  linux/…
…
```

Koala keeps the image for your computer's architecture only: `linux/arm64`
on a Mac with Apple silicon, `linux/amd64` on Linux. There's no emulation of
the other. A VM made from it now starts without a
download:

```console
$ koala run --image docker.io/library/alpine:3.21 -- head -1 /etc/os-release
NAME="Alpine Linux"
```

`koala run` always takes the command to run after `--`.

## Step 2: A full Linux, with systemd and Docker

A full VM comes from Koala's **catalog**, which has one entry:
`ubuntu-24.04`. It is part of what `koala system install` downloaded and
verified, so it works offline:

```console
$ koala create dev --catalog ubuntu-24.04 --wait
internet on
accepted operation f92d43ac-b125-4560-8154-4886a2ae6cd4 (vm.create)
succeeded f92d43ac-b125-4560-8154-4886a2ae6cd4
$ koala start dev --wait
accepted operation ec223a84-353f-4144-9c9c-4f78461de1f2 (vm.start)
succeeded ec223a84-353f-4144-9c9c-4f78461de1f2
```

`koala start --wait` returns once systemd and Docker are up:

```console
$ koala exec dev -- systemctl is-system-running
running
$ koala exec dev -- sh -c '. /etc/os-release; echo $PRETTY_NAME'
Ubuntu 24.04…
$ koala exec dev -- systemctl is-active docker containerd
active
active
```

Docker runs inside the VM, so you don't need Docker Desktop on your Mac:

```console
$ koala exec dev -- docker run --rm hello-world
Unable to find image 'hello-world:latest' locally
…
Hello from Docker!
This message shows that your installation appears to be working correctly.
…
```

A full VM gets more by default than a lean one:

```console
$ koala inspect dev
dev (12e349c3-48cb-4f03-a791-aa5a15c3a093)
  state      Running
  mode       environment, full profile
  image      catalog ubuntu-24.04
             … digest sha256:755ee6f00d2f…
  resources  2 vCPUs, 1 GiB memory, 8 GiB disk
  command    the image's
  user       the image's
  internet   on
  grants     none
  published  none
  volumes    none
  shares     none
  secrets    none
  run        e4db5a93-bcaa-493f-affe-a256f3f7990f
  spec       generation 1; cleanup: retain
```

Docker's images and containers live on the VM's own disk (8 GiB here), and
go when you remove the VM:

```console
$ koala stop dev --wait
accepted operation a932bee0-a839-4814-8eba-5c17a85bbdb8 (vm.stop)
succeeded a932bee0-a839-4814-8eba-5c17a85bbdb8
$ koala rm dev --wait
accepted operation 7497f6c3-510b-4071-bb5e-933461aa7f4c (vm.remove)
succeeded 7497f6c3-510b-4071-bb5e-933461aa7f4c
```

## Step 3: Which kind you get

An OCI image (`--image`) is always lean, and the catalog (`--catalog`) is
always full. Asking for another pairing is refused, and nothing is made:

<!-- tutorial: fails -->
```console
$ koala create oops --image docker.io/library/alpine:3 --profile full --wait
internet on
accepted operation dd3c626e-b621-40c7-b31b-83730c7f4d40 (vm.create)
failed dd3c626e-b621-40c7-b31b-83730c7f4d40 IMAGE_INCOMPATIBLE
```

| | Lean (`--image`) | Full (`--catalog ubuntu-24.04`) |
|---|---|---|
| Runs | Your image's command | systemd, Docker and containerd |
| Default size | 1 vCPU, 256 MiB, 1 GiB disk | 2 vCPUs, 1 GiB, 8 GiB disk |
| Good for | Jobs, one service, an agent | A development box, Docker, several services |

## Step 4: Images from a private registry

For a registry that needs a password, store its login once. The password
goes to your login keychain, never into a file or a VM. Without
`--password-stdin`, `koala` asks for it. Each login gets an ID; with
`--json`, it is printed on stdout, so keep it in a variable. The registry and
password below are made up:

```console
$ LOGIN=$(printf %s 'not-a-real-password' | koala registry login registry.example.com --username demo --password-stdin --json | sed -n 's/.*"registryId":"\([^"]*\)".*/\1/p')
logged in to registry.example.com as demo; registry login e67c7a47-d228-433f-acca-b476acf5d79a
use it with: koala image pull --registry-login e67c7a47-d228-433f-acca-b476acf5d79a REFERENCE
```

Koala stores the login without contacting the registry, so a wrong password
shows up at the first pull. Pull with the login's ID:

<!-- tutorial: skip -->
```console
$ koala image pull registry.example.com/team/tool:1.2 --registry-login $LOGIN --wait
```

To forget the login, and delete it from your keychain:

```console
$ koala registry logout $LOGIN
forgot registry login e67c7a47-d228-433f-acca-b476acf5d79a on this host
```

## Clean up

The VM is gone already. The `alpine:3.21` image stays, and so do the other
images you downloaded; `koala image prune` removes every image no VM uses
(see [Tutorial 7](tutorial-look-after.md#keep-your-disk-tidy)).

## What you learned

| Command | What it does |
|---|---|
| `koala image pull REF` | Download an image ahead of time |
| `koala image list` | The images on this Mac |
| `koala run --image REF -- COMMAND` | Run a command from an image (the command is required) |
| `koala create NAME --catalog ubuntu-24.04` | A full VM: systemd and Docker |
| `koala registry login REGISTRY --username U` | Store a private registry's login (keychain) |
| `koala image pull REF --registry-login ID` | Pull with it |
| `koala registry logout ID` | Forget it |

## Next

That's the last tutorial. The [guides](README.md#guides) explain each topic in full, and the [examples](README.md#examples) set up real agents.

More on this page's topics:

- [Images and private registries](images.md): references, digests and
  logins in detail.
- [Profiles: lean and full](profiles.md): Docker in a full VM, and what's
  tested.
