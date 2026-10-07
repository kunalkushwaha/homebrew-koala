# Troubleshooting

[User guide](README.md) > Troubleshooting

## Reading an error

A refused request looks like this:

```text
koala: error 409 INVALID_STATE: The resource's state does not permit this request. (request 6f0c...)
```

The upper-case word is the **error code**. It is stable; the message after
it may change. A spec error also names the field, for example
`at /spec/network/allow/0/ports`.

A request that was accepted but failed later (with `--wait`) ends like
this, with the code last:

```text
failed OPERATION_ID RESOURCE_ADMISSION_FAILED
```

`koala events --vm VM` and `koala console VM` often show more detail.

## The manager does not start

| Message | What to do |
| --- | --- |
| `manager unavailable: ...` | The manager is not running. Run `koala system start`. |
| `koala: no .../Library/LaunchAgents/dev.koala.manager.plist` | Koala is not installed for this user. Run `koala system install` ([getting started](getting-started.md#installation)). |
| `INSTALL_VMS_RUNNING` | `system install` (upgrade) or `system uninstall` found running VMs. Stop them, or add `--stop-vms`. |
| `INSTALL_START_FAILED ... is running again` | The new manager did not start, and the previous version was restored. The message quotes the end of `~/Library/Application Support/Koala/logs/manager.log`. |
| `INSTALL_MANAGER_UNAVAILABLE` | The installed manager would not start, so running VMs could not be checked; nothing was changed. A common cause is data written by a newer Koala: install that version or a later one. |
| `INSTALL_PAYLOAD_INVALID` | The release folder is incomplete or altered. Download it again. |
| `INSTALL_FOREIGN_INSTALLATION` | The launchd agent belongs to an installation with another `--root` or made by hand. Use that root, or remove the plist. |
| `INSTALL_FAILED: cannot delete a keychain item` or `... keychain item(s) remain` (from `system uninstall --purge`) | The purge stopped before deleting Koala's data folder. Delete the item it names with `security delete-generic-password -s SERVICE -a ACCOUNT`, or in Keychain Access, and run the purge again. |
| `installation: unverified (...)` in `system info`, or `the job plist is not a private regular file`, `the manager executable's signature is invalid` | The launchd agent or the manager binary is not owned by you, is writable by others, or is not signed as expected. Reinstall. |
| `launchd has no loaded job gui/UID/dev.koala.manager` | The agent is installed but not loaded by launchd. Log out and in, or reinstall. |
| `the manager did not answer within 600s` (exit status 3) | Run `koala system info` to see whether it came up late. |
| `refusing the manager socket: ...` | The socket is not a private socket owned by you. Do not point `--socket` at another user's socket. |

## Messages from `koala` itself

| Message | What to do |
| --- | --- |
| `the VM is not running (Stopped)` | `koala start VM --wait`, then retry. |
| `-t needs a terminal on stdin and stdout` | You are piping or redirecting. Drop `-t` (use `-i` for stdin). |
| `--json cannot share stdout with workload bytes` | Use `--result-file PATH`, or `run --detach --json`. |
| `the VM has no primary process in its current run` | It is an environment VM. Use `koala logs VM --execution ID` or `--serial`. |
| `refusing to stop the manager with live VMs: ...` | Stop them, or use `koala system stop --stop-vms`. |
| `refusing the transfer helper: ...` | `koala-transfer` beside `koala` is missing, or is writable by your group or others. Reinstall. |
| `detached; execution ID continues` | You detached; reattach with `koala attach ID`. |
| `outcome unknown ...` (exit status 3 or 125) | The manager stopped answering mid-request. Check the result with `koala list`, `koala inspect VM` or `koala execution inspect ID`, as the message says, before retrying. |
| `retained output may be incomplete` | Some output was still being saved when the wait ran out. Run `koala logs` again. |

## Error codes

### Names, files and state

| Code | Meaning and what to do |
| --- | --- |
| `NOT_FOUND` | No VM, volume, execution, secret or registry login by that name or ID. Check `koala list`, `koala volume list`. |
| `AMBIGUOUS_NAME` | Several VMs or volumes share that name. Use the ID listed in the message. |
| `INVALID_ARGUMENT` | A value in the request is not allowed, for example a volume size or a name. The message says which. |
| `INVALID_SPEC` | The spec is invalid at the pointer shown. Check it with `koala config validate -f FILE`. |
| `INVALID_STATE` | The VM is in the wrong state, for example `update` on a running VM or `rm` before `stop`. |
| `STALE_GENERATION` | The VM changed while you were updating it. Export and update again. |
| `CONFLICT` | The request clashes with existing state, for example `volume rm` while a VM refers to the volume. |
| `IDEMPOTENCY_CONFLICT` | A retried request did not match the original. Run the command again. |

### Images

| Code | Meaning and what to do |
| --- | --- |
| `IMAGE_INCOMPATIBLE` | The image does not fit the profile: OCI images need `lean`, catalog entries `full`. Or the catalog entry is unknown. |
| `UNSUPPORTED_ARCHITECTURE` | The image has no `linux/arm64` variant. |
| `IMAGE_PREPARATION_FAILED`, `REGISTRY_ERROR` | The image could not be fetched or prepared, or the registry answered with an error (for example a wrong password or a missing image). Check the reference, your network and your login. |
| `REGISTRY_AUTH_INVALID` | The registry's sign-in challenge could not be used. Check the registry address. |
| `NOT_FOUND` on `image pull --registry-login` | The login ID no longer exists (for example after `registry logout`). |

### Runtimes and the catalog

| Code | Meaning and what to do |
| --- | --- |
| `RUNTIME_CORRUPT`, `CATALOG_CORRUPT` | An installed runtime or catalog file no longer matches its signed manifest (for example a damaged disk or an edited file). Koala refuses to use it. Reinstall the runtime. |
| `RUNTIME_UNTRUSTED`, `CATALOG_UNTRUSTED` | It is not signed by a release key your Koala trusts. Install runtimes only from Koala releases. |
| `RUNTIME_NOT_FOUND`, `CATALOG_NOT_FOUND` | The runtime or catalog entry is not installed. |
| `RUNTIME_INCOMPATIBLE` | The runtime does not fit the VM's profile or image. |

### Grants, secrets and the keychain

| Code | Meaning and what to do |
| --- | --- |
| `GRANT_REQUIRED` | A start needs something it cannot have: a shared directory that was moved, replaced or had its owner or permissions changed; a secret that does not exist; or a secret waiting for keychain approval. The message says which. Fix it, or `koala update` the stopped VM. |
| `KEYCHAIN_APPROVAL_PENDING` | macOS is asking whether `koala-manager` may use a Koala keychain item (usually after an upgrade). Click **Always Allow**, then retry. See [secrets](secrets.md#the-macos-approval-prompt-after-an-upgrade). |
| `KEYCHAIN_ACCESS_DENIED` | The prompt was denied. Retry and approve it. |
| `SECRET_STORE_UNAVAILABLE` | The keychain refused the request for another reason. Retry; if it persists, check your login keychain in Keychain Access. |
| `PAYLOAD_TOO_LARGE` | A secret or password over 64 KiB, or another request over its size limit. |

### Resources and storage

| Code | Meaning and what to do |
| --- | --- |
| `RESOURCE_ADMISSION_FAILED` | Not enough unreserved memory or disk to start the VM. Stop other VMs, or lower `memoryMiB`. See [limits](limits.md#memory-cpu-and-disk). |
| `STORAGE_SPACE_EXHAUSTED` | Your Mac's disk is too full. Free space and retry. |
| `RESOURCE_EXHAUSTED` | A manager limit was reached, such as too many open log or event streams, or a busy state store. Retry shortly. |

### Network

| Code | Meaning and what to do |
| --- | --- |
| `NETWORK_POLICY_INVALID` | A grant is not allowed: for example a protected address, or a LAN range wider than `/8`. `koala inspect --json VM` shows the field under `network.policyError`. |
| `NETWORK_UNAVAILABLE` | The VM's network could not be set up, for example because a published port is already in use on your Mac. |

A VM shown as `Degraded` lost its network, usually after a manager restart.
Stop and start it. See [networking](networking.md#after-a-manager-restart).

### Commands, logs and copies

| Code | Meaning and what to do |
| --- | --- |
| `EXEC_START_FAILED` | The command could not be started in the VM, for example the program does not exist. This is not the program's exit code. |
| `RETENTION_EXPIRED` | The output you asked for is no longer kept. |
| `TRANSFER_EXISTS` | The `cp` destination already exists. Choose another name or add `--replace`. |
| `TRANSFER_INVALID_PATH` | A path in the copy is not usable, for example the copied entry is itself a symlink. |
| `TRANSFER_INVALID_ENTRY` | The tree contains something `cp` refuses: a hard link, a device file, a FIFO or a symlink that leads outside the tree. |
| `TRANSFER_BUDGET` | The copy exceeds 100,000 entries or 16 GiB. |

### Internal failures

`INTERNAL`, `WORKER_FAILED`, `GUEST_UNAVAILABLE`, `DEADLINE_EXCEEDED`, a VM
in `TerminationUnknown`, or a command that ended `lost` mean something went
wrong inside Koala or the VM. Check `koala console VM` and `koala events
--vm VM`. Koala keeps the VM's resources reserved until it is sure the VM
has stopped, so a `TerminationUnknown` VM may take a while to settle.
