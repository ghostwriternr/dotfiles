{ lib, ... }: {

  nix.settings = {
    experimental-features = "nix-command flakes";
    warn-dirty = false;
    trusted-users = [ "root" "@admin" "naresh" ];

    # Numtide's binary cache for everything from `inputs.llm-agents`
    # (opencode, pi, skills CLI). Saves source-building Bun bundles,
    # Node deps, etc. on every bump. Public key from the upstream flake's
    # `nixConfig.extra-trusted-public-keys`.
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
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
