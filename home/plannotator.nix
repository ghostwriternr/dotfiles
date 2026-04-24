{ pkgs, ... }:

# Home-manager wiring for plannotator. The actual package lives in
# pkgs/plannotator/default.nix and is exposed on pkgs via the flake
# overlay. This module just installs the binary and the slash-command
# files that OpenCode needs (see comment in pkgs/plannotator/default.nix
# for why we install commands ourselves).

{
  home.packages = [ pkgs.plannotator ];

  # Install slash-command files to ~/.config/opencode/commands/ where
  # opencode discovers them. Source is a nix-store path, so these are
  # read-only store symlinks (not mkOutOfStoreSymlink) — they stay
  # pinned with the version and get replaced atomically on a bump.
  xdg.configFile."opencode/commands/plannotator-annotate.md".source =
    "${pkgs.plannotator.commands}/commands/plannotator-annotate.md";
  xdg.configFile."opencode/commands/plannotator-archive.md".source =
    "${pkgs.plannotator.commands}/commands/plannotator-archive.md";
  xdg.configFile."opencode/commands/plannotator-last.md".source =
    "${pkgs.plannotator.commands}/commands/plannotator-last.md";
  xdg.configFile."opencode/commands/plannotator-review.md".source =
    "${pkgs.plannotator.commands}/commands/plannotator-review.md";
}
