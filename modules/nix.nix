{ lib, ... }: {

  nix.settings = {
    experimental-features = "nix-command flakes";
    warn-dirty = false;
    trusted-users = [ "root" "@admin" "naresh" ];
  };

  # Allow specific packages with non-free licenses (e.g. HashiCorp BSL).
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vault"
  ];

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
}
