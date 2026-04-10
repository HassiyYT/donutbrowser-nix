# Repository Settings Configuration

This repository uses hourly automation to keep Donut Browser up to date.

## Required GitHub Settings

### 1) Workflow Permissions

1. Go to **Settings** -> **Actions** -> **General**.
2. Under **Workflow permissions**, set:
   - **Read and write permissions**
3. Save.

### 2) ARM Builder

Automatic CI builds and caches only `x86_64-linux`.

The `aarch64-linux` build is manual-only until one of these exists:

- a self-hosted GitHub Actions runner labeled `self-hosted`, `Linux`, `ARM64`
- a native ARM build runner you map to the same labels

If you use the manual ARM workflow with `actions/checkout@v5`, keep the self-hosted
runner updated to a recent GitHub Actions runner release that supports Node 24-era
JavaScript actions.

### 3) Updater Behavior

The hourly updater can skip a new upstream Donut Browser release when the carried
patch set no longer applies cleanly.

- skipped updates are expected to stay green in Actions
- the pinned packaged version remains unchanged until the patch set is refreshed
- `Build and Cache` should no longer trigger from `workflow_run`

## Required Secrets

Add these in **Settings** -> **Secrets and variables** -> **Actions**.

- `CACHIX_AUTH_TOKEN`: Cachix auth token with push access to `hassiyyt`

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

## Cachix Details

- Cache: `hassiyyt`
- Substituter: `https://hassiyyt.cachix.org`
- Public key: `hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno=`
