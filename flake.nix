{
  description = "Naresh's darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Opencode skill packs (non-flake, pinned in flake.lock)
    superpowers.url = "github:obra/superpowers";
    superpowers.flake = false;
    cloudflare-skills.url = "github:cloudflare/skills";
    cloudflare-skills.flake = false;

    # Pi extension: subagent delegation (non-flake, pinned in flake.lock).
    # Builtin agents (scout/worker/planner/oracle/reviewer) are wired up
    # in home/pi.nix; per-agent model overrides live in config/pi/settings.json.
    pi-subagents.url = "github:nicobailon/pi-subagents";
    pi-subagents.flake = false;

    # Pi extension: cross-session coordination companion to pi-subagents.
    # Lets child agents `intercom.ask` the parent for clarification mid-run
    # rather than guessing or stalling. Pi-subagents auto-detects the bridge
    # when both extensions are loaded.
    pi-intercom.url = "github:nicobailon/pi-intercom";
    pi-intercom.flake = false;

    # Numtide's daily-updated catalogue of AI coding agents. Sources
    # opencode, pi, and the skills CLI; the same input can later expose
    # claude-code, codex, crush, gemini-cli, etc. with one line each.
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, sops-nix, ... }: {
    darwinConfigurations."KVQ52GY6N9" = nix-darwin.lib.darwinSystem {
      modules = [
        ./modules/nix.nix
        ./modules/homebrew.nix
        ./modules/system.nix
        ./modules/postgresql.nix
        ./modules/macos.nix
        ./modules/wm.nix
        home-manager.darwinModules.home-manager
        {
          # These need flake-level bindings, so they stay inline.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Local overlay for two narrow concerns:
          #   - direnv: workaround for a darwin-specific test failure.
          #   - plannotator: locally packaged tool not in nixpkgs.
          nixpkgs.overlays = [
            (_final: prev: {
              # direnv 2.37.1 test-fish hangs/SIGKILLs on darwin in 25.11.
              # Upstream bug: NixOS/nixpkgs#507531 (bisected to libarchive
              # 3.8.4 -> 3.8.6, commit 32e655f). Skip the check phase on
              # darwin only until a fix is backported. Remove this override
              # once `nix-update` shows direnv building cleanly from cache.
              direnv = prev.direnv.overrideAttrs (old: {
                doCheck = !prev.stdenv.hostPlatform.isDarwin;
              });

              # plannotator is a local package definition — not in nixpkgs.
              # Packaged here so `nix-update -F .#plannotator` can target
              # it for version/hash bumps. See pkgs/plannotator/default.nix
              # and scripts/bump-plannotator.sh.
              plannotator = prev.callPackage ./pkgs/plannotator { };
            })
          ];

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.naresh = import ./home.nix;
        }
      ];
    };
  };
}
