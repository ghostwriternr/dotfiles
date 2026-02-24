#!/usr/bin/env bash
# bootstrap.sh — One-time setup for nix-darwin on a Cloudflare WARP machine.
#
# This script does two things:
#   1. Extracts the WARP CA cert from the macOS keychain and saves it to
#      ~/.config/cloudflare/zero_trust_cert.pem (where flake.nix expects it).
#   2. Temporarily patches /etc/nix/nix.conf so the nix-daemon can download
#      during the first darwin-rebuild. After that, security.pki takes over.
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

COMBINED_BUNDLE=$(mktemp /tmp/nix-ca-bundle.XXXXXX.pem)
cat "$NIX_CA_FILE" > "$COMBINED_BUNDLE"
echo "" >> "$COMBINED_BUNDLE"
echo "# Cloudflare WARP Zero Trust certificates (added by bootstrap.sh)" >> "$COMBINED_BUNDLE"
echo "$WARP_CERTS" >> "$COMBINED_BUNDLE"

info "Combined CA bundle: ${COMBINED_BUNDLE}"

# --- Patch /etc/nix/nix.conf ---

NIX_CONF="/etc/nix/nix.conf"
REAL_CONF=$(readlink -f "$NIX_CONF" 2>/dev/null || echo "$NIX_CONF")

# Safety: never write into the Nix store — that corrupts it.
if [[ "$REAL_CONF" == /nix/store/* ]]; then
  warn "${NIX_CONF} is a symlink into the Nix store (nix-darwin is managing it)."
  warn "Writing a standalone nix.conf instead."
  # Break the symlink: copy the store file to a real file, then append.
  sudo cp "$REAL_CONF" "${NIX_CONF}.tmp"
  sudo mv "${NIX_CONF}.tmp" "$NIX_CONF"
  REAL_CONF="$NIX_CONF"
fi

if grep -q "ssl-cert-file" "$REAL_CONF" 2>/dev/null; then
  warn "ssl-cert-file already set in ${NIX_CONF}."
  echo "  Current setting:"
  grep "ssl-cert-file" "$REAL_CONF"
  echo ""
  read -rp "  Overwrite? [y/N] " answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    info "Skipping nix.conf modification."
    echo ""
    info "Done. If the existing ssl-cert-file is correct, run:"
    echo "  sudo darwin-rebuild switch --flake ~/.config/nix-darwin"
    exit 0
  fi
  # Remove existing ssl-cert-file line(s) before appending
  sudo sed -i.bak '/^ssl-cert-file/d' "$REAL_CONF"
fi

info "Appending ssl-cert-file to ${NIX_CONF}..."
echo "ssl-cert-file = ${COMBINED_BUNDLE}" | sudo tee -a "$REAL_CONF" >/dev/null

# --- Restart nix-daemon ---

info "Restarting nix-daemon..."
sudo launchctl kickstart -k system/org.nixos.nix-daemon 2>/dev/null || true
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
info "bootstrap is no longer needed. The temporary bundle at"
info "  ${COMBINED_BUNDLE}"
info "can be deleted after the build."
