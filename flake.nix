{
  description = "Naresh's darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    configuration = { pkgs, ... }: {
      # System-wide packages. Search with: nix search nixpkgs <name>
      environment.systemPackages =
        [ pkgs.vim
        ];

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Cloudflare WARP Zero Trust: add corporate CA so nix-daemon and other tools trust the TLS-inspecting proxy.
      # The cert lives outside the repo (extracted by bootstrap.sh) to avoid committing internal infrastructure artifacts.
      security.pki.certificateFiles = [ /Users/naresh/.config/cloudflare/zero_trust_cert.pem ];

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # The user that owns the system.
      system.primaryUser = "naresh";

      # Define the user so home-manager can derive home.username and home.homeDirectory.
      users.users.naresh.home = "/Users/naresh";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#KVQ52GY6N9
    darwinConfigurations."KVQ52GY6N9" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.naresh = import ./home.nix;
        }
      ];
    };
  };
}
