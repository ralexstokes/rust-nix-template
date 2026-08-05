# Authoritative CI check definitions (run via `nix flake check` / `just ci-nix`).
# The `ci` recipe in the scaffold justfile mirrors these for fast local runs —
# keep the two in sync.
{
  pkgs,
  crane,
  rustToolchain,
  nightlyToolchain,
  projectName,
  src,
  extraCiCommands,
  extraSourceFilter,
}:
let
  craneLib = crane.mkLib pkgs;
  craneLibStable = craneLib.overrideToolchain rustToolchain;
  craneLibNightly = craneLib.overrideToolchain nightlyToolchain;
  cargoSrc = pkgs.lib.cleanSourceWith {
    src = pkgs.lib.cleanSource src;
    filter =
      path: type:
      type == "directory"
      || craneLib.filterCargoSources path type
      # trybuild UI-test expectations; harmless if the project has none.
      || pkgs.lib.hasSuffix ".stderr" (toString path)
      || extraSourceFilter path type;
  };
  commonArgs = {
    CARGO_PROFILE = "";
    pname = projectName;
    src = cargoSrc;
    strictDeps = true;
    version = "0.1.0";
  };
  dependencyArgs = commonArgs // {
    cargoCheckExtraArgs = "";
    cargoExtraArgs = "--locked --workspace --all-targets --all-features";
  };
  cargoArtifactsStable = craneLibStable.buildDepsOnly dependencyArgs;
  cargoArtifactsNightly = craneLibNightly.buildDepsOnly dependencyArgs;
in
{
  cargo-fmt = craneLibNightly.cargoFmt (
    commonArgs
    // {
      cargoExtraArgs = "--all";
    }
  );

  cargo-clippy = craneLibNightly.cargoClippy (
    commonArgs
    // {
      cargoArtifacts = cargoArtifactsNightly;
      cargoExtraArgs = "--locked";
      cargoClippyExtraArgs = "--workspace --all-targets --all-features -- -D warnings";
      doInstallCargoArtifacts = false;
    }
  );

  cargo-ci = craneLibStable.mkCargoDerivation (
    commonArgs
    // {
      cargoArtifacts = cargoArtifactsStable;
      nativeBuildInputs = [ pkgs.cargo-nextest ];
      buildPhaseCargoCommand = ''
        cargo build --locked --workspace --all-targets --all-features
        cargo nextest run --locked --workspace --all-features --lib --bins --tests --examples
        cargo test --locked --workspace --doc --all-features
        RUSTDOCFLAGS="-D warnings" cargo doc --locked --workspace --no-deps --all-features
      ''
      + extraCiCommands;
      doInstallCargoArtifacts = false;
    }
  );
}
