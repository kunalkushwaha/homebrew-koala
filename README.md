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

[![Watch the explainer: Koala - run agents with confidence (YouTube)](https://img.youtube.com/vi/1--kPBb8dOU/maxresdefault.jpg)](https://youtu.be/1--kPBb8dOU)

*Watch the explainer: [Koala - run agents with confidence](https://youtu.be/1--kPBb8dOU) (YouTube).*

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
  VMs run Ubuntu 24.04 with systemd and Docker Engine
  (`koala create NAME --catalog ubuntu-24.04`).
- **Grant access explicitly:** share a host folder, publish a port, allow a
  service on your Mac, or give a secret to one VM.
- **Keep API keys on your Mac:** give a VM a broker grant instead of a key.
  The key stays in your login keychain, and the broker adds it only to the
  requests a policy allows, even with the VM's internet off. Templates
  cover model providers, chat bots (Telegram, Slack, Discord) and GitHub
  Apps. This suits AI agents ([example](docs/example-hermes.md)).
- **Set up an agent in one command:** `koala create hermes --template hermes`
  makes the agent's VM, the policy that keeps its key on your Mac, a volume
  and its setup, after showing you the plan ([templates](docs/templates.md)).
  `koala template update` gets newer templates, signed with the release key.
  Examples: [Hermes](docs/example-hermes.md) and
  [OpenClaw](docs/example-openclaw.md) (not tested on Koala yet), with their
  files in [examples](examples).
- **Run a browser agent:** a normal browser in a VM that you sign in to
  through a live view, and an agent beside it that drafts posts and replies
  for you to approve ([example](docs/example-x-agent.md), code in
  [examples/x-agent](examples/x-agent)).
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
