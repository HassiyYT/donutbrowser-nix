# donutbrowser-nix

Pure-source Nix flake for [Donut Browser](https://github.com/zhom/donutbrowser).

This flake exposes:

- `packages.<system>.{default,donutbrowser}`
- `apps.<system>.{default,donutbrowser}`
- `checks.<system>.default`
- `overlays.default`

Supported systems:

- `x86_64-linux`
- `aarch64-linux`

Automated CI currently builds and caches `x86_64-linux` only. `aarch64-linux`
remains a supported flake output, but its GitHub Actions build is manual until a
native ARM64 runner is available.

## Quick Start

Run directly:

```bash
nix run github:HassiyYT/donutbrowser-nix#donutbrowser
```

Install into the current profile:

```bash
nix profile install github:HassiyYT/donutbrowser-nix#donutbrowser
```

## Cachix

The flake declares the `hassiyyt` Cachix cache:

- `https://hassiyyt.cachix.org`
- `hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno=`

## Development

Build exactly what CI builds:

```bash
nix build .#donutbrowser --print-build-logs
```

Update to the latest upstream Donut Browser release:

```bash
./scripts/update-version.sh
```

Check whether a newer release exists:

```bash
./scripts/update-version.sh --check
```

Repository automation and required GitHub settings are documented in
[`./.github/REPOSITORY_SETTINGS.md`](./.github/REPOSITORY_SETTINGS.md).
