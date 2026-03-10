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
| AI tools | opencode, oh-my-openagent | home-manager | home/opencode.nix |
| GitLab CLI | glab (config + encrypted token) | home-manager | home/glab.nix |
| GitHub CLI | gh (config) | home-manager | home/programs.nix |
| Dev tools | fzf, zoxide, direnv, bat, ripgrep, fd, etc. | home-manager + nix | home/programs.nix, home.nix |
| Secrets | sops-nix (age encryption) | home-manager | home/secrets.nix |
| macOS | dock, keyboard, Finder, trackpad, screenshots, Touch ID sudo | nix-darwin | modules/macos.nix |
| Nix | gc, optimise, flakes-only, no channels | nix-darwin | modules/nix.nix |
| Packages | 8 brew formulae, 17 casks, 28 nix pkgs | nix-darwin + nix | modules/homebrew.nix, home.nix |

## Repo structure

```
~/.config/nix-darwin/
├── flake.nix              # Entry point — inputs and system config
├── flake.lock             # Pinned dependency versions
├── home.nix               # Home-manager root — imports, packages
├── bootstrap.sh           # One-time WARP cert setup for first build
│
├── modules/               # System-level (nix-darwin) configuration
│   ├── nix.nix            # Nix settings, gc, optimise
│   ├── homebrew.nix       # Taps, formulae, casks
│   ├── system.nix         # Platform, user, WARP cert path
│   └── macos.nix          # macOS defaults (dock, keyboard, Finder, etc.)
│   └── wm.nix             # Window manager services (yabai + skhd)
│
├── home/                  # User-level (home-manager) configuration
│   ├── shell.nix          # Zsh: aliases, env vars, functions, integrations
│   ├── git.nix            # Git: user, aliases, ignores, WARP cert include
│   ├── programs.nix       # Programs: direnv, fzf, zoxide, starship, neovim, ghostty, ssh, gh
│   ├── secrets.nix        # sops-nix: secret declarations and age key path
│   ├── opencode.nix       # Opencode: config, skills, plugins, secret injection
│   └── glab.nix           # GitLab CLI: config template, secret injection
│
├── config/                # Raw config files (templates, keybindings)
│   ├── opencode/          # opencode.json (template), oh-my-opencode.json, AGENTS.md, skills/
│   ├── glab-cli/          # config.yml (template), aliases.yml
│   ├── yabairc            # Yabai window manager rules and settings
│   └── skhdrc             # skhd hotkey bindings
│
├── secrets/
│   └── default.yaml       # sops-encrypted secrets (age)
│
└── docs/
    ├── setup.md           # New machine bootstrap guide
    ├── architecture.md    # How the system works
    └── warp-cert.md       # WARP certificate handling
```

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
