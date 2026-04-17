# References

Pointers back to the project documents and runtime rules that this skill
depends on. When these documents disagree with this skill, they win
(for their respective domains).

---

## Project documents

| Document | Authority on | Key sections |
|---|---|---|
| [CLAUDE.md](../../../CLAUDE.md) | Claude-side project standing rules | Stage Order Reference (stage code vs real stage), screen coordinate standards, boss sprite routing, identity + scale invariants |
| [AGENTS.md](../../../AGENTS.md) | Runtime / code-integration rules (Codex territory) | Boss Sprite Workflow, Runtime Performance Rules, Stage Integration Checklist, Testing Guidelines |

Rule of precedence:

- Asset-generation procedure (prompts, nukki, output naming, QA) -> this skill
- Runtime integration (loader, caching, render loop, trigger wiring) -> `AGENTS.md`
- Claude-side standing invariants and routing -> `CLAUDE.md`

If a conflict arises inside this skill about runtime behavior, `AGENTS.md`
wins and the skill should be updated to point at `AGENTS.md` for that item
rather than restating it.

---

## Stage mapping (critical, often mis-remembered)

| Code `current_stage` | Real stage | Boss | Theme |
|---|---|---|---|
| `5` | 6 | Honglyeon | Chinese fire |
| `6` | 5 | Nemesis | Ocean / battleship |

Full table in `CLAUDE.md` "Stage Order Reference". Always state both numbers
in a prompt when they might disagree, so downstream readers do not pick
the wrong boss.

---

## File paths (duplicated here and in CLAUDE.md on purpose)

Codex reads `CLAUDE.md` and `AGENTS.md`, not this skill. So file path
conventions are intentionally duplicated in CLAUDE.md so Codex can find
assets without loading this skill.

| File | Path |
|---|---|
| Walk (raw / nukki) | `items/[name]_boss_sheet.{jpeg,png}` |
| Attack (raw / nukki) | `items/[name]_boss_attack.{jpeg,png}` |
| Dash (raw / nukki) | `items/[name]_boss_dash.{jpeg,png}` |
| Turn (optional, raw / nukki) | `items/[name]_boss_turn.{jpeg,png}` |
| Sprite class | `entities/[name]_boss_sprite.py` |
| Background | `backgrounds/stage[N]_*.jpeg` |

---

## Tools

| Tool | Used for |
|---|---|
| Gemini MCP `mcp__gemini__gemini-generate-image` | Sheet generation |
| `remove_bg.py` (this directory) | Offline JPEG->PNG nukki (`py remove_bg.py <src> <dst>`) |
| PIL + NumPy | Runtime of `remove_bg.py` |
