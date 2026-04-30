# Architecture

## Overview
This system uses a flake-based nix-darwin and home-manager configuration to manage a macOS environment. Nix-darwin handles system-level settings like macOS defaults, nix daemon configuration, and homebrew integration. Home-manager manages the user-level environment, including shell configuration, git settings, CLI programs, and secrets. The codebase is split into two main directories: `modules/` for system-level configuration and `home/` for user-level configuration.

## Module graph
```
flake.nix
├── modules/nix.nix          # Nix daemon: flakes, gc, optimise
├── modules/homebrew.nix     # Brew: taps, formulae, casks
├── modules/system.nix       # Platform, user, WARP cert
├── modules/macos.nix        # macOS defaults
├── modules/wm.nix           # Window manager services (yabai + skhd)
├── modules/postgresql.nix   # Postgres server launchd service
└── home-manager
    └── home.nix             # User packages + imports every home/*.nix
```

`home/` contains one module per concern (`shell`, `git`, `programs`, `secrets`, `opencode`, `glab`, `theme`, `colima`). Any new home-manager module must be added to `home.nix`'s `imports` list; any new system module must be added to `flake.nix`'s `modules` list.

## Nix vs Brew
The choice between Nix and Homebrew depends on the type of tool and its integration requirements.

Nix is used for:
- CLI tools that don't require deep macOS integration (ripgrep, fd, bun, zig).
- Tools that have dedicated home-manager modules (fzf, zoxide, direnv, starship).
- Container tooling: colima, docker CLI, docker-buildx, docker-compose.
- Window management: yabai and skhd via nix-darwin `services.yabai` and `services.skhd`.

Brew is used for:
- GUI applications (casks) due to Gatekeeper, Spotlight indexing, and auto-update requirements.
- Cloudflare internal tools from the private `cloudflare/engineering` tap.
- `cloudflared`, because SSH ProxyCommand directives hardcode `/opt/homebrew/bin/cloudflared`.

Prefer Nix if home-manager provides a `programs.X` module or the tool is a CLI binary. Use Brew for GUI apps, private taps, and tools with hardcoded brew paths.

## Secrets management
Secrets are managed using sops-nix with age encryption. The age key is derived from the SSH key located at `~/.ssh/cloudflare/id_ed25519`. Encrypted values are stored in `secrets/default.yaml`, which is safe to commit to the repository. The `.sops.yaml` file maps the age public key to the secrets file pattern.

On macOS, sops-nix uses a LaunchAgent rather than systemd. This means secrets are decrypted to `~/.config/sops-nix/secrets/` at login. Because decryption happens at login rather than during the nix activation phase, activation scripts use a retry loop to wait for decrypted files to appear. Activation scripts then read these secrets and substitute placeholders in configuration templates.

Declared secrets live as `sops.secrets.<name>` entries in `home/*.nix` — grep for `sops.secrets` to see the live list rather than tracking it here.

To add a new secret:
1. Run `SOPS_AGE_KEY=$(nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/cloudflare/id_ed25519) nix run nixpkgs#sops -- --set '["secret_name"] "value"' secrets/default.yaml`.
2. Add `sops.secrets.secret_name = {};` in the relevant module.
3. Reference the secret via `config.sops.secrets.secret_name.path` in an activation script.

## Config file strategies
The system uses three distinct patterns for managing configuration files.

1. **Nix module**: Used for tools like Ghostty or SSH. Home-manager generates the configuration file as a read-only symlink pointing to the nix store. This is the preferred method for tools that don't need to write back to their own configuration.
2. **Template + activation script**: Used for `opencode.json` and GitLab's `config.yml`. A template file in `config/` contains placeholder tokens like `__SECRET__`. An activation script copies this template to the target location and substitutes secrets from sops. The resulting file is a real, mutable file rather than a symlink. This pattern is necessary for tools that write state back to their configuration and require secret injection.
3. **mkOutOfStoreSymlink**: Creates a symlink from the home directory to a file within the git repository. The target remains mutable, and any edits made by the user or external tools land directly in the git working tree. This is used for files that are frequently edited.

## External dependencies
Several components exist outside this repository and must be present for the system to function correctly.

- `~/.config/cloudflare/zero_trust_cert.pem`: The WARP CA certificate.
- `~/.ssh/cloudflare/id_ed25519`: The SSH key used for git and as the sops age key.
- `~/.config/cloudflare/vault-funcs`: Cloudflare vault helpers, sourced if present.
- `~/.local/share/cloudflare-warp-certs/`: Environment variables and git configuration for WARP certificates.
- `~/.config/nvim/`: Neovim configuration, managed in the `ghostwriternr/LazyVim` repository.
- `~/.colima/`: Configuration for the Colima Docker runtime.

## Flake inputs
- `nixpkgs`: The unstable package set.
- `nix-darwin`: Manages macOS system configuration.
- `home-manager`: Manages the user environment.
- `sops-nix`: Handles secrets management.
- `superpowers`: An opencode skill pack from `obra/superpowers`.
- `cloudflare-skills`: An opencode skill pack from `cloudflare/skills`.
- `llm-agents`: Numtide's daily-updated catalogue of AI coding agents (`numtide/llm-agents.nix`). Sources `opencode`, `pi`, and the `skills` CLI; transparently extensible to other agents (claude-code, codex, crush, gemini-cli, etc.) by adding `llm.<name>` to `home.packages`. Binary cache configured at `cache.numtide.com` (see `modules/nix.nix`).

## OpenCode agents
Custom agents are defined as markdown files in `config/opencode/agents/` and symlinked to `~/.config/opencode/agents/` via `mkOutOfStoreSymlink` in `home/opencode.nix`. Each file combines a YAML frontmatter (model, permissions, mode) with a system prompt body.

The roster splits into **primary** agents (`build`, `deep`, `quick`, `large`) for top-level interaction and **subagents** (`oracle`, `review`, `research`, `librarian`) dispatched via the `task` tool. Image and PDF analysis is handled by the `look_at` plugin (`config/opencode/plugins/look-at.js`), not an agent. Built-in agents `plan`, `general`, and `explore` are disabled in `opencode.json` because the custom roster replaces them.

Model choices follow Amp's architecture: different model families for different cognitive styles (Claude for structured instruction-following, GPT for autonomous reasoning, Gemini for parallel tool use and analysis). Live model assignments live in each agent's YAML frontmatter — don't duplicate them here; they drift. Use the `auditing-agent-sources` skill to compare against upstream references (OpenCode, Amp, oh-my-openagent) when bumping.

Non-flake inputs are pinned in `flake.lock`. Update them using `nix flake update <input>`.

## The --impure flag
Using the `--impure` flag is required during system activation because `security.pki.certificateFiles` references an absolute path outside the flake tree. The WARP certificate at `~/.config/cloudflare/zero_trust_cert.pem` is machine-specific infrastructure rather than shared configuration. It cannot be committed to the repository as it is unique to each Cloudflare account. If you aren't using Cloudflare WARP, you can remove the certificateFiles line and the requirement for the `--impure` flag. See `docs/warp-cert.md` for more details.

## Plannotator
[Plannotator](https://plannotator.ai) is a browser-based plan/code annotation UI for AI coding agents. It exposes a `submit_plan` tool and four universal slash commands. Packaged in `pkgs/plannotator/default.nix`, exposed on the overlay as `pkgs.plannotator`, and consumed by the thin home-manager module `home/plannotator.nix`.

Wired into `build`, `deep`, and `large` primary agents via `plan-agent` workflow mode (see `config/opencode/opencode.json`'s top-level `plugin` array). These are the primaries that write plans and route them to the human for review. When they call `submit_plan`, a browser opens for annotation; structured feedback round-trips to the agent. Composes with the existing oracle-subagent-autonomous-review flow: agent writes plan → oracle critiques the markdown → agent revises → plannotator shows the improved plan to the human. `quick` is excluded (Haiku one-liner agent, doesn't plan). Subagents are auto-excluded (the plugin only targets primaries).

Four slash commands are installed as markdown stubs to `~/.config/opencode/commands/`: `/plannotator-annotate <file|url|dir>`, `/plannotator-last`, `/plannotator-review`, `/plannotator-archive`. These are **not** installed by the plugin's npm `postinstall` — OpenCode's plugin installer runs with `Arborist({ignoreScripts: true})` (`packages/opencode/src/npm/index.ts:150` in the opencode repo), so postinstalls never fire. The `plannotator-commands` subpackage fetches the npm tarball, extracts `package/commands/*.md`, and the home-manager module installs them via `xdg.configFile`. Keeping commands as a proper `mkDerivation` (not `runCommand`) is deliberate — it lets `nix-update -F -s commands .#plannotator` bump the tarball hash natively.

The binary derivation follows the same shape as `nixpkgs/pkgs/by-name/cl/claude-code-bin/package.nix` — another Bun-compiled single-file CLI from GitHub releases. `dontStrip = true` is **critical**: Bun embeds JS bytecode after the Mach-O segments, and stripping corrupts it.

**Bumping the version:** automatic. The daily `nix-update` zsh function (`home/shell.nix:124`) runs a plannotator check as step 2.5, using `nix-update -F --version stable --use-github-releases` to bump the binary, then `nix-update -F --version skip -s commands` to bump the npm tarball hash, then a `sed` to update the plugin pin in `config/opencode/opencode.json`. The three changes land as a single `plannotator: X -> Y` commit, separate from the usual `flake: update inputs` commit. Plannotator is never cached on `cache.nixos.org` (personal package, not in nixpkgs), so it always shows up in the daily "will build from source" prompt — that gate doubles as a pre-merge review checkpoint. Answering `n` reverts both the nixpkgs bump and the plannotator bump cleanly.

**Manual bumping**, if ever needed: from the flake root, run:
```sh
nix run nixpkgs#nix-update -- -F --version <new> --use-github-releases \
  darwinConfigurations.KVQ52GY6N9.pkgs.plannotator
nix run nixpkgs#nix-update -- -F --version skip -s commands \
  darwinConfigurations.KVQ52GY6N9.pkgs.plannotator
sed -i '' "s|@plannotator/opencode@[0-9.]*|@plannotator/opencode@<new>|" \
  config/opencode/opencode.json
```

**Local state across rebuilds:** `~/.cache/opencode/packages/@plannotator/` is opencode's own plugin cache, refreshed when the version changes. `~/.plannotator/` is plannotator's runtime state (plan history, drafts) — user data, not nix-managed. The four `~/.config/opencode/commands/plannotator-*.md` entries are nix-store symlinks and disappear cleanly when the module is removed.
