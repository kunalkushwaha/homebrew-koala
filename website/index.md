---
title: Koala — Linux VMs for your Mac
hide:
  - navigation
  - toc
---

<div class="koala-hero" markdown>
<div markdown>
<span class="koala-badge">Preview · 0.1.0-preview.4</span>

<h1>Run Linux workloads on your Mac, each in its own lightweight VM.</h1>

<p class="lead">Koala is a command-line tool for macOS developers. It runs jobs,
services, development environments and AI agents in ARM64 Linux VMs on Apple
silicon, using Apple's Virtualization framework. Each VM has its own kernel,
disk and network, and gets only the access you grant it.</p>

[Get started](guide/getting-started.md){ .md-button .md-button--primary }
[Read the user guide](guide/README.md){ .md-button }
</div>
<pre class="mascot" aria-hidden="true">⠀⢀⣤⠶⠞⠲⢦⣄⠀⠀⠀⠀⠀⠀⠀⠀⣠⡴⠖⠳⠶⣤⡀
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
⠀⠀⠀⠀⠈⠻⠷⠤⠬⠿⠛⠛⠛⠛⠿⠥⠤⠾⠟⠁</pre>
</div>

## Install

```sh
brew install kunalkushwaha/koala/koala
koala system install          # set up and start the manager for your user (no sudo)
```

You need a Mac with Apple silicon and macOS 26 or newer. Images must be built
for `linux/arm64`. To install from a release archive instead, see
[getting started](guide/getting-started.md#installation).

## Try it

=== "A throwaway job"

    A command in a fresh VM that is removed when the command ends:

    ```sh
    koala run --image docker.io/library/alpine:3 -- /bin/sh -c 'echo hello from the guest; uname -m'
    ```

=== "A VM that stays up"

    Create a persistent VM and work in it:

    ```sh
    koala create dev --image docker.io/library/alpine:3 --wait
    koala start dev --wait
    koala exec -it dev -- /bin/sh        # an interactive shell; type exit to leave
    koala stop dev --wait
    ```

=== "An agent, sandboxed"

    An environment VM with the internet off, access to one service on your
    Mac, and one named secret delivered as a file. Save it as `agent.json`:

    ```json
    {"apiVersion": "koala.dev/v1alpha1", "kind": "VirtualMachine", "spec": {
      "name": "agent", "mode": "environment", "profile": "lean",
      "image": {"kind": "oci", "reference": "docker.io/library/alpine:3", "platform": "linux/arm64"},
      "network": {"internet": false, "allow": [
        {"kind": "host-service", "address": "127.0.0.1", "protocol": "tcp", "ports": [8080]}],
        "publish": []},
      "shares": [], "volumes": [],
      "secrets": [{"name": "agent-token", "mode": "file", "destination": "/run/secrets/agent-token"}]}}
    ```

    ```sh
    koala secret set agent-token        # prompts for the value; stored in your login keychain
    koala config validate -f agent.json
    koala create -f agent.json --wait
    koala start agent --wait
    koala exec agent -- cat /run/secrets/agent-token
    ```

    Inside the VM, the service on your Mac is `host-1.koala.internal:8080`.
    See [networking](guide/networking.md), [secrets](guide/secrets.md) and the
    [Hermes example](guide/example-hermes.md).

## What you can do

<div class="grid cards" markdown>

-   :material-lightning-bolt:{ .lg .middle } **Run throwaway jobs**

    ---

    A command in a fresh VM, removed when it ends. Good for builds, tests and
    untrusted scripts.

    [:octicons-arrow-right-24: Jobs and VMs](guide/vms.md)

-   :material-server:{ .lg .middle } **Keep services and environments**

    ---

    VMs that keep running after your terminal closes. Run commands, open a
    shell, copy files in and out.

    [:octicons-arrow-right-24: Working inside a VM](guide/working-in-vms.md)

-   :material-docker:{ .lg .middle } **Use the images you have**

    ---

    Docker-style (OCI) images from Docker Hub or a private registry, pinned by
    digest when a VM is created.

    [:octicons-arrow-right-24: Images and registries](guide/images.md)

-   :material-layers-outline:{ .lg .middle } **Lean or full**

    ---

    *Lean* VMs run one image with a minimal init. *Full* VMs run a Linux
    distribution with systemd and Docker Engine.

    [:octicons-arrow-right-24: Profiles](guide/profiles.md)

-   :material-shield-lock-outline:{ .lg .middle } **Grant access explicitly**

    ---

    Share a folder, publish a port, allow one service on your Mac, or give a
    secret to one VM. Nothing else gets through.

    [:octicons-arrow-right-24: Networking](guide/networking.md)

-   :material-account-check-outline:{ .lg .middle } **No `sudo`**

    ---

    A background manager that runs as you keeps track of your VMs. Nothing is
    installed system-wide.

    [:octicons-arrow-right-24: Getting started](guide/getting-started.md)

</div>

## What a VM can reach

By default, a VM gets:

| | Default | When you grant it |
| --- | --- | --- |
| **Internet** | Yes, public addresses only | Can be switched off |
| **Files on your Mac** | None | Folders you share; read-only unless you ask for read-write |
| **Secrets** | None | Named secrets, given to one VM as a file or an environment variable |
| **Services on your Mac** | None | One address and specific ports |
| **Your LAN** | None | A specific prefix and ports |
| **Other VMs** | Never | Not available in v0.1 |
| **Published ports** | None | On `127.0.0.1`, or on the LAN when you ask |

Koala treats everything inside a VM as untrusted, and trusts you, the
logged-in macOS user. VMs do not keep running after you log out or restart
your Mac. See [how it works](how-it-works.md) and
[limits](guide/limits.md).

!!! warning "Koala is in preview"

    Koala's security work is not complete, so use it with workloads and on
    machines you trust. Each [release's notes](https://github.com/kunalkushwaha/homebrew-koala/releases)
    say what is done and what is not. This site describes only what works
    today.
