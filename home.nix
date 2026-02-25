{ config, lib, pkgs, ... }:

{
  home.stateVersion = "25.11";

  # ── Packages (CLI tools managed by nix instead of brew) ─────────────────────
  home.packages = with pkgs; [
    bun
    coreutils
    difftastic
    fd
    just
    nerd-fonts.fira-code
    tree
    watch
  ];

  # ── Window manager configs (yabai + skhd installed via brew) ─────────────────
  home.file.".yabairc".source = ./config/yabairc;
  home.file.".skhdrc".source = ./config/skhdrc;

  # ── Secrets (sops-nix) ─────────────────────────────────────────────────────
  sops = {
    defaultSopsFile = ./secrets/default.yaml;
    age.sshKeyPaths = [ "/Users/naresh/.ssh/cloudflare/id_ed25519" ];

    secrets = {
      exa_api_key = {};
    };
  };

  # ── Shell (zsh) ─────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;

    shellAliases = {
      vim = "nvim";
      zsh-refresh = "rm -f ~/.zcompdump* && exec zsh";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";

      # Colima / Docker
      DOCKER_BUILDKIT = "1";
      DOCKER_HOST = "unix://\${HOME}/.colima/default/docker.sock";
      WRANGLER_DOCKER_HOST = "unix://\${HOME}/.colima/default/docker.sock";
    };

    # WARP cert env vars (SSL_CERT_FILE, NODE_EXTRA_CA_CERTS, REQUESTS_CA_BUNDLE,
    # CARGO_HTTP_CAINFO). Managed by cloudflare-certs brew formula.
    envExtra = ''
      . /Users/naresh/.local/share/cloudflare-warp-certs/config.sh
    '';

    # Homebrew shellenv (PATH, HOMEBREW_PREFIX, etc.)
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';

    initContent = lib.mkAfter ''
      # Recompile zshrc if edited
      [[ ~/.zshrc -nt ~/.zshrc.zwc ]] && zcompile ~/.zshrc

      # ── Secrets ───────────────────────────────────────────────────────────
      if [ -f "${config.sops.secrets.exa_api_key.path}" ]; then
        export EXA_API_KEY=$(cat "${config.sops.secrets.exa_api_key.path}")
      fi

      # ── ASDF ──────────────────────────────────────────────────────────────
      export PATH="''${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
      fpath=(''${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

      # ── Bun ───────────────────────────────────────────────────────────────
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"

      # ── Cloudflare ────────────────────────────────────────────────────────
      [ -f /Users/naresh/.config/cloudflare/vault-funcs ] && source /Users/naresh/.config/cloudflare/vault-funcs

      # Cloudflare private NPM registry authentication
      cf-npm-auth() {
        echo "Authenticating with Cloudflare private NPM registry..."
        local token
        token=$(cloudflared access login --no-verbose https://registry.cloudflare-ui.com 2>/dev/null)
        if [[ -z "$token" ]]; then
          echo "Failed to get token. Make sure cloudflared is installed and you're on VPN/WARP."
          return 1
        fi
        export NPM_TOKEN="$token"
        echo "NPM_TOKEN set. Valid for ~1 week."
        echo "You can now run pnpm/npm/yarn commands that need @cloudflare packages."
      }

      cf-npm-check() {
        if [[ -z "$NPM_TOKEN" ]]; then
          echo "NPM_TOKEN is not set. Run: cf-npm-auth"
          return 1
        fi
        local payload exp now
        payload=$(echo "$NPM_TOKEN" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null)
        exp=$(echo "$payload" | grep -o '"exp":[0-9]*' | cut -d: -f2)
        now=$(date +%s)
        if [[ -n "$exp" && "$exp" -gt "$now" ]]; then
          local remaining=$(( (exp - now) / 86400 ))
          echo "NPM_TOKEN is valid. Expires in ~''${remaining} days."
          return 0
        else
          echo "NPM_TOKEN is expired or invalid. Run: cf-npm-auth"
          return 1
        fi
      }

      # ── Chayos (Linear → Dashboard sync) ─────────────────────────────────
      CHAYOS_URL="https://chayos.ghostwriternr.workers.dev"
      CHAYOS_DASHBOARD="https://agents-dashboard.katjareznikova.workers.dev"

      chayos-auth() {
        local token
        token=$(cloudflared access token --app "$CHAYOS_DASHBOARD" 2>/dev/null)
        if [[ -z "$token" ]]; then
          echo "Session expired. Opening browser for SSO login..."
          cloudflared access login "$CHAYOS_DASHBOARD" 2>/dev/null
          token=$(cloudflared access token --app "$CHAYOS_DASHBOARD" 2>/dev/null)
          if [[ -z "$token" ]]; then
            echo "✗ Failed to get token. Make sure cloudflared is installed and WARP is on."
            return 1
          fi
        fi
        local result
        result=$(curl -s -X POST "$CHAYOS_URL/auth" -d "$token")
        if echo "$result" | grep -q '"ok":true'; then
          local hours=$(echo "$result" | grep -o '"remainingHours":[0-9.]*' | cut -d: -f2)
          echo "✓ Token stored. Expires in ''${hours}h."
        else
          local err=$(echo "$result" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
          echo "✗ Failed: $err"
          return 1
        fi
      }

      chayos-status() {
        curl -s "$CHAYOS_URL/status" | python3 -m json.tool
      }

      chayos-sync() {
        curl -s -X POST "$CHAYOS_URL/sync" | python3 -m json.tool
      }

      # ── Docker helpers ────────────────────────────────────────────────────
      docker-tail-all() {
        local -A TAILING_PIDS
        trap 'for pid in ''${TAILING_PIDS[@]}; do kill $pid 2>/dev/null; done; return' INT TERM EXIT

        while true; do
          for container in $(docker ps -q 2>/dev/null); do
            if [[ ! -v TAILING_PIDS[$container] ]]; then
              docker logs -f --since 1s "$container" 2>&1 | sed "s/^/[$container] /" &
              TAILING_PIDS[$container]=$!
            fi
          done
          for container in ''${(k)TAILING_PIDS}; do
            if ! docker ps -q 2>/dev/null | grep -q "^''${container}$"; then
              kill ''${TAILING_PIDS[$container]} 2>/dev/null
              unset "TAILING_PIDS[$container]"
            fi
          done
          sleep 2
        done
      }

      # WARP-friendly Docker base images for local builds
      fix-warp-docker() {
        local CONFIG_DIR="$HOME/.config/cloudflare"
        local CERT_FILE="$CONFIG_DIR/zero_trust_cert.pem"

        if [ ! -f "$CERT_FILE" ]; then
          echo "Exporting Cloudflare certs from Keychain..."
          mkdir -p "$CONFIG_DIR"
          security find-certificate -a -c "Cloudflare" -p /Library/Keychains/System.keychain > "$CERT_FILE"
        fi

        echo "Building WARP-friendly Ubuntu image for amd64..."
        docker build --platform linux/amd64 \
          -f "$CONFIG_DIR/Dockerfile.warp-ubuntu" \
          -t warp-ubuntu:22.04-amd64 \
          "$CONFIG_DIR"
        docker tag warp-ubuntu:22.04-amd64 ubuntu:22.04

        echo "Building WARP-friendly Alpine image for amd64..."
        docker build --platform linux/amd64 \
          -f "$CONFIG_DIR/Dockerfile.warp-alpine" \
          -t warp-alpine:3.21-amd64 \
          "$CONFIG_DIR"
        docker tag warp-alpine:3.21-amd64 alpine:3.21

        echo "Done! Docker builds should now work with WARP enabled."
        echo "Tagged: ubuntu:22.04, alpine:3.21"
      }
    '';
  };

  # ── PATH additions ──────────────────────────────────────────────────────────
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.codeium/windsurf/bin"
  ];

  # ── Direnv ──────────────────────────────────────────────────────────────────
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
  };

  # ── Git ─────────────────────────────────────────────────────────────────────
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
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
}
