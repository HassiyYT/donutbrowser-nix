# Repository Guidelines

## Project Structure & Module Organization
This repository is a source-build Nix flake for Donut Browser on Linux. `flake.nix` exposes package, app, overlay, check, and dev-shell outputs. `package.nix` contains the source derivation, sidecar staging, frontend build, and Tauri bundle install logic. Update automation lives in `scripts/update-version.sh` and `.github/workflows/`.

## Build, Test, and Development Commands
Use Nix-native commands from the repository root:

- `nix build .#donutbrowser --print-build-logs` builds the package exactly as CI does.
- `nix run .#donutbrowser` launches the packaged app.
- `nix flake check` validates the flake outputs for the current system.
- `./scripts/update-version.sh --check` checks whether a newer upstream release exists.
- `./scripts/update-version.sh --version 0.19.0` pins to a specific upstream release.

## Coding Style & Naming Conventions
Match existing file style. Nix uses two-space indentation and explicit semicolons. Bash scripts keep `#!/usr/bin/env bash`, `set -euo pipefail`, `snake_case` function names, and `readonly` constants for shared values. Keep packaging changes narrow and make updater logic easy to review.

## Testing Guidelines
There is no unit test suite. Validation is:

- `nix build .#donutbrowser --print-build-logs`
- `nix flake check`

If you change the updater, also run:

- `./scripts/update-version.sh --check`

## Commit & Pull Request Guidelines
Follow the existing automated update style:

- `chore: update donutbrowser to version 0.19.0`

For manual changes, use `fix:` or `chore:` with an imperative summary. If you open a PR manually, state what changed, why, and how it was validated. The hourly updater in this repo pushes version bumps directly to `main`.

## Security & Configuration Tips
Do not commit secrets. `CACHIX_AUTH_TOKEN` belongs in GitHub Actions secrets only. The `aarch64-linux` build job assumes a native ARM builder or self-hosted ARM64 runner is available before enabling full multi-arch cache publication.
