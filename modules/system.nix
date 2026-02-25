{ pkgs, ... }: {

  # System-wide packages. Search with: nix search nixpkgs <name>
  environment.systemPackages = [
    pkgs.vim
  ];

  # Cloudflare WARP Zero Trust: add corporate CA so nix-daemon and other tools
  # trust the TLS-inspecting proxy. The cert lives outside the repo (extracted
  # by bootstrap.sh), so --impure is needed when rebuilding.
  # See docs/warp-cert.md for details.
  security.pki.certificateFiles = [ /Users/naresh/.config/cloudflare/zero_trust_cert.pem ];

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = "naresh";
  users.users.naresh.home = "/Users/naresh";
}
