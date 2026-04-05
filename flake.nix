{
  description = "Pure-source Nix flake for Donut Browser with hourly automated updates";

  nixConfig = {
    extra-substituters = [ "https://hassiyyt.cachix.org" ];
    extra-trusted-public-keys = [
      "hassiyyt.cachix.org-1:GPb2J+eS5AyHtVF9zQ+cchuQJl65WrxpcrdYsSiDjno="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        donutbrowser = final.callPackage ./package.nix { };
      };
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.donutbrowser;
          donutbrowser = pkgs.donutbrowser;
          "pnpm-deps" = pkgs.donutbrowser.passthru.pnpmDeps;
          "cargo-deps" = pkgs.donutbrowser.passthru.cargoDeps;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.donutbrowser}/bin/donutbrowser";
          };
          donutbrowser = {
            type = "app";
            program = "${pkgs.donutbrowser}/bin/donutbrowser";
          };
        };

        checks.default = pkgs.donutbrowser;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cachix
            gh
            jq
            nix
            nixpkgs-fmt
          ];
        };

        formatter = pkgs.nixpkgs-fmt;
      }
    )
    // {
      overlays.default = overlay;
    };
}
