# OpenCode Specialized Agents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace OMO's agent roster with native OpenCode agents modeled after Amp's architecture.

**Architecture:** 9 agents defined as markdown files in `config/opencode/agents/`, symlinked to `~/.config/opencode/agents/` via nix. Each agent is a combination of model + permissions + system prompt, tuned to the model family's cognitive style.

**Key constraint:** Setting a custom `prompt` on an agent REPLACES the OpenCode provider base prompt. Environment info, skills, and AGENTS.md are always included regardless. Agents without a custom prompt automatically get the provider-specific base (anthropic.txt for Claude, codex.txt for GPT, gemini.txt for Gemini).

**Reference material:** `/tmp/amp-reference/` contains Amp's system prompts, tool descriptions, and OpenCode's provider base prompts.

---

## Task 1: Create agent directory and nix symlink

**Files:**
- Create: `config/opencode/agents/` (directory)
- Modify: `home/opencode.nix`

- [ ] **Step 1: Create directory**

```bash
mkdir -p config/opencode/agents
```

- [ ] **Step 2: Add symlink to opencode.nix**

Add after the `# -- Plugins` section:

```nix
  # -- Custom agents (mutable -- symlink to repo so edits land in git) --------

  xdg.configFile."opencode/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${nixDarwinDir}/config/opencode/agents";
```

---

## Task 2: Write `build.md` -- primary coding agent

**Files:**
- Create: `config/opencode/agents/build.md`

**Strategy:** NO custom prompt. Empty body = uses anthropic.txt provider base automatically. Only set model and permissions via frontmatter. This is the safest approach -- proven OpenCode base prompt, zero risk of regression.

- [ ] **Step 1: Create build.md**

```markdown
---
description: Main coding agent. Proactive, collaborative, handles coding and planning.
mode: primary
model: anthropic/claude-opus-4-6
---
```

Empty body intentional -- inherits OpenCode's anthropic.txt provider prompt.

---

## Task 3: Write `deep.md` -- autonomous deep reasoning agent

**Files:**
- Create: `config/opencode/agents/deep.md`

**Strategy:** Custom prompt = OpenCode's codex.txt base (79 lines, tuned for GPT models) + Amp deep-mode behavioral overlay. The codex.txt base provides OpenCode-specific tool instructions. The overlay adds autonomous personality from Amp's Codex prompt.

**Key behavioral additions from Amp deep mode:**
- Autonomous: "go off and solve problems on its own, not pair program"
- Pragmatic: "the best change is often the smallest correct change"
- Minimal tests: "default to not adding tests"
- Principle-driven: high-level goals, not detailed rules (GPT's strength)

- [ ] **Step 1: Create deep.md**

Frontmatter:
```yaml
---
description: Autonomous deep reasoning. For thorny bugs, complex problems, and deep research. Goes deep for minutes without checking in.
mode: primary
model: openai/gpt-5.3-codex
reasoningEffort: high
---
```

Body: codex.txt content with these additions prepended:

```
# Deep Mode

You are an autonomous coding agent. You go deep on problems -- reading files, exploring the codebase, and reasoning through solutions for minutes before making changes. You do not check in constantly with the user.

## Autonomy
- Persist until the task is fully handled end-to-end. Do not stop at analysis or partial fixes.
- Unless the user explicitly asks for a plan or brainstorm, assume they want you to make code changes.
- If you encounter challenges or blockers, attempt to resolve them yourself.

## Pragmatism and Scope
- The best change is often the smallest correct change.
- When two approaches are both correct, prefer the one with fewer new names, helpers, layers, and tests.
- Keep obvious single-use logic inline. Do not extract a helper unless it is reused or hides meaningful complexity.
- A small amount of duplication is better than speculative abstraction.
- Default to not adding tests. Add a test only when the user asks, or when the change fixes a subtle bug that existing tests do not cover.

[...then the full codex.txt content follows...]
```

Reference: `/tmp/amp-reference/opencode-provider-codex.txt` for the base, `/tmp/amp-reference/prompt-deep-mode.md` for behavioral inspiration.

---

## Task 4: Write `quick.md` -- fast cheap agent

**Files:**
- Create: `config/opencode/agents/quick.md`

**Strategy:** Short custom prompt. NOT the full anthropic.txt (105 lines would contradict the speed-first ethos). Instead: essential OpenCode tool instructions + Amp rush-mode ultra-concise behavior. The prompt itself should be short -- that's the whole point.

- [ ] **Step 1: Create quick.md**

Frontmatter:
```yaml
---
description: Fast and cheap. For small, well-defined tasks -- typo fixes, simple renames, one-liner changes.
mode: primary
model: anthropic/claude-haiku-4-5
steps: 15
---
```

Body: A short prompt (~30-40 lines) combining:
1. "SPEED FIRST" directive from Amp rush mode
2. Essential OpenCode tool instructions (use Edit not sed, use Glob not find, etc.)
3. Ultra-concise communication style (1-3 words when possible)
4. "Do the work, minimal or no explanation. Let the code speak."

Reference: `/tmp/amp-reference/prompt-rush-mode.md` for behavioral inspiration.

---

## Task 5: Write `large.md` -- max context agent

**Files:**
- Create: `config/opencode/agents/large.md`

**Strategy:** NO custom prompt, like build. Same model, same provider base. The only difference is a note about large-scale refactors in the description. Amp hides this mode and discourages its use -- models produce worse output with more context.

- [ ] **Step 1: Create large.md**

```markdown
---
description: Same as build but for large-scale refactors where you need maximum context. Use sparingly -- models give better results with less context.
mode: primary
model: anthropic/claude-opus-4-6
---
```

Note: OpenCode doesn't have per-agent context window limits like Amp, so this is functionally identical to build but serves as a mental mode switch for the user.

---

## Task 6: Write `oracle.md` -- second opinion subagent

**Files:**
- Create: `config/opencode/agents/oracle.md`

**Strategy:** Focused role prompt. Read-only. Different model family (GPT-5.4) for genuine analytical diversity from Claude main agent. Adapted from Amp's oracle tool description.

The oracle is a consultant, not an executor. It reviews, plans, debugs, and provides expert guidance -- but never edits code.

- [ ] **Step 1: Create oracle.md**

Frontmatter:
```yaml
---
description: Second opinion powered by GPT-5.4. For complex reasoning, plan review, debugging, and architecture analysis. Read-only -- consults but does not execute.
mode: subagent
model: openai/gpt-5.4
reasoningEffort: high
permission:
  edit: deny
  bash:
    "*": deny
    "git diff*": allow
    "git log*": allow
    "git blame*": allow
    "git show*": allow
---
```

Body: Role-specific prompt (~30-40 lines) covering:
1. "You are a consulting advisor, not an executor"
2. What to use oracle for: code reviews, architecture feedback, debugging complex flows, planning implementations, alternative viewpoints
3. What NOT to use oracle for: simple file reads, codebase searches, code modifications
4. "Be specific about findings. Reference file paths and line numbers."

Reference: `/tmp/amp-reference/tool-oracle.md` for Amp's oracle tool description.

---

## Task 7: Write `review.md` -- code review subagent

**Files:**
- Create: `config/opencode/agents/review.md`

**Strategy:** Focused role prompt. Read-only. Gemini 3.1 Pro for deep analysis and bug identification (Amp's choice). Adapted from Amp's review model behavior.

- [ ] **Step 1: Create review.md**

Frontmatter:
```yaml
---
description: Code review and bug identification powered by Gemini. Read-only. Surfaces bugs, risks, and actionable feedback while filtering noise.
mode: subagent
model: google/gemini-3.1-pro-preview
temperature: 0.1
permission:
  edit: deny
  bash:
    "*": deny
    "git diff*": allow
    "git log*": allow
    "git blame*": allow
    "git show*": allow
---
```

Body: Role-specific prompt (~30-40 lines) covering:
1. "You are a code reviewer. Prioritize identifying bugs, risks, behavioral regressions, and missing tests."
2. "Present findings first, ordered by severity with file/line references."
3. "Keep summaries brief -- findings are the primary focus."
4. "If no issues found, state explicitly and mention residual risks or testing gaps."

Reference: Amp's smart mode prompt has a detailed "review" section that describes exactly this behavior. `/tmp/amp-reference/prompt-smart-mode.md` section on reviews.

---

## Task 8: Write `research.md` -- fast codebase search subagent

**Files:**
- Create: `config/opencode/agents/research.md`

**Strategy:** Focused role prompt. Read-only. Gemini 3 Flash for speed and parallel tool calls. Similar to OpenCode's built-in explore agent but with Amp's finder philosophy: diverse queries, parallel execution, conclude fast.

- [ ] **Step 1: Create research.md**

Frontmatter:
```yaml
---
description: Fast codebase search and retrieval powered by Gemini Flash. For finding code by behavior or concept, correlating patterns across files, and answering codebase questions.
mode: subagent
model: google/gemini-3-flash-preview
permission:
  edit: deny
  bash:
    "*": deny
    "git log*": allow
    "git show*": allow
  webfetch: deny
---
```

Body: Adapted from OpenCode's explore.txt + Amp's finder tool description (~25 lines):
1. "You are a codebase search specialist."
2. "Use Glob for file patterns, Grep for content search, Read for specific files."
3. "Run independent searches in parallel. Fire off multiple queries simultaneously."
4. "Formulate precise engineering queries, not vague searches."
5. "Return file paths as absolute paths. Include line numbers."

Reference: `/tmp/amp-reference/opencode-agent-explore.txt` and `/tmp/amp-reference/tool-finder.md`.

---

## Task 9: Write `librarian.md` -- external code research subagent

**Files:**
- Create: `config/opencode/agents/librarian.md`

**Strategy:** Focused role prompt. Read-only but with webfetch access for external code research. Claude Sonnet 4.6 for tool-calling dexterity across repositories. Adapted from Amp's librarian tool description.

- [ ] **Step 1: Create librarian.md**

Frontmatter:
```yaml
---
description: Deep research on external codebases, libraries, and documentation. Powered by Claude Sonnet. For understanding how dependencies work, exploring open-source implementations, and cross-repo analysis.
mode: subagent
model: anthropic/claude-sonnet-4-6
permission:
  edit: deny
  bash:
    "*": deny
    "git log*": allow
    "git show*": allow
---
```

Body: Role-specific prompt (~25-30 lines) covering:
1. "You are a research specialist for understanding external codebases and libraries."
2. "Use WebFetch to read documentation, source code on GitHub, and API references."
3. "Provide thorough, documentation-quality responses."
4. "When answering, show findings in full -- do not summarize excessively."
5. What to use librarian for: understanding complex codebases, exploring cross-repo relationships, finding specific implementations, understanding code evolution
6. What NOT to use for: local file reads, code modifications, simple searches

Reference: `/tmp/amp-reference/tool-librarian.md` for Amp's librarian description.

---

## Task 10: Write `lookat.md` -- media analysis subagent

**Files:**
- Create: `config/opencode/agents/lookat.md`

**Strategy:** Focused role prompt. Read-only. Gemini 3 Flash for multimodal analysis. Adapted from Amp's look_at tool description.

- [ ] **Step 1: Create lookat.md**

Frontmatter:
```yaml
---
description: Image, PDF, and media file analysis powered by Gemini Flash. For extracting information from visual content, diagrams, mockups, and documents.
mode: subagent
model: google/gemini-3-flash-preview
permission:
  edit: deny
  bash:
    "*": deny
  webfetch: deny
---
```

Body: Role-specific prompt (~15-20 lines) covering:
1. "You analyze images, PDFs, and media files to extract specific information."
2. "Always provide a clear objective for what you're extracting."
3. "For source code or plain text, use Read instead."
4. "Describe visual content precisely -- layouts, UI elements, diagrams, data."

Reference: `/tmp/amp-reference/tool-lookat.md` for Amp's look_at description.

---

## Task 11: Disable replaced built-in agents

**Files:**
- Modify: `config/opencode/opencode.json`

- [ ] **Step 1: Add agent overrides to opencode.json**

Add to the top-level config:

```json
"agent": {
  "plan": { "disable": true },
  "general": { "disable": true },
  "explore": { "disable": true }
}
```

`plan` is replaced by build + oracle consultation. `general` and `explore` are replaced by our specialized subagents.

---

## Task 12: Update documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/architecture.md`

- [ ] **Step 1: Update README.md**

Update the AI tools row and config tree to reflect the new agents directory.

- [ ] **Step 2: Update docs/architecture.md**

Add a section documenting the agent architecture: which agents exist, their models, roles, and the prompt strategy (no-prompt vs custom-prompt).

---

## Task 13: Verify

- [ ] **Step 1: Rebuild nix**

```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin --impure
```

- [ ] **Step 2: Confirm agents directory is symlinked**

```bash
ls -la ~/.config/opencode/agents/
```

- [ ] **Step 3: Confirm agents appear in opencode**

Launch opencode and verify:
- Tab cycles: build, deep, quick, large
- @mention shows: oracle, review, research, librarian, lookat
- Built-in plan, general, explore are gone
