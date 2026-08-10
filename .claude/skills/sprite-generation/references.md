# References

Pointers back to the project documents and runtime rules that this skill
depends on. When these documents disagree with this skill, they win
(for their respective domains).

---

## Project documents

| Document | Authority on | Key sections |
|---|---|---|
| [CLAUDE.md](../../../CLAUDE.md) | Claude-side asset routing and terminology | Draw routing, visual terminology, Live2D continuity, skill-effect sheets |
| [AGENTS.md](../../../AGENTS.md) | Runtime / code-integration rules (Codex territory) | Boss Sprite Workflow, Runtime Performance Rules, Stage Integration Checklist, Testing Guidelines |
| [docs/sprites/boss_sprite_runtime_contract.md](../../../docs/sprites/boss_sprite_runtime_contract.md) | Shared runtime state vocabulary | Attack-vs-stun semantics, Godot texture keys, verification checklist |
| [docs/sprites/stage1_dalji.md](../../../docs/sprites/stage1_dalji.md) | Stage 1 Dalji compact runtime contract | Accepted asset set, Python/Godot mapping, regression checks |
| [docs/stage6_tetriser_port_plan.md](../../../docs/stage6_tetriser_port_plan.md) | Current Stage 6 mapping | Tetriser owner and legacy Python Stage 7 provenance |

Rule of precedence:

- Asset-generation procedure (prompts, nukki, output naming, QA) -> this skill
- Runtime integration (loader, caching, render loop, trigger wiring) -> `AGENTS.md`
- Runtime state vocabulary and legacy key semantics -> `docs/sprites/boss_sprite_runtime_contract.md`
- Stage 1 Dalji compact runtime mapping -> `docs/sprites/stage1_dalji.md`
- Claude-side standing invariants and routing -> `CLAUDE.md`

If a conflict arises inside this skill about runtime behavior, `AGENTS.md`
wins and the skill should be updated to point at `AGENTS.md` for that item
rather than restating it.

Critical cross-document guardrail:

- A regenerated walk sheet does NOT become canonical automatically.
- If the candidate walk is more side-biased than the previous accepted
  walk, reject / regenerate / rollback asset-side instead of handing it
  to Codex for runtime rescue.
- Front-biased walk means stable left and right travel still read as
  forward-facing in gameplay.

---

## Stage mapping (critical, often mis-remembered)

| Godot `current_stage` | Current stage | Boss | Theme / provenance |
|---|---|---|---|
| `5` | 5 | Hongryun / Honglyeon | Chinese fire |
| `6` | 6 | Tetriser | Ported from legacy Python Stage 7 |

Original Python Stage 6 Nemesis/ocean content is excluded. `AGENTS.md` owns the
current stage mapping; the Tetriser plan owns Stage 6 details. State both the
Godot stage and legacy Python provenance only when they genuinely differ.

---

## File paths

Claude receives `CLAUDE.md`, its rules, and this skill when triggered. Codex
receives the `AGENTS.md` chain and the `.agents/skills/` loader mirror when the
skill triggers. Runtime paths stay here and in the runtime owner contract.

Use `items/` as an asset-generation scratch / staging convention only.
Accepted runtime assets for the current project must be copied into the
repo-local Godot asset tree and wired from the owning Godot module. The
original Python/Pygame sprite class paths are legacy porting references only.

| File | Path |
|---|---|
| Walk (raw / nukki staging) | `items/[name]_boss_sheet.{jpeg,png}` |
| Attack (raw / nukki staging) | `items/[name]_boss_attack.{jpeg,png}` |
| Dash (raw / nukki staging) | `items/[name]_boss_dash.{jpeg,png}` |
| Turn (optional, raw / nukki staging) | `items/[name]_boss_turn.{jpeg,png}` |
| Godot runtime boss assets | `godot/assets/sprites/bosses/[name]/...` or the stage owner's established asset folder |
| Godot runtime owner | `godot/scripts/...` owning stage / boss / renderer module |
| Legacy Python sprite class reference | `entities/[name]_boss_sprite.py` |
| Legacy Python background reference | `backgrounds/stage[N]_*.jpeg` |

---

## Tools

| Tool | Used for |
|---|---|
| AutoSprite MCP (repo-configured sheet generator) | Final runtime sheet generation |
| Gemini / built-in imagegen | Still concepts or explicit approved fallback only |
| `remove_bg.py` (this directory) | Offline JPEG->PNG nukki (`py remove_bg.py <src> <dst>`) |
| PIL + NumPy | Runtime of `remove_bg.py` |
