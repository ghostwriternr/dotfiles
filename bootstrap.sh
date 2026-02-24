#!/usr/bin/env bash
# bootstrap.sh — One-time setup for nix-darwin on a Cloudflare WARP machine.
#
# This script does two things:
#   1. Extracts the WARP CA cert from the macOS keychain and saves it to
#      ~/.config/cloudflare/zero_trust_cert.pem (where flake.nix expects it).
#   2. Temporarily patches the nix-daemon's launchd plist so it trusts the
#      WARP CA during the first darwin-rebuild. After that, security.pki takes over.
#
# Usage:
#   chmod +x bootstrap.sh
#   ./bootstrap.sh
#   sudo darwin-rebuild switch --flake ~/.config/nix-darwin

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }

# --- Pre-flight checks ---

if ! command -v nix &>/dev/null; then
  error "Nix is not installed. Install Lix or Nix first:"
  echo "  https://lix.systems/install/"
  exit 1
fi

if ! pgrep -x nix-daemon &>/dev/null; then
  error "nix-daemon is not running. Start it first."
  exit 1
fi

# --- Extract Cloudflare WARP cert from system keychain ---

info "Extracting Cloudflare WARP certificates from system keychain..."
WARP_CERTS=$(security find-certificate -a -c "Cloudflare" -p /Library/Keychains/System.keychain 2>/dev/null || true)

if [[ -z "$WARP_CERTS" ]]; then
  error "No Cloudflare certificates found in system keychain."
  echo "  Is Cloudflare WARP / Zero Trust enrolled on this machine?"
  exit 1
fi

CERT_COUNT=$(echo "$WARP_CERTS" | grep -c "BEGIN CERTIFICATE" || true)
info "Found ${CERT_COUNT} Cloudflare certificate(s)."

# --- Save cert to permanent location (referenced by flake.nix) ---

WARP_CA_DIR="$HOME/.config/cloudflare"
WARP_CA_FILE="${WARP_CA_DIR}/zero_trust_cert.pem"

mkdir -p "$WARP_CA_DIR"
echo "$WARP_CERTS" > "$WARP_CA_FILE"
info "Saved WARP CA cert to ${WARP_CA_FILE}"

# --- Locate the Nix CA bundle ---

# Try flakes-based lookup first (works without channels), then legacy, then brute-force.
NIX_CA_FILE=""

# Method 1: flakes (nix build)
CACERT_PATH=$(nix build nixpkgs#cacert --print-out-paths --no-link 2>/dev/null || true)
if [[ -n "$CACERT_PATH" && -f "${CACERT_PATH}/etc/ssl/certs/ca-bundle.crt" ]]; then
  NIX_CA_FILE="${CACERT_PATH}/etc/ssl/certs/ca-bundle.crt"
fi

# Method 2: channels (nix-instantiate)
if [[ -z "$NIX_CA_FILE" ]]; then
  CACERT_PATH=$(nix-instantiate --eval -E '(import <nixpkgs> {}).cacert' 2>/dev/null | tr -d '"' || true)
  if [[ -n "$CACERT_PATH" && -f "${CACERT_PATH}/etc/ssl/certs/ca-bundle.crt" ]]; then
    NIX_CA_FILE="${CACERT_PATH}/etc/ssl/certs/ca-bundle.crt"
  fi
fi

# Method 3: find in store (last resort)
if [[ -z "$NIX_CA_FILE" ]]; then
  NIX_CA_FILE=$(find /nix/store -maxdepth 3 -name "ca-bundle.crt" -path "*/etc/ssl/certs/*" 2>/dev/null | head -1 || true)
fi

if [[ -z "$NIX_CA_FILE" || ! -f "$NIX_CA_FILE" ]]; then
  error "Could not find the Nix CA bundle in the store."
  echo "  Try: nix build nixpkgs#cacert --print-out-paths --no-link"
  exit 1
fi

info "Using Nix CA bundle: ${NIX_CA_FILE}"

# --- Build combined CA bundle ---

COMBINED_BUNDLE="${WARP_CA_DIR}/bootstrap-ca-bundle.pem"
cat "$NIX_CA_FILE" > "$COMBINED_BUNDLE"
echo "" >> "$COMBINED_BUNDLE"
echo "# Cloudflare WARP Zero Trust certificates (added by bootstrap.sh)" >> "$COMBINED_BUNDLE"
echo "$WARP_CERTS" >> "$COMBINED_BUNDLE"

info "Combined CA bundle: ${COMBINED_BUNDLE}"

# --- Patch nix-daemon launchd plist ---
#
# We point NIX_SSL_CERT_FILE in the daemon's launchd plist to our combined
# bundle. This is a runtime-only change — no managed files on disk are
# mutated (unlike patching /etc/nix/nix.conf, which is a nix-darwin-managed
# symlink into the store). After the first successful darwin-rebuild,
# security.pki takes over and sets NIX_SSL_CERT_FILE permanently.

DAEMON_PLIST="/Library/LaunchDaemons/org.nixos.nix-daemon.plist"

if [[ ! -f "$DAEMON_PLIST" ]]; then
  error "Nix daemon plist not found at ${DAEMON_PLIST}"
  echo "  Is the nix-daemon installed correctly?"
  exit 1
fi

PREV_CERT_FILE=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:NIX_SSL_CERT_FILE" "$DAEMON_PLIST" 2>/dev/null || true)

if [[ -n "$PREV_CERT_FILE" ]]; then
  info "Previous NIX_SSL_CERT_FILE: ${PREV_CERT_FILE}"
  sudo /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:NIX_SSL_CERT_FILE ${COMBINED_BUNDLE}" "$DAEMON_PLIST"
else
  # Ensure EnvironmentVariables dict exists
  /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$DAEMON_PLIST" &>/dev/null || \
    sudo /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables dict" "$DAEMON_PLIST"
  sudo /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:NIX_SSL_CERT_FILE string ${COMBINED_BUNDLE}" "$DAEMON_PLIST"
fi

info "Patched daemon plist: NIX_SSL_CERT_FILE → ${COMBINED_BUNDLE}"

# --- Restart nix-daemon ---
#
# We unload/load (not kickstart -k) so launchd re-reads the plist.

info "Restarting nix-daemon..."
sudo launchctl unload "$DAEMON_PLIST" 2>/dev/null || true
sudo launchctl load "$DAEMON_PLIST"
sleep 2

if pgrep -x nix-daemon &>/dev/null; then
  info "nix-daemon restarted successfully."
else
  warn "nix-daemon may not have restarted. Check: sudo launchctl list | grep nix"
fi

# --- Verify connectivity ---

info "Verifying nix can reach the internet..."
if nix eval nixpkgs#hello.name 2>/dev/null; then
  info "Connectivity verified!"
else
  warn "Verification failed. The daemon may need a moment. Try again in a few seconds."
fi

echo ""
info "Bootstrap complete. Now run:"
echo "  sudo darwin-rebuild switch --flake ~/.config/nix-darwin"
echo ""
info "After the first successful build, security.pki takes over and this"
info "bootstrap is no longer needed. The combined bundle at"
info "  ${COMBINED_BUNDLE}"
info "can be deleted after the build."
