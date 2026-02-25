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
      "hashicorp/tap"
      "int128/kubelogin"
      "jackielii/tap"
      "koekeishiya/formulae"
      "sst/tap"
      "zurawiki/brews"
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

      # dev tools (tools with nix home-manager modules moved to home.nix)
      "anomalyco/tap/opencode"
      "gawk"
      "gh"
      "glab"
      "gnupg"
      "util-linux"

      # containers (upstream recommends brew for macOS)
      "colima"
      "docker"
      "docker-buildx"
      "docker-compose"
      "docker-credential-helper"
      "lima-additional-guestagents"

      # languages / runtimes
      "asdf"
      "biome"
      "openjdk"
      "tenv"
      "zig"

      # infra
      "bazelisk"
      "hashicorp/tap/vault"
      "jackielii/tap/skhd-zig"
      "koekeishiya/formulae/yabai"

      # misc
      "nginx"
      "websocat"
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
