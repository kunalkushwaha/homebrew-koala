# Limits and behaviour

[User guide](README.md) > Limits and behaviour

## Your terminal, logout, sleep and restarts

| Event | What happens to your VMs |
| --- | --- |
| You close the terminal or `koala` exits | VMs and commands keep running. Reattach with `koala attach`. |
| The screen locks | VMs keep running. |
| The Mac sleeps | VMs are paused while the Mac sleeps and continue after wake. An attached `exec` survives. Published ports answer again after wake. |
| A timeout passes while the Mac sleeps | Sleep time counts. An expired command is stopped right after wake, before new work starts. It cannot be stopped while the Mac is asleep. |
| The manager restarts or crashes | VMs and commands keep running; `attach`, `exec`, `cp`, `logs` and `stats` keep working. Each VM's network is cut off (`Degraded`) until you stop and start it. |
| A VM's worker process crashes | Its commands end as `lost` (exit status 125). A job's VM is still cleaned up. |
| You log out of macOS | **VMs stop.** Koala tries a clean shutdown, but logout may end them first. |
| The Mac restarts | VMs stop. |

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
- Before creating disks and starting VMs, the manager checks your Mac's free
  space and keeps a reserve (2 GiB or 2% of the volume, whichever is
  larger). When space runs short, new work is refused
  (`STORAGE_SPACE_EXHAUSTED` or `RESOURCE_ADMISSION_FAILED`), and Koala may
  stop running VMs to protect their disks. It never deletes persistent data
  to free space.

`koala stats VM` shows what the manager reserved for a running VM. Usage
measured inside the guest is not reported yet.

## Not available yet

Planned for v0.1 but not built yet:

- **The full profile in a release:** the preview publishes the lean
  runtime only. The full runtime and the signed catalog (the full-profile
  image you can use) are not published yet.
- **Reattaching running VMs across an upgrade:** an upgrade stops them
  (`--stop-vms`).
- **A daemon settings file** (`~/Library/Application Support/Koala/config.json`)
  for log and disk budgets is documented but not read by the manager yet.
- **Terminal names in full-profile shells:** `tty` prints `not a tty`.
- **A reference host broker** for agents without secrets.
- **Release qualification:** adversarial-guest tests, crash, pressure and endurance tests, performance targets
  and the release review.

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
