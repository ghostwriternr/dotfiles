{ config, inputs, lib, ... }:

let
  nixDarwinDir = "${config.home.homeDirectory}/.config/nix-darwin";
  opencodeConfigDir = "${nixDarwinDir}/config/opencode";
  opencodeNodeModules = "${config.home.homeDirectory}/.config/opencode/node_modules";
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

  xdg.configFile."opencode/skills/auditing-agent-sources".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/skills/auditing-agent-sources";

  xdg.configFile."opencode/skills/updating-opencode-agents".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/skills/updating-opencode-agents";

  # ── Custom agents (mutable — symlink to repo so edits land in git) ──────────

  xdg.configFile."opencode/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/agents";

  # ── Plugins ──────────────────────────────────────────────────────────────────
  #
  # NOTE: Plugins that `import from "@opencode-ai/plugin"` need node_modules
  # reachable from their real file path. mkOutOfStoreSymlink resolves to the
  # repo dir, which has no node_modules. The activation script below symlinks
  # OpenCode's node_modules into the repo config dir so Bun can resolve deps.

  xdg.configFile."opencode/plugins/superpowers.js" = {
    source = "${inputs.superpowers}/.opencode/plugins/superpowers.js";
    force = true;
  };

  xdg.configFile."opencode/plugins/look-at.js".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/plugins/look-at.js";

  xdg.configFile."opencode/plugins/interactive-bash.js".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/plugins/interactive-bash.js";

  # ── opencode.json (mutable — symlink to repo so edits land in git) ───────────

  xdg.configFile."opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/opencode.json";

  # ── Plugin dependency resolution ────────────────────────────────────────────
  #
  # Bun resolves imports from the plugin's real file path (the repo), not the
  # symlink location (~/.config/opencode/plugins/). This activation script
  # creates a node_modules symlink in the repo's config/opencode/ dir so that
  # `import from "@opencode-ai/plugin"` resolves correctly.

  home.activation.opencode-plugin-deps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${opencodeNodeModules}" ]; then
      ln -sfn "${opencodeNodeModules}" "${opencodeConfigDir}/node_modules"
    fi
  '';
}
