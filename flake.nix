{
  description = "Naresh's darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }: {
    darwinConfigurations."KVQ52GY6N9" = nix-darwin.lib.darwinSystem {
      modules = [
        ./modules/nix.nix
        ./modules/homebrew.nix
        ./modules/system.nix
        home-manager.darwinModules.home-manager
        {
          # These need flake-level bindings, so they stay inline.
          system.configurationRevision = self.rev or self.dirtyRev or null;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.naresh = import ./home.nix;
        }
      ];
    };
  };
}
