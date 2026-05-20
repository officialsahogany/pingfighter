import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

function readJsonValue(filePath, segments) {
  try {
    if (!fs.existsSync(filePath)) {
      return null;
    }
    let value = JSON.parse(fs.readFileSync(filePath, "utf8"));
    for (const segment of segments) {
      if (value == null) {
        return null;
      }
      value = value[segment];
    }
    return typeof value === "string" && value.trim() ? value : null;
  } catch {
    return null;
  }
}

function replaceInFile(filePath, replacements) {
  try {
    if (!fs.existsSync(filePath)) {
      return;
    }
    let text = fs.readFileSync(filePath, "utf8");
    let changed = false;
    for (const [from, to] of replacements) {
      if (text.includes(from)) {
        text = text.replace(from, to);
        changed = true;
      }
    }
    if (changed) {
      fs.writeFileSync(filePath, text, "utf8");
    }
  } catch {
    // Do not write to stdout; MCP uses stdout for JSON-RPC only.
  }
}

function patchGeminiMcp(repoRoot) {
  const geminiRoot = path.join(
    repoRoot,
    "mcp",
    "node_modules",
    "@rlabs-inc",
    "gemini-mcp",
    "dist",
  );
  const clientPath = path.join(geminiRoot, "gemini-client.js");
  const queryPath = path.join(geminiRoot, "tools", "query.js");
  const analyzePath = path.join(geminiRoot, "tools", "analyze.js");
  const summarizePath = path.join(geminiRoot, "tools", "summarize.js");

  replaceInFile(clientPath, [
    [
      "        logger.info(`Output directory: ${outputDir}`);\n        // Use the user's preferred model for init test, fallback to flash (higher free tier limits)",
      "        logger.info(`Output directory: ${outputDir}`);\n        if (process.env.GEMINI_MCP_SKIP_STARTUP_CHECK === 'true') {\n            logger.info('Skipping Gemini API startup check; tools will connect on demand');\n            return;\n        }\n        // Use the user's preferred model for init test, fallback to flash (higher free tier limits)",
    ],
  ]);
  replaceInFile(queryPath, [
    [
      "        console.log(`Querying Gemini ${model} model (thinking: ${thinkingLevel || 'default'}) with prompt: ${prompt.substring(0, 100)}...`);",
      "        console.error(`Querying Gemini ${model} model (thinking: ${thinkingLevel || 'default'}) with prompt: ${prompt.substring(0, 100)}...`);",
    ],
  ]);
  replaceInFile(analyzePath, [
    [
      "        console.log(`Analyzing code with focus on ${focus}`);",
      "        console.error(`Analyzing code with focus on ${focus}`);",
    ],
    [
      "        console.log(`Analyzing text with focus on ${type}`);",
      "        console.error(`Analyzing text with focus on ${type}`);",
    ],
  ]);
  replaceInFile(summarizePath, [
    [
      "        console.log(`Summarizing content (${length}, ${format})`);",
      "        console.error(`Summarizing content (${length}, ${format})`);",
    ],
  ]);
}

const launcherDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.dirname(launcherDir);
const homeDir = os.homedir();

let apiKey = process.env.GEMINI_API_KEY;
if (!apiKey || !apiKey.trim()) {
  const candidates = [
    path.join(homeDir, ".vscode", "mcp.json"),
    path.join(repoRoot, ".vscode", "mcp.json"),
    path.join(homeDir, ".claude", "settings.json"),
    path.join(repoRoot, ".claude", "settings.json"),
  ];

  for (const filePath of candidates) {
    apiKey = readJsonValue(filePath, [
      "mcpServers",
      "gemini",
      "env",
      "GEMINI_API_KEY",
    ]);
    if (apiKey) {
      break;
    }
  }
}

if (!apiKey || !apiKey.trim()) {
  console.error(
    "GEMINI_API_KEY not found in env, ~/.vscode/mcp.json, project .vscode/mcp.json, ~/.claude/settings.json, or project .claude/settings.json",
  );
  process.exit(1);
}

process.env.GEMINI_API_KEY = apiKey;
process.env.GEMINI_MCP_SKIP_STARTUP_CHECK =
  process.env.GEMINI_MCP_SKIP_STARTUP_CHECK || "true";
process.env.QUIET = process.env.QUIET || "true";

patchGeminiMcp(repoRoot);

await import("../mcp/node_modules/@rlabs-inc/gemini-mcp/dist/index.js");
