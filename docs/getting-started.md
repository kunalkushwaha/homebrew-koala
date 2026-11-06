# Install, upgrade and remove

[User guide](README.md) > Install, upgrade and remove

Install Koala, start it, and check it's ready. Then go on to
[Tutorial 1: Your first VM](tutorial-first-vm.md).

## Installation

Koala is published on the
[releases page](https://github.com/kunalkushwaha/homebrew-koala/releases)
and through a Homebrew tap. One release holds the Mac and the Linux files.
On Linux, install the Debian package: see
[Koala on Linux](linux.md#installing). On a Mac, Homebrew is the recommended
path:

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
- downloads the lean and full runtimes (about 330 MB, once for each new
  runtime) and verifies their signatures against the release key;
- writes `manager.json`, plus the launchd agent at
  `~/Library/LaunchAgents/dev.koala.manager.plist`;
- starts the manager.

Running it again changes nothing. `koala --version` prints the release
version.

**Upgrading:** with Homebrew, `brew upgrade koala`, then
`koala system install`; from an archive, run `koala system install` from the
newer release. On Linux, see [Koala on Linux](linux.md#upgrading). If VMs
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
Koala's registry logins, secrets and the broker's API keys in your login
keychain. `--purge`
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
koala
  version    0.1.0-rc.1
  install    verified, /path/to/koala-manager
  manager    running, build koala-manager
  events     kept 30 days
  audit copy the unified log (dev.koala, audit), up to date; drops aren't reported by macOS
  new VMs    accepted (2 running)
  memory     37.0 GiB free for new VMs: 48 GiB, less 9.6 GiB kept for the system
             and 1.4 GiB reserved by running VMs
             a new VM needs its memory plus 192 MiB (lean) or 256 MiB (full)
  disk       9.7 GiB free for new VMs: 30.2 GiB free, less 18.5 GiB kept free
             and 2 GiB promised to running VMs
```

The `new VMs`, `memory` and `disk` rows say whether Koala would start
another VM now, and if not, why and what frees room. `version` shows the
manager's release too when it differs from `koala`'s (after an upgrade,
restart the manager). On Linux, the `audit copy` row counts lines syslog
dropped.

`install    unverified (...)` means the launchd agent is missing or does
not pass Koala's checks (owner, permissions, signature). See
[troubleshooting](troubleshooting.md#the-manager-does-not-start).

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

- [Tutorial 1: Your first VM](tutorial-first-vm.md), then the other
  [tutorials](README.md#tutorials), in order.
- `koala --help` lists every command, and `koala COMMAND --help` shows one
  command's usage, options and examples. Docker's names work too: `koala ps`
  and `koala ls` list VMs, `koala images` lists images, and `koala image ls`
  and `koala volume ls` are the same as their `list` commands.
