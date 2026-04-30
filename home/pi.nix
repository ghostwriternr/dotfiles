{ config, ... }:

# Pi reads from ~/.pi/, NOT XDG ~/.config/pi/. Hence home.file rather than
# xdg.configFile. The mkOutOfStoreSymlink keeps edits live in git so /reload
# inside pi picks them up without a darwin-rebuild.

{
  home.file.".pi/agent/extensions/cloudflare-ai".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/nix-darwin/config/pi/extensions/cloudflare-ai";
}
