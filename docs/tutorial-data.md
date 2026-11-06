# Tutorial 3: Give a VM your data, not your Mac

[User guide](README.md) > Tutorial 3: Give a VM your data, not your Mac

An AI agent, or any tool you don't fully trust, often needs some of your
files. In about ten minutes you will try the three ways Koala gives a VM
data, each with no internet:
1. **Copy** files in and results out. The VM never sees your Mac.
2. **Share** one folder read-only, plus one folder it may write to.
3. **A volume:** a disk that outlives any one VM.

**You'll learn:** `koala cp`, `koala create --mount`,
`koala create --volume`, `koala volume create`, `koala volume list` and
`koala volume rm`.

Every command and every output on this page comes from a real run. IDs and
your folder's path will differ.

## Before you start

Koala is installed and running ([Tutorial 1](tutorial-first-vm.md)). Make a
folder to work in, with two small files to stand in for your data:

```console
$ mkdir koala-data-tutorial && cd koala-data-tutorial
$ mkdir notes out
$ chmod go-w out
$ printf 'buy milk\ncall the bank\n' > notes/monday.txt
$ printf 'book flights\nbuy milk\n' > notes/tuesday.txt
```

`chmod go-w out` makes sure only you can write to `out`. Koala refuses to
share a folder for writing if other users could write to it too. On Linux,
new folders are often group-writable; on a Mac this changes nothing.

## 1. Copy in, work, copy out

Make a VM with no internet:

```console
$ koala create box --image docker.io/library/alpine:3 --no-internet --wait
internet off
accepted operation 4ae51b72-a134-4888-9439-070d01ea3eb1 (vm.create)
succeeded 4ae51b72-a134-4888-9439-070d01ea3eb1
$ koala start box --wait
accepted operation 4110f7b5-93d8-4c7c-aa63-99305e82e3c7 (vm.start)
succeeded 4110f7b5-93d8-4c7c-aa63-99305e82e3c7
```

Copy the `notes` folder in. One side of `koala cp` is always `VM:/path`:

```console
$ koala cp notes box:/root/notes
copied 2 entries, 45 bytes
```

Work on the copy inside the VM (here, count the repeated lines), then copy
the result out:

```console
$ koala exec box -- sh -c 'cat /root/notes/*.txt | sort | uniq -c | sort -rn > /root/summary.txt'
$ koala cp box:/root/summary.txt summary.txt
copied 1 entry, 60 bytes
$ cat summary.txt
      2 buy milk
      1 call the bank
      1 book flights
```

The VM worked on copies. Nothing in it can reach your Mac's files, and with
`--no-internet` it can't send them anywhere either. A large copy shows one
progress line that updates as it goes.

```console
$ koala stop box --wait
accepted operation 174de2bc-3cf4-4b7c-ba3b-8a33760f9b05 (vm.stop)
succeeded 174de2bc-3cf4-4b7c-ba3b-8a33760f9b05
$ koala rm box --wait
accepted operation f8431a02-d85e-4738-8cd2-4a88b5a67c91 (vm.remove)
succeeded f8431a02-d85e-4738-8cd2-4a88b5a67c91
```

## 2. Share a folder

Copying suits a one-off job. To let a VM see a folder as it changes, share
it with `--mount HOST:GUEST`. A share is **read-only** unless you add `:rw`.
Here the VM may read `notes` and write only to `out`:

```console
$ koala create reader --image docker.io/library/alpine:3 --no-internet --mount "$PWD/notes:/notes" --mount "$PWD/out:/out:rw" --wait
mount …/koala-data-tutorial/notes -> /notes (ro)
mount …/koala-data-tutorial/out -> /out (rw)
internet off
accepted operation ed18155f-2884-4690-8d3e-2f4adce25157 (vm.create)
succeeded ed18155f-2884-4690-8d3e-2f4adce25157
$ koala start reader --wait
accepted operation 436673b7-ee59-4c1b-8a79-ad25c5c5741e (vm.start)
succeeded 436673b7-ee59-4c1b-8a79-ad25c5c5741e
$ koala exec reader -- ls /notes
monday.txt
tuesday.txt
```

Before it changes anything, `koala create` lists each share and whether it
is `ro` or `rw`. The VM can read your notes, but it can't change them:

<!-- tutorial: fails -->
```console
$ koala exec reader -- sh -c 'echo changed > /notes/monday.txt'
sh: can't create /notes/monday.txt: Read-only file system
koala: execution aa0ad421-3fb6-4e28-87da-581ecbc25b44 exited (exit 1)
```

```console
$ cat notes/monday.txt
buy milk
call the bank
```

What it writes to `/out` appears in your `out` folder at once:

```console
$ koala exec reader -- sh -c 'wc -l /notes/*.txt > /out/count.txt'
$ cat out/count.txt
        2 /notes/monday.txt
        2 /notes/tuesday.txt
        4 total
```

`koala inspect` lists a VM's shares at any time:

```console
$ koala inspect reader
reader (16eb0d74-2f6e-49e8-922b-361124c6675e)
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
  shares     …/koala-data-tutorial/notes at /notes, read-only
             …/koala-data-tutorial/out at /out, read-write
  secrets    none
  run        02f7e22c-8de4-4c82-955a-00525d0aa2fb
  spec       generation 1; cleanup: retain
```

Share the smallest folder that will do, never your home folder. A VM sees
everything in a share, including files you add later.

```console
$ koala stop reader --wait
accepted operation 14fe90fc-8353-4a2c-9ecc-b5aabd1da54e (vm.stop)
succeeded 14fe90fc-8353-4a2c-9ecc-b5aabd1da54e
$ koala rm reader --wait
accepted operation 07962451-96e4-409e-989b-6d781eb85d2d (vm.remove)
succeeded 07962451-96e4-409e-989b-6d781eb85d2d
```

## 3. Keep data on a volume

A **volume** is a disk that Koala keeps for you, apart from any VM. When
you remove a VM, its volume stays. An agent's memory, a database or a cache
belongs on one. Make a 256 MiB volume:

```console
$ koala volume create scratch --size 256MiB --wait
accepted operation 24f7b7fb-fb05-4591-8d63-235f001c5989 (volume.create)
succeeded 24f7b7fb-fb05-4591-8d63-235f001c5989
```

Attach it to a VM with `--volume NAME:/path`, write a file, then remove the
VM:

```console
$ koala create first --image docker.io/library/alpine:3 --no-internet --volume scratch:/data --wait
volume scratch -> /data (rw)
internet off
accepted operation 0f1450af-f658-4d85-b62a-71a1119bc839 (vm.create)
succeeded 0f1450af-f658-4d85-b62a-71a1119bc839
$ koala start first --wait
accepted operation 54b240e7-e559-4b01-b0c4-601cddda0de4 (vm.start)
succeeded 54b240e7-e559-4b01-b0c4-601cddda0de4
$ koala exec first -- sh -c 'echo "kept on the volume" > /data/keep.txt'
$ koala stop first --wait
accepted operation decdfb95-ca10-47fb-8d90-66afdefb9cb3 (vm.stop)
succeeded decdfb95-ca10-47fb-8d90-66afdefb9cb3
$ koala rm first --wait
accepted operation 68688be9-a6ad-48d3-9448-5edb98ecf2d9 (vm.remove)
succeeded 68688be9-a6ad-48d3-9448-5edb98ecf2d9
```

A new VM with the same volume finds the file:

```console
$ koala create second --image docker.io/library/alpine:3 --no-internet --volume scratch:/data --wait
volume scratch -> /data (rw)
internet off
accepted operation d7d8ded2-6675-4dd2-adf5-7badaaf804b4 (vm.create)
succeeded d7d8ded2-6675-4dd2-adf5-7badaaf804b4
$ koala start second --wait
accepted operation 27ab4bdc-3510-4927-a260-fcc09995276b (vm.start)
succeeded 27ab4bdc-3510-4927-a260-fcc09995276b
$ koala exec second -- cat /data/keep.txt
kept on the volume
```

```console
$ koala volume list
NAME  …  CAPACITY  USED  …  VMS  IN USE
…
scratch  …  256 MiB  …  1    yes
```

`VMS` counts the VMs that name the volume, and `IN USE` says whether a
running VM holds it now. Only one VM at a time can write to a volume, and
`koala volume rm` refuses while any VM refers to it, even a stopped one.

## Clean up

```console
$ koala stop second --wait
accepted operation 024fdd10-58aa-480f-a5f3-330aa03af8ab (vm.stop)
succeeded 024fdd10-58aa-480f-a5f3-330aa03af8ab
$ koala rm second --wait
accepted operation ee990b86-443f-414c-bd5a-d6176db3e910 (vm.remove)
succeeded ee990b86-443f-414c-bd5a-d6176db3e910
$ koala volume rm scratch --wait
accepted operation 881d9371-c9bb-49e0-b03a-937cbac4563d (volume.delete)
succeeded 881d9371-c9bb-49e0-b03a-937cbac4563d
$ cd .. && rm -r koala-data-tutorial
```

`koala volume rm` deletes the volume and everything on it.

## What you learned

| Way | Command | The VM sees | Use it for |
|---|---|---|---|
| Copy | `koala cp SRC VM:/path`, `koala cp VM:/path DST` | Only a copy | A one-off job on some files |
| Share | `koala create … --mount /host:/guest[:rw]` | That folder, live; read-only unless `:rw` | A folder the VM reads as it changes, and a folder for its results |
| Volume | `koala volume create NAME --size S`, `koala create … --volume NAME:/path` | A disk of its own that outlives the VM | An agent's memory, a database, a cache |

`koala volume list` shows your volumes; `koala volume rm NAME` deletes one.

## Next

**Next tutorial:** [Tutorial 4: Decide what an agent can reach](tutorial-policy.md).

More on this page's topics:

- [Shares, volumes and disks](storage.md): sizes, read-only volumes, and
  shares in a VM file.
- [Tutorial 2: Run an AI agent safely](tutorial-agent.md): an agent whose
  memory lives on a volume.
