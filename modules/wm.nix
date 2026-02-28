# Window management services: yabai (tiling) + skhd (hotkeys).
# nix-darwin manages launchd plists and config file generation.
{ ... }:

{
  services.yabai = {
    enable = true;
    enableScriptingAddition = false;
    extraConfig = builtins.readFile ../config/yabairc;
  };

  services.skhd = {
    enable = true;
    skhdConfig = builtins.readFile ../config/skhdrc;
  };
}
