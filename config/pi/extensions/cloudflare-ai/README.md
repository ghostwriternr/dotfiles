# cloudflare-ai pi extension

Routes pi requests through the corporate `opencode-access` Cloudflare Worker
(`https://opencode.cloudflare.dev`) to Cloudflare AI Gateway. Discovers
provider config from `/.well-known/opencode` and merges with `models.dev`
for full model metadata. Equivalent in spirit to opencode's
`opencode auth login https://opencode.cloudflare.dev`.

## Setup

1. Confirm `cloudflared` is on PATH and you're on WARP/VPN.
2. Launch pi, type `/login`, select `cloudflare-ai` from the provider menu.
   cloudflared opens a browser for SSO; the resulting JWT is stored at
   `~/.pi/agent/auth.json`.
3. `pi --provider cloudflare-ai --model claude-sonnet-4-6 -p "hi"`

The extension caches the merged config at
`~/.pi/agent/cloudflare-ai-cache.json` (5min TTL, atomic writes). On network
failure the cache is used as fallback. Safe to delete the cache file.

## Models

Live list comes from the worker; see <https://opencode.cloudflare.dev/.well-known/opencode>.
Worker blacklists/whitelists are honored automatically. Models without
context/output limits in either source are skipped (with a warning). Model
IDs match the provider's native format — `claude-sonnet-4-6`, `gpt-5.2-mini`,
`gemini-2.5-flash`, `@cf/moonshotai/kimi-k2.6`. No prefix.

## Troubleshooting

- `no access token` → in pi, run `/login` and pick `cloudflare-ai`
- `fetch failed and no cache` → check WARP/VPN; first run requires network
- After model bumps in the worker, run `/reload` in pi to refresh the cache
- TLS/cert errors: ensure pi was launched from a shell that sourced
  `~/.local/share/cloudflare-warp-certs/config.sh` (handled by this repo's
  `home/shell.nix:56-59` envExtra)

## Security

Extension runs with full system permissions per pi's extension model. Source
lives in `nix-darwin` repo; review before installing externally.
