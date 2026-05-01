/**
 * cloudflare-ai pi extension
 *
 * Routes requests through the corporate opencode-access Cloudflare Worker
 * (https://opencode.cloudflare.dev) to Cloudflare AI Gateway. Discovers
 * provider config from /.well-known/opencode and merges with models.dev
 * for full model metadata.
 *
 * Auth: cloudflared access JWT, captured by selecting `cloudflare-ai` from
 * pi's `/login` provider menu.
 * Pattern modelled on the bundled custom-provider-gitlab-duo example.
 *
 * Design invariants:
 * - The provider's `api` field is a custom string ("cloudflare-ai-api"). It
 *   keys into pi-ai's global api-registry Map, so a built-in name (e.g.
 *   "anthropic-messages") would replace pi's built-in provider.
 * - Each model's id matches what the upstream API expects in the request
 *   body. The worker's well-known publishes model ids verbatim for most
 *   providers; for Workers AI it publishes prefixed ids (e.g.
 *   `workers-ai/@cf/...`) because routing happens via AI Gateway's
 *   `/compat` endpoint. pi-ai serializes `model.id` straight into the
 *   upstream request body, so the id we register is the id sent.
 * - The provider config has no `apiKey`. pi forwards unset env-var names as
 *   literal strings, so a placeholder there would leak into requests. The
 *   JWT is read inside `streamCloudflareAI` from `options.apiKey`, which
 *   pi populates from OAuth credentials.
 * - Outgoing headers are the merge of `options.headers` (pi puts attribution
 *   headers there, sdk.js:199-207), `REQUIRED_HEADERS`, and `cf-access-token`.
 *   Later keys win, so the access token is authoritative.
 * - For the Anthropic backend, `x-api-key` is set to null in the outgoing
 *   headers. pi-ai requires a non-empty apiKey and the @anthropic-ai/sdk
 *   would otherwise emit `X-Api-Key: SENTINEL_API_KEY`, which the worker
 *   forwards untouched to AI Gateway. Null in `defaultHeaders` triggers the
 *   SDK's "explicit omit" path, letting AI Gateway's BYOK Anthropic
 *   credentials authenticate upstream.
 *
 * Source layout:
 * - oauth.ts  — cloudflared subprocess wrapper (login/refresh/JWT decode)
 * - models.ts — well-known + models.dev fetch, atomic cache, buildModels
 * - index.ts  — this file: provider registration + stream dispatch
 */

import { homedir } from "node:os";
import { join } from "node:path";
import {
	type Api,
	type AssistantMessageEventStream,
	type Context,
	type Model,
	type SimpleStreamOptions,
	streamSimpleAnthropic,
	streamSimpleGoogle,
	streamSimpleOpenAICompletions,
	streamSimpleOpenAIResponses,
} from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { buildPiMcpConfig, writePiMcpConfig } from "./mcp.js";
import { type Backend, type CFModel, buildModels, loadConfig } from "./models.js";
import { loginViaCloudflared, refreshViaCloudflared } from "./oauth.js";

const WORKER_URL = "https://opencode.cloudflare.dev";
const WELL_KNOWN_URL = `${WORKER_URL}/.well-known/opencode`;
const MODELS_DEV_URL = "https://models.dev/api.json";
const AGENT_DIR = join(homedir(), ".pi", "agent");
const CACHE_PATH = join(AGENT_DIR, "cloudflare-ai-cache.json");
const MCP_PATH = join(AGENT_DIR, "mcp.json");
const CACHE_TTL_MS = 5 * 60 * 1000;
const FETCH_TIMEOUT_MS = 5 * 1000;
const SENTINEL_API_KEY = "cloudflare-ai-sentinel"; // placeholder; the worker strips the Authorization header
const PROVIDER_API: Api = "cloudflare-ai-api" as Api; // custom api-registry key, distinct from any built-in

const REQUIRED_HEADERS: Record<string, string> = {
	"X-Requested-With": "xmlhttprequest",
};

const STREAM_FN_BY_BACKEND: Record<
	Backend,
	(
		model: Model<Api>,
		context: Context,
		options?: SimpleStreamOptions,
	) => AssistantMessageEventStream
> = {
	anthropic: streamSimpleAnthropic as any,
	"openai-responses": streamSimpleOpenAIResponses as any,
	google: streamSimpleGoogle as any,
	"workers-ai": streamSimpleOpenAICompletions as any,
};

function makeStreamFn(modelMap: Map<string, CFModel>) {
	return function streamCloudflareAI(
		model: Model<Api>,
		context: Context,
		options?: SimpleStreamOptions,
	): AssistantMessageEventStream {
		const cfg = modelMap.get(model.id);
		if (!cfg) {
			throw new Error(`[cloudflare-ai] unknown model: ${model.id}`);
		}

		// pi's OAuth pipeline puts the JWT on options.apiKey. The provider config
		// omits apiKey at the top level (see file-header invariants).
		const accessToken = options?.apiKey;
		if (!accessToken) {
			throw new Error(`[cloudflare-ai] no access token; run /login in pi and pick cloudflare-ai`);
		}

		// Bind the model to the proxy baseUrl. model.id is the raw upstream ID
		// and travels through to the provider untouched.
		const modelForInner = { ...model, baseUrl: cfg.baseUrl };

		// Merge order: caller's options first (so pi's attribution headers in
		// options.headers, sdk.js:199-207, survive), then REQUIRED_HEADERS, then
		// the access token. Later spreads win.
		const headers: Record<string, string> = {
			...options?.headers,
			...REQUIRED_HEADERS,
			"cf-access-token": accessToken,
		};

		// Anthropic backend: omit `x-api-key` from the outgoing request so AI
		// Gateway's BYOK Anthropic credentials handle upstream auth. pi-ai
		// requires a non-empty apiKey and the @anthropic-ai/sdk emits
		// `X-Api-Key` from the constructor's apiKey arg (sdk/client.js:123-128),
		// so we still pass SENTINEL_API_KEY and then null the resulting header
		// via `defaultHeaders`. sdk/internal/headers.js:60-63 reads null as
		// "explicitly omit". The worker forwards request headers unchanged to
		// AI Gateway.
		//
		// OpenAI: the worker deletes `Authorization` before forwarding, so the
		// sentinel from `apiKey` never reaches upstream.
		// Google: auth is via `?key=` query param, populated only when apiKey
		// looks like a real key; the sentinel is ignored.
		// Workers AI: routed through `/compat`, where AI Gateway BYOK provides
		// upstream auth and no `x-api-key`/`Authorization` header is consulted.
		if (cfg.backend === "anthropic") {
			(headers as Record<string, string | null>)["x-api-key"] = null;
		}

		const streamOptions: SimpleStreamOptions = {
			...options,
			apiKey: SENTINEL_API_KEY, // ignored upstream; required non-empty by pi-ai
			headers,
		};

		const innerFn = STREAM_FN_BY_BACKEND[cfg.backend];
		return innerFn(modelForInner, context, streamOptions);
	};
}

export default async function (pi: ExtensionAPI) {
	let cfg;
	try {
		cfg = await loadConfig({
			wellKnownUrl: WELL_KNOWN_URL,
			modelsDevUrl: MODELS_DEV_URL,
			cachePath: CACHE_PATH,
			cacheTtlMs: CACHE_TTL_MS,
			fetchTimeoutMs: FETCH_TIMEOUT_MS,
		});
	} catch (err) {
		console.error(`[cloudflare-ai] startup failed: ${(err as Error).message}`);
		return;
	}

	try {
		writePiMcpConfig(MCP_PATH, buildPiMcpConfig(cfg.wellKnown.config.mcp));
	} catch (err) {
		console.warn(`[cloudflare-ai] MCP config write failed: ${(err as Error).message}`);
	}

	const models = buildModels(cfg);
	if (models.length === 0) {
		console.warn("[cloudflare-ai] no models resolved; provider not registered");
		return;
	}

	const modelMap = new Map(models.map((m) => [m.id, m]));

	pi.registerProvider("cloudflare-ai", {
		baseUrl: WORKER_URL,
		// apiKey is omitted here; pi's OAuth pipeline supplies the JWT to
		// streamCloudflareAI via options.apiKey at request time.
		api: PROVIDER_API,
		models: models.map(({ id, name, reasoning, input, cost, contextWindow, maxTokens, compat }) => ({
			id,
			name,
			reasoning,
			input,
			cost,
			contextWindow,
			maxTokens,
			...(compat ? { compat } : {}),
		})),
		oauth: {
			name: "Cloudflare AI Gateway (corp)",
			login: (callbacks) => loginViaCloudflared(WORKER_URL, callbacks),
			refreshToken: (creds) => refreshViaCloudflared(WORKER_URL, creds),
			getApiKey: (cred) => cred.access,
		},
		streamSimple: makeStreamFn(modelMap),
	});
}
