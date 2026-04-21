# Menhera Turn FLUX Kontext Publish QA — V1 Report

**Status: PUBLISHING CANDIDATE BUILT. Edge QA PASS after nukki. Gameplay-scale QA materially PASS. BUT — under the stricter "walk-병치 same-Menhera + future identity anchor" rule, sock-top pink accent and cap side-ribbon drift are BLOCKERS. CANONICAL PROMOTION HELD. Runtime unchanged.**

## 1. Publishing candidate files written (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_turn_sheet_v1.png` | 4×2 publishing PNG, 2752×1536 RGB (matches canonical walk dims / cells 688×768) |
| `menhera_flux_kontext_turn_sheet_v1.jpeg` | Same sheet as JPEG q=95 for nukki input |
| `menhera_flux_kontext_turn_sheet_v1_nukki.png` | Post-`remove_bg.py` RGBA output, 2752×1536 (crisp hard-edge alpha) |
| `menhera_flux_kontext_turn_sheet_v1_gameplay.png` | 2-row side-by-side at gameplay scale (79×88 per cell): row1 canonical walk, row2 turn candidate |
| `menhera_flux_kontext_turn_sheet_v1_gameplay_4x.png` | 4× nearest-neighbor zoom of the above for QA readability |
| `menhera_flux_kontext_turn_vs_walk_paired_4x.png` | 8 per-frame pairs (walk_i next to turn_i) at 4× zoom |
| `menhera_turn_walk_pair_f1_6x.png`, `f4_peak_6x.png`, `f7_settle_6x.png` | 6× pair zooms for critical frames |
| `_edgeqa_{pre,post_nukki}_f{1..8}.png` | Torso/bow crops pre vs post nukki for edge audit |
| `menhera_flux_kontext_turn_publish_qa_v1_report.md` | This report |

Frame order in the sheet:
- Row 1: f1 (carry-in), f2 (plant), f3 (wind-up), f4 (peak_v2)
- Row 2: f5 (rebound), f6 (recovery), f7 (settle), f8 = f1 reuse

`items/menhera_boss_turn.png` was **not** overwritten.

## 2. JPEG / PNG nukki pair — created

- JPEG written at q=95 from the stitched 4×2 PNG.
- `py d:/main/bosspong/.claude/skills/sprite-generation/remove_bg.py
  d:/main/bosspong/.tmp/menhera_flux_kontext_turn_sheet_v1.jpeg
  d:/main/bosspong/.tmp/menhera_flux_kontext_turn_sheet_v1_nukki.png`
  completed successfully. Output is a 2752×1536 RGBA PNG with crisp
  hard-edge alpha, as expected from the skill's 2-step flood-fill + halo
  kill algorithm.

## 3. Stop-and-ask: edge QA immediately after nukki — PASS

Pre/post nukki side-by-side on the three most sensitive prop regions,
checked on f1, f3, f4 (peak), f7 (representative of all identity states):

| Edge region | f1 pre | f1 post | f3 pre | f3 post | f4 pre | f4 post | f7 pre | f7 post |
|---|---|---|---|---|---|---|---|---|
| Exactly 4 black bows on white panel | 4 | **4 intact** | 4 | **4 intact** | 4 | **4 intact** | 4 | **4 intact** |
| Pink paw pads on gloves | visible | **visible** | visible | **visible** | visible | **visible** | visible | **visible** |
| Med-kit pouch edge (white + pink cross) | clean | **clean** | clean | **clean** | clean | **clean** | clean | **clean** |

No halo break, no alpha punch-out, no outline break on any frame's 4
bows / pink paw pads / med-kit edge. The hard-edge nukki preserved
every identity prop that was readable in the source.

Net: not "promotion blocked after nukki." Proceeded to the next QA step.

## 4. Gameplay-scale QA — materially PASS

Rendered walk + turn at `79×88` per frame (the sprite class's target
size: `MenheraBossSprite.__init__(width=79, height=88)`), then 4× zoom
for inspection. Key results:

- **Body read vs walk**: walk frames render at 64×88 visible body;
  turn frames render at 51–62×88 visible body (full 88 px height, width
  slightly narrower depending on pose). Turn is **not** smaller than
  walk vertically. Within the +/-5% body-scale lock when height is the
  dominant axis.
- **Face / forehead clipping**: none observed on any turn frame at
  gameplay size. No chopped forehead, no squashed head read. This
  passes CLAUDE.md §9.1.4 clipped-face guardrail.
- **Per-frame motion readability at 79×88**:
  - f1 → f2 → f3 reads as low-amplitude build toward peak
  - f4 clearly shows the raised paw at peak (pink pad visible even at
    gameplay size)
  - f5 → f6 → f7 softens back to near-neutral
  - f7 → f8 (=f1) → walk reconnection is clean since both f7 and f1
    are near-canonical-walk neutrals
- **Cross-sheet clarity tier**: turn row reads in the same pixel-art
  class as the walk row. No anime-soft regression.
- **Identity props at gameplay size**:
  - gingham cap + red cross: readable on all frames ✓
  - cream/blonde inner bangs: visible as warmer tone on viewer-right ✓
  - pink heart cheek: hard to verify at native 79×88 but visible at 4×
    zoom on correct cheek ✓
  - 4 bows: **more cleanly readable on turn than on walk** at gameplay
    size (turn's FLUX-crisp bows survived the downscale better) ✓
  - paw pads: visible on raised paw frames ✓
  - med-kit: clearly visible ✓
  - cloth-tail: visible ✓
- **Auxiliary-only read**: the turn cycle does NOT dominate the walk.
  f1 and f7 are near-neutral; the visible accent is only at f3-f5. So
  it reads as an aux direction-change sheet, not a replacement cycle.

## 5. Drift judgment vs canonical walk — applying the stricter rule

Under the updated stricter rule ("walk 병치 기준 + 이후 attack/dash
realign identity anchor 가능성 전제"), two drifts remain that were
flagged on peak V2 and propagated into every new frame.

### 5.1. Sock-top pink accent

- On canonical walk: thigh-highs are **plain white with no pink band**.
- On turn candidate (peak and all derived frames): thigh-highs have a
  **small pink accent band at the top edge**.
- At native 79×88: barely readable.
- At 6× per-frame pair zoom (`menhera_turn_walk_pair_f*_6x.png`):
  **clearly visible as a different identity cue than the canonical walk**.
- Under strict rule: because this turn may later anchor attack / dash
  regeneration, the pink sock accent would compound into the whole
  boss set and diverge from the canonical walk silhouette.
- **Verdict: BLOCKER under the stricter rule.**

### 5.2. Cap ribbon: front-center → two side accents

- On canonical walk: cap has a single red-ribbon / cross language at
  the front / top center.
- On turn candidate: cap has small red accents on both sides of the
  cap, with a less pronounced front-center ribbon.
- At native 79×88: both read as "red on pink cap" — not obviously
  different.
- At 6× zoom: **visibly a different ribbon language than the canonical**.
- Same propagation concern applies.
- **Verdict: BLOCKER under the stricter rule** (softer than sock-top
  because the gameplay-scale distinction is smaller, but still
  anchor-unsafe).

### 5.3. Drifts that are NOT blockers

- Cream/blonde inner bangs proportion: slight asymmetry vs canonical
  but inside identity band — canonical has this asymmetry too.
- Hair silhouette volume: turn hair is slightly wispier than walk's
  rounder silhouette at gameplay size, but the difference is within
  pose-to-pose variance on the walk cycle itself.
- Per-frame body width variance (51–62 px): acceptable because height
  (the primary cross-sheet-lock axis) is always at target 88 px.

## 6. Canonical promotion — HELD

Under the stricter rule, I am NOT recommending canonical overwrite in
this pass. The publishing candidate is visually strong and nukki-clean,
but promoting it now embeds sock-top pink accent + cap side-ribbon
drift as the new identity baseline for every downstream sheet that will
be regenerated off this turn. That is an avoidable, cheap-to-fix
regression.

Critical runtime context that must also be resolved **before** any
canonical promotion, regardless of the drift question:

> `entities/menhera_boss_sprite.py:48-53` currently has
> `TURN_GRID_COLS = 8`, `TURN_GRID_ROWS = 1`, and a
> `TURN_FRAME_ORDER` tuple with eight `(col, 0)` entries. The current
> `items/menhera_boss_turn.png` is 10664×1536 (an 8×1 aux sheet).
> This publishing candidate is **4×2 at 2752×1536** to match the
> canonical walk dimensions. Dropping the 4×2 file onto the existing
> 8×1 loader WILL slice the wrong cells and corrupt runtime playback.
> So any canonical promotion requires a **coordinated runtime change**:
> flip to `TURN_GRID_COLS = 4`, `TURN_GRID_ROWS = 2`, and update
> `TURN_FRAME_ORDER` to the matching `(col, row)` pairs. That is a
> Codex hand-off change, not an asset-side change.

## 7. Recommended next actions (user decides)

**Option A — Clean promotion (recommended)**

1. Narrow touch-up regenerate of peak v2 with `flux_kontext_max`,
   using peak v2 itself as `input_image` + the same reference stack,
   narrow instruction: "strip the small pink band at the top of the
   white thigh-high socks (restore PLAIN white socks), and move the
   cap red-ribbon accent to a single front-center bow (canonical walk
   language). Keep everything else identical." Save as
   `.tmp/menhera_flux_kontext_peak_v3.png`.
2. Edge-QA peak_v3 for 4 bows / paw pads / med-kit intact.
3. Regenerate f1/f2/f3/f5/f6/f7 using peak_v3 as primary anchor
   (same reference stack as f1-v1 etc.), add the same drift-strip
   instruction.
4. Rerun Sections 1–5 of this report (stitch → jpeg → nukki → edge QA
   → gameplay QA → drift judgment).
5. If drift clean: proceed to Codex runtime handoff below to swap
   `TURN_GRID_COLS/ROWS` to 4/2 + update `TURN_FRAME_ORDER`, then
   promote `items/menhera_boss_turn.{jpeg,png}`.

**Option B — Ship-as-is with anchor-role guardrail (not recommended)**

1. Document in the Menhera art notes that `menhera_flux_kontext_*`
   assets are **not** to be used as identity anchor for future
   attack/dash regeneration. Canonical walk remains the only anchor.
2. Coordinate the same runtime grid flip (TURN_GRID_COLS/ROWS → 4/2).
3. Promote `items/menhera_boss_turn.{jpeg,png}` with an explicit note
   in `sprite-generation/examples.md` about the sock-top + cap-ribbon
   drift being accepted at gameplay scale.

Option A is recommended because Option B relies on future-worker
discipline that a single drifty anchor will eventually erode.

## 8. Codex handoff note (for whenever promotion happens)

```
FLUX Kontext publish-QA V1 built a 4x2 Menhera turn candidate but
promotion is HELD pending a narrow drift touch-up on peak + derived
frames. Canonical asset + runtime are unchanged.

Asset state:
- items/menhera_boss_turn.png                          -> unchanged (current 8x1, 10664x1536)
- items/menhera_boss_sheet.png                         -> canonical walk (unchanged)
- items/menhera_boss_victory.png                       -> quality reference (unchanged)
- .tmp/menhera_flux_kontext_turn_sheet_v1.{png,jpeg}   -> publishing candidate (NOT for runtime)
- .tmp/menhera_flux_kontext_turn_sheet_v1_nukki.png    -> nukki candidate (NOT for runtime)
- .tmp/menhera_flux_kontext_turn_sheet_v1_gameplay*.png -> gameplay-scale QA renders
- .tmp/menhera_turn_walk_pair_*_6x.png                 -> per-frame pair drift QA

Runtime policy unchanged:
  - front-biased canonical walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off
  - RENDER_TURN_FRAMES = False in entities/menhera_boss_sprite.py

Whenever Option A promotion happens, the required runtime changes are:
  - entities/menhera_boss_sprite.py:48  TURN_GRID_COLS = 4   (was 8)
  - entities/menhera_boss_sprite.py:49  TURN_GRID_ROWS = 2   (was 1)
  - entities/menhera_boss_sprite.py:50  TURN_FRAME_ORDER should become
      ((0,0),(1,0),(2,0),(3,0),(0,1),(1,1),(2,1),(3,1))
  - RENDER_TURN_FRAMES remains False until a separate smoke-check
    confirms the new 4x2 sheet reads cleanly at gameplay size on the
    live runtime (CLAUDE.md §9.1.4 pre-runtime clipped-face audit).

No runtime wiring changes in this pass.
```

## 9. Summary (for the user's one-screen read)

- Publishing candidate built, JPEG + nukki PNG pair created.
- Edge QA after nukki: **PASS** (4 bows / paw pads / med-kit all intact).
- Gameplay-scale QA vs canonical walk: **materially PASS**, same pixel
  class, same body read, turn reads as auxiliary direction-change sheet.
- Drift judgment under strict rule: **sock-top pink accent + cap side
  ribbons are BLOCKERS** because this turn may serve as the identity
  anchor for future attack/dash realign.
- **Canonical promotion: HELD.**
- Recommended next step: Option A narrow touch-up (regen peak v3 +
  derived frames with sock / cap-ribbon strip instruction), then rerun
  this same QA pass.
- Runtime still on hop-only fallback. No code changes.
