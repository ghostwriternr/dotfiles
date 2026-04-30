# AGENTS.md

nix-darwin + home-manager flake for a single machine (`KVQ52GY6N9`, Cloudflare work MacBook, Apple Silicon, Lix). Read `README.md` and `docs/architecture.md` first — this file only captures gotchas those docs don't make obvious.

## Critical traps

- **Nix flakes only see git-tracked files.** Any new file must be `git add`ed before a rebuild will see it. A missing `git add` manifests as cryptic "file not found" during evaluation.
- **`--impure` is mandatory, not optional.** `modules/system.nix:12` references an absolute path outside the flake tree (`/Users/naresh/.config/cloudflare/zero_trust_cert.pem`). Do not try to "fix" this — the WARP cert is per-account infrastructure and intentionally excluded. See `docs/warp-cert.md`.
- **Do not rebuild yourself; propose changes and let the user rebuild.** Rebuilds need sudo and take 30s–10min. The user has two commands (both in `home/shell.nix`) that wrap `darwin-rebuild` for different purposes — pick the right one when suggesting:
  - `nix-rebuild` (alias, `home/shell.nix:22`) — pure rebuild of the current working tree. Suggest this after editing nix files for an ad-hoc change.
  - `nix-update` (zsh function, `home/shell.nix:125`) — daily/weekly hygiene wrapper. Updates flake inputs, bumps plannotator, runs a binary-cache dry-run gate, rebuilds, upgrades brew, refreshes skills, then commits + pushes. Do **not** suggest `nix-update` for ad-hoc rebuilds; its scope is much wider than what most edits need.
  - For syntax-only verification without rebuilding, use `nix build --dry-run '.#darwinConfigurations.KVQ52GY6N9.system' --impure`.
- **Host is hardcoded.** `flake.nix:20` only defines `darwinConfigurations."KVQ52GY6N9"`. Any dry-build or eval must use that attribute.

## Layout: system vs user, and where edits land

- `modules/` → nix-darwin (system-level: macOS defaults, homebrew, nix daemon, launchd services like yabai/skhd, WARP cert).
- `home/` → home-manager (user-level: shell, git, CLI programs, secrets, opencode, glab).
- `flake.nix` wires them together; `home.nix` is home-manager's root and imports every `home/*.nix`. New home-manager modules must be added to `home.nix`'s `imports`. New system modules go in `flake.nix`'s `modules` list.
- `config/` holds raw config files (templates, keybindings) that nix files in `home/` reference.

## Three config-file patterns (pick the right one)

`docs/architecture.md` explains this; the practical consequence for agents:

1. **Nix-generated (read-only store symlink)** — default for `programs.X`. User cannot mutate; edits must happen in `.nix` files.
2. **Template + sops activation script** — used when the tool writes back to its own config (e.g. `config/glab-cli/config.yml`, `config/opencode/opencode.json`). Placeholders like `__GLAB_CFDATA_TOKEN__` are substituted at activation from `~/.config/sops-nix/secrets/`. Edit the template in `config/`, not the decrypted copy in `~/.config/`.
3. **`mkOutOfStoreSymlink`** — symlinks a live file in `~/.config/` back to this repo so edits land in git. This is how `config/opencode/{agents,skills,plugins,opencode.json,AGENTS.md}` work (see `home/opencode.nix`). **Editing `~/.config/opencode/agents/foo.md` is editing this repo.** Touching these files outside a commit still changes opencode behaviour live.

## OpenCode-specific

OpenCode setup details (file-surfacing patterns, agent roster, permission model, plugins, skills, edit checklist, gotchas) live in `config/opencode/AGENTS.md`. OpenCode auto-loads it for any session rooted under `config/opencode/`. Do not duplicate that content here.

Two cross-cutting reminders that interact with the rest of this file:

- `config/agent-rules.md` is the **global, machine-wide, tool-agnostic** rules file (commit messages, PR descriptions, plan storage). It is symlinked to both `~/.config/opencode/AGENTS.md` and `~/.pi/agent/AGENTS.md`, applies to every agent session everywhere — not just this repo — and is shared between opencode and pi. Do not put nix-darwin-specific notes or tool-specific notes in it; keep it neutral.
- `config/opencode/node_modules` is gitignored and symlinked by an activation script in `home/opencode.nix:69` so plugins resolving `@opencode-ai/plugin` from the real repo path work under Bun.

## Secrets

- Managed by sops-nix with age derived from `~/.ssh/cloudflare/id_ed25519`. Encrypted file: `secrets/default.yaml` (safe to commit).
- On macOS, decryption runs via LaunchAgent at login, **not** during nix activation. Activation scripts that need secrets use retry loops (see `home/glab.nix:24`).
- To edit a secret: `SOPS_AGE_KEY=$(nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/cloudflare/id_ed25519) nix run nixpkgs#sops -- secrets/default.yaml`. Do not write plaintext secrets anywhere in the repo.
- Declare a new secret with `sops.secrets.<name> = {};` in a `home/*.nix` module, then reference `config.sops.secrets.<name>.path`.

## Nix vs Homebrew

CLI tools → Nix (`home.nix` `home.packages` or `programs.X` modules). GUI apps, private Cloudflare taps, and anything with a hardcoded `/opt/homebrew/bin/...` consumer (notably `cloudflared`) → Brew (`modules/homebrew.nix`). See `docs/architecture.md` "Nix vs Brew" for the reasoning.

## Verification before claiming done

- `nix flake check --impure` — evaluates the flake.
- `nix build --dry-run '.#darwinConfigurations.KVQ52GY6N9.system' --impure` — full evaluation without activation. Use this to catch eval errors before asking the user to rebuild.
- There is no formatter config, linter, or test suite. Match the existing 2-space indent and section-header (`# ── Name ─────`) style in `.nix` files.

## Shell environment quirks

- `home/shell.nix` uses `envExtra` (not `profileExtra`) to set `PATH`/brew/bun/asdf/WARP-certs, because non-interactive shells spawned by tools like opencode (`/bin/zsh -c "…"`) read `.zshenv` only. Moving these into `profileExtra` silently breaks tool-spawned subshells.
- WARP cert env vars (`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `CARGO_HTTP_CAINFO`, etc.) come from the external `cloudflare-certs` brew formula at `~/.local/share/cloudflare-warp-certs/config.sh`, not this repo.

## Commit style

Follow the rules in `config/opencode/AGENTS.md` (Chris Beams' seven rules). Recent history shows an ad-hoc prefix style ("flake:", "homebrew:", "chore:") — match the existing scope prefix when touching a well-scoped area, but it isn't strictly Conventional Commits.
