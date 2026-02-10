# donutbrowser-nix

Nix flake for [Donut Browser](https://github.com/zhom/donutbrowser) with:

- Hourly GitHub Actions update checks
- Automatic update PR creation (latest release tags)
- Linux build validation in CI
- Cachix binary cache publishing

## Scope

- Target platform: `x86_64-linux`
- Upstream tracking: GitHub release tags from `zhom/donutbrowser`
- Package source: Linux AppImage asset from upstream releases

## Quick Start

Run from this repository:

```bash
nix run .#donutbrowser
```

Install into your profile:

```bash
nix profile install .#donutbrowser
```

## Runtime Binary Cleanup Workaround

The wrapper script in `package.nix` protects downloaded browser binaries during
startup to avoid an upstream cleanup bug that can remove them too early.

- Default behavior: protect version directories for `8` seconds at startup
- Override window: set `DONUTBROWSER_STARTUP_PROTECT_SECS=<seconds>`
- Disable workaround: set `DONUTBROWSER_ALLOW_BINARY_CLEANUP=1`

## Binary Cache (Cachix)

The flake config already includes:

- Substituter: `https://hassiyyt.cachix.org`
- Public key: `hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno=`

To configure globally (optional):

```nix
{
  nix.settings = {
    extra-substituters = [ "https://hassiyyt.cachix.org" ];
    extra-trusted-public-keys = [
      "hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno="
    ];
  };
}
```

## Automation Workflows

- `.github/workflows/update-donutbrowser.yml`
  - Runs hourly (`0 * * * *`)
  - Checks latest release tag
  - Updates `package.nix` version/asset/hash
  - Creates PR and enables auto-merge
- `.github/workflows/build.yml`
  - Builds package on push/PR and after updater completion
  - Pushes build outputs to Cachix on `main`
- `.github/workflows/test-pr.yml`
  - Validates PRs that modify package/flake/workflow files
- `.github/workflows/create-version-tag.yml`
  - Creates version and moving tags after successful main build

## Required Repository Setup

See `.github/REPOSITORY_SETTINGS.md`.

Required secret:

- `CACHIX_AUTH_TOKEN`

Required GitHub settings:

- Actions workflow permissions: read/write
- Allow Actions to create/approve PRs
- Enable auto-merge

## Manual Update

Check for updates only:

```bash
./scripts/update-version.sh --check
```

Apply latest release update:

```bash
./scripts/update-version.sh
```

Update to a specific release:

```bash
./scripts/update-version.sh --version 0.13.9
```
