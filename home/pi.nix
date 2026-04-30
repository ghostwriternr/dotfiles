{ config, lib, ... }:

# Pi reads from ~/.pi/, NOT XDG ~/.config/pi/. Hence home.file rather than
# xdg.configFile. mkOutOfStoreSymlink keeps edits live in git so /reload
# inside pi picks them up without a darwin-rebuild, and so pi can write
# back to settings.json (lastChangelogVersion bumps after updates,
# /settings slash command edits) — Pattern 3 from AGENTS.md, same dynamic
# as config/opencode/opencode.json.

let
  nixDarwinDir = "${config.home.homeDirectory}/.config/nix-darwin";
in
{
  # ── Cloudflare AI provider extension ────────────────────────────────────────
  #
  # Routes pi through the corp opencode-access worker for Claude/GPT/Gemini/
  # Workers AI. See config/pi/extensions/cloudflare-ai/README.md.

  home.file.".pi/agent/extensions/cloudflare-ai".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/pi/extensions/cloudflare-ai";

  # ── settings.json (mutable — pi writes lastChangelogVersion + /settings) ────

  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/pi/settings.json";

  # ── Themes (Everforest, auto-switching with macOS appearance) ───────────
  #
  # Strategy: settings.json sets `theme: "everforest"` (constant). The
  # active theme file `~/.pi/agent/themes/everforest.json` is *not*
  # nix-managed — it's a regular file that `sync-pi-theme` overwrites
  # with the appropriate variant on system theme change. Pi watches the
  # active theme file and hot-reloads, so no relaunch is needed.
  #
  # The two source variants below are symlinked into place per-file
  # (rather than symlinking the whole `themes/` dir) so the parent stays
  # a mutable real directory where `sync-pi-theme` can drop the active
  # `everforest.json` without fighting nix ownership. The variants are
  # also independently selectable as themes (`everforest-dark` /
  # `everforest-light`) if you ever want to pin one regardless of
  # macOS appearance.

  home.file.".pi/agent/themes/everforest-dark.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/pi/themes/everforest-dark.json";

  home.file.".pi/agent/themes/everforest-light.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/pi/themes/everforest-light.json";

  # ── Theme sync helper (invoked by theme-watcher + activation) ────────────
  #
  # Lives in ~/.local/bin/ so theme-watcher.swift can reference it via
  # "$HOME/.local/bin/sync-pi-theme" (launchd-spawned shells have a
  # minimal env; absolute path under $HOME is the most stable handle).

  home.file.".local/bin/sync-pi-theme" = {
    source = ../config/pi/bin/sync-pi-theme;
    executable = true;
  };

  # Bootstrap the active theme file on every rebuild so a fresh install
  # has the right variant in place before pi first launches. After the
  # first system theme toggle, theme-watcher takes over.
  home.activation.syncPiTheme =
    lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
      $DRY_RUN_CMD ${config.home.homeDirectory}/.local/bin/sync-pi-theme || true
    '';

  # ── Global AGENTS.md (mutable — machine-wide rules for every session) ───────
  #
  # Source is `config/agent-rules.md`, shared with opencode (see
  # `home/opencode.nix`). Content is tool-agnostic (commit-message rules, PR
  # rules, plan storage) — about the user's standards, not pi-specific
  # behaviour. Pi auto-loads `~/.pi/agent/AGENTS.md` regardless of the
  # symlink target's name.

  home.file.".pi/agent/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/agent-rules.md";
}
