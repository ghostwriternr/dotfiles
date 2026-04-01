{ config, lib, ... }:

{
  programs.zsh = {
    enable = true;

    shellAliases = {
      vim = "nvim";
      zsh-refresh = "rm -f ~/.zcompdump* && exec zsh";

      # Nix
      nix-rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin --impure";

      # Homebrew
      brew-update = "brew update && brew upgrade && brew cleanup";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";

      # Colima / Docker
      DOCKER_BUILDKIT = "1";
      DOCKER_HOST = "unix://\${HOME}/.colima/default/docker.sock";
      WRANGLER_DOCKER_HOST = "unix://\${HOME}/.colima/default/docker.sock";
    };

    # Runs for ALL zsh contexts (interactive, non-interactive, login, scripts).
    # This is critical: tools like opencode spawn /bin/zsh -c "command" which
    # is neither login nor interactive, so .zprofile and .zshrc are NOT read.
    envExtra = ''
      # Homebrew (PATH, HOMEBREW_PREFIX, HOMEBREW_CELLAR, etc.)
      eval "$(/opt/homebrew/bin/brew shellenv)"

      # ASDF version manager shims
      export PATH="''${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

      # Bun runtime
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"

      # WARP cert env vars (SSL_CERT_FILE, NODE_EXTRA_CA_CERTS, REQUESTS_CA_BUNDLE,
      # CARGO_HTTP_CAINFO). Managed by cloudflare-certs brew formula.
      . /Users/naresh/.local/share/cloudflare-warp-certs/config.sh
    '';

    # profileExtra intentionally left empty — brew shellenv moved to envExtra
    # so non-interactive shells (opencode, scripts) also get brew on PATH.

    initContent = lib.mkAfter ''
      # Recompile zshrc if the real file (resolving symlinks) is newer than the cache
      [[ $(realpath ~/.zshrc) -nt ~/.zshrc.zwc ]] && zcompile ~/.zshrc

      # ── Secrets ───────────────────────────────────────────────────────────
      if [ -f "${config.sops.secrets.exa_api_key.path}" ]; then
        export EXA_API_KEY=$(cat "${config.sops.secrets.exa_api_key.path}")
      fi

      # ── ASDF (completions only — PATH is in envExtra) ────────────────────
      fpath=(''${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

      # ── Nix helpers ──────────────────────────────────────────────────────
      # Smart update: checks binary cache before committing to source builds.
      # Updates non-nixpkgs inputs first (always fast), then nixpkgs with a
      # dry-run gate. If too many packages need building from source, lets you
      # revert the nixpkgs bump while keeping the other updates.
      nix-update() {
        local flake_dir="$HOME/.config/nix-darwin"
        local system_attr="$flake_dir#darwinConfigurations.KVQ52GY6N9.system"

        # 1. Update non-nixpkgs inputs (always fast — no source builds)
        echo ":: Updating non-nixpkgs inputs..."
        nix flake update home-manager nix-darwin sops-nix superpowers cloudflare-skills \
          --flake "$flake_dir" || return 1

        # Snapshot lock after safe updates, before touching nixpkgs
        local safe_lock
        safe_lock=$(<"$flake_dir/flake.lock")

        # 2. Update nixpkgs
        echo ":: Updating nixpkgs..."
        nix flake update nixpkgs --flake "$flake_dir" || return 1

        # 3. Dry-run: check what needs building from source
        echo ":: Checking binary cache coverage..."
        local dry_output
        dry_output=$(nix build --dry-run "$system_attr" --impure 2>&1)
        local dry_exit=$?

        if [[ $dry_exit -ne 0 ]] && ! echo "$dry_output" | grep -q 'will be built\|will be fetched'; then
          echo "⚠  Dry-run evaluation failed:"
          echo "$dry_output"
          read -q "choice?Proceed with rebuild anyway? [y/n] "
          echo
          [[ "$choice" != "y" ]] && return 1
        fi

        # .drv paths only appear under "will be built" — fetch paths don't end in .drv
        local build_lines
        build_lines=$(echo "$dry_output" | grep '\.drv$' | \
          sed 's|^[[:space:]]*/nix/store/[a-z0-9]*-||; s|\.drv$||')

        if [[ -n "$build_lines" ]]; then
          local count=$(echo "$build_lines" | wc -l | tr -d ' ')
          echo
          echo "⚠  $count package(s) will build from source:"
          echo "$build_lines" | sed 's/^/  - /'
          echo
          read -q "choice?Proceed with source builds? [y/n] "
          echo
          if [[ "$choice" != "y" ]]; then
            echo ":: Reverting nixpkgs (keeping other input updates)..."
            echo "$safe_lock" > "$flake_dir/flake.lock"
          fi
        else
          echo "✓ All packages cached"
        fi

        # 4. Rebuild
        echo ":: Rebuilding..."
        sudo darwin-rebuild switch --flake "$flake_dir" --impure || return 1

        # 5. Commit and push
        git -C "$flake_dir" add flake.lock
        git -C "$flake_dir" commit -m 'flake: update inputs'
        git -C "$flake_dir" push
      }

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

      # ── GitHub branch protection (cloudflare/sandbox-sdk) ────────────────
      gh-unprotect-main() {
        gh api repos/cloudflare/sandbox-sdk/rulesets/7268489 -X PUT \
          --input - <<< '{"enforcement":"disabled"}' > /dev/null \
          && echo "protect-main ruleset DISABLED — direct push to main allowed"
      }

      gh-protect-main() {
        gh api repos/cloudflare/sandbox-sdk/rulesets/7268489 -X PUT \
          --input - <<< '{"enforcement":"active"}' > /dev/null \
          && echo "protect-main ruleset ACTIVE — main branch protected"
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

      # ── Window manager helpers ──────────────────────────────────────────
      # macOS Accessibility permissions are tied to the exact binary path.
      # After nix updates, yabai/skhd get new /nix/store paths and need
      # re-granting. This copies the real binary path to clipboard for
      # easy pasting in System Settings > Accessibility file picker.
      wm-fix-perms() {
        local target="''${1:-yabai}"
        if [[ "$target" != "yabai" && "$target" != "skhd" ]]; then
          echo "Usage: wm-fix-perms [yabai|skhd]  (default: yabai)"
          return 1
        fi
        local bin_path
        bin_path=$(readlink -f "$(which "$target")")
        echo "$target: $bin_path"
        printf "%s" "$bin_path" | pbcopy
        echo "(copied to clipboard — paste with Cmd+Shift+G in the file picker)"
        open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
      }

      # Wrapper: intercept yabai's built-in service commands and redirect
      # to nix-darwin managed launchd services. yabai --start-service etc.
      # create a conflicting com.asmvik.yabai plist that ignores nix config.
      yabai() {
        case "$1" in
          --start-service|--restart-service|--install-service)
            echo "⚠  Blocked: 'yabai $1' conflicts with nix-darwin service."
            echo "   Running: wm-restart yabai"
            wm-restart yabai
            ;;
          --stop-service|--uninstall-service)
            echo "⚠  Blocked: 'yabai $1' conflicts with nix-darwin service."
            echo "   Use: launchctl kill SIGTERM gui/$(id -u)/org.nixos.yabai"
            ;;
          *)
            command yabai "$@"
            ;;
        esac
      }

      # Restart yabai/skhd via launchd (nix-darwin managed services).
      wm-restart() {
        local target="''${1:-yabai}"
        if [[ "$target" != "yabai" && "$target" != "skhd" ]]; then
          echo "Usage: wm-restart [yabai|skhd]  (default: yabai)"
          return 1
        fi
        launchctl kickstart -k "gui/$(id -u)/org.nixos.$target"
      }
    '';
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.codeium/windsurf/bin"
  ];
}
