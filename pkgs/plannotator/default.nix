# Plannotator — interactive plan/code annotation UI for AI coding agents.
#
# Ships as a precompiled Bun single-binary from GitHub releases. We also
# extract the matching @plannotator/opencode npm tarball to get the slash-
# command markdown files that OpenCode expects at ~/.config/opencode/commands/
# — OpenCode's plugin installer uses Arborist with ignoreScripts:true, so
# the npm package's postinstall (which would normally copy those files)
# never runs and we have to install them ourselves.
#
# Shape modelled on nixpkgs/pkgs/by-name/cl/claude-code-bin — the closest
# analogue (another Bun-compiled single-file CLI from GitHub releases).
#
# ── Bumping ──
# Run from the flake root:
#
#   nix-update -F --version <new> \
#     --use-github-releases \
#     darwinConfigurations.KVQ52GY6N9.pkgs.plannotator
#
#   nix-update -F --version skip -s commands \
#     darwinConfigurations.KVQ52GY6N9.pkgs.plannotator
#
#   sed -i '' "s|@plannotator/opencode@[0-9.]*|@plannotator/opencode@<new>|" \
#     config/opencode/opencode.json
#
# The first bumps the binary src + version. The second bumps the npm
# tarball hash (tracks the same version string on the parent derivation,
# so pass --version skip). The third is the plugin pin in opencode.json
# that lives outside nix's model.

{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  nix-update-script,
}:

let
  # The commands subpackage is a proper mkDerivation (not runCommand) so
  # `nix-update -F -s commands` can locate its version/src positions.
  # The version attribute is defined inline and must be kept equal to the
  # parent plannotator version; nix-update will bump both together when
  # invoked with --version on the parent and -s commands.
  mkCommands =
    version:
    stdenvNoCC.mkDerivation {
      pname = "plannotator-commands";
      inherit version;

      src = fetchurl {
        url = "https://registry.npmjs.org/@plannotator/opencode/-/opencode-${version}.tgz";
        hash = "sha256-uvSbsELCB5fk8XPwGWDGK2WwyzatU/i3d0ykFpMfOZo=";
      };

      # src is a tarball; let stdenv unpack it. sourceRoot is `package/`
      # (npm convention).
      sourceRoot = "package";

      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/commands
        cp commands/*.md $out/commands/
        # Sanity check: at least one command file must be present.
        test -f $out/commands/plannotator-annotate.md
        runHook postInstall
      '';

      meta = {
        description = "OpenCode slash-command files shipped by @plannotator/opencode";
        homepage = "https://www.npmjs.com/package/@plannotator/opencode";
        license = with lib.licenses; [
          mit
          asl20
        ];
        platforms = lib.platforms.all;
      };
    };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "plannotator";
  version = "0.19.1";

  # `name = "plannotator"` so installBin produces $out/bin/plannotator
  # rather than $out/bin/plannotator-darwin-arm64.
  src = fetchurl {
    url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/plannotator-darwin-arm64";
    hash = "sha256-H2ebrkAC9pQ9gGT4k5KMcikhtme+BdLsTilrP2v8TZ8=";
    name = "plannotator";
  };

  nativeBuildInputs = [ installShellFiles ];

  strictDeps = true;

  dontUnpack = true;
  dontBuild = true;
  # Bun embeds the JS bytecode after the Mach-O segments; stripping
  # corrupts the embedded bundle and the raw Bun runtime executes
  # instead of the compiled program. Same caveat as claude-code-bin.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    installBin $src
    runHook postInstall
  '';

  passthru = {
    # Commands derivation is exposed via passthru so:
    #   1. the home-manager module can consume it (pkgs.plannotator.commands)
    #   2. `nix-update -F -s commands .#plannotator` can bump its tarball
    #      hash independently (and its version, in sync with the parent).
    commands = mkCommands finalAttrs.version;

    # `nix-update-script` generates a thin wrapper around the `nix-update`
    # binary. Pass `-u` to nix-update to use it, or invoke nix-update
    # directly as shown in the header comment.
    updateScript = nix-update-script {
      extraArgs = [ "--use-github-releases" ];
    };
  };

  meta = {
    description = "Interactive plan and code review UI for AI coding agents";
    homepage = "https://plannotator.ai";
    license = with lib.licenses; [
      mit
      asl20
    ]; # dual-licensed MIT OR Apache-2.0
    platforms = [ "aarch64-darwin" ];
    mainProgram = "plannotator";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
