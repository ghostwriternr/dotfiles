{ ... }:

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
}
