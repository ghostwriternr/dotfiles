---
name: amp-audit
description: Use when checking if agent configurations are up to date with Amp's latest models, prompts, or features. Triggers on "amp audit", "audit agents", "check models", "agents feel stale", "update agent config", or after Amp ships an update.
---

# Amp Audit

Compare our OpenCode agent roster against Amp's current state. Covers model assignments, prompt content, and new features.

## Prerequisites

- Amp CLI installed and authed at `~/.amp/bin/amp`
- Agent files at `~/.config/nix-darwin/config/opencode/agents/`
- Internet access for fetching `ampcode.com/models` and `ampcode.com/chronicle`

## Our Agent Roster (baseline)

| Agent | Mode | Model | Amp Equivalent |
|---|---|---|---|
| build | primary | anthropic/claude-opus-4-6 | Smart mode |
| deep | primary | openai/gpt-5.4 | Deep mode |
| quick | primary | anthropic/claude-haiku-4-5 | Rush mode |
| large | primary | anthropic/claude-opus-4-6 | Large mode |
| oracle | subagent | openai/gpt-5.4 | Oracle tool |
| review | subagent | google/gemini-3.1-pro-preview | Review feature |
| research | subagent | google/gemini-3-flash-preview | Search/Finder |
| librarian | subagent | anthropic/claude-sonnet-4-6 | Librarian tool |
| lookat | subagent | google/gemini-3-flash-preview | Look At tool |

## Audit Process

### 0. Update Amp CLI

Always update before auditing. The binary is the source of truth -- a stale binary means a stale audit.

```bash
amp update
amp --version  # confirm the update, note the release timestamp
```

Report the version and release date at the top of the audit report.

Run all three checks below. Report findings at the end.

### 1. Model Assignments

Fetch Amp's current models page and compare against our roster.

```bash
# Fetch current Amp model assignments
webfetch https://ampcode.com/models
```

For each role in the table above, compare Amp's current model against ours. Flag any mismatches:

```
MISMATCH: oracle uses openai/gpt-5.4 but Amp now uses openai/gpt-5.5
  → Update config/opencode/agents/oracle.md frontmatter: model: openai/gpt-5.5
```

Also read each agent file's `model:` field from frontmatter to get the current local state:

```bash
# Extract model fields from all agent files
grep -r "^model:" ~/.config/nix-darwin/config/opencode/agents/
```

### 2. Prompt Content

Extract Amp's current system prompts from the binary and compare key sections against our prompts.

```bash
# Dump relevant prompt functions from the amp binary
strings ~/.amp/bin/amp | grep -A500 'function DO3' | head -550  # Smart mode
strings ~/.amp/bin/amp | grep -A300 'function ZO3' | head -350  # Deep mode (Codex)
strings ~/.amp/bin/amp | grep -A100 'function sw3' | head -120  # Rush mode
```

For each primary agent (deep, quick), compare:
- **Behavioral sections**: autonomy rules, pragmatism, scope constraints
- **Tool usage patterns**: which tools are emphasized, parallel execution rules
- **Communication style**: verbosity, update frequency, formatting rules
- **Frontend guidelines**: design principles, anti-slop rules

Flag ALL changes -- structural (new/removed sections) and wording. Amp iterates prompts deliberately; even a rewording likely fixes a behavioral issue they observed. Report wording changes with the original and new text so the user can judge whether to adopt.

```
PROMPT CHANGE (structural): deep mode now includes a "Security" section covering secret handling
  → Add security guidelines to config/opencode/agents/deep.md

PROMPT CHANGE (wording): rush mode changed "minimize tokens" to "minimize output tokens, think internally"
  → Original: "Minimize thinking time, minimize tokens, maximize action."
  → Current:  "Minimize output tokens, think internally, maximize action."
  → Consider updating config/opencode/agents/quick.md
```

For subagents, check the tool descriptions:

```bash
amp tools show oracle 2>&1
amp tools show librarian 2>&1
amp tools show look_at 2>&1
amp tools show finder 2>&1
```

Compare tool descriptions against our subagent prompt bodies. Flag new capabilities or changed boundaries.

### 3. New Features

Check for new agent modes, tools, or capabilities we don't cover.

```bash
# List all current tools
amp tools list 2>&1

# Check chronicle for recent announcements
webfetch https://ampcode.com/chronicle
```

Compare `amp tools list` against our agent roster. Flag tools that don't map to any of our agents. Check the chronicle for announcements about new modes, model changes, or architectural shifts since our last audit.

```
NEW FEATURE: Amp added a "Painter" tool using gemini-3-pro-image for image generation
  → Consider adding a painter.md subagent
```

## Report Format

Present findings as a structured report:

```
## Amp Audit Report — YYYY-MM-DD

### Model Mismatches
- [list of mismatches with suggested updates, or "None found"]

### Prompt Changes
- [list of significant prompt changes with suggestions, or "No significant changes"]

### New Features
- [list of new features not covered by our agents, or "None detected"]

### Summary
[one sentence: "X mismatches, Y prompt changes, Z new features detected" or "All agents are current"]
```

## Common Mistakes

- **Dismissing wording changes**: Amp iterates prompts deliberately. A rewording isn't cosmetic -- it likely fixed a behavioral issue. Always report the before/after so the user can judge.
- **Trusting the chronicle over the binary**: Model changes may ship without an announcement. The binary is the source of truth. Always extract from it, don't rely on the blog alone.
- **Not checking the binary**: The `/models` page shows model names but not prompt content. Always extract from the binary too.
- **Updating models without updating prompts**: If Amp moves a role to a different model family (e.g., Claude to Gemini), the prompt style may need to change too. Different model families respond to different prompting styles.
