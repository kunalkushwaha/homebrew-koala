# What Koala protects against, and what it doesn't

Use this to answer "is it safe to run X in Koala?" honestly.

## What a VM gets: only what's granted

- **No host files,** except directories shared explicitly with `--mount`.
  Shares are read-only unless `:rw` is asked for.
- **No secrets,** unless a named secret is granted to that VM.
- **API keys through the broker never enter the VM.** The broker, on the
  host, adds the key only to the requests the policy allows, within its
  limits. A compromised agent can use the access it was given, but can't
  steal the key or call anything else with it.
- **The network:** the internet by default (off with `--no-internet`), but
  never the Mac's own services, the LAN or other VMs unless granted. Every
  connection is checked by a network helper on the host, outside the VM.
- **Published ports** listen on `127.0.0.1` unless an address is given.
- **Each VM has its own kernel, disk and network stack,** and VMs don't share
  a network with each other.

The VM, its guest kernel and everything running inside it are treated as
untrusted. Koala is tested against a hostile guest, its broker against leaked
keys, and its manager and helpers by crashing them at chosen points, on real
VMs on macOS and Linux.

## What Koala doesn't promise

- To protect against a compromised host, or the logged-in user: Koala
  trusts the user.
- To take back data the guest already received. Removing a secret or a share
  stops future access only.
- That an agent with internet access can't send out what it can read. Turning
  the internet off (with broker grants for what it needs) is what stops that.
- To keep VMs running after the user logs out, or across a reboot.
- Dedicated CPU cores, or a cap on the host's total memory use.

## So, for an assistant

- Agent with model access only: `--no-internet` and a broker grant. It can
  talk to its model and nothing else.
- Agent that must browse: the internet on, keys through the broker, no
  secrets, no read-write shares of anything that matters.
- Never suggest copying keys, SSH keys, cloud credentials or browser
  profiles into a VM, or sharing the home directory.
- The plan `koala create` prints is the contract: read it back, and ask
  before widening it.
