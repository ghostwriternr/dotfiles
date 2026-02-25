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

      # dev tools
      "anomalyco/tap/opencode"
      "coreutils"
      "difftastic"
      "fd"
      "fzf"
      "gawk"
      "gh"
      "glab"
      "gnupg"
      "just"
      "neovim"
      "starship"
      "tree"
      "util-linux"
      "watch"
      "zoxide"

      # containers
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
      "betterdisplay"
      "ghostty"
      "localsend"
      "upscayl"
    ];
  };
}
