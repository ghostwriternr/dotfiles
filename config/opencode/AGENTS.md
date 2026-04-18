# Global Rules

These rules apply to every OpenCode session on this machine, across all projects. Project-level `AGENTS.md` may override specifics.

## Git Commit Messages

Follow Chris Beams' seven rules (https://cbea.ms/git-commit/):

1. **Separate subject from body with a blank line.** If the commit needs a body, there must be one blank line between the subject and the body.
2. **Limit the subject line to 50 characters.** 72 is a hard ceiling.
3. **Capitalize the subject line.** "Accelerate to 88 miles per hour", not "accelerate…".
4. **Do not end the subject line with a period.**
5. **Use the imperative mood in the subject line.** "Fix bug", not "Fixed bug" or "Fixes bug". A properly formed subject line should complete the sentence: *"If applied, this commit will ___."*
6. **Wrap the body at 72 characters.** Git does not wrap text automatically.
7. **Use the body to explain *what* and *why*, not *how*.** The diff shows how; the message explains intent and context.

### Additional guidance

- Keep the subject line a concise summary of the change. Prefer specific verbs ("Refactor", "Introduce", "Remove") over vague ones ("Update", "Change").
- Omit the body for trivial commits where the subject fully describes the change. Include a body when motivation, tradeoffs, side effects, or references matter.
- Reference issues, PRs, or external links in the body, not the subject.
- Match the repository's existing convention if it clearly diverges (e.g. Conventional Commits via `feat:`/`fix:` prefixes). When in doubt, ask. Project-level `AGENTS.md` takes precedence.

## Pull Request / Merge Request Descriptions

When opening a PR or MR (forge-agnostic — GitHub, GitLab, Gitea, etc.), follow Google's CL description guidelines (https://google.github.io/eng-practices/review/developer/cl-descriptions.html):

1. **First line is a short, imperative summary of *what* the change does.** Treat it exactly like a commit subject line: follow the Chris Beams rules above (≤50 chars target / 72 hard ceiling, capitalized, imperative mood, no trailing period). For single-commit PRs the title and the commit subject should be identical.
2. **Body explains *why*, not *how*.** Motivation, context, tradeoffs, shortcomings of the chosen approach, links to issues/specs/design docs, screenshots for UI changes. The diff shows how. Assume external links may be inaccessible to future readers — include enough context in the body that the PR stands on its own.
3. **Be specific.** "Fix bug" or "Phase 1" is a bad description; "Remove size limit on RPC server message freelist" is a good one. A reviewer should understand the change without reading the diff.
4. **Write for the future reader, not just today's reviewer.** Someone will find this PR via `git log` or a bug hunt months later with no context.
5. **Update the description as the PR evolves.** If review rounds change the scope or approach, edit the description to match the final state.
6. **Keep PRs small and single-purpose.** Rule of thumb: ~100 lines is comfortable, ~1000 is almost always too large; a change touching 50 files counts as large even if the line count is modest. Whole-file deletions and trusted mechanical refactors (codemods, formatter runs) can be larger. If the description needs "and also…" clauses, the PR wants splitting. See https://google.github.io/eng-practices/review/developer/small-cls.html for splitting strategies (horizontal/vertical/stacking).
7. **Separate refactors from behaviour changes.** Moving or renaming a class belongs in a different PR from fixing a bug in that class. Small local cleanups (a variable rename, a nearby typo) can ride along with a feature or bugfix.
8. **Include related tests in the same PR.** Behaviour changes need new or updated tests; pure refactors should be covered by existing or newly-added tests. Test-only PRs that backfill coverage for untested code can land ahead of the refactor they enable.

### Additional guidance

- Match the repository's existing PR template if one exists (`.github/PULL_REQUEST_TEMPLATE.md`, `.gitlab/merge_request_templates/`). Fill in every section — don't leave placeholder text.
- Reference issues with the forge's auto-close syntax (`Fixes #123`, `Closes !456`) in the body when the PR resolves an issue.
- When the repo squash-merges, the PR body becomes the squashed commit body — write it to be commit-worthy, not just reviewer-chatter.
- Project-level `AGENTS.md` takes precedence over these rules.

## Superpowers Plan Storage

**Override** the default `docs/superpowers/plans/` location from `superpowers:writing-plans`. By default, plans, specs, and reviews are noisy working artifacts the user does not want to commit into source repos, but does want to revisit weeks later. Save them to the user's Obsidian vault instead.

**Root:** `~/Documents/notes/Engineering/Plans/<repo-name>/`

**Layout:**

- Plans → `~/Documents/notes/Engineering/Plans/<repo-name>/plans/YYYY-MM-DD-<feature>.md`
- Specs (from `superpowers:brainstorming`) → `~/Documents/notes/Engineering/Plans/<repo-name>/specs/YYYY-MM-DD-<feature>.md`
- Code review docs (from `superpowers:requesting-code-review` or saved oracle/review output) → `~/Documents/notes/Engineering/Plans/<repo-name>/reviews/YYYY-MM-DD-<topic>.md`

**Resolving `<repo-name>`:** `basename "$(git rev-parse --show-toplevel)"` from inside the working repo. If not in a git repo, use the basename of the current working directory.

**Create the directory if missing:** `mkdir -p ~/Documents/notes/Engineering/Plans/<repo-name>/{plans,specs,reviews}` before writing the first artifact for a repo.

**Cross-references:** When a plan references its spec (or vice versa), use the absolute vault path so links survive when files are read from either side. Example: `**Spec:** ~/Documents/notes/Engineering/Plans/nix-darwin/specs/2026-04-18-agent-upgrade-design.md`.

**Announcement to the user:** When saving, report the full vault path, not the skill's default. e.g. *"Plan saved to `~/Documents/notes/Engineering/Plans/nix-darwin/plans/2026-04-18-foo.md`"*.

**Do not commit these files to the working repo.** The vault is a separate git repo (`~/Documents/notes/`) with its own commit cadence — leave vault commits to the user unless asked.

**Per-repo override:** A project-level `AGENTS.md` can opt back into committing plans inside the repo (useful for open-source or team projects). If the project-level file specifies a plan location, that wins over this rule.
