{
  description = "Naresh's darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
