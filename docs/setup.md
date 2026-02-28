# Setting up a new machine

This guide covers the process of bootstrapping a fresh macOS install into a fully configured system. It's written for a Cloudflare work MacBook on Apple Silicon.

## Prerequisites

Ensure these items are in place before you start.

*   The machine must be enrolled in Cloudflare Zero Trust (WARP).
*   An SSH key must exist at `~/.ssh/cloudflare/id_ed25519`. This key is used for git authentication and sops-nix age encryption.
*   Install the macOS command-line tools by running `xcode-select --install`.

## Install Lix

This setup uses Lix, which is a fork of the Nix package manager.

1.  Follow the installation instructions at https://lix.systems/install/.
2.  Verify the installation by running `nix --version`.

## Clone and bootstrap

The bootstrap script handles the chicken-and-egg problem of downloading Nix packages through the Cloudflare WARP proxy.

```bash
git clone git@github.com:ghostwriternr/dotfiles.git ~/.config/nix-darwin
cd ~/.config/nix-darwin
chmod +x bootstrap.sh && ./bootstrap.sh
```

The `bootstrap.sh` script performs these actions:
*   Extracts Cloudflare WARP CA certs from the macOS System Keychain.
*   Creates a combined CA bundle containing both Mozilla and WARP certs.
*   Temporarily patches the nix-daemon to allow downloads through WARP.

Read `docs/warp-cert.md` for a full explanation of this mechanism.

## First rebuild

Run the initial system configuration.

```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin --impure
```

The first run typically takes 5 to 10 minutes. It installs all Homebrew packages and sets up home-manager. You must use the `--impure` flag permanently because the WARP certificate lives outside the flake tree. Subsequent rebuilds usually finish in 30 to 60 seconds.

## Post-install verification

Check these items to confirm the setup succeeded.

*   **Shell**: Open a new terminal window. You should see the starship prompt and your aliases should work.
*   **Git**: Run `git config user.email`. It should return `naresh@cloudflare.com`.
*   **SSH**: Run `ssh -G github.com`. The output should show the Cloudflare-specific configuration.
*   **Window manager**: Confirm that yabai and skhd are running. You will need to grant accessibility permissions (see troubleshooting below).
*   **Secrets**: Check `~/.config/sops-nix/secrets/`. You should see decrypted secret files.
*   **Ghostty**: The terminal should use the Flexoki theme with a 14pt font.

## Troubleshooting

**Nix can't download anything**
The WARP certificate isn't configured correctly. Re-run the `bootstrap.sh` script.

**Error: file not found during rebuild**
Nix flakes only see files tracked by git. Run `git add` on any new files you've created.

**Sops secrets not decrypted**
Verify that your SSH key exists at `~/.ssh/cloudflare/id_ed25519`. You may need to log out and back in to trigger the LaunchAgent.

**Yabai or skhd not working**
After a nix rebuild, the binary paths in `/nix/store` change and macOS Accessibility permissions need re-granting. Run `wm-fix-perms` (or `wm-fix-perms skhd`) to copy the current binary path to your clipboard and open the Accessibility settings pane. Click `+`, press `Cmd+Shift+G`, paste, and confirm. The entry may not appear in the UI list, but permissions will work.

**Brew package not found**
You might need to add the required tap in `modules/homebrew.nix` before the package can be installed.
