---
name: omo-model-audit
description: Use when upgrading oh-my-openagent, checking model availability, fixing config mismatches, or after gaining access to new models. Triggers on 'omo audit', 'model mismatch', 'upgrade omo', 'check models', 'fix config'.
---

# OMO Model Audit

Audit and auto-fix oh-my-openagent model configuration. Copy the checklist below and track progress:

```
Audit Progress:
- [ ] Step 1: Version check & upgrade
- [ ] Step 2: Collect available models
- [ ] Step 3: Collect OMO recommendations
- [ ] Step 4: Read current config
- [ ] Step 5: Cross-reference (3-way diff)
- [ ] Step 6: Auto-fix mismatches
- [ ] Step 7: Verify zero unresolved refs
- [ ] Step 8: Release notes delta review
- [ ] Step 9: Update AGENTS.md
```

## Step 1: Version Check & Upgrade

```bash
npm view oh-my-openagent version                              # latest published
grep '"oh-my-openagent' ~/.config/opencode/opencode.json      # installed ref
```

If outdated: `npm update oh-my-openagent` (updates package only, preserves config).

## Step 2: Collect Available Models

```bash
opencode models 2>&1
```

**This output is the canonical source of truth for model IDs.** Every model in the config MUST appear here exactly as listed. Save the full output.

## Step 3: Collect OMO Recommendations

```bash
git clone --depth 1 https://github.com/code-yeongyu/oh-my-openagent.git /tmp/oh-my-openagent 2>/dev/null || git -C /tmp/oh-my-openagent pull
```

Read `/tmp/oh-my-openagent/src/shared/model-requirements.ts` — contains fallback chains for all agents and categories.

## Step 4: Read Current Config

Read `~/.config/opencode/oh-my-opencode.json`. Extract every `"model"` value from agents and categories.

## Step 5: Cross-Reference

For each configured model, run three checks:

**Check 0 — Is this model known-broken?** (per AGENTS.md constraints). Skip known-broken models in fallback chains the same way you'd skip models that don't exist.

**Check 1 — Does the model ID exist in `opencode models` output?**

Common breakage patterns:
- Missing suffixes: `gemini-3-pro` vs `gemini-3-pro-preview`
- Wrong provider prefix: `workers-ai/@cf/...` vs `workers-ai/workers-ai/@cf/...`
- Stale versions: migration map in `src/shared/migration/model-versions.ts`

**Check 2 — Does it match OMO's recommendation?**

Walk the fallback chain top-to-bottom. First entry whose provider the user has = recommendation (skip known-broken). If `requiresModel` is set and user lacks that model (or it's known-broken), OMO would skip the agent/category entirely — a user override is acceptable.

Remember: overrides match on MODEL, not provider (see AGENTS.md). Same model via different provider = correct alignment, not stale.

## Step 6: Auto-Fix

Fix in this priority order:
1. **Broken IDs** — model not in `opencode models` (ALWAYS fix)
2. **Known-broken models** — model exists but listed as broken in user context (fix, use next fallback)
3. **Stale recommendations** — OMO recommends a different model (not just different provider) for user's providers (fix)
4. **Intentional overrides** — user overrides for something OMO would skip (report, keep)

Use `edit` tool with `replaceAll` for model name fixes.

## Step 7: Verify

```bash
grep '"model"' ~/.config/opencode/oh-my-opencode.json | sed 's/.*"model": "//;s/".*//' | sort -u > /tmp/config_models.txt
opencode models 2>&1 | sort > /tmp/available_models.txt
comm -23 /tmp/config_models.txt /tmp/available_models.txt
```

**Output must be empty.** If not, return to Step 6 and fix remaining mismatches.

## Step 8: Release Notes Delta Review

Compare installed version to latest. Fetch all release notes between them:

```bash
# Get release list from GitHub
gh release list --repo code-yeongyu/oh-my-openagent --limit 30 2>/dev/null || \
  curl -s https://api.github.com/repos/code-yeongyu/oh-my-openagent/releases | grep '"tag_name"'
```

For each release between installed and latest, fetch and review:

```bash
gh release view vX.Y.Z --repo code-yeongyu/oh-my-openagent 2>/dev/null
```

Walk through changes **interactively** with the user. For each release, identify:
- **New hooks** → Ask: "Want to enable this? What behavior do you prefer?"
- **New config options** → Ask: "This new flag does X. Enable it?"
- **New agents/categories** → Ask: "New agent Y available. Configure it?"
- **Deprecated features** → Inform and remove from config if present
- **Breaking changes** → Flag and propose migration
- **Model changes** → Already handled by Steps 5-7, but note rationale

**This step is conversational.** Don't dump all notes at once — walk release by release, ask questions, let the user make decisions.

## Step 9: Update AGENTS.md

After the audit, update `~/.config/opencode/AGENTS.md` (or `rules/omo.md` if AGENTS.md doesn't exist) if any user-specific context changed:

1. **Providers**: Update if user gained/lost provider access
2. **Constraints**: Add newly discovered broken models (e.g., models that appear in `opencode models` but don't actually work)
3. **Gotchas**: Add any new model ID patterns discovered during the audit

## Output Format

```
## OMO Model Audit Results

**OMO Version**: installed vX.Y.Z, latest vA.B.C [UP TO DATE | UPGRADE AVAILABLE]
**Providers**: anthropic, openai, google, ...
**Checked**: N agents, M categories

### Fixes Applied
| Item | Before | After | Reason |
|------|--------|-------|--------|

### Intentional Overrides (kept)
| Item | Config | OMO Would... | Why Kept |
|------|--------|--------------|----------|

### Verification: [PASS | FAIL — N unresolved refs]

### Release Notes Reviewed
vX.Y.Z → vA.B.C (N releases)
User decisions: [list of config changes made from interactive review]

### AGENTS.md: [UPDATED | NO CHANGES NEEDED]
```
