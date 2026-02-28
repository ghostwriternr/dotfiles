{ ... }: {

  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "uninstall"; # remove formulae/casks not listed below
      autoUpdate = false;    # don't update brew during rebuild
      upgrade = false;       # don't upgrade packages during rebuild
    };

    taps = [
      "anomalyco/tap"
      "cloudflare/engineering"
      "jackielii/tap"
      "koekeishiya/formulae"
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

      # dev tools
      "anomalyco/tap/opencode"

      # containers (upstream recommends brew for macOS)
      "colima"
      "docker"
      "docker-buildx"
      "docker-compose"
      "docker-credential-helper"
      "lima-additional-guestagents"

      # window management
      "jackielii/tap/skhd-zig"
      "koekeishiya/formulae/yabai"
    ];

    casks = [
      # terminals / editors
      "ghostty"
      "cursor"
      "windsurf"
      "zed"

      # productivity
      "obsidian"
      "raycast"
      "todoist-app"
      "aqua-voice"
      "bartender"

      # communication
      "beeper"
      "discord"
      "slack"

      # media / utilities
      "betterdisplay"
      "brave-browser"
      "google-drive"
      "localsend"
      "logitune"
      "obs"
      "rectangle"
      "screen-studio"
      "spotify"
      "upscayl"
    ];
  };
}
