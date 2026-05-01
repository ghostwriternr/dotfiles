import { mkdirSync, renameSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

interface WellKnownMcpServer {
	type?: string;
	url?: string;
	oauth?: Record<string, unknown>;
	[key: string]: unknown;
}

export interface WellKnownMcpConfig {
	[name: string]: WellKnownMcpServer;
}

interface PiMcpServer {
	url: string;
	auth?: "oauth";
	lifecycle: "lazy";
}

interface PiMcpConfig {
	mcpServers: Record<string, PiMcpServer>;
}

export function buildPiMcpConfig(mcp: WellKnownMcpConfig | undefined): PiMcpConfig {
	const mcpServers: Record<string, PiMcpServer> = {};

	for (const [name, server] of Object.entries(mcp ?? {})) {
		if (server.type !== "remote" || !server.url) continue;

		mcpServers[name] = {
			url: server.url,
			...(server.oauth ? { auth: "oauth" as const } : {}),
			lifecycle: "lazy",
		};
	}

	return { mcpServers };
}

export function writePiMcpConfig(path: string, config: PiMcpConfig): void {
	mkdirSync(dirname(path), { recursive: true });
	const tmpPath = `${path}.${process.pid}.tmp`;
	writeFileSync(tmpPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
	renameSync(tmpPath, path);
}
