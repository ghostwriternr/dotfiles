# Oracle Gap-Audit Prompt Template

Ready-to-adapt prompt for dispatching Oracle to audit a proposed agent prompt rewrite. Replace the `<PLACEHOLDERS>`.

## When to use

After drafting a new body for an agent `.md` file and BEFORE applying it live. For body rewrites and large additions only — frontmatter-only changes do not need this.

## The Prompt

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
