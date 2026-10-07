# Images and private registries

[User guide](README.md) > Images and private registries

## Images

Lean VMs and jobs run OCI images: the images you know from Docker and other
container registries.

- Only `linux/arm64` images work. A multi-platform image is resolved to its
  `linux/arm64` variant; an image without one is refused before boot.
- A short name such as `alpine:3` means Docker Hub
  (`docker.io/library/alpine:3`). For other registries, start the
  reference with the registry host: `ghcr.io/OWNER/IMAGE:TAG`.
- `create` and `run` fetch the image if needed. When the VM is created, the
  tag is resolved to a fixed digest. If the tag later moves upstream, the
  existing VM keeps the version it was created with.
- The image provides the files and the default command, user, working
  directory and environment. Koala supplies the kernel. `EXPOSE` and
  `VOLUME` in an image grant nothing: ports and directories are opened only
  by your spec.
- Supported layers are uncompressed or gzip; zstd layers are refused. An
  image may have at most 96 layers.
- Koala does not build images (no Dockerfile builds). Build them elsewhere
  and push them to a registry.

Koala's own tests pull from a local test registry. Public registries such
as Docker Hub use the same code, but are not part of the tested journeys.

## Manage the image cache

```sh
koala image pull docker.io/library/alpine:3 --wait   # fetch and prepare now
koala image list                                     # reference, digest, platform
koala image prune --wait                             # remove images no VM uses
```

`image prune` never removes an image a VM still uses, and never touches
volumes.

## Private registries

Log in once; the password goes to your login keychain, not to a file:

```sh
printf %s "$PASSWORD" | koala registry login registry.example.com --username developer --password-stdin
```

- `REGISTRY` is a host, or `host:port`, without `https://` or a path.
- Without `--password-stdin`, `koala` prompts for the password without
  echoing it. A password is never accepted as an argument. One trailing line
  end is removed. The limit is 64 KiB.
- On success `koala` prints a **registry login ID**:

  ```text
  logged in to registry.example.com as developer; registry login LOGIN_ID
  use it with: koala image pull --registry-login LOGIN_ID REFERENCE
  ```

Pull with that login:

```sh
koala image pull registry.example.com/team/tool:1.2 --registry-login LOGIN_ID --wait
```

Forget the login on this Mac (this deletes the keychain item):

```sh
koala registry logout LOGIN_ID
```

- `logout` does not revoke a token the registry has already issued.
- Pulling with a login ID that no longer exists fails with `NOT_FOUND`.
- Registry passwords are used on your Mac only; they are never copied into
  a VM.
- After a Koala upgrade, macOS may ask to allow the new manager to use the
  stored login. See [secrets](secrets.md#the-macos-approval-prompt-after-an-upgrade);
  the same applies here.

**Not covered yet:** `--registry-login` applies to `image pull` only. Using
a privately pulled image in `koala create` or `koala run` is not part of the
tested journeys.
