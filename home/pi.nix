{ config, ... }:

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
