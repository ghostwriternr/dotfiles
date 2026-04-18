# Oracle Gap-Audit Prompt Templates

Two templates: per-agent gap audit (use once per drafted agent) and final holistic audit (use once over the whole staged set). Replace the `<PLACEHOLDERS>`.

## When to use

- **Per-agent template**: after drafting a new body for a single agent file and BEFORE applying it live. Required for body rewrites and large additions; skip for frontmatter-only changes.
- **Holistic template**: after every per-agent draft in a batch has passed its per-agent audit. Catches cross-cutting issues (tool mismatches, task-permission escalation, missing files, parameter↔prompt tensions) that per-agent passes miss.

## Template 1 — Per-agent gap audit

```
## Task

Audit this proposed rewrite of <AGENT_NAME>.md. Be ruthless — flag ANYTHING present in the base prompt that is missing from the proposed prompt and is relevant to this agent's role, even if it seems minor. Also flag contradictions, over-boxing, or rotted references.

## Context

OpenCode agents with body content REPLACE the provider base prompt — they do not extend it. So every behaviour the agent needs must be present in the proposed prompt itself.

This is audit pass <N>. If a previous pass exists, focus on what prior review found plus anything new. Do not re-litigate issues already closed unless you see evidence they were not actually fixed.

## Files to read

**Proposed new prompt (the draft under review):**
<PATH_TO_DRAFT>

**Base prompt the agent replaces:**
<PATH_TO_BASE>
(anthropic.txt for Claude agents; gpt.txt for OpenAI; gemini.txt for Gemini — at ~/github/opencode/packages/opencode/src/session/prompt/)

**Current live agent file (for diff context):**
config/opencode/agents/<AGENT_NAME>.md

**Upstream source(s) being ported from (if any):**
<PATHS — e.g. ~/github/oh-my-openagent/src/agents/oracle.ts, or extracted Amp prompt text>

## Report format

For this agent, produce:

1. **Covered gaps** — lines/sections of the base prompt the proposed draft correctly addresses (brief list, no need for full quotes).
2. **Remaining gaps** — lines/sections of the base prompt that are MISSING from the proposed draft AND relevant to this agent's role. Quote the source lines. For each gap, recommend: ADD (integrate into draft), SKIP (intentional — justify why), or ADAPT (different wording needed for this role).
3. **Contradictions** — places where the proposed draft says one thing while the base prompt, the upstream source, or the frontmatter permissions say another.
4. **Over-boxing** — phrases that duplicate permission restrictions in prose, or that suppress tool use (e.g. "you do not execute", "read-only" read too strictly). Recommend rewording.
5. **Rotted references** — anything citing upstream symbols, line numbers, or version-specific behaviour that will drift. Recommend replacing with discovery recipes.
6. **Bottom line** — one sentence: "N remaining gaps, M contradictions, K over-boxing issues, J rotted references" OR "No issues — ready to ship."

Be direct. The only wrong answer is to gloss over something real.
```

## Iteration

1. First pass usually surfaces structural gaps — missing sections, forgotten base-prompt directives.
2. Second pass surfaces wording issues and contradictions.
3. Third pass usually catches the last over-boxing and any rotted references.
4. Stop when Oracle reports "No issues".

If a fourth pass is still surfacing real issues, the draft may be fundamentally off — step back and re-read the base prompt yourself before continuing to iterate.

## Anti-pattern

Do NOT ask Oracle to "confirm the draft is good" or "verify no gaps". Those framings encourage positive bias. Ask it to find problems.

## Template 2 — Holistic final audit

Run this once, after every per-agent pass has cleared. It finds the cross-cutting issues per-agent passes miss.

```
## Task

FINAL review of the complete proposed agent system — prompts, frontmatters, permissions, parameters, and global config together. All per-agent gap audits have already passed. Your job: find anything that only shows up when the system is viewed as a whole.

Previous per-agent passes covered: replacement-semantics gaps, base-prompt content, over-boxing, rotted references. Do not re-litigate those unless you see a regression.

## Context

OpenCode agents replace the provider base prompt when they have body content. Permissions are per-target for `task`. Tool availability depends on modelID (e.g. GPT gets `apply_patch` while others get `edit`/`write`). Native subagents like `general` appear in Task menus by default.

## Files to read

**Staged drafts (the complete proposed agent set):**
<PATHS — e.g. ~/Documents/notes/Engineering/Plans/nix-darwin/staging/YYYY-MM-DD-<topic>/*.md>

**Current live agents (for diff context):**
config/opencode/agents/*.md

**Global config that interacts with per-agent frontmatter:**
config/opencode/opencode.json

**OpenCode internals for cross-checking:**
~/github/opencode/packages/opencode/src/tool/registry.ts          (tool selection by model)
~/github/opencode/packages/opencode/src/agent/agent.ts            (native subagents)
~/github/opencode/packages/opencode/src/provider/transform.ts     (option defaults)
~/github/opencode/packages/opencode/src/permission/evaluate.ts    (permission semantics)

**Base prompts (for cross-family mismatch checks):**
~/github/opencode/packages/opencode/src/session/prompt/*.txt

## What to check

1. **Complete roster.** Is every agent in our roster represented in the staged set, OR explicitly intentional as unchanged? Flag missing files (`large.md` was forgotten last time).
2. **Tool ↔ model consistency.** For each agent, does the prompt reference the file-editing tool that its model actually receives per `tool/registry.ts`? GPT-family refers to `apply_patch`; others to `edit`/`write`. Flag every mismatch.
3. **Task permission escalation.** For any agent with `task` unlocked, does the permission allowlist explicitly scope dispatch targets? Unrestricted `task` exposes native `general` (edit-capable), creating both a distraction surface and a privilege path around `edit: deny`.
4. **Parameter ↔ prompt tensions.** Does any agent set high verbosity / reasoning while its prompt also imposes strict brevity caps? These fight at runtime.
5. **Global config interactions.** Does `opencode.json` undercut or reinforce per-agent frontmatter in ways the draft authors didn't intend? E.g. global `edit: ask` as a safety net, globally disabled agents that still appear referenced in prompts.
6. **Cross-family content leakage.** Does a Claude agent's prompt contain GPT-only response-channel language, or vice versa? Base prompts have family-specific sections that should not cross over.
7. **Rotted references.** Any stale mentions of "the base prompt" / "inherit from" / "override" in drafts — phrases that made sense in a previous shape but don't now.

## Report format

- **Must fix** — blocking issues with file:line evidence and concrete remediation
- **Consider** — non-blocking polish with recommendation
- **Confirmed** — what's coherent (brief)
- **Bottom line** — ship / do-not-ship, one sentence

Be direct. The only wrong answer is to pass the system and have me discover a cross-cutting issue after deploy.
```
