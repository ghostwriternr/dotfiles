{ pkgs, ... }:

{
  imports = [
    ./home/git.nix
    ./home/programs.nix
    ./home/secrets.nix
    ./home/shell.nix
  ];

  home.stateVersion = "25.11";

  # ── Packages (CLI tools managed by nix instead of brew) ─────────────────────
  home.packages = with pkgs; [
    bun
    coreutils
    difftastic
    fd
    just
    nerd-fonts.fira-code
    tree
    watch
  ];

  # ── Window manager configs (yabai + skhd installed via brew) ─────────────────
  home.file.".yabairc".source = ./config/yabairc;
  home.file.".skhdrc".source = ./config/skhdrc;
}
