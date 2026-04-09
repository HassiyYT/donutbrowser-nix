# Repository Settings Configuration

This repository uses hourly automation to keep Donut Browser up to date.

## Required GitHub Settings

### 1) Workflow Permissions

1. Go to **Settings** -> **Actions** -> **General**.
2. Under **Workflow permissions**, set:
   - **Read and write permissions**
3. Save.

### 2) ARM Builder

The `aarch64-linux` cache job assumes one of these exists:

- a self-hosted GitHub Actions runner labeled `self-hosted`, `Linux`, `ARM64`
- a native ARM build runner you map to the same labels

## Required Secrets

Add these in **Settings** -> **Secrets and variables** -> **Actions**.

- `CACHIX_AUTH_TOKEN`: Cachix auth token with push access to `hassiyyt`

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

## Cachix Details

- Cache: `hassiyyt`
- Substituter: `https://hassiyyt.cachix.org`
- Public key: `hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno=`
