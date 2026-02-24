# dotfiles

Declarative macOS system configuration using [nix-darwin](https://github.com/nix-darwin/nix-darwin) + [home-manager](https://github.com/nix-community/home-manager), managed as a Nix flake.

Running on Apple Silicon (aarch64-darwin) with [Lix](https://lix.systems/) as the Nix implementation.

## Usage

Rebuild after changes:

```sh
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

Flakes only see git-tracked files — stage or commit new files before rebuilding.

Update flake inputs:

```sh
nix flake update --flake ~/.config/nix-darwin
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

Search for packages:

```sh
nix search nixpkgs <name>
```

## Fresh machine setup

1. **Install Lix** — https://lix.systems/install/
2. **Clone** — `git clone git@github.com:ghostwriternr/dotfiles.git ~/.config/nix-darwin`
3. **Bootstrap** (Cloudflare machines only) — `./bootstrap.sh` (see below)
4. **Build** — `sudo darwin-rebuild switch --flake ~/.config/nix-darwin`

## Design decisions

### Config location

Lives in `~/.config/nix-darwin` rather than `/etc/nix-darwin`. The `--flake` flag points here explicitly. This keeps user config out of system directories and makes it easier to manage with git.

### Cloudflare WARP / Zero Trust

Cloudflare's WARP Zero Trust proxy does TLS inspection, which breaks all Nix downloads unless the nix-daemon trusts the corporate CA. This is handled by `security.pki.certificateFiles` pointing to `~/.config/cloudflare/zero_trust_cert.pem` — nix-darwin concatenates these with the Mozilla CA bundle into `/etc/ssl/certs/ca-certificates.crt`.

The cert file lives **outside** this repo (not committed) to avoid publishing internal infrastructure artifacts. `bootstrap.sh` extracts it from the macOS System Keychain and saves it to the expected path.

**Chicken-and-egg problem:** The very first `darwin-rebuild` on a fresh machine needs to download from the internet, but `security.pki` hasn't taken effect yet. `bootstrap.sh` also temporarily patches `/etc/nix/nix.conf` with an `ssl-cert-file` entry to solve this. After the first successful build, `security.pki` takes over permanently.

To re-extract after cert rotation:

```sh
./bootstrap.sh  # or manually:
security find-certificate -a -c "Cloudflare" -p /Library/Keychains/System.keychain > ~/.config/cloudflare/zero_trust_cert.pem
```

### home-manager

Integrated as a nix-darwin module (not standalone). `useGlobalPkgs` and `useUserPackages` are enabled so home-manager shares the same nixpkgs instance as the system config. User-level config lives in `home.nix`; system-level config is in `flake.nix` (will be split into separate files as it grows).
