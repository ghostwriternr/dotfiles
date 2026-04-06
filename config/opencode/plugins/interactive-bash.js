/**
 * Interactive Bash plugin for OpenCode
 *
 * Provides an `interactive_bash` tool that gives agents tmux-based
 * persistent terminal sessions. Supports: new-session, send-keys,
 * capture-pane, kill-session, list-sessions.
 *
 * Session names are auto-prefixed with oc-<sessionID>- to enforce
 * ownership and prevent collisions across OpenCode sessions.
 */

import { tool } from "@opencode-ai/plugin";
import { spawn } from "bun";

// ── Constants ────────────────────────────────────────────────────────────────

const ALLOWED_COMMANDS = [
  "new-session",
  "send-keys",
  "capture-pane",
  "kill-session",
  "list-sessions",
];

const ALLOWED_KEYS = [
  "Enter",
  "C-c",
  "Escape",
  "Tab",
  "Up",
  "Down",
  "Left",
  "Right",
];

const LABEL_RE = /^[a-zA-Z0-9_-]+$/;
const LABEL_MAX = 30;
const LINES_DEFAULT = 100;
const LINES_MIN = 1;
const LINES_MAX = 2000;
const TIMEOUT_MS = 60_000;
const SESSION_PREFIX = "oc";

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeSessionName(sessionID, label) {
  return `${SESSION_PREFIX}-${sessionID}-${label}`;
}

function sessionPrefix(sessionID) {
  return `${SESSION_PREFIX}-${sessionID}-`;
}

function validateLabel(label) {
  if (!label || typeof label !== "string") {
    return "session label is required";
  }
  if (label.length > LABEL_MAX) {
    return `session label must be at most ${LABEL_MAX} characters, got ${label.length}`;
  }
  if (!LABEL_RE.test(label)) {
    return "session label must match [a-zA-Z0-9_-]+";
  }
  return null;
}

function clampLines(n) {
  if (n == null) return LINES_DEFAULT;
  const val = Math.floor(Number(n));
  if (Number.isNaN(val)) return LINES_DEFAULT;
  return Math.max(LINES_MIN, Math.min(LINES_MAX, val));
}

async function runTmux(tmuxPath, args, timeoutMs = TIMEOUT_MS) {
  const proc = spawn([tmuxPath, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });

  const timer = setTimeout(() => {
    try {
      proc.kill();
    } catch {}
  }, timeoutMs);

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]).finally(() => clearTimeout(timer));

  return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode };
}

// ── Plugin ───────────────────────────────────────────────────────────────────

export const InteractiveBashPlugin = async (ctx) => {
  // Resolve tmux at init — cache the path
  let tmuxPath = null;
  try {
    const result = await runTmux("tmux", ["-V"], 5000);
    if (result.exitCode === 0) {
      tmuxPath = "tmux";
    }
  } catch {
    // tmux not found — will error on first use
  }

  // Per-OpenCode-session tracking: Map<sessionID, Set<tmuxSessionName>>
  const tracked = new Map();

  function getTracked(sessionID) {
    let set = tracked.get(sessionID);
    if (!set) {
      set = new Set();
      tracked.set(sessionID, set);
    }
    return set;
  }

  async function cleanupSession(sessionID) {
    const set = tracked.get(sessionID);
    if (!set) return;
    for (const name of set) {
      try {
        await runTmux(tmuxPath || "tmux", ["kill-session", "-t", name], 5000);
      } catch {
        // best-effort
      }
    }
    tracked.delete(sessionID);
  }

  return {
    tool: {
      interactive_bash: tool({
        description: [
          "Manage persistent terminal sessions via tmux. Use for long-running processes",
          "(dev servers, watchers), interactive TUI programs (vim, debuggers, REPLs),",
          "and running parallel commands.",
          "",
          "Commands:",
          '  new-session   — create a session. Provide a label like "dev".',
          "                  Optional: cwd (working directory), shell_command (run immediately).",
          "  send-keys     — send input to a session.",
          "                  Use text + enter:true to type a command and press Enter.",
          '                  Use key for special keys: "C-c", "Enter", "Escape", "Tab", "Up", "Down", "Left", "Right".',
          "  capture-pane  — read terminal output from a session. Optional: lines (default 100).",
          "  kill-session  — destroy a session. Always clean up when done.",
          "  list-sessions — see your active sessions.",
          "",
          "Session names are auto-prefixed for isolation — just provide a short label.",
          "",
          "Example: start a dev server, check output, then stop it:",
          '  1. command: "new-session", session: "dev"',
          '  2. command: "send-keys",   session: "dev", text: "npm run dev", enter: true',
          '  3. command: "capture-pane", session: "dev"',
          '  4. command: "send-keys",   session: "dev", key: "C-c"',
          '  5. command: "kill-session", session: "dev"',
        ].join("\n"),

        args: {
          command: tool.schema
            .enum(ALLOWED_COMMANDS)
            .describe(
              "The tmux operation to perform: new-session, send-keys, capture-pane, kill-session, list-sessions"
            ),
          session: tool.schema
            .string()
            .optional()
            .describe(
              'Short label for the session (e.g. "dev", "tests"). Required for all commands except list-sessions. Auto-prefixed for isolation.'
            ),
          text: tool.schema
            .string()
            .optional()
            .describe(
              "Literal text to type into the session (send-keys only). Mutually exclusive with key."
            ),
          key: tool.schema
            .enum(ALLOWED_KEYS)
            .optional()
            .describe(
              "Special key to send (send-keys only): Enter, C-c, Escape, Tab, Up, Down, Left, Right. Mutually exclusive with text."
            ),
          enter: tool.schema
            .boolean()
            .optional()
            .describe(
              "If true, press Enter after sending text (send-keys only). Default: false."
            ),
          cwd: tool.schema
            .string()
            .optional()
            .describe(
              "Working directory for the new session (new-session only). Defaults to project directory."
            ),
          shell_command: tool.schema
            .string()
            .optional()
            .describe(
              'Command to run immediately in the new session (new-session only), e.g. "npm run dev".'
            ),
          lines: tool.schema
            .number()
            .optional()
            .describe(
              "Number of scrollback lines to capture (capture-pane only). Default: 100, max: 2000."
            ),
        },

        async execute(args, context) {
          // ── Validate command ───────────────────────────────────────
          if (!ALLOWED_COMMANDS.includes(args.command)) {
            return `Error: unknown command "${args.command}". Allowed: ${ALLOWED_COMMANDS.join(", ")}`;
          }

          // ── Check tmux availability ────────────────────────────────
          if (!tmuxPath) {
            return "Error: tmux is not installed. Add tmux to home.packages in home.nix and run darwin-rebuild switch.";
          }

          const sid = context.sessionID;
          const prefix = sessionPrefix(sid);

          // ── list-sessions (no session label needed) ────────────────
          if (args.command === "list-sessions") {
            const result = await runTmux(tmuxPath, [
              "list-sessions",
              "-F",
              "#{session_name}",
            ]);
            // tmux exits non-zero when no server is running
            if (result.exitCode !== 0) {
              return "No active sessions.";
            }
            const owned = result.stdout
              .split("\n")
              .filter((line) => line.startsWith(prefix))
              .map((line) => line.slice(prefix.length));
            if (owned.length === 0) {
              return "No active sessions.";
            }
            return `Active sessions:\n${owned.map((l) => `  - ${l}`).join("\n")}`;
          }

          // ── Validate session label ─────────────────────────────────
          const labelError = validateLabel(args.session);
          if (labelError) {
            return `Error: ${labelError}`;
          }

          const name = makeSessionName(sid, args.session);

          // ── Ownership check (trivially true by construction) ───────
          if (!name.startsWith(prefix)) {
            return "Error: session ownership validation failed.";
          }

          // ── new-session ────────────────────────────────────────────
          if (args.command === "new-session") {
            const tmuxArgs = ["new-session", "-d", "-s", name];
            if (args.cwd) {
              tmuxArgs.push("-c", args.cwd);
            } else {
              tmuxArgs.push("-c", context.directory);
            }
            if (args.shell_command) {
              tmuxArgs.push(args.shell_command);
            }
            const result = await runTmux(tmuxPath, tmuxArgs);
            if (result.exitCode !== 0) {
              return `Error: ${result.stderr || `tmux exited with code ${result.exitCode}`}`;
            }
            getTracked(sid).add(name);
            return `Session "${args.session}" created.`;
          }

          // ── send-keys ──────────────────────────────────────────────
          if (args.command === "send-keys") {
            if (args.text != null && args.key != null) {
              return 'Error: provide either "text" or "key", not both.';
            }
            if (args.text == null && args.key == null) {
              return 'Error: send-keys requires either "text" or "key".';
            }

            if (args.key != null) {
              if (!ALLOWED_KEYS.includes(args.key)) {
                return `Error: unknown key "${args.key}". Allowed: ${ALLOWED_KEYS.join(", ")}`;
              }
              const result = await runTmux(tmuxPath, [
                "send-keys",
                "-t",
                name,
                args.key,
              ]);
              if (result.exitCode !== 0) {
                return `Error: ${result.stderr || `tmux exited with code ${result.exitCode}`}`;
              }
              return `Sent key "${args.key}" to "${args.session}".`;
            }

            // text mode — use -l for literal (no key interpretation)
            const result = await runTmux(tmuxPath, [
              "send-keys",
              "-t",
              name,
              "-l",
              "--",
              args.text,
            ]);
            if (result.exitCode !== 0) {
              return `Error: ${result.stderr || `tmux exited with code ${result.exitCode}`}`;
            }

            // Optionally send Enter after text
            if (args.enter) {
              const enterResult = await runTmux(tmuxPath, [
                "send-keys",
                "-t",
                name,
                "Enter",
              ]);
              if (enterResult.exitCode !== 0) {
                return `Error sending Enter: ${enterResult.stderr || `tmux exited with code ${enterResult.exitCode}`}`;
              }
            }

            const enterNote = args.enter ? " + Enter" : "";
            return `Sent text to "${args.session}"${enterNote}.`;
          }

          // ── capture-pane ───────────────────────────────────────────
          if (args.command === "capture-pane") {
            const lineCount = clampLines(args.lines);
            const result = await runTmux(tmuxPath, [
              "capture-pane",
              "-p",
              "-t",
              name,
              "-S",
              `-${lineCount}`,
            ]);
            if (result.exitCode !== 0) {
              return `Error: ${result.stderr || `tmux exited with code ${result.exitCode}`}`;
            }
            return result.stdout || "(empty)";
          }

          // ── kill-session ───────────────────────────────────────────
          if (args.command === "kill-session") {
            const result = await runTmux(tmuxPath, [
              "kill-session",
              "-t",
              name,
            ]);
            if (result.exitCode !== 0) {
              return `Error: ${result.stderr || `tmux exited with code ${result.exitCode}`}`;
            }
            getTracked(sid).delete(name);
            return `Session "${args.session}" destroyed.`;
          }

          return `Error: unhandled command "${args.command}".`;
        },
      }),
    },

    // ── Cleanup: kill tracked tmux sessions when OpenCode session ends ────
    event: async ({ event }) => {
      if (event.type === "session.deleted") {
        const sessionID = event.properties?.info?.id;
        if (sessionID) {
          await cleanupSession(sessionID);
        }
      }
    },
  };
};
