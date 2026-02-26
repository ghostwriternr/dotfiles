{ lib, ... }:

{
  # ── Direnv ──────────────────────────────────────────────────────────────────
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
  };

  # ── FZF ─────────────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Zoxide ──────────────────────────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Starship ────────────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      format = "$directory$git_branch$git_status$fill$cmd_duration$line_break$character";

      directory = {
        truncation_length = 4;
        style = "bold blue";
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = "bold red";
      };

      fill.symbol = " ";

      cmd_duration = {
        min_time = 2000;
        format = "[$duration](italic yellow)";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  # ── Neovim ──────────────────────────────────────────────────────────────────
  # Config managed separately at ~/.config/nvim (ghostwriternr/LazyVim)
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # ── Ghostty ────────────────────────────────────────────────────────────────
  # Installed via brew cask; nix manages config only.
  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      theme = "dark:Flexoki Dark,light:Flexoki Light";
      font-size = 14;
      keybind = "shift+enter=text:\\x1b\\r";
    };
  };

  # ── SSH ────────────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # all defaults match SSH's own; avoids redundant Host * block
    includes = [
      "~/.colima/ssh_config"
    ];
    matchBlocks."cloudflare" = {
      match = "all";
      extraOptions = {
        Include = "~/.ssh/cloudflare/config";
      };
    };
  };

  # ── GitHub CLI ────────────────────────────────────────────────────────────
  # Installed via brew; config managed here. programs.gh needs a package,
  # so we use xdg.configFile directly to avoid a stub wrapper.
  xdg.configFile."gh/config.yml".text = lib.generators.toYAML {} {
    version = 1;
    git_protocol = "https";
    editor = "";
    prompt = "enabled";
    prefer_editor_prompt = "disabled";
    pager = "";
    aliases = {
      co = "pr checkout";
    };
    http_unix_socket = "";
    browser = "";
  };
}
