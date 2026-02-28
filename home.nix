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
    bazelisk
    asdf-vm
    biome
    bun
    coreutils
    difftastic
    fd
    gawk
    gnupg
    glab
    just
    nerd-fonts.fira-code
    nginx
    openjdk
    ripgrep
    tree
    tenv
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

  # ── Window manager configs (yabai + skhd installed via brew) ─────────────────
  home.file.".yabairc".source = ./config/yabairc;
  home.file.".skhdrc".source = ./config/skhdrc;
}
