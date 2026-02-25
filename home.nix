{ pkgs, ... }:

{
  home.stateVersion = "25.11";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
  };
}
