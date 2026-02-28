{ pkgs, ... }:

{
  imports = [
    ./home/git.nix
    ./home/programs.nix
    ./home/secrets.nix
    ./home/shell.nix
    ./home/opencode.nix
    ./home/glab.nix
  ];

  home.stateVersion = "25.11";

  # ── Packages (CLI tools managed by nix instead of brew) ─────────────────────
  home.packages = with pkgs; [
    asdf-vm
    bazelisk
    biome
    bun
    coreutils
    difftastic
    docker-client
    docker-buildx
    docker-compose
    docker-credential-helpers
    fd
    gawk
    glab
    gnupg
    just
    nerd-fonts.fira-code
    nginx
    opencode
    openjdk
    ripgrep
    tenv
    tree
    util-linux
    uv
    vault
    watch
    websocat
    zig

    # rust
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt
  ];

}
