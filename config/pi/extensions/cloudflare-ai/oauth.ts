/**
 * cloudflared OAuth subprocess wrapper for the cloudflare-ai pi extension.
 *
 * Spawns `cloudflared access login` for SSO and `cloudflared access token`
 * for fresh JWTs. App-agnostic — the caller passes the app URL, so this
 * module is reusable for any cloudflared OAuth provider.
 *
 * Cancellation: callbacks.signal SIGTERMs the subprocess on Esc.
 * cloudflared's own SSO timeout governs login duration; this module
 * does not impose its own.
 */

import { spawn, type ChildProcess } from "node:child_process";
import type { OAuthCredentials, OAuthLoginCallbacks } from "@mariozechner/pi-ai";

const URL_REGEX = /https?:\/\/[^\s"']+/;

interface RunOpts {
	signal?: AbortSignal;
	onStderr?: (line: string) => void;
}

interface RunResult {
	stdout: string;
	stderr: string;
	code: number;
}

function runCloudflared(args: string[], opts: RunOpts = {}): Promise<RunResult> {
	return new Promise((resolve) => {
		const child: ChildProcess = spawn("cloudflared", args, {
			stdio: ["ignore", "pipe", "pipe"],
		});
		let stdout = "";
		let stderr = "";

		child.stdout?.on("data", (chunk: Buffer) => {
			stdout += chunk.toString();
		});
		child.stderr?.on("data", (chunk: Buffer) => {
			const text = chunk.toString();
			stderr += text;
			if (opts.onStderr) {
				for (const line of text.split("\n")) {
					if (line.trim()) opts.onStderr(line.trim());
				}
			}
		});

		const onAbort = () => {
			if (!child.killed) child.kill("SIGTERM");
		};

		if (opts.signal) {
			if (opts.signal.aborted) onAbort();
			else opts.signal.addEventListener("abort", onAbort);
		}

		const cleanup = () => {
			opts.signal?.removeEventListener("abort", onAbort);
		};

		child.on("close", (code) => {
			cleanup();
			resolve({ stdout, stderr, code: code ?? 1 });
		});

		child.on("error", (err) => {
			cleanup();
			resolve({ stdout, stderr: stderr + err.message, code: 1 });
		});
	});
}

function decodeJwtExp(jwt: string): number {
	const parts = jwt.split(".");
	if (parts.length !== 3) throw new Error("invalid JWT shape");
	const payload = JSON.parse(
		Buffer.from(parts[1], "base64url").toString("utf8"),
	) as { exp?: number };
	if (!payload.exp) throw new Error("JWT missing exp claim");
	return payload.exp;
}

export async function captureToken(
	appUrl: string,
	opts: { signal?: AbortSignal } = {},
): Promise<OAuthCredentials> {
	const result = await runCloudflared(["access", "token", "--app", appUrl], opts);
	const jwt = result.stdout.trim();
	if (!jwt || result.code !== 0) {
		throw new Error(
			`cloudflared access token returned empty/error: ${result.stderr || "(no stderr)"}`,
		);
	}
	const exp = decodeJwtExp(jwt);
	return {
		refresh: "", // cloudflared owns the SSO session; no separate refresh token
		access: jwt,
		expires: exp * 1000 - 5 * 60 * 1000, // 5min buffer
	};
}

export async function loginViaCloudflared(
	appUrl: string,
	callbacks: OAuthLoginCallbacks,
): Promise<OAuthCredentials> {
	callbacks.onProgress?.("Running cloudflared access login... browser will open.");

	let urlEmitted = false;
	const loginResult = await runCloudflared(
		["access", "login", "--no-verbose", `-app=${appUrl}`],
		{
			signal: callbacks.signal,
			onStderr: (line) => {
				// cloudflared prints "Please open the following URL in your browser: <url>"
				// to stderr. Capture the URL once and surface to onAuth (pi opens it).
				// Other stderr lines flow to onProgress.
				if (!urlEmitted) {
					const match = line.match(URL_REGEX);
					if (match) {
						urlEmitted = true;
						callbacks.onAuth?.({ url: match[0] });
						return;
					}
				}
				callbacks.onProgress?.(line);
			},
		},
	);

	if (loginResult.code !== 0) {
		throw new Error(
			`cloudflared login failed (exit ${loginResult.code}): ${loginResult.stderr || "(no stderr)"}`,
		);
	}

	callbacks.onProgress?.("SSO complete; capturing token...");
	return captureToken(appUrl, { signal: callbacks.signal });
}

export async function refreshViaCloudflared(
	appUrl: string,
	_creds: OAuthCredentials,
): Promise<OAuthCredentials> {
	// cloudflared persists the SSO session across token requests (multi-day TTL).
	// Just re-fetch a fresh JWT; if empty, throw to force re-login.
	return captureToken(appUrl);
}
