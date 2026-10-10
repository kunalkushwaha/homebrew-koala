# Koala

```text
⠀⢀⣤⠶⠞⠲⢦⣄⠀⠀⠀⠀⠀⠀⠀⠀⣠⡴⠖⠳⠶⣤⡀
⢀⡞⠁⠀⠀⠀⠀⠙⣧⣠⡤⠴⠦⢤⣄⣼⠋⠀⠀⠀⠀⠈⢳⡀
⢸⠁⠀⠠⠡⠡⢠⡾⠋⠀⠀⠀⠀⠀⠀⠙⢷⡤⠡⠡⠡⠀⠈⡇
⢸⡄⠀⠡⠡⢱⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⡧⠡⠡⠁⢠⡇
⠀⢳⣄⠀⠁⣿⠀⠀⠀⠿⢀⣴⣦⡀⠿⠀⠀⠀⣷⠁⠁⣠⡞
⠀⠀⠉⠛⠶⢿⡀⠀⠀⠀⣾⣴⣿⣷⠀⠀⠀⢀⡿⠶⠛⠉
⠀⠀⠀⠀⠀⠈⢷⡀⠀⠀⠘⢿⡿⠃⠀⠀⢀⡾⠁
⠀⠀⠀⠀⠀⠀⣠⡿⠶⣤⣀⣀⣀⣀⣤⠶⢿⣄
⠀⠀⠀⠀⠀⣼⠏⠀⠈⡇⠉⡩⢉⠉⢸⠁⠀⠹⣧
⠀⠀⠀⠀⠀⢿⡄⠀⣠⠇⢊⠔⡡⢊⠸⣄⠀⢠⡿
⠀⠀⠀⠀⠀⣨⣿⢿⣁⡀⠁⠊⠔⠁⢀⣈⡿⣿⣅
⠀⠀⠀⠀⠈⠻⠷⠤⠬⠿⠛⠛⠛⠛⠿⠥⠤⠾⠟⠁
```

**Run Linux workloads on your Mac, each in its own lightweight virtual machine.**

Koala is a command-line tool for macOS developers. It runs jobs, services and
development environments in ARM64 Linux VMs on Apple silicon, using Apple's
Virtualization framework. Each VM has its own kernel, disk and network, and
gets only the access you grant it.

> **Preview:** Koala is in preview, and v0.1 is in development. Its security
> work is not complete, so use it with workloads and on machines you trust.
> Each release's notes say what is done and what is not.

**Documentation:** <https://kunalkushwaha.github.io/homebrew-koala/>

This repository holds Koala's
[releases](https://github.com/kunalkushwaha/homebrew-koala/releases), its
Homebrew formula and its [user guide](docs/README.md). Koala's source code is
not public yet.

## What you can do

- **Run a throwaway job:** a command in a fresh VM that is removed when the
  command ends.
- **Keep an environment or a service:** a VM that keeps running after your
  terminal closes. Run commands in it, open a shell, and copy files in and out.
- **Use the images you already have:** Docker-style (OCI) images from Docker
  Hub or a private registry.
- **Choose a profile:** *lean* VMs run one image with a minimal init. *Full*
  VMs, which run a Linux distribution with systemd and Docker Engine, are not
  in the current preview.
- **Grant access explicitly:** share a host folder, publish a port, allow a
  service on your Mac, or give a secret to one VM.
- **No `sudo`:** a background manager that runs as you keeps track of your VMs.

## Requirements

- A Mac with Apple silicon.
- macOS 26 or newer.
- Images built for `linux/arm64`. Intel (x86-64) images are not supported.

## Install

```sh
brew install kunalkushwaha/koala/koala
koala system install          # set up and start the manager for your user (no sudo)
```

Or download an archive from the
[releases page](https://github.com/kunalkushwaha/homebrew-koala/releases).
Each release's notes give the archive checksum and the runtime signing key,
and [getting started](docs/getting-started.md) explains the archive install.

## Quick start

Run a throwaway job:

```sh
koala run --image docker.io/library/alpine:3 -- /bin/sh -c 'echo hello from the guest; uname -m'
```

Create a VM that stays up, and work in it:

```sh
koala create dev --image docker.io/library/alpine:3 --wait
koala start dev --wait
koala exec -it dev -- /bin/sh        # an interactive shell; type exit to leave
koala stop dev --wait
```

`koala --help` lists every command, and `koala COMMAND --help` explains one.

## What a VM can reach

By default, a VM gets:

- **Internet access**, which you can switch off.
- **No files from your Mac**, except folders you share. Shares are read-only
  unless you ask for read-write.
- **No secrets**, except named secrets you give to that VM.
- **No access to services on your Mac or to your LAN** unless you grant it,
  and none to other VMs.
- **Published ports on `127.0.0.1` only**, unless you ask for the LAN.

Koala treats everything inside a VM as untrusted, and trusts you, the
logged-in macOS user. VMs do not keep running after you log out or restart
your Mac. See [limits](docs/limits.md) for the details.

## Upgrade

```sh
brew upgrade koala
koala system install          # add --stop-vms if VMs are running
```

## Uninstall

```sh
koala system uninstall        # keeps VMs, volumes and images; --purge --yes deletes them
brew uninstall koala
```

## User guide

- [Getting started](docs/getting-started.md): install, start the manager, and
  run a first job and a first VM.
- [Jobs and VMs](docs/vms.md): jobs, services, environments and VM spec files.
- [Working inside a VM](docs/working-in-vms.md): `exec`, terminals, `attach`,
  `cp`, logs and the console.
- [Images and private registries](docs/images.md)
- [Secrets](docs/secrets.md)
- [Networking](docs/networking.md): internet, host services, the LAN and
  published ports.
- [Shares, volumes and disks](docs/storage.md)
- [Profiles: lean and full](docs/profiles.md)
- [Limits and behaviour](docs/limits.md)
- [Troubleshooting](docs/troubleshooting.md)

## License

Koala is licensed under the Apache License, Version 2.0. Each release archive
includes the `LICENSE` file, and a `NOTICE` file that lists the third-party
software in the binaries.

## Documentation website

The website is built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/)
from `mkdocs.yml`: its own pages are in `website/`, and `website/guide` is a
link to the user guide in `docs/`, so each release's guide is published as is.
`.github/workflows/pages.yml` publishes it to GitHub Pages. To preview it:

```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements-docs.txt
.venv/bin/mkdocs serve
```
