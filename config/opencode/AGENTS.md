# OMO — User-Specific Context

## My Providers
anthropic, openai, google, workers-ai

## Known Constraints
- I don't use the OMO installer — config is manually maintained
- Model IDs in `opencode models` output are the canonical source of truth (not OMO docs or model-requirements.ts)
- User config overrides are unconditionally respected — match on MODEL name, not provider path

## Common Model ID Gotchas
- Google models need `-preview` suffix: `google/gemini-3-pro-preview`, `google/gemini-3-flash-preview`
- Workers-AI has double prefix: `workers-ai/workers-ai/@cf/moonshotai/kimi-k2.5`

## Config Audit
Run `omo audit` or invoke the `omo-model-audit` skill to validate config, fix model mismatches, and review release notes.
