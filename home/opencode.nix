{ config, inputs, ... }:

let
  nixDarwinDir = "${config.home.homeDirectory}/.config/nix-darwin";
in
{
  # ── Skills — upstream repos (read-only, pinned via flake.lock) ───────────────

  xdg.configFile."opencode/skills/superpowers" = {
    source = "${inputs.superpowers}/skills";
    force = true; # upstream repo — always overwrite stale manual clones
  };

  xdg.configFile."opencode/skills/cloudflare" = {
    source = inputs.cloudflare-skills;
    force = true;
  };

  # ── Skills — user-authored (mutable — symlink to repo) ──────────────────────

  xdg.configFile."opencode/skills/amp-audit".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/skills/amp-audit";

  # ── Custom agents (mutable — symlink to repo so edits land in git) ──────────

  xdg.configFile."opencode/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/agents";

  # ── Plugins ──────────────────────────────────────────────────────────────────

  xdg.configFile."opencode/plugins/superpowers.js" = {
    source = "${inputs.superpowers}/.opencode/plugins/superpowers.js";
    force = true;
  };

  # ── opencode.json (mutable — symlink to repo so edits land in git) ───────────

  xdg.configFile."opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/opencode.json";
}
