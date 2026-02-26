# Architecture

## Overview
This system uses a flake-based nix-darwin and home-manager configuration to manage a macOS environment. Nix-darwin handles system-level settings like macOS defaults, nix daemon configuration, and homebrew integration. Home-manager manages the user-level environment, including shell configuration, git settings, CLI programs, and secrets. The codebase is split into two main directories: `modules/` for system-level configuration and `home/` for user-level configuration.

## Module graph
```
flake.nix
├── modules/nix.nix           # Nix daemon: flakes, gc, optimise
├── modules/homebrew.nix      # Brew: taps, formulae, casks
├── modules/system.nix        # Platform, user, WARP cert
├── modules/macos.nix         # macOS defaults
└── home-manager
    └── home.nix
        ├── home/shell.nix    # Zsh config
        ├── home/git.nix      # Git config
        ├── home/programs.nix # CLI tools + their configs
        ├── home/secrets.nix  # sops-nix declarations
        ├── home/opencode.nix # AI tooling config
        └── home/glab.nix     # GitLab CLI config
```

## Nix vs Brew
The choice between Nix and Homebrew depends on the type of tool and its integration requirements.

Nix is used for:
- CLI tools that don't require deep macOS integration (ripgrep, fd, bun).
- Tools that have dedicated home-manager modules (fzf, zoxide, direnv, starship).

Brew is used for:
- GUI applications (casks).
- Tools tightly coupled to specific macOS versions (yabai, skhd-zig).
- Cloudflare internal tools (cfsetup, cf-paste).
- Tools where Homebrew provides better macOS integration (colima, docker).

Prefer Nix if home-manager provides a `programs.X` module. Use Brew for GUI apps or tools sensitive to macOS versioning.

## Secrets management
Secrets are managed using sops-nix with age encryption. The age key is derived from the SSH key located at `~/.ssh/cloudflare/id_ed25519`. Encrypted values are stored in `secrets/default.yaml`, which is safe to commit to the repository. The `.sops.yaml` file maps the age public key to the secrets file pattern.

On macOS, sops-nix uses a LaunchAgent rather than systemd. This means secrets are decrypted to `~/.config/sops-nix/secrets/` at login. Because decryption happens at login rather than during the nix activation phase, activation scripts use a retry loop to wait for decrypted files to appear. Activation scripts then read these secrets and substitute placeholders in configuration templates.

Currently managed secrets include `exa_api_key` for opencode MCP and `glab_cfdata_token` for the GitLab CLI.

To add a new secret:
1. Run `SOPS_AGE_KEY=$(nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/cloudflare/id_ed25519) nix run nixpkgs#sops -- --set '["secret_name"] "value"' secrets/default.yaml`.
2. Add `sops.secrets.secret_name = {};` in the relevant module.
3. Reference the secret via `config.sops.secrets.secret_name.path` in an activation script.

## Config file strategies
The system uses three distinct patterns for managing configuration files.

1. **Nix module**: Used for tools like Ghostty or SSH. Home-manager generates the configuration file as a read-only symlink pointing to the nix store. This is the preferred method for tools that don't need to write back to their own configuration.
2. **Template + activation script**: Used for `opencode.json` and GitLab's `config.yml`. A template file in `config/` contains placeholder tokens like `__SECRET__`. An activation script copies this template to the target location and substitutes secrets from sops. The resulting file is a real, mutable file rather than a symlink. This pattern is necessary for tools that write state back to their configuration and require secret injection.
3. **mkOutOfStoreSymlink**: Used for `oh-my-opencode.json` and `AGENTS.md`. This creates a symlink from the home directory to the file within the git repository. The target remains mutable, and any edits made by the user or external tools land directly in the git working tree. This is used for files that are frequently edited.

## External dependencies
Several components exist outside this repository and must be present for the system to function correctly.

- `~/.config/cloudflare/zero_trust_cert.pem`: The WARP CA certificate.
- `~/.ssh/cloudflare/id_ed25519`: The SSH key used for git and as the sops age key.
- `~/.config/cloudflare/vault-funcs`: Cloudflare vault helpers, sourced if present.
- `~/.local/share/cloudflare-warp-certs/`: Environment variables and git configuration for WARP certificates.
- `~/.config/nvim/`: Neovim configuration, managed in the `ghostwriternr/LazyVim` repository.
- `~/.colima/`: Configuration for the Colima Docker runtime.

## Flake inputs
- `nixpkgs`: The unstable package set.
- `nix-darwin`: Manages macOS system configuration.
- `home-manager`: Manages the user environment.
- `sops-nix`: Handles secrets management.
- `superpowers`: An opencode skill pack from `obra/superpowers`.
- `cloudflare-skills`: An opencode skill pack from `cloudflare/skills`.

Non-flake inputs are pinned in `flake.lock`. Update them using `nix flake update <input>`.

## The --impure flag
Using the `--impure` flag is required during system activation because `security.pki.certificateFiles` references an absolute path outside the flake tree. The WARP certificate at `~/.config/cloudflare/zero_trust_cert.pem` is machine-specific infrastructure rather than shared configuration. It cannot be committed to the repository as it is unique to each Cloudflare account. If you aren't using Cloudflare WARP, you can remove the certificateFiles line and the requirement for the `--impure` flag. See `docs/warp-cert.md` for more details.
