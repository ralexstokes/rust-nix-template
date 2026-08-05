# rust-nix-template

This repo is both a Nix library and a flake template:

- `lib/` — `mkRustProject`, the devshell/checks constructor consumers import.
- `templates/default/` — the complete scaffold `nix flake new -t` copies into
  new projects (justfile, `scripts/dev`, `.envrc`, CI workflow, placeholder
  `hello` crate).
- `flake.nix` — exports both and dogfoods `mkRustProject` on
  `templates/default`, so `nix flake check` tests the library against the
  exact scaffold users receive.

## Running anything

All tooling comes from the Nix devshell; it is **not** on the base PATH.
Prefix commands with `./scripts/dev` (a symlink into the scaffold — it enters
*this* repo's devshell):

```sh
./scripts/dev nix flake check --no-update-lock-file   # the authoritative CI gate
cd templates/default && ../../scripts/dev just test   # fast cargo iteration on the scaffold workspace
```

Never run `templates/default/scripts/dev` directly from inside this repo: it
would resolve the scaffold's own flake, whose `rust-env` input is the
published GitHub repo, not this checkout.

## Editing rules

- The scaffold `justfile` mirrors the checks in `lib/crane-checks.nix` and
  `lib/mk-rust-project.nix` — keep them in sync when changing either.
- New files must be `git add`ed before `nix flake check` can see them.
- After changing the template, smoke-test `nix flake new -t` end to end — the
  recipe is in README.md under "Developing this repo".

## Worktrees

Create them under `.worktrees`. `./scripts/dev` gives any worktree the correct
toolchain regardless of how it was created (direnv does not load in
non-interactive shells, and a shell spawned from another checkout carries that
checkout's devshell; the wrapper detects both via `REPO_DEVSHELL`).
