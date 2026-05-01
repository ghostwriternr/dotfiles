{ config, ... }:

let
  nixDarwinDir = "${config.home.homeDirectory}/.config/nix-darwin";
in
{
  # Zed is installed as a Homebrew cask in modules/homebrew.nix.
  # Keep the user-editable config mutable: edits made by Zed land in this repo.
  xdg.configFile."zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/zed/settings.json";

  xdg.configFile."zed/keymap.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/zed/keymap.json";
}
