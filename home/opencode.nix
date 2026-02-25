{ config, lib, pkgs, inputs, ... }:

let
  nixDarwinDir = "${config.home.homeDirectory}/.config/nix-darwin";

  # opencode.json template — contains __EXA_API_KEY__ placeholder.
  # The activation script below substitutes it with the real sops secret.
  opencodeConfigTemplate = ../config/opencode/opencode.json;
in
{
  # ── Config files (mutable — symlink to repo so edits land in git) ────────────

  xdg.configFile."opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/AGENTS.md";

  xdg.configFile."opencode/oh-my-opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/oh-my-opencode.json";

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

  xdg.configFile."opencode/skills/omo-model-audit".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/skills/omo-model-audit";

  # ── Plugins ──────────────────────────────────────────────────────────────────

  xdg.configFile."opencode/plugins/superpowers.js" = {
    source = "${inputs.superpowers}/.opencode/plugins/superpowers.js";
    force = true;
  };

  # ── opencode.json (generated — secret substitution from sops) ────────────────
  # Copies the template, replaces __EXA_API_KEY__ with the real key from sops-nix.
  # Falls back to the unpatched template on first rebuild before sops has
  # decrypted secrets.

  home.activation.patchOpencodeConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
      config_dir="${config.xdg.configHome}/opencode"
      target="$config_dir/opencode.json"
      secret="${config.sops.secrets.exa_api_key.path}"

      mkdir -p "$config_dir"

      if [ -f "$secret" ]; then
        ${lib.getExe' pkgs.gnused "sed"} \
          "s|__EXA_API_KEY__|$(cat "$secret")|g" \
          "${opencodeConfigTemplate}" > "$target"
      else
        cp "${opencodeConfigTemplate}" "$target"
      fi
      chmod 600 "$target"
    '';
}
