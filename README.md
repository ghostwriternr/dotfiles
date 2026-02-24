# dotfiles

nix-darwin + home-manager flake for macOS (Apple Silicon, Lix).

## Usage

```sh
# rebuild
sudo darwin-rebuild switch --flake ~/.config/nix-darwin --impure

# update inputs
nix flake update --flake ~/.config/nix-darwin

# search packages
nix search nixpkgs <name>
```

New files must be staged/committed before rebuilding (flakes only see git-tracked files).

## Setup

1. Install [Lix](https://lix.systems/install/)
2. `git clone git@github.com:ghostwriternr/dotfiles.git ~/.config/nix-darwin`
3. `./bootstrap.sh` — one-time WARP cert setup ([details](docs/warp-cert.md))
4. `sudo darwin-rebuild switch --flake ~/.config/nix-darwin --impure`

`--impure` is needed because the WARP cert lives outside the flake tree.
