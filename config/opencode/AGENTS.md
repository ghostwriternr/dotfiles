# OpenCode setup

OpenCode is configured under this directory. Files are surfaced into `~/.config/opencode/` by `home/opencode.nix` using three patterns. Knowing which is which is the only thing that matters when editing.

## How files reach `~/.config/opencode/`

- **`mkOutOfStoreSymlink` (mutable, lands in git)** — `agents/`, `skills/auditing-agent-sources/`, `skills/updating-opencode-agents/`, `plugins/look-at.js`, `plugins/interactive-bash.js`, `opencode.json`, and `../agent-rules.md` (surfaced as `~/.config/opencode/AGENTS.md`; shared with pi). The symlink at `~/.config/opencode/<x>` *is* this repo. Editing the live path edits git.
- **Nix store, read-only** — upstream skill packs `skills/superpowers/` and `skills/cloudflare/`, plus the upstream `plugins/superpowers.js`. Sourced from flake inputs `superpowers` and `cloudflare-skills` in `flake.nix`, pinned via `flake.lock`. Bump with `nix flake update superpowers cloudflare-skills`. `force = true` in `home/opencode.nix` overwrites stale manual clones on rebuild.
- **Activation script** — `home/opencode.nix:69` symlinks `~/.config/opencode/node_modules` into this repo's `node_modules` so Bun can resolve `@opencode-ai/plugin` for plugins running from their real (repo) path. `node_modules` is gitignored.

If a rebuild does not pick up an agent edit, verify `home/opencode.nix` still uses `mkOutOfStoreSymlink` rather than a copy with `force = true`.

`../agent-rules.md` (one level up, at `config/agent-rules.md`) is **the global, machine-wide, tool-agnostic** rules file (commit-message rules, PR rules, plan-storage location). It is symlinked out as `~/.config/opencode/AGENTS.md` *and* `~/.pi/agent/AGENTS.md`, and applies to every agent session everywhere — not just this repo. Do not put nix-darwin-specific notes or opencode-specific notes there; keep it tool-neutral. The file you are reading now (`AGENTS.md` in this directory) is the **project-scoped** counterpart and only auto-loads when a session is rooted under `config/opencode/`.

## Agent roster (`agents/*.md`)

All agents are custom; built-in `plan`, `explore`, `general` are disabled in `opencode.json`. Models live in YAML frontmatter — never duplicate them here, they drift. Use the `auditing-agent-sources` skill to compare against upstream.

| File | Mode | Role |
|---|---|---|
| `build.md` | primary | Default coder |
| `large.md` | primary | Same body as `build.md`, used when a long-context model is wanted |
| `deep.md` | primary | Autonomous deep reasoning, long horizons |
| `quick.md` | primary | One-shot tiny edits, cheap model |
| `oracle.md` | subagent | Second-opinion advisor, read-only |
| `review.md` | subagent | Code review, read-only |
| `research.md` | subagent | Fast codebase search |
| `librarian.md` | subagent | External-doc and dependency research |

`large.md` is a verbatim mirror of `build.md`'s body. Empty-body agents fall back to the *raw provider prompt* — not to another agent's body — so any cross-agent prompt sharing has to be explicit.

## The body-replacement rule

**Agent body content REPLACES the provider base prompt.** It does not extend or merge. A short custom body silently drops the 100+ lines of tool-use, parallelism, code-reference, and TodoWrite emphasis carried in `~/github/opencode/packages/opencode/src/session/prompt/{anthropic,gpt,gemini}.txt`.

Re-verify before any major rewrite — if upstream flips this to extend, much of `skills/updating-opencode-agents/` needs updating:

```bash
rg -n "system|prompt" ~/github/opencode/packages/opencode/src/session/llm.ts
```

For any body rewrite, use the **`updating-opencode-agents` skill** — it documents the staging-directory + Oracle gap-audit loop that catches what the base prompt was carrying. Skipping it costs review rounds.

## Permission model (`opencode.json`)

`opencode.json` is the global allow/ask/deny matrix for tools and bash patterns. Three things to know:

- **Last-match-wins.** Order matters within the bash block; later patterns override earlier ones. Add new entries near related rules.
- **`task` is per-target.** `task: { "*": deny, research: allow }` is a real allowlist. Native subagents (`general`, `explore`) appear in the Task menu by default with edit permissions — always pair `task: allow` with an explicit allowlist or globally disable the natives.
- **Bash patterns are prefix-matched.** `git status *` allows `git status`, `git status --short`, etc. Compound commands (`&&`, `||`, `;`, pipes, redirects) are NOT safely captured — `interactive-bash.js` routes those through the `interactive_bash` permission instead.

## Plugins (`plugins/`)

- **`superpowers.js`** — upstream from `obra/superpowers`. Provides the `skill` tool that loads `skills/<name>/SKILL.md` content into context on demand. Read-only from our perspective; bump via `nix flake update superpowers`.
- **`look-at.js`** — custom. `look_at` tool spawns a child session against `gemini-3-flash-preview` to analyze pasted images, files on disk, or base64 data. Solves the "task tool only forwards text" problem for vision work.
- **`interactive-bash.js`** — custom. `interactive_bash` tool wraps tmux sessions auto-prefixed with `oc-<sessionID>-`. Buffers split text sends and re-checks them against `permission.bash` rules at Enter time so the buffer cannot bypass policy. Compound commands always prompt.

`opencode.json`'s top-level `plugin` array additionally pulls `@plannotator/opencode` from npm — that one is managed by the daily `nix-update` zsh function and bumped automatically. See `docs/architecture.md` for plannotator integration details.

## Skills

- **`skills/superpowers/`** — upstream meta-skills for brainstorming, planning, debugging, TDD, code review, worktrees, etc. Read-only.
- **`skills/cloudflare/`** — upstream Cloudflare-platform skill pack (Workers, KV, R2, Agents SDK, Wrangler, etc.). Read-only.
- **`skills/auditing-agent-sources/`** — custom. Run when checking whether our agent prompts are stale relative to OpenCode upstream, Amp, and oh-my-openagent. Surfaces deltas; does not apply them.
- **`skills/updating-opencode-agents/`** — custom. Run when editing or rewriting an agent. Encodes the body-replacement rule, the Oracle gap-audit loop, and the known gotchas (model-specific tool selection, provider option defaults, parameter↔prompt tension, native-subagent escalation paths).

## Editing checklist

1. Edit files in this directory directly. The symlink picks up changes immediately for `mkOutOfStoreSymlink`-managed files; no rebuild needed unless the symlink itself moves.
2. For new files, `git add` first — Nix flakes only see git-tracked files, and a new agent file won't be evaluable without it.
3. For multi-file agent rewrites: stage drafts under `~/Documents/notes/Engineering/Plans/nix-darwin/staging/YYYY-MM-DD-<topic>/`, run the `updating-opencode-agents` skill's gap-audit loop, then deploy as a single commit.
4. After substantive changes, restart the OpenCode session — frontmatter and body are loaded once at session start.
5. For `home/opencode.nix` changes (adding a new managed file, changing how something is sourced), suggest the user run `nix-rebuild`. See the repo-root `AGENTS.md` for why you don't run rebuilds yourself and how `nix-rebuild` differs from `nix-update`.

## Common gotchas

- **`edit: deny` is not a sandbox.** It blocks `edit`/`write`/`apply_patch` but bash can still create files. "Read-only" is enforced by both the permission system and the prompt.
- **GPT vs Claude/Gemini get different file tools.** `tool/registry.ts` historically routes non-`oss`, non-`gpt-4` GPT models to `apply_patch`; everything else gets `edit` + `write`. A prompt that says "use the Edit tool" fails for a GPT-5.x agent. Re-verify in `~/github/opencode/packages/opencode/src/tool/registry.ts` when porting prompts across families.
- **Provider option defaults silently override frontmatter.** OpenCode has historically forced low verbosity on some GPT-5.x variants in `provider/transform.ts`. Set `options.textVerbosity: high` explicitly if you want it; do not trust inheritance.
- **Parameter↔prompt tension.** Don't pair `textVerbosity: high` with a prompt that imposes "≤3 bullets" caps. Pick one.
