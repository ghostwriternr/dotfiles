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
