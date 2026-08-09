# my-project

Bootstrapped from [rust-nix-template](https://github.com/ralexstokes/rust-nix-template).

## Getting started

All tooling comes from the Nix devshell — see `AGENTS.md` for the contract.

```sh
chmod +x tools/dev            # `nix flake new` drops the executable bit
git init && git add -A        # flakes only see tracked files
direnv allow                  # interactive shells; agents use ./tools/dev
./tools/dev just ci           # fast local CI mirror
./tools/dev just ci-nix       # authoritative clean lane (nix flake check)
```

## Make it yours

- Rename this project: set `name` under `[workspace.metadata]` in `Cargo.toml`
  (the flake reads it to label Nix derivations) and rewrite this README.
- Replace the placeholder `crates/hello` crate and update the workspace
  `members`.
- Pick your Rust version in `rust-toolchain.toml`.
- For CI caching, replace the `ralexstokes` Cachix cache name in
  `.github/workflows/ci.yml` with your own and set a `CACHIX_AUTH_TOKEN`
  repository secret — or delete the Cachix steps.
- Customization beyond the defaults goes through the `mkRustProject` arguments
  in `flake.nix` (extra devshell packages, extra checks, extra CI commands);
  mirror any check changes in the `justfile`.
