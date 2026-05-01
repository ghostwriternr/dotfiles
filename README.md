nix-darwin + home-manager flake for macOS (Apple Silicon, Lix). Cloudflare work machine.

## Quick start

1. Install Lix: https://lix.systems/install/
2. `git clone git@github.com:ghostwriternr/dotfiles.git ~/.config/nix-darwin`
3. `./bootstrap.sh` (see [docs/warp-cert.md](docs/warp-cert.md))
4. `sudo darwin-rebuild switch --flake ~/.config/nix-darwin --impure`

### Notes
- New or modified files must be `git add`ed before rebuilding. Flakes only see files tracked by git.
- The `--impure` flag is required because the WARP certificate resides outside the flake tree.

## What's managed

| Category | Tool | Managed by | Module |
| :--- | :--- | :--- | :--- |
| Shell | zsh (aliases, env, functions) | home-manager | home/shell.nix |
| Prompt | starship | home-manager | home/programs.nix |
| Editor | neovim (config in separate repo) | home-manager | home/programs.nix |
| Git | config, aliases, global ignores | home-manager | home/git.nix |
| Terminal | ghostty (Flexoki theme) | home-manager | home/programs.nix |
| SSH | config (Colima + Cloudflare) | home-manager | home/programs.nix |
| Window mgr | yabai + skhd | nix-darwin services | modules/wm.nix + config/ |
| AI tools | opencode, pi | home-manager | home/opencode.nix, home/pi.nix |
| GitLab CLI | glab (config + encrypted token) | home-manager | home/glab.nix |
| GitHub CLI | gh (config) | home-manager | home/programs.nix |
| Dev tools | fzf, zoxide, direnv, bat, ripgrep, fd, etc. | home-manager + nix | home/programs.nix, home.nix |
| Secrets | sops-nix (age encryption) | home-manager | home/secrets.nix |
| macOS | dock, keyboard, Finder, trackpad, screenshots, Touch ID sudo | nix-darwin | modules/macos.nix |
| Postgres | launchd service + client libs | nix-darwin | modules/postgresql.nix |
| Nix | gc, optimise, flakes-only, no channels | nix-darwin | modules/nix.nix |
| Theme | Flexoki palette shared across terminal, fzf, eza, bat | home-manager | home/theme.nix |
| Container runtime | Colima config (docker socket path) | home-manager | home/colima.nix |
| Packages | CLI tools, dev toolchains, fonts | nix-darwin + nix | modules/homebrew.nix, home.nix |

## Repo structure

```
~/.config/nix-darwin/
├── flake.nix       # Entry point — inputs and darwinConfiguration
├── flake.lock      # Pinned dependency versions
├── home.nix        # Home-manager root — imports home/*.nix + packages
├── bootstrap.sh    # One-time WARP cert setup for first build
├── AGENTS.md       # OpenCode instructions for working in this repo
│
├── modules/        # System-level (nix-darwin) configuration
├── home/           # User-level (home-manager) configuration
├── config/         # Raw config files (templates, keybindings, opencode, pi)
├── secrets/        # sops-encrypted secrets (age)
└── docs/           # setup.md, architecture.md, warp-cert.md
```

See `docs/architecture.md` for what each directory contains and how the pieces wire together.

## Common commands

```sh
# Rebuild after config changes (or use the alias: nix-rebuild)
sudo darwin-rebuild switch --flake ~/.config/nix-darwin --impure

# Update all flake inputs, rebuild, commit and push (alias: nix-update)
nix flake update --flake ~/.config/nix-darwin

# Update brew packages (alias: brew-update)
brew update && brew upgrade && brew cleanup

# Fix yabai/skhd accessibility permissions after nix updates
wm-fix-perms        # copies yabai path to clipboard, opens System Settings
wm-fix-perms skhd   # same for skhd

# Search for nix packages
nix search nixpkgs <name>

# Edit a sops secret
SOPS_AGE_KEY=$(nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/cloudflare/id_ed25519) \
  nix run nixpkgs#sops -- secrets/default.yaml
```

## See also

- [docs/setup.md](docs/setup.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/warp-cert.md](docs/warp-cert.md)
