# Secrets

[User guide](README.md) > Secrets

A secret is a named value, such as an API token, that Koala keeps in your
login keychain and gives only to the VMs you grant it to.

## Store, inspect and remove a secret

```sh
printf %s "$TOKEN" | koala secret set agent-token --value-stdin
koala secret set agent-token          # or: prompt for the value without echoing it
koala secret inspect agent-token      # name, version, size and update time; never the value
koala secret rm agent-token
```

- A value is never accepted as an argument and is never printed.
- With `--value-stdin`, the bytes are stored exactly as read, including any
  trailing newline. Use `printf %s`, not `echo`, to avoid adding one.
- The limit is 64 KiB.
- `secret set` on an existing name replaces the whole value and increases
  its version.
- Names are 1 to 128 characters: letters, digits, `.`, `_` and `-`, starting
  with a letter or digit.
- `secret rm` deletes the keychain item. VMs that already received the value
  keep their copy; it cannot be taken back.

## Give a secret to a VM

Grant it in the VM's spec file, as a file, as an environment variable, or
both:

```json
"secrets": [
  {"name": "agent-token", "mode": "file", "destination": "/run/secrets/agent-token"},
  {"name": "agent-token", "mode": "environment", "variable": "AGENT_TOKEN"}
]
```

- **File:** the value is written into an in-memory filesystem (tmpfs) in the
  guest, readable only by root (mode 0400). It is not written to the VM's
  disk.
- **Environment:** the variable is set for every process Koala starts in that
  VM, including `koala exec` commands. Environment variables are easier to
  leak (child processes, crash reports, `ps`), so prefer files.
- The value is read when the VM starts. After `secret set`, restart the VM
  to give it the new value.
- A VM without the grant gets neither the file nor the variable.
- If the secret does not exist when the VM starts, the start fails with
  `GRANT_REQUIRED`.

Koala keeps secret values out of VM specs, logs, process arguments and
operation results. It cannot stop a program inside the VM from copying,
logging or sending a value it has received.

## Agents without secrets

For an AI agent or other untrusted tool, you can keep credentials out of the
VM entirely. Run a small service on your Mac (a *broker*) that holds the
credentials and performs only the actions you allow. Grant the VM access to
that one service with a [host-service grant](networking.md#reach-a-service-on-your-mac),
and give it `"secrets": []`. A reference broker is planned and is not available yet.

## The login keychain

Secrets (service `dev.koala.guest-secret.v1`) and registry logins (service
`dev.koala.registry.v1`) are stored as items in your login keychain. They are
encrypted at rest, and each item trusts the Koala manager that created it.

### The macOS approval prompt after an upgrade

When a new Koala manager build first reads an existing item (after an
upgrade, for example), macOS shows a prompt asking whether
`koala-manager` may use it. This happens once per item.

- Approve with **Always Allow**, then run the command again.
- While the prompt is waiting, Koala waits up to 60 seconds, then fails the
  request with `KEYCHAIN_APPROVAL_PENDING` (retryable). Approve the prompt
  and retry.
- If you click **Deny**, the request fails with `KEYCHAIN_ACCESS_DENIED`.
  Retry and approve.
- A VM start that needs a secret waiting for approval fails with
  `GRANT_REQUIRED`, and the message says that approval is pending.
- A `secret set` or `secret rm` that timed out waiting for the prompt has an
  unknown outcome: it takes effect if you approve later. Check with `koala
  secret inspect NAME`.
