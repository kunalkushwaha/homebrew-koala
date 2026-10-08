# Getting started

[User guide](README.md) > Getting started

## Installation

Koala is published as a preview, on the
[releases page](https://github.com/kunalkushwaha/homebrew-koala/releases)
and through a Homebrew tap. Homebrew is the recommended path:

```sh
brew install kunalkushwaha/koala/koala
koala system install
```

Or download the release archive, and check its checksum against the release
notes before you extract it:

```sh
shasum -a 256 koala-VERSION-darwin-arm64.tar.gz   # compare with the release notes
tar -xzf koala-VERSION-darwin-arm64.tar.gz
xattr -dr com.apple.quarantine koala-VERSION      # see below
koala-VERSION/bin/koala system install
```

A browser download carries the quarantine attribute, which stops macOS from
running Koala's binaries: they are ad-hoc signed, not signed with an Apple
Developer ID or notarized. Remove it only after the checksum matches, and
keep the extracted folder: the `koala` command runs from it.

This needs an Apple silicon Mac with macOS 26 or later. Run it as your own
user, not with `sudo`. It:
- checks every file of the release against its `share/koala/install.json`;
- copies the manager, network helper and image extractor into
  `~/Library/Application Support/Koala/versions/VERSION/`, then signs them
  for this Mac;
- downloads the lean runtime and verifies its signature against the
  release key;
- writes `manager.json`, plus the launchd agent at
  `~/Library/LaunchAgents/dev.koala.manager.plist`;
- starts the manager.

Running it again changes nothing. `koala --version` prints the release
version.

**Upgrading:** run `koala system install` from the newer release. If VMs
are running, it refuses and nothing changes; add `--stop-vms` to stop them
first. If the new manager does not start, the previous version is put back
and started again. Installing an older release over data written by a newer
one is refused.

**Uninstalling:**

```sh
koala system uninstall [--stop-vms]
```

This removes the agent, the binaries and the configuration. It keeps your
VMs, volumes, images and runtimes under
`~/Library/Application Support/Koala` and prints their paths, so a later
install finds them again. `--purge --yes` also deletes that folder, plus
Koala's registry logins and secrets in your login keychain. `--purge`
without `--yes` lists what it would delete and stops.

**Files outside the Application Support folder:**
- **Worker sockets** are in `~/.koala/run`. The path must stay short: a
  macOS socket path is limited to 104 bytes.
- **The manager socket** is in your temporary directory.

The commands below assume Koala is installed this way.

## Start the manager

```sh
koala system start
```

This starts the installed manager and waits until it answers (up to 600
seconds; change that with `--timeout S`). It prints `manager running`, or
`manager already running`.

Check the installation and the manager at any time:

```sh
koala system info
```

```text
installation: verified /path/to/koala-manager
manager: running BUILD
```

`installation: unverified (...)` means the launchd agent is missing or does
not pass Koala's checks (owner, permissions, signature). See
[troubleshooting](troubleshooting.md#the-manager-does-not-start).

## Run a first job

A job is a command in a throwaway VM. The VM is removed automatically when
the command ends.

```sh
koala run --image docker.io/library/alpine:3 -- /bin/sh -c 'echo hello from the guest; uname -m'
```

- Everything after `--` is the command, passed as-is (no host shell).
- The image is fetched on first use. See [images](images.md).
- `koala` stays attached and prints the command's output. Its exit status is
  the command's exit status.

## Create a first persistent VM

An *environment* VM stays up until you stop it, and you run commands in it
with `koala exec`:

```sh
koala create dev --image docker.io/library/alpine:3 --wait
koala start dev --wait
koala exec dev -- /bin/sh -c 'cat /etc/os-release'
koala exec -it dev -- /bin/sh        # an interactive shell; type exit to leave
```

See what you have:

```sh
koala list
koala inspect dev
```

## Clean up

```sh
koala stop dev --wait
koala rm dev --wait
```

## Stop the manager

```sh
koala system stop
```

This refuses while VMs are running, and names them. To stop those VMs first,
then the manager:

```sh
koala system stop --stop-vms
```

## Next steps

`koala --help` lists every command. `koala COMMAND --help` shows one
command's usage, options and examples: for example `koala create --help` or
`koala volume create --help`. Docker's names work too: `koala ps` and
`koala ls` list VMs, `koala images` lists images, and `koala image ls` and
`koala volume ls` are the same as their `list` commands.

- [Jobs and VMs](vms.md): services, VM spec files and resources.
- [Working inside a VM](working-in-vms.md): `exec`, `cp`, logs.
