/**
 * Model discovery + cache for the cloudflare-ai pi extension.
 *
 * Fetches /.well-known/opencode (worker config) and api.json (models.dev),
 * merges them per-provider, caches at the supplied path with TTL.
 *
 * Per-provider candidate sourcing:
 *  - openai + cloudflare-workers-ai: worker-authoritative model list
 *    (worker dynamically populates these — full IDs, no models.dev needed)
 *  - anthropic + google: models.dev list (worker only sets baseURL/blacklist)
 *
 * Cache writes are atomic (tmp file + rename) so concurrent pi readers
 * always see a complete JSON document. Same pattern pi's auth-storage uses.
 */

import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

export type Backend = "anthropic" | "openai-responses" | "google" | "workers-ai";

export interface CFModel {
	id: string; // raw upstream ID — sent literally to the provider API
	name: string;
	backend: Backend;
	baseUrl: string;
	reasoning: boolean;
	input: ("text" | "image")[];
	cost: { input: number; output: number; cacheRead: number; cacheWrite: number };
	contextWindow: number;
	maxTokens: number;
	compat?: Record<string, unknown>; // explicit for workers-ai (proxy URL fools autodetect)
}

interface WellKnownProvider {
	name?: string;
	blacklist?: string[];
	whitelist?: string[];
	options?: { baseURL?: string };
	models?: Record<string, WellKnownModel>;
}

interface WellKnownModel {
	id?: string;
	name?: string;
	reasoning?: boolean;
	tool_call?: boolean;
	modalities?: { input?: string[]; output?: string[] };
	cost?: { input?: number; output?: number; cache_read?: number; cache_write?: number };
	limit?: { context?: number; output?: number };
	options?: { parallel_tool_calls?: boolean; [k: string]: unknown };
}

interface WellKnownConfig {
	auth: { command: string[]; env: string };
	config: {
		provider: Record<string, WellKnownProvider>;
		mcp?: import("./mcp.js").WellKnownMcpConfig;
	};
}

interface ModelsDevModel {
	id?: string;
	name?: string;
	reasoning?: boolean;
	modalities?: { input?: string[]; output?: string[] };
	cost?: { input?: number; output?: number; cache_read?: number; cache_write?: number };
	limit?: { context?: number; output?: number };
}

interface ModelsDevPayload {
	[providerKey: string]: { models?: Record<string, ModelsDevModel> };
}

export interface CachedConfig {
	fetchedAt: number;
	wellKnown: WellKnownConfig;
	modelsDev: ModelsDevPayload;
}

const BACKEND_BY_PROVIDER_KEY: Record<string, Backend> = {
	anthropic: "anthropic",
	openai: "openai-responses",
	google: "google",
	"cloudflare-workers-ai": "workers-ai",
};

const MODELS_DEV_KEY_BY_PROVIDER: Record<string, string> = {
	anthropic: "anthropic",
	openai: "openai",
	google: "google",
	"cloudflare-workers-ai": "workers-ai",
};

// Worker is the gatekeeper for OpenAI + Workers AI (it dynamically populates
// these). For Anthropic + Google the worker only sets baseURL/blacklist; the
// model list comes from models.dev (same as opencode itself).
const WORKER_AUTHORITATIVE = new Set(["openai", "cloudflare-workers-ai"]);

// Workers AI models aren't catalogued on models.dev, and the worker's well-known
// occasionally publishes a model without a `limit` block. The other Workers AI
// entries cluster at 131K–262K context and a uniform 32K output, so this
// fallback is the smallest context in the known set paired with that output
// ceiling. Used only for the cloudflare-workers-ai backend.
const WORKERS_AI_DEFAULT_LIMITS = { context: 131072, output: 32000 } as const;

async function fetchJson<T>(url: string, signal: AbortSignal): Promise<T> {
	const res = await fetch(url, { signal });
	if (!res.ok) throw new Error(`${url} → HTTP ${res.status}`);
	return (await res.json()) as T;
}

function readCache(cachePath: string): CachedConfig | null {
	try {
		return JSON.parse(readFileSync(cachePath, "utf8")) as CachedConfig;
	} catch {
		return null;
	}
}

function writeCache(cachePath: string, cache: CachedConfig): void {
	// Write to a pid-suffixed tmp file then rename, so a concurrent reader
	// always observes either the previous complete file or the new one.
	try {
		mkdirSync(dirname(cachePath), { recursive: true });
		const tmp = `${cachePath}.tmp-${process.pid}`;
		writeFileSync(tmp, JSON.stringify(cache, null, 2));
		renameSync(tmp, cachePath);
	} catch (err) {
		console.warn(`[cloudflare-ai] cache write failed: ${(err as Error).message}`);
	}
}

export interface LoadConfigOpts {
	wellKnownUrl: string;
	modelsDevUrl: string;
	cachePath: string;
	cacheTtlMs: number;
	fetchTimeoutMs: number;
}

export async function loadConfig(opts: LoadConfigOpts): Promise<CachedConfig> {
	const cached = readCache(opts.cachePath);
	if (cached && Date.now() - cached.fetchedAt < opts.cacheTtlMs) {
		return cached;
	}

	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), opts.fetchTimeoutMs);
	try {
		const [wellKnown, modelsDev] = await Promise.all([
			fetchJson<WellKnownConfig>(opts.wellKnownUrl, controller.signal),
			fetchJson<ModelsDevPayload>(opts.modelsDevUrl, controller.signal),
		]);
		const fresh: CachedConfig = { fetchedAt: Date.now(), wellKnown, modelsDev };
		writeCache(opts.cachePath, fresh);
		return fresh;
	} catch (fetchErr) {
		if (cached) {
			console.warn(
				`[cloudflare-ai] using stale cache (fetch failed: ${(fetchErr as Error).message})`,
			);
			return cached;
		}
		throw new Error(
			`[cloudflare-ai] could not fetch ${opts.wellKnownUrl} or ${opts.modelsDevUrl}, ` +
				`and no cache exists at ${opts.cachePath}. Network issue? ` +
				`Original error: ${(fetchErr as Error).message}`,
		);
	} finally {
		clearTimeout(timer);
	}
}

function pickModalities(input: string[] | undefined): ("text" | "image")[] {
	if (!input || input.length === 0) return ["text"];
	const filtered = input.filter((m): m is "text" | "image" => m === "text" || m === "image");
	return filtered.length > 0 ? filtered : ["text"];
}

function workersAiCompat(wk: WellKnownModel | undefined): Record<string, unknown> {
	// pi-ai's openai-completions provider autodetects Cloudflare Workers AI quirks
	// from baseURL ~= api.cloudflare.com (openai-completions.js:815-829). Our
	// proxy URL is opencode.cloudflare.dev/compat, so autodetect misses. We must
	// declare compat explicitly to get tools / system prompts / reasoning right.
	const compat: Record<string, unknown> = {
		supportsDeveloperRole: false, // Cloudflare uses "system" role, not "developer"
		supportsReasoningEffort: wk?.reasoning ?? false,
		requiresAssistantAfterToolResult: false,
	};
	if (wk?.options?.parallel_tool_calls !== undefined) {
		compat.supportsParallelToolCalls = wk.options.parallel_tool_calls;
	}
	return compat;
}

export function buildModels(cfg: CachedConfig): CFModel[] {
	const out: CFModel[] = [];

	for (const [providerKey, backend] of Object.entries(BACKEND_BY_PROVIDER_KEY)) {
		const provider = cfg.wellKnown.config.provider[providerKey];
		if (!provider) continue;

		const baseURL = provider.options?.baseURL;
		if (!baseURL) {
			console.warn(`[cloudflare-ai] provider ${providerKey} missing baseURL, skipping`);
			continue;
		}

		const wkModels = provider.models ?? {};
		const mdKey = MODELS_DEV_KEY_BY_PROVIDER[providerKey] ?? providerKey;
		const mdModels = cfg.modelsDev[mdKey]?.models ?? {};
		const blacklist = new Set(provider.blacklist ?? []);
		const whitelist = provider.whitelist ? new Set(provider.whitelist) : null;

		// Per-provider candidate sourcing
		const candidateIds = WORKER_AUTHORITATIVE.has(providerKey)
			? Object.keys(wkModels)
			: Object.keys(mdModels);

		for (const candidateId of candidateIds) {
			if (blacklist.has(candidateId)) continue;
			if (whitelist && !whitelist.has(candidateId)) continue;

			const wk = wkModels[candidateId];
			const md = mdModels[candidateId];

			// The worker's well-known may publish a separate `id` inside the
			// model object (e.g. workers-ai prefixes its compat-endpoint ids
			// with "workers-ai/"). When present, that's the id the upstream
			// API expects in the request body.
			const id = wk?.id ?? candidateId;

			const name = wk?.name ?? md?.name ?? candidateId;
			const reasoning = wk?.reasoning ?? md?.reasoning ?? false;
			const input = pickModalities(wk?.modalities?.input ?? md?.modalities?.input);

			const cost = {
				input: wk?.cost?.input ?? md?.cost?.input ?? 0,
				output: wk?.cost?.output ?? md?.cost?.output ?? 0,
				cacheRead: wk?.cost?.cache_read ?? md?.cost?.cache_read ?? 0,
				cacheWrite: wk?.cost?.cache_write ?? md?.cost?.cache_write ?? 0,
			};

			let contextWindow = wk?.limit?.context ?? md?.limit?.context;
			let maxTokens = wk?.limit?.output ?? md?.limit?.output;

			// Explicit-zero limits in models.dev mean the model is intentionally
			// listed but isn't a chat model (image generation, audio, etc.) — pi-ai's
			// chat/responses stream functions can't use it. Silent skip.
			if (contextWindow === 0 || maxTokens === 0) {
				continue;
			}

			// Workers AI models aren't on models.dev. When the worker omits a
			// `limit` block, fall back to a conservative default sized to the
			// smallest context in the rest of the catalog.
			if (backend === "workers-ai") {
				contextWindow ??= WORKERS_AI_DEFAULT_LIMITS.context;
				maxTokens ??= WORKERS_AI_DEFAULT_LIMITS.output;
			}

			// Null/undefined means neither source published limits. Surface a warning
			// so the worker- or models.dev-side gap is visible.
			if (contextWindow == null || maxTokens == null) {
				console.warn(
					`[cloudflare-ai] skipping ${providerKey}/${candidateId} — no context/output limits in well-known or models.dev`,
				);
				continue;
			}

			out.push({
				id, // RAW upstream id
				name,
				backend,
				baseUrl: baseURL,
				reasoning,
				input,
				cost,
				contextWindow,
				maxTokens,
				...(backend === "workers-ai" ? { compat: workersAiCompat(wk) } : {}),
			});
		}
	}

	return out;
}
