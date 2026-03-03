/**
 * Compaction memory hook
 *
 * Saves key conversation content to a dated memory file before compaction
 * discards the original messages. This ensures important context survives
 * compaction and becomes searchable via memory_search.
 *
 * Triggered by the `before_compaction` plugin hook (fire-and-forget).
 * Writes to `<workspace>/memory/YYYY-MM-DD-HHmm-compaction.md`.
 */

import fs from "node:fs/promises";
import path from "node:path";
import { createSubsystemLogger } from "../../../logging/subsystem.js";
import type {
  PluginHookBeforeCompactionEvent,
  PluginHookAgentContext,
} from "../../../plugins/types.js";

const log = createSubsystemLogger("hooks/compaction-memory");

/** Max chars per message to include (avoids huge tool results bloating the file) */
const MAX_MESSAGE_CHARS = 800;
/** Max total messages to include */
const MAX_MESSAGES = 40;

/**
 * Extract readable text from a message object.
 * Messages can have various shapes depending on role and content type.
 */
function extractMessageText(msg: Record<string, unknown>): string | null {
  const role = msg.role as string | undefined;
  if (role !== "user" && role !== "assistant") {
    return null;
  }

  const content = msg.content;
  if (typeof content === "string") {
    return content;
  }

  if (Array.isArray(content)) {
    for (const block of content) {
      if (
        typeof block === "object" &&
        block !== null &&
        (block as Record<string, unknown>).type === "text"
      ) {
        const text = (block as Record<string, unknown>).text;
        if (typeof text === "string") {
          return text;
        }
      }
    }
  }

  return null;
}

/**
 * Format messages into readable markdown sections.
 */
function formatMessages(messages: unknown[]): string {
  const lines: string[] = [];
  let count = 0;

  for (const raw of messages) {
    if (count >= MAX_MESSAGES) {
      break;
    }
    if (typeof raw !== "object" || raw === null) {
      continue;
    }
    const msg = raw as Record<string, unknown>;
    const text = extractMessageText(msg);
    if (!text || text.startsWith("/")) {
      continue;
    }

    const role = msg.role as string;
    const truncated =
      text.length > MAX_MESSAGE_CHARS ? `${text.slice(0, MAX_MESSAGE_CHARS)}…` : text;
    lines.push(`**${role}**: ${truncated}`);
    count++;
  }

  return lines.join("\n\n");
}

export async function handleBeforeCompaction(
  event: PluginHookBeforeCompactionEvent,
  ctx: PluginHookAgentContext,
): Promise<void> {
  const messages = event.messages;
  if (!messages || messages.length === 0) {
    log.debug("No messages in compaction event, skipping");
    return;
  }

  // Resolve workspace directory from context
  const workspaceDir = (ctx as Record<string, unknown>).workspaceDir as string | undefined;
  if (!workspaceDir) {
    log.debug("No workspaceDir in hook context, skipping");
    return;
  }

  const agentId = (ctx as Record<string, unknown>).agentId as string | undefined;
  const sessionKey = (ctx as Record<string, unknown>).sessionKey as string | undefined;

  try {
    const memoryDir = path.join(workspaceDir, "memory");
    await fs.mkdir(memoryDir, { recursive: true });

    const now = new Date();
    const dateStr = now.toISOString().split("T")[0]; // YYYY-MM-DD
    const timeStr = now.toISOString().split("T")[1].split(".")[0].replace(/:/g, "");
    const hhMm = timeStr.slice(0, 4); // HHmm

    const filename = `${dateStr}-${hhMm}-compaction.md`;
    const filePath = path.join(memoryDir, filename);

    // Avoid duplicate writes if compaction fires multiple times rapidly
    try {
      await fs.access(filePath);
      log.debug("Compaction memory file already exists, skipping", { filename });
      return;
    } catch {
      // File doesn't exist, proceed
    }

    const formatted = formatMessages(messages);
    if (!formatted) {
      log.debug("No extractable content from compacted messages");
      return;
    }

    const content = [
      `# Compaction Memory: ${dateStr} ${hhMm.slice(0, 2)}:${hhMm.slice(2)}`,
      "",
      `- **Agent**: ${agentId ?? "unknown"}`,
      `- **Session**: ${sessionKey ?? "unknown"}`,
      `- **Messages compacted**: ${event.compactingCount ?? event.messageCount}`,
      "",
      "## Conversation",
      "",
      formatted,
      "",
    ].join("\n");

    await fs.writeFile(filePath, content, "utf-8");
    const relPath = filePath.replace(/^\/Users\/[^/]+/, "~");
    log.info(`Compaction memory saved to ${relPath} (${messages.length} messages)`);
  } catch (err) {
    log.error("Failed to save compaction memory", {
      error: err instanceof Error ? err.message : String(err),
    });
  }
}
