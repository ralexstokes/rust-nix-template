# Library half of this flake: bind the pinned inputs and expose the
# constructors. Consumers reach this as `rust-env.lib.mkRustProject`.
inputs: {
  mkRustProject = import ./mk-rust-project.nix inputs;
}
