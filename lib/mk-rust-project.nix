# Build complete flake outputs (devShells, checks, formatter) for a Rust
# workspace. `src` must contain Cargo.toml, Cargo.lock, and rust-toolchain.toml.
{
  nixpkgs,
  flake-utils,
  crane,
  rust-overlay,
}:
{
  # Root of the consuming project.
  src,
  # Labels the Nix derivations. Defaults to `[workspace.metadata] name`, then
  # `[package] name`, from Cargo.toml.
  projectName ? null,
  # pkgs: [ ... ] — additional packages for the devshell.
  extraShellPackages ? pkgs: [ ],
  # pkgs: [ ... ] — additional native build tools for every Crane derivation.
  # Use this for build.rs dependencies such as Zig, CMake, or pkg-config.
  extraBuildPackages ? pkgs: [ ],
  # Additional flake checks, merged over the defaults. Either a plain
  # function `pkgs: { ... }`, or a set pattern such as
  # `{ pkgs, craneLibNightly, commonArgs, cargoArtifactsNightly, ... }: { ... }`
  # — each named attribute is supplied from pkgs merged with the check
  # context (toolchains, crane instances, filtered source, prebuilt
  # dependency artifacts; see crane-checks.nix), the context winning on
  # collision. Custom cargo checks reuse the template's machinery instead of
  # rebuilding it, and destructuring pkgs directly also works.
  extraChecks ? pkgs: { },
  # Shell commands appended to the cargo-ci check (e.g. example smoke runs).
  extraCiCommands ? "",
  # path: type: bool — files to keep in the cargo build sandbox beyond the
  # defaults (Cargo sources and trybuild .stderr expectations). Anything else
  # a check reads — nextest config, Markdown pulled into doctests via
  # include_str! — must be kept here, or `nix flake check` silently runs
  # without it even though the working tree has it.
  extraSourceFilter ? path: type: false,
}:
let
  cargoToml = builtins.fromTOML (builtins.readFile (src + "/Cargo.toml"));
  name =
    if projectName != null then
      projectName
    else
      cargoToml.workspace.metadata.name or (cargoToml.package.name or "rust-project");
in
flake-utils.lib.eachDefaultSystem (
  system:
  let
    overlays = [ (import rust-overlay) ];
    pkgs = import nixpkgs {
      inherit system overlays;
    };
    toolchainConfig = builtins.fromTOML (builtins.readFile (src + "/rust-toolchain.toml"));
    stableChannel = toolchainConfig.toolchain.channel;
    rustHost = pkgs.stdenv.hostPlatform.rust.rustcTarget;
    rustToolchain = pkgs.rust-bin.fromRustupToolchainFile (src + "/rust-toolchain.toml");
    nightlyToolchain = pkgs.rust-bin.selectLatestNightlyWith (
      toolchain:
      toolchain.default.override {
        extensions = [
          "clippy"
          "rustfmt"
        ];
      }
    );
    rustupHome = pkgs.runCommandLocal "${name}-rustup-home" { } ''
      mkdir -p $out/toolchains $out/update-hashes
      ln -s ${rustToolchain} $out/toolchains/${stableChannel}-${rustHost}
      ln -s ${nightlyToolchain} $out/toolchains/nightly-${rustHost}
      printf 'version = "12"\n\n[overrides]\n' > $out/settings.toml
    '';
    cargoChecks = import ./crane-checks.nix {
      inherit
        pkgs
        crane
        rustToolchain
        nightlyToolchain
        src
        extraCiCommands
        extraBuildPackages
        extraSourceFilter
        ;
      projectName = name;
    };
    # A set-pattern extraChecks receives its named attrs from pkgs merged
    # with the check context (context wins), so pre-existing consumers that
    # destructure pkgs (`{ runCommandLocal, ... }: ...`) keep working next to
    # ones pulling crane internals. A plain lambda (functionArgs = { }) keeps
    # the original pkgs interface.
    checkContext =
      pkgs
      // {
        inherit pkgs rustToolchain nightlyToolchain;
      }
      // cargoChecks.context;
    extraCheckAttrs =
      let
        wanted = builtins.functionArgs extraChecks;
      in
      if wanted == { } then
        extraChecks pkgs
      else
        extraChecks (builtins.intersectAttrs wanted checkContext);
    # Every .nix file in the project, so consumers never maintain a list.
    nixSources = builtins.filter (p: pkgs.lib.hasSuffix ".nix" (toString p)) (
      pkgs.lib.filesystem.listFilesRecursive src
    );
  in
  {
    formatter = pkgs.nixfmt;

    checks = {
      nixfmt = pkgs.runCommandLocal "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
        ${pkgs.lib.concatMapStringsSep "\n" (f: "nixfmt --check ${f}") nixSources}
        touch $out
      '';
    }
    // cargoChecks.checks
    // extraCheckAttrs;

    devShells.default = pkgs.mkShell {
      RUSTUP_HOME = rustupHome;
      RUSTUP_TOOLCHAIN = stableChannel;
      packages =
        with pkgs;
        [
          rustup
          cargo-nextest
          git
          just
          nixfmt
          ripgrep
        ]
        ++ extraShellPackages pkgs;
    };
  }
)
