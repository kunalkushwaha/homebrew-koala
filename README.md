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

Koala runs Linux VMs for development and CI on Apple silicon Macs (macOS 26
or later). Koala is in **preview**: its security proofs are not complete.

This repository holds Koala's [releases](https://github.com/kunalkushwaha/homebrew-koala/releases),
its Homebrew formula and its user guide.

## Install

```sh
brew install kunalkushwaha/koala/koala
koala system install          # finish the install for your user (no sudo)
```

Or download an archive from the [releases page](https://github.com/kunalkushwaha/homebrew-koala/releases).
Each release's notes give the archive checksum and the runtime signing key.

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

## Learn more

Read the [user guide](docs/README.md), starting with
[getting started](docs/getting-started.md). `koala --help` lists every
command.

Koala is licensed under the Apache License, Version 2.0.
