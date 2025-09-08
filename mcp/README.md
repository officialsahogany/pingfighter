MCP Integration (External Runner)
=================================

This repo includes a lightweight, client‑agnostic setup to run Model Context Protocol (MCP) servers externally and use them alongside Codex CLI.

What this gives you
- A single `mcp.config.json` listing the servers you want.
- Helper scripts to check environment and run an MCP client against those servers.
- You keep Codex as your main coding assistant; when you need MCP tools, you run the runner and copy results back into Codex.

Prerequisites
- Node.js ≥ 18 with `npx`
- API keys for any external servers you enable (Slack, YouTube, etc.)

Servers included (templates)
- `filesystem` – official MCP filesystem server
- `slack`      – Slack server (requires bot/app tokens)
- `youtube`    – YouTube server (requires API key)
- `context7`   – placeholder; replace with the actual package you use
- `sequential` – placeholder; replace with the actual package you use
- `magic`      – placeholder; replace with the actual package you use

Environment (.env or shell exports)
- Slack:
  - `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN` (if required), `SLACK_SIGNING_SECRET` (if required)
- YouTube:
  - `YOUTUBE_API_KEY`

Files
- `mcp.config.json` – MCP servers and how to launch them (stdio)
- `run.sh`          – starts a generic MCP client with the above config
- `check.sh`        – sanity checks (Node, npx, required envs)

Quick start
1) Ensure Node is present:
   - `node -v && npx -v`
2) Export your API keys (example):
   - `export SLACK_BOT_TOKEN=xoxb-...`
   - `export YOUTUBE_API_KEY=AIza...`
3) Run the client:
   - `bash mcp/run.sh`

Notes
- The server package names for `context7`, `sequential`, `magic` are placeholders. Replace them with the actual server packages you intend to use.
- The MCP client used here is `@modelcontextprotocol/cli` (community CLI). If you prefer a different MCP client, adjust `run.sh` accordingly.

