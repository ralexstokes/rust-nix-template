# rust-nix-template

A Nix flake providing a complete Rust development environment two ways:

1. **A library** (`lib.mkRustProject`) any flake can import — devshell, CI
   checks, and formatter, defined once here and updated downstream with
   `nix flake update`.
2. **A template** (`templates.default`) for the files Nix can't inject — the
   `justfile`, `scripts/dev`, `.envrc`, GitHub workflow, toolchain files, and a
   placeholder crate.

## Starting a new project

```sh
nix flake new -t github:ralexstokes/rust-nix-template my-project
cd my-project
chmod +x scripts/dev          # `nix flake new` drops the executable bit
git init && git add -A        # flakes only see tracked files
./scripts/dev just ci
```

The scaffold's `flake.nix` is ~10 lines: it pins this repo as the `rust-env`
input and calls `mkRustProject { src = ./.; }`. Everything else it ships is
plain files; `templates/default/README.md` lists the rename steps.

## What `mkRustProject` provides

- **Devshell** — stable toolchain from the project's `rust-toolchain.toml` via
  [rust-overlay], plus a pinned nightly for `fmt`/`clippy`. `rustup` is wired
  to a read-only store-backed `RUSTUP_HOME`, so `cargo +nightly ...` works
  offline. Ships `cargo-nextest`, `just`, `nixfmt`, `ripgrep`, `git`.
- **Checks** (`nix flake check`) — `cargo-fmt`, `cargo-clippy`
  (`-D warnings`), `cargo-ci` (build, nextest, doctests, rustdoc with
  `-D warnings`) via [crane], and `nixfmt` over every `.nix` file in the tree.
- **Formatter** — `nix fmt` runs nixfmt.

Arguments:

| argument             | default                          | purpose                                    |
| -------------------- | -------------------------------- | ------------------------------------------ |
| `src`                | (required)                       | project root with `Cargo.toml`/`Cargo.lock`/`rust-toolchain.toml` |
| `projectName`        | from `Cargo.toml`                | labels the Nix derivations                 |
| `extraShellPackages` | `pkgs: [ ]`                      | more devshell packages                     |
| `extraChecks`        | `pkgs: { }`                      | more flake checks, merged over defaults    |
| `extraCiCommands`    | `""`                             | shell commands appended to `cargo-ci` (e.g. example smoke runs) |
| `extraSourceFilter`  | `path: type: false`              | extra files kept in the cargo build sandbox |

## Repo layout

- `lib/` — `mk-rust-project.nix` (devshell + outputs) and `crane-checks.nix`
  (the cargo checks).
- `templates/default/` — the complete scaffold copied by `nix flake new -t`.
- `flake.nix` — exports both, and dogfoods: this repo's own devshell and
  checks come from `mkRustProject` applied to `templates/default`, so CI
  always tests the library against exactly what the template hands out.

## Developing this repo

`./scripts/dev <cmd>` (a symlink into the scaffold) runs commands in this
repo's devshell. The authoritative gate is:

```sh
./scripts/dev nix flake check --no-update-lock-file
```

For fast cargo iteration against the scaffold workspace, run the scaffold's
justfile from inside it with the root devshell:

```sh
cd templates/default && ../../scripts/dev just test
```

(Do not run `templates/default/scripts/dev` itself from this repo — it would
try to enter the scaffold's own flake, whose `rust-env` input points at the
published repo.)

To try the template end to end without publishing:

```sh
git checkout-index -a --prefix=/tmp/rnt-export/   # clean export of the index
nix flake new -t path:/tmp/rnt-export /tmp/my-project
cd /tmp/my-project && git init -q && git add -A
nix flake check --override-input rust-env path:/tmp/rnt-export
```

[rust-overlay]: https://github.com/oxalica/rust-overlay
[crane]: https://github.com/ipetkov/crane
