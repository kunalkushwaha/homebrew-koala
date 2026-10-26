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

**Run AI agents and other Linux workloads, each in its own lightweight
virtual machine, on your Mac or on a Linux machine.**

Koala is a command-line tool for hosting agents, services, jobs and
development environments in Linux VMs, at your desk or on a home server or
lab machine. Each VM has its own kernel, disk and network, and gets only the
access you grant it. With the broker, an agent's API keys stay outside its
VM. The same `koala` commands, VM specs and policies work on both hosts.

[![Watch the explainer: Koala - run agents with confidence (YouTube)](https://img.youtube.com/vi/1--kPBb8dOU/maxresdefault.jpg)](https://youtu.be/1--kPBb8dOU)

*Watch the explainer: [Koala - run agents with confidence](https://youtu.be/1--kPBb8dOU) (YouTube).*

> **Preview:** Koala is in preview. It is tested hard, on real VMs, on both
> platforms ([how](#how-koala-is-tested)), and v0.1 is still in development:
> commands and file formats may change between previews. Each release's notes
> say what changed.

**Documentation:** <https://kunalkushwaha.github.io/homebrew-koala/>

This repository holds Koala's
[releases](https://github.com/kunalkushwaha/homebrew-koala/releases), its
Homebrew formula and its [user guide](docs/README.md). Each release holds the
Mac and the Linux files. Koala's source code is not public yet.

## Platforms

| | macOS | Linux (preview) |
| --- | --- | --- |
| Host | Apple silicon, macOS 26 or newer | x86-64 Ubuntu 24.04, kernel 6.12 or newer, access to `/dev/kvm` |
| Hypervisor | Apple's Virtualization framework | KVM, through Cloud Hypervisor |
| Images | `linux/arm64` | `linux/amd64` |
| Install | Homebrew, or a release archive | A Debian package, or a release archive |
| Background manager | A launchd agent | A systemd user service |
| Sandboxes | App Sandbox for the helpers, a Seatbelt profile per VM run | Landlock and seccomp, and namespaces where Koala's AppArmor profile is loaded |
| Secrets | The login Keychain | The desktop keyring (Secret Service), or encrypted files |

## What you can do

- **Run a throwaway job:** a command in a fresh VM that is removed when the
  command ends.
- **Keep an environment or a service:** a VM that keeps running after your
  terminal closes. Run commands in it, open a shell, and copy files in and out.
- **Host agents at home or in a lab:** on a Linux server, the manager is a
  systemd user service, and with lingering on, your VMs keep running with
  nobody logged in ([Koala on Linux](docs/linux.md#logging-out)).
- **Use the images you already have:** Docker-style (OCI) images from Docker
  Hub or a private registry.
- **Choose a profile:** *lean* VMs run one image with a minimal init. *Full*
  VMs run Ubuntu 24.04 with systemd and Docker Engine
  (`koala create NAME --catalog ubuntu-24.04`).
- **Grant access explicitly:** share a host folder, publish a port, allow a
  service on your computer, or give a secret to one VM.
- **Keep API keys out of the VM:** give a VM a broker grant instead of a key.
  The key stays on your computer (the login keychain on a Mac, the broker's
  own encrypted files on Linux), and the broker adds it only to the requests
  a policy allows, even with the VM's internet off. Templates cover model
  providers, chat bots (Telegram, Slack, Discord) and GitHub Apps
  ([the broker](docs/broker.md)).
- **Set up an agent in one command:** `koala create hermes --template hermes`
  makes the agent's VM, the policy that keeps its key outside the VM, a
  volume and its setup, after showing you the plan
  ([templates](docs/templates.md)). `koala template update` gets newer
  templates, signed with the release key. Examples:
  [Hermes](docs/example-hermes.md) and [OpenClaw](docs/example-openclaw.md)
  (not tested on Koala yet), with their files in [examples](examples).
- **Run a browser agent (on a Mac):** a normal browser in a VM that you sign
  in to through a live view, and an agent beside it that drafts posts and
  replies for you to approve ([example](docs/example-x-agent.md), code in
  [examples/x-agent](examples/x-agent)).
- **No `sudo` for everyday use:** a background manager that runs as you
  keeps track of your VMs.

## How Koala is tested

Koala is tested by attacking it, on real VMs, on both platforms:

- **Root inside the VM, attacking the boundary.** The hostile-guest suites
  run as root in a VM, with a healthy control VM beside it. They attack the
  guest channels (lengths, credits, order), the network (spoofing,
  fragments, floods under resource limits), storage and credentials, on
  lean and full VMs. On Linux, an escape probe runs under each production
  sandbox (the VM's process, the hypervisor, the shared-folder server, the
  network helper): every attempt is refused, while the same probe
  unconfined succeeds.
- **Fuzzing every parser that reads guest data.** Each of more than 40 fuzz
  targets (Swift, Go and C) runs for at least 100,000 generated inputs and
  5 minutes, the Swift and C targets under AddressSanitizer and the C
  targets under UBSan too.
- **Crashing every process at chosen points.** About 1,400 crash checks on
  each platform kill the manager, each VM's process and every helper (the
  image extractor, file transfer, the network helper and the broker) at
  chosen moments, on lean and full VMs. Each case checks that no VM is
  duplicated or lost, no process is left behind, the state store is
  intact, and the VM starts again.
- **Hunting for leaked keys.** The broker's suites put a canary key on the
  host, then search the VM's disk, its volumes and the image for it. It
  must appear only on the upstream request.
- **The same suites on both platforms.** The Mac's acceptance suites run
  unchanged on Linux with KVM: the CLI journeys, networking, the hostile
  guest, the broker and the crash campaign.
- **Every release, as a user gets it.** A simulated fresh Mac that cannot
  see the build tree; an upgrade from the previous published release with
  a VM running, on a Mac and from the previous `.deb` on Linux; and a clean
  install and removal on each platform, on Linux on a clean Ubuntu machine.

## Install

On a Mac:

```sh
brew install kunalkushwaha/koala/koala
koala system install          # set up and start the manager for your user (no sudo)
```

On Linux, download the Debian package from the
[releases page](https://github.com/kunalkushwaha/homebrew-koala/releases), check
its checksum against the release notes, then:

```sh
sudo apt install ./koala_VERSION_amd64.deb
koala system check            # what this host has, and what is missing
koala system install          # set up and start the manager for your user (no sudo)
```

Each release's notes give the checksums and the runtime signing keys.
[Getting started](docs/getting-started.md) explains the archive install, and
[Koala on Linux](docs/linux.md) covers the Linux requirements, logging out,
upgrading and removing.

## Quick start

Run a throwaway job:

```sh
koala run --image docker.io/library/alpine:3 -- /bin/sh -c 'echo hello from the guest; uname -m'
```

It prints `aarch64` on a Mac and `x86_64` on Linux. Create a VM that stays
up, and work in it:

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
- **No files from your computer**, except folders you share. Shares are
  read-only unless you ask for read-write.
- **No secrets**, except named secrets you give to that VM.
- **No access to services on your computer or to your LAN** unless you grant
  it, and none to other VMs.
- **Published ports on `127.0.0.1` only**, unless you ask for the LAN.

Koala treats everything inside a VM as untrusted, and trusts you, the
logged-in user. On a Mac, VMs stop when you log out; on Linux, they keep
running with lingering on. Nothing starts by itself after a restart. See
[limits](docs/limits.md) for the details.

## Upgrade

On a Mac:

```sh
brew upgrade koala
koala system install          # add --stop-vms if VMs are running
```

On Linux, install the new release's `.deb` with `sudo apt install`, then
`koala system install` (see [upgrading](docs/linux.md#upgrading)).

## Uninstall

```sh
koala system uninstall        # keeps VMs, volumes and images; --purge --yes deletes them
brew uninstall koala          # on a Mac
sudo apt remove koala         # on Linux, after each user's koala system uninstall
```

## User guide

- [Getting started](docs/getting-started.md): install, start the manager, and
  run a first job and a first VM.
- [Jobs and VMs](docs/vms.md): jobs, services, environments and VM spec files.
- [Working inside a VM](docs/working-in-vms.md): `exec`, terminals, `attach`,
  `cp`, logs and the console.
- [Images and private registries](docs/images.md)
- [Secrets](docs/secrets.md)
- [Keys outside the VM (the broker)](docs/broker.md)
- [VM templates for agents](docs/templates.md)
- [Networking](docs/networking.md): internet, host services, the LAN and
  published ports.
- [Shares, volumes and disks](docs/storage.md)
- [Profiles: lean and full](docs/profiles.md)
- [Limits and behaviour](docs/limits.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Koala on Linux (preview)](docs/linux.md): requirements, the Debian
  package, logging out, upgrading and removing.

## License

Koala is licensed under the Apache License, Version 2.0. Each release archive
includes the `LICENSE` file, and a `NOTICE` file that lists the third-party
software in it.

## Documentation website

The website is built with [Astro Starlight](https://starlight.astro.build/).
Its own pages (home, how it works) are in `src/content/docs/`, and its theme is
`src/styles/koala.css`. The user guide in `docs/` is published as is:
`scripts/sync-guide.mjs` copies it into the site at build time, so each
release's guide reaches the site with no extra step.
`.github/workflows/pages.yml` publishes it to GitHub Pages. To preview it:

```sh
npm ci
npm run dev
```
