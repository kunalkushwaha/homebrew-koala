# Limits and behaviour

[User guide](README.md) > Limits and behaviour

## Your terminal, logout, sleep and restarts

On a Mac:

| Event | What happens to your VMs |
| --- | --- |
| You close the terminal or `koala` exits | VMs and commands keep running. Reattach with `koala attach`. |
| The screen locks | VMs keep running. |
| The Mac sleeps | VMs are paused while the Mac sleeps and continue after wake. An attached `exec` survives. Published ports answer again after wake. |
| A timeout passes while the Mac sleeps | Sleep time counts. An expired command is stopped right after wake, before new work starts. It cannot be stopped while the Mac is asleep. |
| The manager restarts or crashes | VMs and commands keep running; `attach`, `exec`, `cp`, `logs` and `stats` keep working. Within about 10 seconds the manager rebuilds each VM's network, with its broker grants and its published ports on the same host ports. A VM whose network can't be rebuilt shows `Degraded` until you stop and start it. See [networking](networking.md#after-a-manager-restart). |
| A VM's worker process crashes | Its commands end as `lost` (exit status 125). A job's VM is still cleaned up. |
| You log out of macOS | **VMs stop.** Koala tries a clean shutdown, but logout may end them first. |
| The Mac restarts | VMs stop. |

On Linux, closing the terminal and a crash of the manager or of a VM's
worker are as on a Mac. These differ:

| Event | What happens to your VMs |
| --- | --- |
| You log out | systemd stops the manager and **your VMs stop**, unless lingering is on. With `sudo loginctl enable-linger "$USER"`, they keep running. See [Koala on Linux](linux.md#logging-out). |
| The computer restarts | VMs stop. |
| The computer sleeps | Not tested on Linux yet, nor VPN or Wi-Fi changes with VMs running. |

After logout or a restart, nothing is started again automatically. At your
next login the manager records interrupted runs; persistent VMs keep their
disks, and leftover job VMs are cleaned up. Start persistent VMs again with
`koala start`.

Koala does not keep your Mac awake. To keep long jobs running, prevent
sleep yourself (for example with `caffeinate`) and stay logged in.

## Memory, CPU and disk

**Memory.** `memoryMiB` is the RAM the guest sees, a fixed amount. On your
Mac:

- The VM's memory is allocated as the guest uses it, up to `memoryMiB`, plus
  some overhead for Koala's helper processes.
- Koala does not ask the guest to give memory back while it runs. Stop the
  VM to free its memory.
- Before a start, the manager reserves the VM's RAM plus a fixed overhead
  (192 MiB for lean, 256 MiB for full), and keeps at least 4 GiB or 20% of
  your Mac's memory, whichever is larger, unreserved. A start that does not
  fit fails (`RESOURCE_ADMISSION_FAILED`).

**CPU.** `vcpus` is the number of virtual CPUs. They are not dedicated
cores, and VMs together can have more vCPUs than your Mac has cores.

**Disk.** `diskMiB` is the size of the VM's own disk:

- It is a limit inside the guest. The file on your Mac grows only as data is
  written.
- It does not cover named volumes (each has its own size) or writable host
  shares (no limit beyond your Mac's free space).
- VM disks and named volumes have a journal. After a hard stop (a crash, a
  power loss, or the VM's process killed), the guest replays it the next
  time it mounts the disk, so the filesystem stays consistent. Writes the
  guest hadn't flushed yet can be lost. The journal takes 1/64 of the size,
  at least 4 MiB and at most 128 MiB. Lean VMs' disks and volumes made by
  0.1.0-preview.16 or earlier have no journal; recreate them to get one.
- When a lean VM's disk is full (or damaged), a command can finish without
  the VM being able to record how it ended. Koala then stops the VM: it
  ends `Failed`, and the command `failed` with reason `lost` (no exit code
  is made up). In 0.1.0-preview.16 and earlier, such a command never
  ended.
- To recover a lean VM whose disk is full, start it (it boots while full)
  and run a command that frees space, for example
  `koala exec VM -- rm /path/to/big-file`. That command completes normally.
  Any other command stops the VM again while the disk stays full. Watch a
  VM's disk with `koala stats`. In 0.1.0-preview.16 and earlier, a VM whose
  disk was full didn't start (`BOOT_FAILED`).
- Before creating disks and starting VMs, the manager checks your Mac's free
  space and keeps a reserve (2 GiB or 2% of the volume, whichever is
  larger). When space runs short, new work is refused
  (`STORAGE_SPACE_EXHAUSTED` or `RESOURCE_ADMISSION_FAILED`), and Koala may
  stop running VMs to protect their disks. It never deletes persistent data
  to free space. `koala system info` shows what is free for new VMs, what
  Koala keeps in reserve and what running VMs hold.

`koala stats` shows what each running VM uses: CPU, memory and processes as
the guest reports them (not verified), and disk, network and Koala's own
processes as your computer measures them. On Linux it also shows the VM's
own memory and CPU; on a Mac, Apple's Virtualization process holds them and
they aren't shown yet. See [what a VM uses](vms.md#what-a-vm-uses-koala-stats).

## Not available yet

Planned for v0.1 but not built yet:

- **Reattaching running VMs across an upgrade:** an upgrade stops them
  (`--stop-vms`).
- **A daemon settings file** (`~/Library/Application Support/Koala/config.json`)
  for log and disk budgets is documented but not read by the manager yet.
- **Terminal names in full-profile shells:** `tty` prints `not a tty`.
- **Release qualification:** pressure and endurance tests, performance targets
  and the release review. The adversarial-guest
  tests and the crash tests are done; see
  [how Koala is tested](https://github.com/kunalkushwaha/homebrew-koala#how-koala-is-tested).

Not part of v0.1:

- Running VMs after logout, or starting them automatically at login or boot.
- Networking between VMs, and changing a running VM's network.
- Snapshots, cloning VMs, and GPU access.
- Intel (x86-64) images, Rosetta, and Intel Macs.
- Building images (Dockerfiles), installer ISOs and your own kernels.
- An interactive serial login or a built-in SSH server. Use `koala exec -it`.
- Changing a VM's base image or profile. Create a new VM instead.
- Changing CPU or memory of a running VM. Stop it and `koala update` it.

The CLI also has no forced stop or forced removal (`--force`): `koala rm`
needs a stopped or failed VM.
