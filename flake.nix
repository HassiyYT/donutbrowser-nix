{
  description = "Nix flake for Donut Browser - anti-detect browser with hourly automated updates";

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

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        donutbrowser = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.donutbrowser;
          donutbrowser = pkgs.donutbrowser;
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

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cachix
            curl
            gh
            jq
            nix
            nixpkgs-fmt
          ];
        };
      }
    ) // {
      overlays.default = overlay;
    };
}
