#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <context-mode|pi-mcp-adapter>" >&2
  exit 2
fi

pkg="$1"
case "$pkg" in
  context-mode) attr="context-mode" ;;
  pi-mcp-adapter) attr="pi-mcp-adapter" ;;
  *) echo "unsupported Pi package: $pkg" >&2; exit 2 ;;
esac

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
pkg_dir="$repo_dir/pkgs/pi-packages/$pkg"
pkg_file="$pkg_dir/default.nix"
lock_file="$pkg_dir/package-lock.json"
system_attr="$repo_dir#darwinConfigurations.KVQ52GY6N9.pkgs.piPackages.$attr"
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

old_version=$(grep -m1 '^  version = ' "$pkg_file" | sed -E 's/.*"([^"]+)".*/\1/')
new_version=$(npm view "$pkg" version --json | tr -d '"')

if [[ "$old_version" == "$new_version" ]]; then
  echo "✓ $pkg already at latest ($old_version)"
  exit 0
fi

echo ":: Bumping $pkg: $old_version -> $new_version"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
(
  cd "$tmp"
  tarball=$(npm pack "$pkg@$new_version" --silent)
  tar -xzf "$tarball" package/package.json
  cp package/package.json "$pkg_dir/package.json"
)
(
  cd "$pkg_dir"
  npm install --package-lock-only --ignore-scripts --omit=dev >/dev/null
  rm package.json
)

perl -0pi -e "s/version = \"[^\"]+\";/version = \"$new_version\";/" "$pkg_file"
perl -0pi -e "s#${pkg//-/\\-}-[0-9][^/]*\\.tgz#${pkg}-${new_version}.tgz#" "$pkg_file"
perl -0pi -e "my \$n=0; s/hash = \"sha256-[^\"]+\";/++\$n == 1 ? 'hash = \"$fake_hash\";' : \$&/ge" "$pkg_file"
perl -0pi -e "s/npmDepsHash = \"sha256-[^\"]+\";/npmDepsHash = \"$fake_hash\";/" "$pkg_file"

capture_hash() {
  local output got
  set +e
  output=$(nix build --impure --no-link "$system_attr" 2>&1)
  local status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    return 1
  fi
  got=$(printf '%s\n' "$output" | sed -n 's/.*got:[[:space:]]*\(sha256-[^[:space:]]*\).*/\1/p' | head -1)
  if [[ -z "$got" ]]; then
    printf '%s\n' "$output" >&2
    echo "could not find hash mismatch for $pkg" >&2
    exit $status
  fi
  printf '%s' "$got"
}

src_hash=$(capture_hash)
perl -0pi -e "my \$n=0; s/hash = \"sha256-[^\"]+\";/++\$n == 1 ? 'hash = \"$src_hash\";' : \$&/ge" "$pkg_file"

deps_hash=$(capture_hash)
perl -0pi -e "s/npmDepsHash = \"sha256-[^\"]+\";/npmDepsHash = \"$deps_hash\";/" "$pkg_file"

nix build --impure --no-link "$system_attr" >/dev/null

echo "✓ $pkg bumped: $old_version -> $new_version"
