/**
 * Look At plugin for OpenCode
 *
 * Provides a `look_at` tool that forwards images to a vision-capable model
 * in a child session. Solves the problem where pasted images can't reach
 * subagents through the `task` tool (which only forwards text).
 *
 * Three input modes:
 *   1. Pasted image: call with just `goal` — finds the image from the conversation
 *   2. File on disk: provide `file_path`
 *   3. Raw base64: provide `image_data` (programmatic use)
 */

import { tool } from "@opencode-ai/plugin";
import fs from "fs/promises";
import path from "path";

const VISION_PROVIDER = "google";
const VISION_MODEL = "gemini-3-flash-preview";

const SYSTEM_PROMPT = `You interpret media files that cannot be read as plain text.

Your job: examine the attached file and extract ONLY what was requested.

Guidelines:
- For UI screenshots: identify components, layout, interactive elements, text, visual hierarchy.
- For diagrams/flowcharts: identify nodes, labels, connections, flow direction.
- For documents/PDFs: extract headings, sections, main content. Preserve table structure.
- For charts/graphs: identify chart type, axis labels, units, data points, trends.
- Be precise with colors, positions, and labels. Use positional references (top-left, center, etc.).
- If content is partially obscured or ambiguous, say so explicitly.
- Your output goes straight to the main agent for continued work.`;

/**
 * Search session messages for the most recent image attachment.
 */
async function findImageInSession(client, sessionID) {
  const result = await client.session.messages({ path: { id: sessionID } });
  const messages = result.data || [];

  for (const msg of [...messages].reverse()) {
    if (msg.info?.role !== "user") continue;
    const parts = msg.parts || [];
    for (const part of [...parts].reverse()) {
      if (part.type === "file" && part.mime?.startsWith("image/")) {
        return { url: part.url, mime: part.mime, filename: part.filename };
      }
      // Also check for PDFs
      if (part.type === "file" && part.mime === "application/pdf") {
        return { url: part.url, mime: part.mime, filename: part.filename };
      }
    }
  }
  return null;
}

/**
 * Parse base64 data that may or may not have a data: URI prefix.
 */
function parseBase64(data) {
  if (data.startsWith("data:")) {
    const match = data.match(/^data:([^;]+);base64,(.*)$/);
    if (match) {
      return { url: data, mime: match[1] };
    }
  }
  return {
    url: `data:image/png;base64,${data}`,
    mime: "image/png",
  };
}

/**
 * Guess MIME type from file extension.
 */
function guessMime(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const map = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
    ".pdf": "application/pdf",
    ".heic": "image/heic",
    ".heif": "image/heif",
    ".bmp": "image/bmp",
    ".tiff": "image/tiff",
    ".tif": "image/tiff",
  };
  return map[ext] || "application/octet-stream";
}

export const LookAtPlugin = async (ctx) => {
  return {
    tool: {
      look_at: tool({
        description:
          "Analyze an image, PDF, or visual file using a vision-capable model. " +
          "For pasted images: call with just a goal — the pasted image is found automatically from the conversation. " +
          "For files on disk: provide file_path. " +
          "Returns a text description or analysis.",
        args: {
          goal: tool.schema
            .string()
            .describe(
              "What specific information to extract or analyze from the image"
            ),
          file_path: tool.schema
            .string()
            .optional()
            .describe("Absolute path to an image or PDF file on disk"),
          image_data: tool.schema
            .string()
            .optional()
            .describe(
              "Base64-encoded image data, with or without data: URI prefix"
            ),
        },
        async execute(args, context) {
          let fileUrl;
          let mime;
          let filename;

          if (args.image_data) {
            const parsed = parseBase64(args.image_data);
            fileUrl = parsed.url;
            mime = parsed.mime;
            filename = "image";
          } else if (args.file_path) {
            const absPath = path.isAbsolute(args.file_path)
              ? args.file_path
              : path.resolve(context.directory, args.file_path);

            let buffer;
            try {
              buffer = await fs.readFile(absPath);
            } catch (err) {
              return `Error: could not read file: ${absPath} — ${err.message}`;
            }

            mime = guessMime(absPath);
            fileUrl = `data:${mime};base64,${buffer.toString("base64")}`;
            filename = path.basename(absPath);
          } else {
            const found = await findImageInSession(
              ctx.client,
              context.sessionID
            );
            if (!found) {
              return (
                "Error: no image found in the conversation. " +
                "Either paste an image before calling this tool, or provide a file_path."
              );
            }
            fileUrl = found.url;
            mime = found.mime;
            filename = found.filename || "pasted-image";
          }

          // Create a child session for the vision analysis
          const session = await ctx.client.session.create({
            body: {
              parentID: context.sessionID,
              title: `look_at: ${args.goal.slice(0, 60)}`,
            },
          });
          const childId = session.data.id;

          try {
            const result = await ctx.client.session.prompt({
              path: { id: childId },
              body: {
                model: {
                  providerID: VISION_PROVIDER,
                  modelID: VISION_MODEL,
                },
                system: SYSTEM_PROMPT,
                parts: [
                  { type: "text", text: args.goal },
                  { type: "file", mime, url: fileUrl, filename },
                ],
              },
            });

            const { info, parts } = result.data;

            if (info.error) {
              const msg =
                info.error?.data?.message ?? "Unknown vision model error";
              return `Error from vision model: ${msg}`;
            }

            const text = parts
              .filter((p) => p.type === "text" && !p.synthetic)
              .map((p) => p.text)
              .join("\n");

            return text || "Vision model returned no text response.";
          } finally {
            await ctx.client.session
              .delete({ path: { id: childId } })
              .catch(() => {});
          }
        },
      }),
    },
  };
};
