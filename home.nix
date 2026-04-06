{ pkgs, ... }:

{
  imports = [
    ./home/theme.nix
    ./home/git.nix
    ./home/programs.nix
    ./home/secrets.nix
    ./home/shell.nix
    ./home/opencode.nix
    ./home/glab.nix
    ./home/colima.nix
  ];

  home.stateVersion = "25.11";

  # ── Packages (CLI tools managed by nix instead of brew) ─────────────────────
  home.packages = with pkgs; [
    asdf-vm
    bazelisk
    biome
    btop
    bun
    coreutils
    colima
    lima-additional-guestagents
    delta
    difftastic
    docker-client
    docker-buildx
    docker-compose
    docker-credential-helpers
    fastfetch
    fd
    git-filter-repo
    gawk
    glab
    gnupg
    jq
    just
    nerd-fonts.fira-code
    nginx
    opencode
    openjdk
    ripgrep
    tenv
    tmux
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
