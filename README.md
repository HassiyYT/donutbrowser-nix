# donutbrowser-nix

Pure-source Nix flake for [Donut Browser](https://github.com/zhom/donutbrowser).

This flake exposes:

- `packages.<system>.{default,donutbrowser}`
- `apps.<system>.{default,donutbrowser}`
- `checks.<system>.default`
- `overlays.default`

## Requirements

- Linux with flakes enabled
- Supported systems:
  - `x86_64-linux`
  - `aarch64-linux`

Automated CI currently builds and caches `x86_64-linux` only. `aarch64-linux`
remains a supported flake output, but its GitHub Actions build is manual until a
native ARM64 runner is available.

Canonical flake reference:

```bash
github:HassiyYT/donutbrowser-nix
```

If you already cloned this repository, replace that reference with `.` in the
examples below.

## Try Without Installing

Run directly:

```bash
nix run github:HassiyYT/donutbrowser-nix#donutbrowser
```

From a local checkout:

```bash
nix run .#donutbrowser
```

## Install For One User

Install into the current profile:

```bash
nix profile install github:HassiyYT/donutbrowser-nix#donutbrowser
```

From a local checkout:

```bash
nix profile install .#donutbrowser
```

The installed executable is:

```bash
donutbrowser
```

## Install System-Wide On NixOS

Add the flake as an input in your system flake:

```nix
{
  inputs.donutbrowser.url = "github:HassiyYT/donutbrowser-nix";
}
```

Then add the package to `environment.systemPackages`:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.donutbrowser.packages.${pkgs.system}.donutbrowser
  ];
}
```

### Optional Overlay Style

If you prefer using `pkgs.donutbrowser`, add the overlay first:

```nix
{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.donutbrowser.overlays.default ];
}
```

Then install it as a normal package:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.donutbrowser ];
}
```

## Install With Home Manager

Add the same flake input:

```nix
{
  inputs.donutbrowser.url = "github:HassiyYT/donutbrowser-nix";
}
```

Then add the package to `home.packages`:

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.donutbrowser.packages.${pkgs.system}.donutbrowser
  ];
}
```

### Optional Overlay Style

If you already use overlays in Home Manager:

```nix
{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.donutbrowser.overlays.default ];
}
```

Then:

```nix
{ pkgs, ... }:
{
  home.packages = [ pkgs.donutbrowser ];
}
```

## Wayland And X11

The package wrapper is tuned for Wayland by default.

On startup it sets:

- `MOZ_ENABLE_WAYLAND=1` if unset
- `GDK_BACKEND=wayland,x11` if unset

### Wayland Users

For Wayland sessions, the default `donutbrowser` launch path is the recommended
configuration.

### X11 Users

X11 is supported too. In many X11 desktop sessions, your session already exports
the right environment, so `donutbrowser` may work without extra configuration.

If you want to force X11 explicitly, launch it like this:

```bash
env \
  GDK_BACKEND=x11 \
  MOZ_ENABLE_WAYLAND=0 \
  donutbrowser
```

## Cachix

The flake declares the `hassiyyt` Cachix cache:

- `https://hassiyyt.cachix.org`
- `hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno=`

If you want to trust it globally instead of relying on per-flake `nixConfig`,
add this to your Nix settings:

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
