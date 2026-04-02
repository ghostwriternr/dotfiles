{ config, ... }:

let t = config.theme; p = t.palette; in
{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Naresh";
        email = "naresh@cloudflare.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;

      # Difftastic: structural diff (opt-in per command via aliases)
      alias = {
        ddiff = "-c diff.external=difft diff";
        dlog  = "-c diff.external=difft log --ext-diff";
        dshow = "-c diff.external=difft show --ext-diff";
      };

      # Delta pager
      core.pager = "delta";
      delta = {
        file-style = "bold";
        file-decoration-style = "none";
        line-numbers = true;
        side-by-side = true;
        dark = true;
      };
      "delta \"dark\"" = {
        syntax-theme = "theme-dark";
        hunk-header-decoration-style = "${p.accent.aqua} box ul";
        line-numbers-left-style = "${p.accent.aqua}";
        line-numbers-right-style = "${p.accent.aqua}";
        line-numbers-minus-style = "${p.accent.red}";
        line-numbers-plus-style = "${p.accent.green}";
        line-numbers-zero-style = "${p.dark.grey1}";
        minus-style = "syntax \"${t.diff.removeBg.dark}\"";
        minus-emph-style = "syntax bold \"${t.diff.removeBg.dark}\"";
        plus-style = "syntax \"${t.diff.addBg.dark}\"";
        plus-emph-style = "syntax bold \"${t.diff.addBg.dark}\"";
      };
      "delta \"light\"" = {
        syntax-theme = "theme-light";
        hunk-header-decoration-style = "${p.accentLight.aqua} box ul";
        line-numbers-left-style = "${p.accentLight.aqua}";
        line-numbers-right-style = "${p.accentLight.aqua}";
        line-numbers-minus-style = "${p.accentLight.red}";
        line-numbers-plus-style = "${p.accentLight.green}";
        line-numbers-zero-style = "${p.light.grey1}";
        minus-style = "syntax \"${t.diff.removeBg.light}\"";
        minus-emph-style = "syntax bold \"${t.diff.removeBg.light}\"";
        plus-style = "syntax \"${t.diff.addBg.light}\"";
        plus-emph-style = "syntax bold \"${t.diff.addBg.light}\"";
      };
      # Rewrite GitHub HTTPS to SSH (avoids corporate SSL inspection issues)
      url."git@github.com:".insteadOf = "https://github.com/";

      color = {
        diff = { meta = "yellow"; frag = "blue bold"; old = "red"; new = "green"; };
        status = { added = "green"; changed = "yellow"; untracked = "red"; };
        branch = { current = "green bold"; local = "yellow"; remote = "blue"; };
      };
    };

    # Corporate WARP cert for HTTPS clone through Zero Trust proxy.
    # Managed by cloudflare-certs brew formula — not in this repo.
    includes = [
      { path = "~/.local/share/cloudflare-warp-certs/gitconfig"; }
    ];

    # Global ignores (applied to all repos)
    ignores = [
      "**/.claude/settings.local.json"
    ];
  };
}
