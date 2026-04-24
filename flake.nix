{
  description = "Naresh's darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Bleeding-edge nixpkgs, consumed only through the overlay in `outputs` for
    # fast-moving packages. Bump with `nix flake update nixpkgs-master`.
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
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
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nixpkgs-master, home-manager, sops-nix, ... }: {
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

          # Overlay for fast-moving packages worth tracking on the bleeding
          # edge. Everything not named here resolves against the cached
          # nixos-unstable channel.
          nixpkgs.overlays = [
            (_final: prev: {
              opencode = (import nixpkgs-master {
                inherit (prev.stdenv.hostPlatform) system;
                config.allowUnfree = true;
              }).opencode;

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
