{ config, lib, pkgs, ... }:

let
  configTemplate = ../config/glab-cli/config.yml;
  aliasesSource = ../config/glab-cli/aliases.yml;
in
{
  sops.secrets.glab_cfdata_token = {};

  # ── glab-cli config (generated — secret substitution from sops) ──────────────
  # glab writes state back to config.yml at runtime (e.g. last_update_check_timestamp),
  # so we can't use a read-only nix store symlink. Instead we copy the template and
  # inject the sops-encrypted token at activation time.

  home.activation.patchGlabConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
      config_dir="${config.xdg.configHome}/glab-cli"
      target="$config_dir/config.yml"
      secret="${config.sops.secrets.glab_cfdata_token.path}"

      mkdir -p "$config_dir"

      # sops-nix decrypts via LaunchAgent (async) — wait for new secrets to appear
      for _i in $(seq 1 20); do [ -f "$secret" ] && break; sleep 0.5; done

      if [ -f "$secret" ]; then
        ${lib.getExe' pkgs.gnused "sed"} \
          "s|__GLAB_CFDATA_TOKEN__|$(cat "$secret")|g" \
          "${configTemplate}" > "$target"
      else
        cp "${configTemplate}" "$target"
      fi
      chmod 600 "$target"

      # aliases — no secrets, just copy
      cp "${aliasesSource}" "$config_dir/aliases.yml"
      chmod 600 "$config_dir/aliases.yml"
    '';
}
