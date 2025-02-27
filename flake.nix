{
  description = "A collection of project templates";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    pre-commit-hooks,
    ...
  }:
    {
      templates = {
        bevy = {
          path = ./bevy;
          description = "A simple bevy boilerplate with GitLab pages setup";
        };
        yew = {
          path = ./yew;
          description = "A simple Yew setup with GitLab pages setup";
        };
        flutter = {
          path = ./flutter;
          description = "A simple Flutter project setup";
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              alejandra.enable = true;
            };
          };
        };
        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
        };
      }
    );
}
