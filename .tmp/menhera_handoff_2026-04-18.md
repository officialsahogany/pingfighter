# Menhera Boss (Stage 3) — Liveliness Pass Hand-off

Date: 2026-04-18
From: Claude (sprite-generation skill)
To: Codex (AGENTS.md runtime owner)

## Sheet changes

| File | Status |
|---|---|
| `items/menhera_boss_sheet.{jpeg,png}` | **REGENERATED** — front-biased walk with stronger whole-body rhythm (visible body bob, hair sway, cat-tail counter-arc, pose-differentiated leg cycle, hem flutter). Identity locked to canonical (no cat ears, one ribbon, olive eyes, pink hair, nurse cap, paw gloves, striped stockings, cat tail). |
| `items/menhera_boss_turn.{jpeg,png}` | **UNCHANGED** — restored from working-tree backup. Three regen attempts collapsed mid-angles to front-facing (chibi turn failure mode per skill §9.1.2). The existing turn sheet has acceptable angle distribution; we're keeping it. |
| `items/menhera_boss_attack.*`, `dash.*`, `victory.*`, `defeat.*` | UNCHANGED |

Backup of pre-change files: `.tmp/menhera_backup_2026-04-18/`

## Runtime work requested

User ask: walk should feel more lively (covered by new walk sheet) AND **the boss should feel like she briefly hops in place when she pivots facing direction**.

The hop is best implemented as a runtime **y-offset overlay during turn-transition playback**, not baked into the sprite. Reason: Gemini repeatedly failed to bake distinct angle steps + a vertical jump arc into the same 13-frame turn sheet, but a code-side y-offset modulation gives a clean, controllable result on top of the existing turn sheet's angle progression.

### 1. Enable turn transitions

In `entities/menhera_boss_sprite.py`:

- Currently `MenheraBossSprite.ENABLE_TURN_TRANSITIONS = False`.
- Set it to `True` so the turn sheet actually plays during left↔right facing changes.
- Confirm the runtime priority `dash > attack > turn-transition > walk > idle` still holds (per `AGENTS.md`).

### 2. Add self-jump y-offset overlay during turn

While a turn-transition is playing, modulate the boss's render y by a small upward arc, then return to baseline:

- **Peak height:** ~6–8% of rendered body height (≈5–7px at the current 88px body).
- **Curve:** half-sine arc — `peak * sin(pi * t / turn_duration)` where `t` ranges 0→`turn_duration`.
- **Timing:** start the arc the moment the turn animation begins; reach peak around the 0° (front-facing) frame in the turn sequence; return to baseline as the turn completes.
- **Scope:** turn-transition only. Do NOT apply to walk (the new walk sheet already has bob baked in) or to attack/dash.
- **Direction-agnostic:** applies the same upward arc whether facing-change is L→R or R→L.

Suggested wiring location: the per-frame turn-transition update in `MenheraBossSprite` (the same path that advances `TURN_FRAME_ORDER`). Expose the y-offset via a new method like `current_y_offset()` and have the Stage 3 render branch in `pingfighter.py` apply it when blitting the boss sprite.

### 3. Optional polish (only if time allows)

- Brief soft "puff" particle at the feet on land (small pastel-pink dust) to sell the landing.
- Slight squash on land frame (vertical scale ×0.96 for 1 frame) — only if it's cheap and doesn't fight the sprite's existing scale.

Both are nice-to-have. The y-offset arc alone delivers the user's "self-jump feel" ask.

## Verification checklist

After integration, please run:

```
py -3 -m py_compile pingfighter.py entities/menhera_boss_sprite.py
```

Then in-game:
- Confirm Stage 3 Menhera now reads as actively walking left/right (not stiff idle).
- Confirm she briefly "hops" when changing direction (visible vertical lift, lands cleanly).
- Confirm walk/attack/dash body scale is still consistent (no apparent body-size change).
- Confirm victory/defeat scenes still play correctly (these sheets are unchanged).

## Notes

- The new walk sheet is slightly different in hair-flow style from the old one (more dynamic flow). This stays within identity-lock tolerance.
- The walk sheet's per-frame body bob is subtle (~5%). If gameplay reads it as "still kind of stiff" after the runtime jump-during-turn lands, consider also adding a small idle/walk y-bob modulation in code (sin-based, low amplitude). But try without first.
