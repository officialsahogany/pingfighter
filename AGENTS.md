AGENTS.md — Engineering Guide for Codex & Other Agents
======================================================

Scope
-----
This file distills the practical guidance (informed by CLAUDE.md) for any coding agent working on this repository (with Codex CLI as the primary client). It defines responsibilities, invariants, and change‑management rules so that automated edits remain safe, reversible, and performant.

Project Overview
----------------
PingFighter is a Python/Pygame arcade boss‑pong game. The codebase mixes legacy and modularized systems, with ongoing refactors. Cross‑platform packaging (PyInstaller) is supported. Most gameplay lives in `pingfighter.py`, but new systems are moving into modular folders.

Agent Responsibilities
----------------------
1) Be surgical: prefer small, localized patches with clear intent and easy rollback.
2) Preserve gameplay invariants (see below) and performance at 60 FPS.
3) Respect resource packing rules so dev run and PyInstaller both work.
4) Avoid large structural changes unless explicitly requested.
5) Prefer feature flags/toggles over breaking behavior; default to safe fallbacks.

Critical Invariants
-------------------
- Resource loading must go through `resource_path(relative_path)`.
- Game must not freeze the main loop; heavy work needs amortization or guards.
- Collision & gauge rules:
  - While “Stopwatch” is active (time frozen), disable paddle collision & gauge gain.
  - After stopwatch recovery, enforce upward trajectory lock only as specified (and clear it on boss hit / round reset).
- Round/Stage transitions must reset transient state:
  - Stopwatch/Smartphone flags, timers, and locks (e.g., `stopwatch_forced_upward`, `stopwatch_upward_lock_timer`).
  - Dash, stun, knockback, temporary FX/particles that should not leak across rounds.

Resource & Packaging
--------------------
- Always load assets via `resource_path()`; never use raw relative paths.
- Keep newly added assets in appropriate folders; avoid renaming existing assets casually.
- When adding fonts/images/sounds, ensure dev + PyInstaller environments are both supported.

Coding Standards
----------------
- Python 3.10+ style, readable names, minimal global churn.
- Prefer pure functions and narrow, explicit mutations.
- Keep logging/prints behind debug guards when noisy.
- For big switches/if‑else on state, extract helpers with clear contracts.

Performance Rules
-----------------
- Rendering: avoid per‑frame surface creation/scaling; pre‑compute or cache.
- Physics/AI: keep per‑frame math cheap; use cooldowns/timers/locks to prevent thrash.
- Avoid tight loops over large ranges in the main thread; use sampling windows.

Stopwatch & Smartphone (Smartphone‑triggered Stopwatch)
-------------------------------------------------------
- During freeze: no paddle collision or gauge gain.
- Recovery:
  - Gradual speed restoration; maintain direction unless explicitly overridden.
  - If triggered by Smartphone, force upward (boss) direction at recovery end and keep a short upward‑lock.
  - Upward‑lock must be cleared on boss paddle contact and on round reset/next round.

Error Handling & Safety
----------------------
- Prefer early returns and explicit guards over implicit state transitions.
- When new globals are required, declare them next to related globals and `global` in functions that mutate them.
- Avoid catching broad Exceptions unless forwarding a clear message or re‑raising with context.

Testing & Validation
--------------------
- Small patches: sanity‑test by running the game, observing FPS/inputs, and checking crash logs.
- Use debug prints sparingly; wrap behind conditions or temporary flags and remove before finalizing large changes.
- If adding new configuration or feature flags, default them to off or conservative behavior.

MCP / External Tools
--------------------
- MCP is supported via external runner in `mcp/` (Codex doesn’t auto‑attach).
- Do not hard‑code secrets; use `mcp/.env` (git‑ignored) or environment variables.

Secrets & Security
------------------
- Never commit API keys or tokens; scrub tokens from git remotes and scripts.
- Prefer `os.getenv("NAME")` for runtime configuration; provide `.env.example` when helpful.

Change Management
-----------------
- Use one `apply_patch` per logical change; include concise commit‑style titles in PR/commit messages (if used externally).
- Add brief comments when changing gameplay‑critical logic (e.g., stopwatch locks), focusing on intent and invariants.
- Do not rename files or functions casually; preserve public interfaces unless explicitly approved.

Quick Checklist for PR‑Quality Patches
--------------------------------------
1) Resource paths use `resource_path`.
2) No stopwatch/gauge violations; rounds reset transient state.
3) No busy loops or heavy allocations in the frame loop.
4) Debug prints are temporary or gated.
5) Minimal blast radius; rollback is trivial.

