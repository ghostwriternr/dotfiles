# Architecture

## Overview
This system uses a flake-based nix-darwin and home-manager configuration to manage a macOS environment. Nix-darwin handles system-level settings like macOS defaults, nix daemon configuration, and homebrew integration. Home-manager manages the user-level environment, including shell configuration, git settings, CLI programs, and secrets. The codebase is split into two main directories: `modules/` for system-level configuration and `home/` for user-level configuration.

## Module graph
```
flake.nix
├── modules/nix.nix          # Nix daemon: flakes, gc, optimise
├── modules/homebrew.nix     # Brew: taps, formulae, casks
├── modules/system.nix       # Platform, user, WARP cert
├── modules/macos.nix        # macOS defaults
├── modules/wm.nix           # Window manager services (yabai + skhd)
├── modules/postgresql.nix   # Postgres server launchd service
└── home-manager
    └── home.nix             # User packages + imports every home/*.nix
```

`home/` contains one module per concern (`shell`, `git`, `programs`, `secrets`, `opencode`, `glab`, `theme`, `colima`). Any new home-manager module must be added to `home.nix`'s `imports` list; any new system module must be added to `flake.nix`'s `modules` list.

## Nix vs Brew
The choice between Nix and Homebrew depends on the type of tool and its integration requirements.

Nix is used for:
- CLI tools that don't require deep macOS integration (ripgrep, fd, bun, zig).
- Tools that have dedicated home-manager modules (fzf, zoxide, direnv, starship).
- Container tooling: colima, docker CLI, docker-buildx, docker-compose.
- Window management: yabai and skhd via nix-darwin `services.yabai` and `services.skhd`.

Brew is used for:
- GUI applications (casks) due to Gatekeeper, Spotlight indexing, and auto-update requirements.
- Cloudflare internal tools from the private `cloudflare/engineering` tap.
- `cloudflared`, because SSH ProxyCommand directives hardcode `/opt/homebrew/bin/cloudflared`.

Prefer Nix if home-manager provides a `programs.X` module or the tool is a CLI binary. Use Brew for GUI apps, private taps, and tools with hardcoded brew paths.

## Secrets management
Secrets are managed using sops-nix with age encryption. The age key is derived from the SSH key located at `~/.ssh/cloudflare/id_ed25519`. Encrypted values are stored in `secrets/default.yaml`, which is safe to commit to the repository. The `.sops.yaml` file maps the age public key to the secrets file pattern.

On macOS, sops-nix uses a LaunchAgent rather than systemd. This means secrets are decrypted to `~/.config/sops-nix/secrets/` at login. Because decryption happens at login rather than during the nix activation phase, activation scripts use a retry loop to wait for decrypted files to appear. Activation scripts then read these secrets and substitute placeholders in configuration templates.

Declared secrets live as `sops.secrets.<name>` entries in `home/*.nix` — grep for `sops.secrets` to see the live list rather than tracking it here.

To add a new secret:
1. Run `SOPS_AGE_KEY=$(nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/cloudflare/id_ed25519) nix run nixpkgs#sops -- --set '["secret_name"] "value"' secrets/default.yaml`.
2. Add `sops.secrets.secret_name = {};` in the relevant module.
3. Reference the secret via `config.sops.secrets.secret_name.path` in an activation script.

## Config file strategies
The system uses three distinct patterns for managing configuration files.

1. **Nix module**: Used for tools like Ghostty or SSH. Home-manager generates the configuration file as a read-only symlink pointing to the nix store. This is the preferred method for tools that don't need to write back to their own configuration.
2. **Template + activation script**: Used for `opencode.json` and GitLab's `config.yml`. A template file in `config/` contains placeholder tokens like `__SECRET__`. An activation script copies this template to the target location and substitutes secrets from sops. The resulting file is a real, mutable file rather than a symlink. This pattern is necessary for tools that write state back to their configuration and require secret injection.
3. **mkOutOfStoreSymlink**: Creates a symlink from the home directory to a file within the git repository. The target remains mutable, and any edits made by the user or external tools land directly in the git working tree. This is used for files that are frequently edited.

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

## OpenCode agents
Custom agents are defined as markdown files in `config/opencode/agents/` and symlinked to `~/.config/opencode/agents/` via `mkOutOfStoreSymlink` in `home/opencode.nix`. Each file combines a YAML frontmatter (model, permissions, mode) with a system prompt body.

The roster splits into **primary** agents (`build`, `deep`, `quick`, `large`) for top-level interaction and **subagents** (`oracle`, `review`, `research`, `librarian`) dispatched via the `task` tool. Image and PDF analysis is handled by the `look_at` plugin (`config/opencode/plugins/look-at.js`), not an agent. Built-in agents `plan`, `general`, and `explore` are disabled in `opencode.json` because the custom roster replaces them.

Model choices follow Amp's architecture: different model families for different cognitive styles (Claude for structured instruction-following, GPT for autonomous reasoning, Gemini for parallel tool use and analysis). Live model assignments live in each agent's YAML frontmatter — don't duplicate them here; they drift. Use the `auditing-agent-sources` skill to compare against upstream references (OpenCode, Amp, oh-my-openagent) when bumping.

Non-flake inputs are pinned in `flake.lock`. Update them using `nix flake update <input>`.

## The --impure flag
Using the `--impure` flag is required during system activation because `security.pki.certificateFiles` references an absolute path outside the flake tree. The WARP certificate at `~/.config/cloudflare/zero_trust_cert.pem` is machine-specific infrastructure rather than shared configuration. It cannot be committed to the repository as it is unique to each Cloudflare account. If you aren't using Cloudflare WARP, you can remove the certificateFiles line and the requirement for the `--impure` flag. See `docs/warp-cert.md` for more details.
