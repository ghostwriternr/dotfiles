---
name: auditing-agent-sources
description: Use when checking whether agent configurations in `config/opencode/agents/` are current with their upstream references. Triggers on "audit agents", "check models", "agents feel stale", "amp audit", "what's new in OpenCode/Amp/OMO", or after a major release from any of those upstreams.
---

# Auditing Agent Sources

Compare our OpenCode agents against three upstream sources (OpenCode itself, Amp, oh-my-openagent) and produce a structured report of deltas. This skill surfaces what changed. To apply changes, use `updating-opencode-agents`.

## Our agent roster — role mapping

| Role | Our agent (file) | Amp equivalent | OMO equivalent |
|---|---|---|---|
| Smart primary coding | build / large | Smart / Large mode | — |
| Deep reasoning | deep | Deep mode (Codex) | Hephaestus |
| Fast primary coding | quick | Rush mode | — |
| Second opinion | oracle | Oracle tool | Oracle |
| Code review | review | Review feature | — |
| Codebase search | research | Finder / Search | — |
| External research | librarian | Librarian tool | — |
| Image / vision | — (plugin) | Look At tool | — |

Roles are reasonably stable. Specific model strings, tool names, and function symbols rot — so this skill does **not** hardcode them. Always extract the live state.

```bash
# Live local state of our agents
grep -rE "^(model|description|mode|temperature|reasoningEffort):" ~/.config/nix-darwin/config/opencode/agents/
```

## Upstream sources

| Source | Local clone / binary | Cadence | Signal quality |
|---|---|---|---|
| OpenCode | `~/github/opencode` | Pull-driven (monthly-ish) | High — base prompts + assembly logic affect every agent |
| Amp | `~/.amp/bin/amp` + `ampcode.com` | Frequent (weeks) | High — Amp iterates deliberately |
| oh-my-openagent | `~/github/oh-my-openagent` | Irregular | Variable — opinionated ideas worth filtering |

**Update first, audit second.** A stale clone is a stale audit.

```bash
amp update && amp --version
( cd ~/github/opencode && git fetch && git log HEAD..@{u} --oneline | head -50 )
( cd ~/github/oh-my-openagent && git fetch && git log HEAD..@{u} --oneline | head -50 )
```

## Audit process

Run all three source-sections. Aggregate into one report at the end.

### Section 1: OpenCode

This is the most consequential source because OpenCode owns the base prompts our agents replace and the assembly logic that decides how our frontmatter interacts with those prompts.

**Base prompts:**

```bash
# Snapshot
ls ~/github/opencode/packages/opencode/src/session/prompt/
# anthropic.txt gpt.txt gemini.txt (maybe more)

# Compare base prompts against our local adaptations for each agent
# (we intentionally diverge — flag only changes that introduce new behaviour
# worth porting into our agents)
diff -u <last-audit-snapshot>/anthropic.txt ~/github/opencode/packages/opencode/src/session/prompt/anthropic.txt
```

**Assembly logic and option defaults:**

```bash
# What has moved in session prompt assembly and provider option normalisation since last audit?
( cd ~/github/opencode && git log --since="<last-audit-date>" -- \
    packages/opencode/src/session/llm.ts \
    packages/opencode/src/session/ \
    packages/opencode/src/provider/ )
```

Look for:
- Changes to how custom agent bodies combine with base prompts (replace vs extend semantics). If this has flipped, the entire `updating-opencode-agents` workflow may need revisiting.
- New or changed provider option defaults (e.g. verbosity / reasoning effort floors). These silently override agent frontmatter.
- New permission types, mode types, or fields in the agent config schema.

**New tools, plugins, or agent fields:**

```bash
rg -l "class.*Tool|registerTool|AgentConfig" ~/github/opencode/packages/opencode/src/
```

Report:
- `OPENCODE CHANGE (base prompt): anthropic.txt added a <section> → consider adapting in build/large/quick/librarian`
- `OPENCODE CHANGE (semantics): llm.ts now extends rather than replaces — revisit updating-opencode-agents skill`
- `OPENCODE NEW FIELD: agent frontmatter now supports <X> → consider adopting on <agents>`

### Section 2: Amp

Amp is a production-hardened reference for prompt wording and model choices. Extract the current state and compare role-by-role.

**Model assignments:**

```bash
webfetch https://ampcode.com/models
```

Compare the model Amp uses for each role against our agent's `model:` field. Flag mismatches.

**Prompt content from the binary:**

Amp ships as a minified binary. Function symbols change every release — do NOT hardcode them. Discover the current ones:

```bash
# Find anchor strings that Amp's prompts actually use, then extract surrounding context.
# Example anchors that have historically been stable: "You are an AI coding agent",
# "Rush mode", "Deep mode". Adjust as needed.
strings ~/.amp/bin/amp | rg -n "(You are|mode:|agent:|coding assistant)" | head -30

# Once you find an anchor, extract the surrounding function — typical prompts
# are 100-500 lines. Adjust -B/-A until you capture a full section.
strings ~/.amp/bin/amp | rg -B2 -A400 "<ANCHOR_STRING>" | head -500
```

If you cannot find a prompt via anchor strings, search the Amp changelog or chronicle for naming hints, then retry. Do not fall back to out-of-date function symbols.

**Tool descriptions:**

```bash
amp tools list
amp tools show <tool-name>
```

Compare tool descriptions against the corresponding subagent prompt bodies. Flag new capabilities or changed boundaries.

**Announcements:**

```bash
webfetch https://ampcode.com/chronicle
```

Look for: new modes, model family shifts, major prompt overhauls, architectural changes.

Report:
- `AMP MISMATCH: oracle uses <our-model> but Amp uses <amp-model>`
- `AMP PROMPT CHANGE (structural): Deep mode added <section> → consider porting to deep.md`
- `AMP PROMPT CHANGE (wording): Rush mode reworded "<before>" → "<after>" → consider for quick.md`
- `AMP NEW TOOL: <name> (<backing model>) → no matching agent, consider adding`

Wording changes matter. Amp iterates prompts deliberately — a reword usually fixes an observed behaviour. Always report the before/after so a human can judge.

### Section 3: oh-my-openagent

OMO has opinionated agent prompts that we have historically cherry-picked from (verbosity/uncertainty sections for oracle, routine-action-bias and exploration-hierarchy for deep).

```bash
# What changed since last audit in the agent prompts?
( cd ~/github/oh-my-openagent && git log --since="<last-audit-date>" --stat src/agents/ )

# Diff specific files we've ported from
diff -u <last-audit-snapshot>/oracle.ts ~/github/oh-my-openagent/src/agents/oracle.ts
diff -u <last-audit-snapshot>/hephaestus/gpt-5-4.ts ~/github/oh-my-openagent/src/agents/hephaestus/gpt-5-4.ts
```

Look for:
- Changes to the Oracle prompt (maps to our `oracle.md`).
- Changes to Hephaestus (maps to our `deep.md`).
- New agents whose role overlaps one of ours.

Report:
- `OMO CHANGE: oracle.ts added <section> → consider for oracle.md`
- `OMO NEW AGENT: <name> — <role description> → evaluate against our <similar agent>`

## Report format

```
## Agent-Source Audit — YYYY-MM-DD

Local state:
- <wc -l output for each agent file>
- <current models extracted from frontmatter>

Upstream versions:
- OpenCode: <git HEAD short SHA> (<date>)
- Amp: <amp --version>
- OMO: <git HEAD short SHA> (<date>)

### OpenCode
<findings, or "No relevant changes since last audit">

### Amp
<findings, or "No relevant changes since last audit">

### OMO
<findings, or "No relevant changes since last audit">

### Summary
<N OpenCode findings, M Amp findings, K OMO findings>

### Recommended next step
Use the `updating-opencode-agents` skill to apply the high-signal deltas.
```

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Hardcoding model strings or function symbols | Rots on every upstream release | Extract live state; use anchor-string search for binary-minified prompts |
| Auditing only Amp | OpenCode base prompts and OMO both affect agent behaviour | Run all three sections |
| Dismissing wording changes | Amp iterates deliberately — rewords usually fix real issues | Always report before/after |
| Trusting chronicle/blog over source | Changes ship without announcement | Binary + git log are the sources of truth |
| Updating models without updating prompts | Model-family changes may require prompt-style changes | Flag model-family shifts; they usually need paired prompt review |
| Treating roles as rigid | Our `librarian` may match Amp's `Finder` better than `Librarian` in a given release | Re-evaluate role mapping when upstream agents are renamed or refactored |

## Related Skills

- **`updating-opencode-agents`** — apply the deltas surfaced by this audit.
- **`superpowers:brainstorming`** — if the audit surfaces a fundamental architectural shift (e.g. replace→extend semantics changed), brainstorm before acting.
