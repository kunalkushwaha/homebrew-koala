# Networking

[User guide](README.md) > Networking

Each VM has its own network stack. Koala checks every connection the guest
makes on the Mac side, so software in the VM cannot switch the rules off.

## The default: internet, and nothing local

Without a `network` section, a VM:

- **can** reach the internet over TCP and UDP;
- **cannot** reach your Mac (including `127.0.0.1` services), your LAN,
  private network ranges such as a VPN's, or other Koala VMs;
- publishes no ports.

Internet means public addresses only. Addresses on your local networks and
VPNs are treated as local, even if they look public, and stay blocked.

To switch the internet off, set it in the spec file:

```json
"network": {"internet": false, "allow": [], "publish": []}
```

Grants in `allow` still work when the internet is off. The VM can still
resolve the names of its granted host services.

## Reach a service on your Mac

Grant one address and specific ports. For example, a service listening on
your Mac at `127.0.0.1:8080`:

```json
"network": {"internet": false, "allow": [
  {"kind": "host-service", "address": "127.0.0.1", "protocol": "tcp", "ports": [8080]}],
  "publish": []}
```

Inside the VM, use the name `host-1.koala.internal`:

```sh
koala exec agent -- /bin/sh -c 'wget -qO- http://host-1.koala.internal:8080/'
```

- Each distinct host address in a spec gets the next name, in order:
  `host-1.koala.internal`, `host-2.koala.internal`, and so on. `koala
  inspect --json VM` lists them under `network.aliases`.
- `address` is an IPv4 address such as `127.0.0.1`. `protocol` is `tcp` or
  `udp`. Up to 64 ports per grant.
- Only the granted ports work. Other ports on the Mac, the Mac's LAN
  address and the internet (when off) are refused.

## Reach a machine on your LAN

```json
"allow": [{"kind": "lan", "cidr": "192.168.1.20/32", "protocol": "tcp", "ports": [443]}]
```

- `cidr` is an IPv4 network written without host bits, `/8` or narrower.
  Prefer a single host (`/32`).
- Loopback and other protected ranges cannot be granted.
- LAN grants create no `host-N` name: use the address.

LAN grants are covered by Koala's network tests, but not by a CLI journey.

## Publish a port

Publishing lets programs on your Mac reach a port in the VM.

With `create` flags:

```sh
koala create box --image docker.io/library/alpine:3 --publish 8080:8080 --wait   # 127.0.0.1:8080 -> guest 8080
koala create box2 --image docker.io/library/alpine:3 --publish 0:8080 --wait     # the Mac picks a free port
koala create box3 --image docker.io/library/alpine:3 --publish 5353:53/udp --wait
```

In a spec file:

```json
"publish": [{"protocol": "tcp", "hostAddress": "127.0.0.1", "hostPort": 0, "guestPort": 8080}]
```

- **Ports listen on `127.0.0.1` by default:** only programs on your Mac can
  connect. `::1` listens on the IPv6 loopback.
- **To expose a port to your LAN**, name another address. With flags,
  `--publish 0.0.0.0:8080:8080` does this. In a file, the entry must also say
  `"scope": "lan"`:

  ```json
  {"protocol": "tcp", "hostAddress": "0.0.0.0", "hostPort": 8080, "guestPort": 8080, "scope": "lan"}
  ```

- `hostPort` 0 lets the Mac choose a free port. `koala inspect VM` shows
  the port actually bound, while the VM runs:

  ```text
  attached: true
  published: tcp 127.0.0.1:52144 -> 8080 (loopback)
  ```

- If the port is already in use on the Mac, the start fails and nothing is
  left listening.
- Publishing a port does not give the VM any outbound access.

## Change a VM's network

Network settings change only while the VM is stopped: export, edit,
`update`, start. See [change a VM](vms.md#change-a-vm-koala-update). To
revoke access immediately, stop the VM.

## After a manager restart

If the manager restarts (or crashes) while a VM runs, the VM keeps running
but its network is cut off for safety:

- `koala list` shows it `Degraded`, and its published ports are closed.
- `exec`, `cp`, `logs` and `stats` keep working.
- `koala stop VM --wait` then `koala start VM --wait` restores the network.

## Wi-Fi, VPN and sleep

Koala follows changes to your Mac's network (Wi-Fi on or off, VPNs, route
changes) and re-checks the rules. Connections that become disallowed are
closed. Across a sleep, published ports pause and answer again after wake.
This was tested on a real Mac with route, VPN, Wi-Fi and sleep changes.

## Not available in v0.1

- Connections between VMs, and grants naming another VM.
- Changing a running VM's network.
- IPv6 connections from the guest.
