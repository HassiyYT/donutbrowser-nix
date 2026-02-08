# Repository Settings Configuration

This repository uses hourly automation to keep Donut Browser up to date.

## Required GitHub Settings

### 1) Workflow Permissions

1. Go to **Settings** -> **Actions** -> **General**.
2. Under **Workflow permissions**, set:
   - **Read and write permissions**
   - Enable **Allow GitHub Actions to create and approve pull requests**
3. Save.

### 2) Auto-Merge

1. Go to **Settings** -> **General**.
2. Under **Pull Requests**, enable **Allow auto-merge**.

## Required Secrets

Add these in **Settings** -> **Secrets and variables** -> **Actions**.

- `CACHIX_AUTH_TOKEN`: Cachix auth token with push access to `hassiyyt` cache.

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

## Cachix Details

- Cache: `hassiyyt`
- Substituter: `https://hassiyyt.cachix.org`
- Public key: `hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno=`

## Verify Setup

1. Manually run workflow **Update Donut Browser Version**.
2. Confirm it creates a PR when an update is available.
3. Confirm **Build and Cache** passes and pushes outputs to Cachix on `main`.
