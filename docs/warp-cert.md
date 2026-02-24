# Cloudflare WARP / Zero Trust certificate handling

## The problem

Cloudflare's WARP Zero Trust proxy does TLS inspection on corporate machines. This breaks all Nix downloads because the nix-daemon doesn't trust the corporate CA by default.

## How it's solved

`flake.nix` uses `security.pki.certificateFiles` to point at the WARP CA cert:

```nix
security.pki.certificateFiles = [ /Users/naresh/.config/cloudflare/zero_trust_cert.pem ];
```

nix-darwin concatenates these with the Mozilla CA bundle into `/etc/ssl/certs/ca-certificates.crt` and sets `NIX_SSL_CERT_FILE` for the nix-daemon automatically.

The cert file lives **outside this repo** at `~/.config/cloudflare/zero_trust_cert.pem`. Zero Trust generates a unique root CA per account — these are internal infrastructure artifacts and shouldn't be committed.

## Bootstrap (chicken-and-egg)

The first `darwin-rebuild` on a fresh machine needs to download from the internet, but `security.pki` hasn't taken effect yet. `bootstrap.sh` solves this by:

1. Extracting Cloudflare certs from the macOS System Keychain
2. Saving them to `~/.config/cloudflare/zero_trust_cert.pem`
3. Building a combined CA bundle (Mozilla + WARP certs)
4. Temporarily pointing `NIX_SSL_CERT_FILE` in the nix-daemon's launchd plist to that bundle
5. Restarting the nix-daemon

After the first successful `darwin-rebuild`, `security.pki` takes over permanently and the temporary bundle can be deleted.

### Why the launchd plist?

The nix-daemon reads `NIX_SSL_CERT_FILE` from its launchd environment. Patching the plist is a runtime-only change — no managed files on disk are mutated. (The alternative — patching `/etc/nix/nix.conf` — is risky because nix-darwin manages that file as a symlink into `/nix/store`. Writing through the symlink corrupts the store silently.)

After the first successful `darwin-rebuild`, `security.pki` takes over the daemon's environment and the plist change is overwritten.

## Re-extracting after cert rotation

```sh
./bootstrap.sh

# or manually:
security find-certificate -a -c "Cloudflare" -p /Library/Keychains/System.keychain > ~/.config/cloudflare/zero_trust_cert.pem
```

## Current certs

As of Feb 2025, the bundle contains two valid certificates:

| Certificate | Expires |
|---|---|
| Cloudflare Inc JSS | 2029 |
| Cloudflare Corporate Zero Trust | 2033 |

One expired cert (Cloudflare for Teams ECC, expired Feb 2025) was removed from the bundle.
