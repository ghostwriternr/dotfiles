{ ... }:

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
