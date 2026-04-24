{ config, lib, pkgs, ... }:

let
  version = "0.19.1";

  # ── Binary ────────────────────────────────────────────────────────────────
  # Precompiled Bun single-binary release. Self-contained Mach-O on darwin
  # (JS runtime + bytecode bundled into the executable), so no patching,
  # runtime deps, or wrapping are needed beyond installing the file with
  # the execute bit set. Shape modelled on nixpkgs' claude-code-bin.
  plannotator = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "plannotator";
    inherit version;

    # `name = "plannotator"` so installBin produces $out/bin/plannotator
    # rather than $out/bin/plannotator-darwin-arm64.
    src = pkgs.fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/plannotator-darwin-arm64";
      hash = "sha256-H2ebrkAC9pQ9gGT4k5KMcikhtme+BdLsTilrP2v8TZ8=";
      name = "plannotator";
    };

    nativeBuildInputs = [ pkgs.installShellFiles ];

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

    meta = {
      description = "Interactive plan and code review UI for AI coding agents";
      homepage = "https://plannotator.ai";
      license = with lib.licenses; [ mit asl20 ]; # dual-licensed MIT OR Apache-2.0
      platforms = [ "aarch64-darwin" ];
      mainProgram = "plannotator";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  });

  # ── Slash command files ───────────────────────────────────────────────────
  # OpenCode's plugin installer uses Arborist with `ignoreScripts: true`
  # (see packages/opencode/src/npm/index.ts:150), so the plugin's own
  # postinstall — which copies commands/*.md into ~/.config/opencode/commands/
  # — never runs under opencode. We fetch the tarball ourselves and extract
  # just the command files. Pinned to the same version as the binary so
  # the two never drift.
  commandsTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@plannotator/opencode/-/opencode-${version}.tgz";
    hash = "sha256-uvSbsELCB5fk8XPwGWDGK2WwyzatU/i3d0ykFpMfOZo=";
  };

  plannotatorCommands = pkgs.runCommand "plannotator-commands-${version}" { } ''
    mkdir -p $out/commands
    tar -xzf ${commandsTarball} -C $out --strip-components=1 package/commands
    # Sanity check: at least one command file must be present.
    test -f $out/commands/plannotator-annotate.md
  '';
in
{
  # ── Binary ──────────────────────────────────────────────────────────────────
  home.packages = [ plannotator ];

  # ── Slash command files ─────────────────────────────────────────────────────
  # Install to ~/.config/opencode/commands/ where opencode discovers them.
  # Source is the nix-store path, so these are read-only store symlinks
  # (not mkOutOfStoreSymlink) — they stay pinned with the version and get
  # replaced atomically on a version bump.
  xdg.configFile."opencode/commands/plannotator-annotate.md".source =
    "${plannotatorCommands}/commands/plannotator-annotate.md";
  xdg.configFile."opencode/commands/plannotator-archive.md".source =
    "${plannotatorCommands}/commands/plannotator-archive.md";
  xdg.configFile."opencode/commands/plannotator-last.md".source =
    "${plannotatorCommands}/commands/plannotator-last.md";
  xdg.configFile."opencode/commands/plannotator-review.md".source =
    "${plannotatorCommands}/commands/plannotator-review.md";
}
