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

      # Nix daemon settings.
      nix.settings = {
        experimental-features = "nix-command flakes";
        warn-dirty = false;
        trusted-users = [ "root" "@admin" "naresh" ];
      };

      # Weekly garbage collection: delete generations older than 30 days.
      nix.gc = {
        automatic = true;
        interval = [{ Weekday = 0; Hour = 3; Minute = 0; }];
        options = "--delete-older-than 30d";
      };

      # Weekly store optimisation: hardlink identical store paths to save disk.
      # Prefer this over auto-optimise-store, which is slow on APFS.
      nix.optimise = {
        automatic = true;
        interval = [{ Weekday = 0; Hour = 4; Minute = 0; }];
      };

      # No channels — flakes only.
      nix.channel.enable = false;

      # Declarative Homebrew management.
      homebrew = {
        enable = true;

        onActivation = {
          cleanup = "uninstall"; # remove formulae/casks not listed below
          autoUpdate = false;   # don't update brew during rebuild
          upgrade = false;      # don't upgrade packages during rebuild
        };

        taps = [
          "anomalyco/tap"
          "cloudflare/engineering"
          "hashicorp/tap"
          "int128/kubelogin"
          "jackielii/tap"
          "koekeishiya/formulae"
          "sst/tap"
          "zurawiki/brews"
        ];

        brews = [
          # cloudflare
          "cloudflare/engineering/cf-k8s-tools"
          "cloudflare/engineering/cf-paste"
          "cloudflare/engineering/cf-yubikey-agent"
          "cloudflare/engineering/cfsetup"
          "cloudflare/engineering/cloudflare-certs"
          "cloudflare/engineering/docker-credential-cloudflared"
          "cloudflared"

          # dev tools
          "anomalyco/tap/opencode"
          "coreutils"
          "difftastic"
          "fd"
          "fzf"
          "gawk"
          "gh"
          "glab"
          "gnupg"
          "just"
          "neovim"
          "starship"
          "tree"
          "util-linux"
          "watch"
          "zoxide"

          # containers
          "colima"
          "docker"
          "docker-buildx"
          "docker-compose"
          "docker-credential-helper"
          "lima-additional-guestagents"

          # languages / runtimes
          "asdf"
          "biome"
          "openjdk"
          "tenv"
          "zig"

          # infra
          "bazelisk"
          "hashicorp/tap/vault"
          "jackielii/tap/skhd-zig"
          "koekeishiya/formulae/yabai"

          # misc
          "nginx"
          "websocat"
        ];

        casks = [
          "betterdisplay"
          "ghostty"
          "localsend"
          "upscayl"
        ];
      };

      # Cloudflare WARP Zero Trust: add corporate CA so nix-daemon and other tools trust the TLS-inspecting proxy.
      # The cert lives outside the repo (extracted by bootstrap.sh), so --impure is needed when rebuilding.
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
