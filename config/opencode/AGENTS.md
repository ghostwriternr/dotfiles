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
