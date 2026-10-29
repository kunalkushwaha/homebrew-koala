# Working inside a VM

[User guide](README.md) > Working inside a VM

## Run a command: `koala exec`

```sh
koala exec dev -- ls -la /
koala exec dev -- /bin/sh -c 'cd /src && make test'
```

The VM must be `Running` (or `Degraded`). Everything after `--` is the
command and its arguments, passed as-is; use `/bin/sh -c '...'` when you
want a shell.

| Option | Meaning |
| --- | --- |
| `-i` | Send your stdin to the command. |
| `-t` | Give the command a terminal (a PTY). Needs a terminal on your side. |
| `-it` | Both: for shells, editors and other interactive programs. |
| `--user U` | Run as this guest user: a name from the image's `/etc/passwd`, `name:group`, or numeric IDs ([profiles](profiles.md#lean-vms)). Default: the image's user (root in a full VM). |
| `--workdir DIR` | Start in this guest directory. |
| `--env KEY=VALUE` | Set a variable. Repeatable. |
| `--timeout S` | Kill the command after `S` seconds (exit status 124). |
| `--result-file PATH` | Write the result as JSON (mode 0600). |

Output:

- Without `-t`, the command's stdout and stderr arrive on your stdout and
  stderr unchanged, byte for byte, binary included. You can pipe them.
- With `-t`, the command's terminal output arrives on your terminal
  unchanged.
- `koala`'s own messages (such as `execution ID`) go to stderr.
- `--json` cannot be mixed with the command's output on stdout. Use it with
  `--result-file`, or use `koala execution inspect --json` afterwards.

Pipe data in with `-i`:

```sh
tar -cf - ./src | koala exec -i dev -- tar -xf - -C /tmp
```

## Interactive shells and detaching

```sh
koala exec -it dev -- /bin/sh
```

- Keys, Ctrl-C and window resizing go to the program in the VM.
- To **detach** and leave the program running, press `Ctrl-]` then `d`.
  `koala` prints the execution ID and how to reattach.
- Closing the terminal window (SIGHUP) or sending SIGTERM to `koala` also
  detaches; it does not stop the program.

Without `-t` (pipes mode), Ctrl-C **cancels** the command once and
`koala` exits with status 130.

In a full-profile VM, `tty` inside the shell prints `not a tty`, although
the terminal itself works. This is not fixed yet.
Programs that need the terminal's name, such as `tmux` or `sudo` with
`use_pty`, may misbehave there. Lean VMs are not affected.

## Reattach: `koala attach`

Every `exec` and every job has an execution ID. Reattach to it:

```sh
koala attach EXECUTION_ID               # output and the result; your stdin goes to it
koala attach --no-stdin EXECUTION_ID    # output and the result only
```

- Only one client can send stdin to an execution at a time; others attach
  with `--no-stdin`.
- Input you typed before a disconnect is never replayed.
- `--cursor N` resumes the output after sequence number `N`.
- If the execution has already finished, `attach` replays its retained
  output and returns its exit status.
- `attach` waits up to 600 seconds for a job that is still starting
  (`--timeout S` to change).

Check or stop an execution without attaching:

```sh
koala execution inspect EXECUTION_ID           # state, reason, exit code, times
koala execution inspect --json EXECUTION_ID
koala execution cancel EXECUTION_ID
```

## Exit statuses

For `run`, `exec` and `attach`, `koala`'s exit status is the command's
result, as recorded by the manager:

| Result | Exit status |
| --- | --- |
| The command exited | Its exit code |
| Killed by a signal | 128 + the signal number |
| Timed out (`--timeout`) | 124 |
| Cancelled (Ctrl-C or `execution cancel`) | 130 |
| Lost or unknown (for example the VM's worker crashed) | 125 |

A command can exit with 124, 125 or 130 itself; `execution inspect` shows the
`reason` (`exited`, `signaled`, `timed_out`, `cancelled` or `lost`) to tell
them apart.

Other `koala` commands exit with 0 on success, 1 when refused or failed, 2
for a usage error, 3 when the outcome is unknown (for example the manager
stopped answering; the message names what to check), and 130 when you
interrupt a wait.

## Copy files: `koala cp`

One side is `VM:/absolute/path`, the other a path on your Mac:

```sh
koala cp ./src dev:/work/src          # a directory into the VM
koala cp ./notes.txt dev:/tmp/notes.txt
koala cp dev:/work/out ./out          # a directory out of the VM
koala cp --replace ./src dev:/work/src
```

- The destination names the new entry exactly. Its parent directory must
  exist. If the destination exists, the copy is refused (`TRANSFER_EXISTS`)
  unless you pass `--replace`, which swaps it in atomically.
- A copied tree appears all at once: a program in the VM never sees half of
  it.
- Regular files, directories and relative symlinks that stay inside the
  tree are copied. Hard links, device files, FIFOs and escaping symlinks are
  refused, and so is a symlink whose target goes through another symlink in
  the copy.
- Copied files and directories keep their permissions, except that group and
  other write are removed.
- Limits per copy: 100,000 entries and 16 GiB.
- The VM must be running. Ctrl-C cancels the copy (exit status 130); files
  that already existed at the destination are left alone.
- A host path that contains a colon is written as `./name:with:colon`.
- In `VM:/path`, use the VM's name (lower-case) or its ID.

Files on your Mac are read and written by a small helper, `koala-transfer`,
installed beside `koala`. If it is missing or writable by others, `cp`
refuses to run.

## Logs: `koala logs`

```sh
koala logs web                          # a service's main process
koala logs web --follow                 # keep printing new output; Ctrl-C to stop
koala logs dev --execution EXECUTION_ID # one exec's output
koala logs dev --serial                 # the VM's serial console
```

- Without `--execution` or `--serial`, `logs` shows the main process of the
  VM's current run. An environment VM has none: name an execution.
- `--run RUN_ID` reads an earlier run instead of the current one.
- After a job finishes, its VM is gone, but its output is kept for a while.
  Read it with the VM's ID and run ID, which `run --detach --json` printed:

  ```sh
  koala logs VM_ID --run RUN_ID --execution EXECUTION_ID
  ```

- Control characters in the output are shown escaped, so a program cannot
  change your terminal through `logs`. `attach` and `exec` show raw output.
- Retained output is limited per run and in total, and is kept for a limited
  time after a job ends. The documented defaults are 16 MiB per run, 256 MiB
  in total and 24 hours; the installed values are set by the installation. When older output is dropped, `logs` prints a
  marker such as `[gap: 4096 bytes, quota]` on stderr. Output that has
  expired returns `RETENTION_EXPIRED`.
- `--json` prints the raw log records.

## Serial console: `koala console`

```sh
koala console dev
koala console --follow dev
```

The read-only serial output of the VM, including early boot messages and
kernel errors. It works even when the VM's agent does not. It is not a
login: use `koala exec -it` for a shell. Koala does not install an SSH
server in VMs.

## Events: `koala events`

```sh
koala events                    # recent events for all VMs
koala events --vm dev --follow  # follow one VM's events
```

Events record lifecycle changes, operations, executions and errors, one
line each. `--json` prints one JSON object per event.

Two kinds help answer "what could this VM reach, and what did it try":

- `spec.updated`: `koala update` replaced the VM's spec. `transition` says
  whether what the VM may reach changed (`grants-changed`) or not
  (`grants-unchanged`), and `grants=sha256:…` is a digest of its network,
  shares, volumes and secrets. `vm.created` carries the first digest.
- `flow.denied`: Koala refused connections from the VM, for example to
  your Mac or your local network. `denied=tcp.22.prohibited-prefix` is the
  protocol, the port and the kind of destination; `count` is how many.
  There is at most one line a minute for each kind of destination, and the
  rest are counted, so a busy VM can't flood the log. The address itself
  isn't recorded. A first refusal shows up within a few seconds; the rest
  of its minute's count when the minute ends or the VM stops.
  `denied=other.0.unsupported-ipv6` is normal: Linux sends IPv6 discovery
  packets on its own, and Koala doesn't forward IPv6.

```text
12 2026-10-27T10:40:02.118Z flow.denied vm=… run=… denied=tcp.22.prohibited-prefix count=7
```

### Events in the macOS log

On macOS, Koala also writes every event to the unified log, where `log
show` and device-management or endpoint-security tools can read it, kept
by macOS's own rules:

```sh
log show --last 1h --predicate 'subsystem == "dev.koala" AND category == "audit"'
```

Each line is the event as `koala events --json` prints it, with its `id`.
On Linux, the events go to the system log with the identifier
`koala-audit`: `journalctl -t koala-audit`, or `/var/log/syslog` on a host
where rsyslog keeps the log. Only events carry that identifier.

### How long events are kept

Events are kept **30 days** by default. `koala system info` shows the
current value (`events    kept 30 days`). To keep them longer, from 1 to
365 days, add an `audit` entry to
`~/Library/Application Support/Koala/manager.json` (on Linux,
`~/.local/share/koala/manager.json`):

```json
"audit": {"retentionDays": 90}
```

Then restart the manager:

```sh
koala system stop --stop-vms
koala system start
```

- The new value applies to events recorded after the restart. Events
  already recorded keep the expiry they were written with.
- A value outside 1–365, or a misspelt key, stops the manager from
  starting: `koala system info` then shows `manager    not reachable`, and
  the manager's log names the key.
- `koala system install` keeps the setting when you upgrade.
- How long workload output is kept (`koala logs`) is a separate setting
  and doesn't change.
