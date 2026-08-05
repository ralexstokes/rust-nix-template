{
  description = "Rust + Nix development environment: importable library and project template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane = {
      url = "github:ipetkov/crane";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      crane,
      rust-overlay,
    }:
    let
      lib = import ./lib {
        inherit
          nixpkgs
          flake-utils
          crane
          rust-overlay
          ;
      };
      # Dogfood: this repo's own devshell and checks come from mkRustProject
      # applied to the scaffold workspace, so CI continuously exercises the
      # library against exactly what `nix flake new -t` hands out.
      project = lib.mkRustProject {
        src = ./templates/default;
        projectName = "rust-nix-template";
        # The scaffold's automatic nixfmt check only sees files under its own
        # tree; cover this repo's Nix sources as well.
        extraChecks = pkgs: {
          nixfmt-lib = pkgs.runCommandLocal "nixfmt-lib-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            nixfmt --check ${./flake.nix} ${./lib/default.nix} ${./lib/mk-rust-project.nix} \
              ${./lib/crane-checks.nix}
            touch $out
          '';
        };
      };
    in
    project
    // {
      inherit lib;

      templates.default = {
        path = ./templates/default;
        description = "Rust workspace with Nix devshell, crane CI checks, and worktree-safe tooling";
        welcomeText = ''
          Next steps:
            chmod +x scripts/dev    # `nix flake new` drops the executable bit
            git init && git add -A  # flakes only see tracked files
            direnv allow            # interactive shells; agents use ./scripts/dev
            ./scripts/dev just ci

          See README.md for the rename checklist.
        '';
      };
    };
}
