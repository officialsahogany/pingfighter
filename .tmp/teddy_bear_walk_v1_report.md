# Stage 3 Teddy Bear Walk V1 — QA Report (REJECT)

## Generation
- Tool: `mcp__flux-kontext__flux_kontext_max`
- Refs:
  - `input_image`: `.tmp/teddy_bear_stage3_redesign_anchor_v1.png` (identity master)
  - `input_image_2`: `.tmp/teddy_bear_procedural_reference_v1.png` (motion / plush mech)
  - `input_image_3`: omitted (menhera ref intentionally excluded to avoid gait humanization)
- aspect_ratio: 16:9, output: `.tmp/teddy_bear_walk_v1.jpeg`
- FLUX id: `ff82fbc7-e211-4ef6-b8af-d122aadd06b6`

## Verdict: REJECT

### QA priority results
1. Same exact teddy as accepted anchor across all 8 frames — **FAIL**
2. Stable front-facing gameplay walk (not side walk) — **PASS** (only positive)
3. Plush bob / ear bounce / dangling-eye motion readable — **FAIL** (no motion at all)
4. Accessories preserved — **PARTIAL** (main bow + belly heart held; safety pin / bandage / mismatched paw drop in and out)
5. Strong enough as canonical walk candidate — **FAIL**

### Failures observed
- **Not a walk cycle.** All 8 frames are near-identical idle portraits. No contact / rise / rebound rhythm, no arm swing, no body bob, no ear bounce.
- **Identity drift across frames.**
  - Frames 3, 4, 7, 8: dangling damaged eye missing
  - Frames 4 and 7: ears recolored to pink (anchor is cocoa with peach inner)
  - Frame 4 top row: no facial detail (eyes / nose missing)
  - Fur saturation and shade shifts between frames
- **Style drift.** Soft sticker / plush-illustration tone with gradients, not the 16-bit pixel art with thick outlines the anchor and prompt enforced.
- **Stage 3 accessory thinning.** Safety pin appears in only 2-3 frames. Bandage patches mostly gone. Mismatched paw patch barely visible.

### Hard-reject triggers from handoff
- [x] loss of dangling-eye identity (multiple frames)
- [x] muddy / painterly rendering (style drift to soft sticker)
- [x] one or more frames reading like a different teddy redesign (frames 3, 4, 7 especially)

## Root cause
Direct anchor → full-sheet FLUX did not preserve identity across all 8 frames.
This matches the CLAUDE.md sprite-generation rule:
> AutoSprite + FLUX works best as a role-split pipeline, not a sheet-to-sheet relay.
> Do NOT assume full-sheet relay will preserve the acting beat.

The same trap applies to direct anchor → full walk-sheet FLUX.

## Next-step options

**Path A — Tightened V2 same-route retry (cheap, fast):**
Re-fire FLUX Kontext Max with stricter prompt language:
- explicit "all 8 frames must be the SAME teddy from the input image"
- explicit "do not redesign face, ears, or accessories between frames"
- explicit "16-bit pixel art with thick black outline, not soft sticker rendering"
- explicit walk-rhythm description per frame slot (1=contact, 2=rise, etc.)
Risk: same direct-sheet failure pattern may repeat.

**Path B — Peak / frame-expansion fallback (handoff-recommended on hold):**
1. Lock a single canonical walk peak (e.g. "stable rise pose") via FLUX with anchor as the only ref
2. Confirm peak holds full identity at gameplay scale
3. Expand surrounding 7 frames one at a time in FLUX, each conditioned on the locked peak
Higher process cost, much higher identity-preservation odds.

**Path C — Tool switch to AutoSprite for motion discovery, then FLUX peak lock:**
Per CLAUDE.md role-split: AutoSprite to discover plush walk acting, then a single FLUX peak from the strongest pose, then frame-expand in FLUX.
Most expensive, strongest payoff if Path A and Path B fail.

## Recommendation
Path B (peak / frame-expansion). Path A is worth one attempt only if user wants to confirm direct-sheet truly cannot land before going to peak-expansion.

## Anchor status: unchanged
`.tmp/teddy_bear_stage3_redesign_anchor_v1.png` remains the accepted redesign anchor. Do not overwrite with anything from this rejected sheet.
