{ ... }: {

  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "uninstall"; # remove formulae/casks not listed below
      autoUpdate = false;    # don't update brew during rebuild
      upgrade = false;       # don't upgrade packages during rebuild
    };

    taps = [
      "cloudflare/engineering"
      "FelixKratz/formulae"
    ];

    brews = [
      # cloudflare
      "cloudflare/engineering/cf-k8s-tools"
      "cloudflare/engineering/cf-paste"
      "cloudflare/engineering/cf-yubikey-agent"
      "cloudflare/engineering/cfsetup"
      "cloudflare/engineering/cloudflare-certs"
      "cloudflare/engineering/docker-credential-cloudflared"
      "cloudflared"

      # window management rice
      "FelixKratz/formulae/sketchybar"
      "FelixKratz/formulae/borders"
    ];

    casks = [
      # terminals / editors
      "ghostty"
      "cursor"
      "windsurf"
      "zed"

      # productivity
      "obsidian"
      "notion"
      "raycast"
      "todoist-app"
      "aqua-voice"
      "bartender"

      # communication
      "beeper"
      "discord"
      "slack"

      # window management (IT-managed, keep)
      "rectangle"

      # AI / ML
      "ollama-app"

      # media / utilities
      "betterdisplay"
      "brave-browser"
      "google-drive"
      "localsend"
      "logitune"
      "obs"
      "screen-studio"
      "spotify"
      "upscayl"
    ];
  };
}
