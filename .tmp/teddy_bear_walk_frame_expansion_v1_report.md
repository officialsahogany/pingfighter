# Stage 3 Teddy Bear Walk — Frame Expansion V1 Report

## Overall verdict: ACCEPT as canonical walk-sheet candidate

Path B (peak-lock then frame expansion) succeeded where direct full-sheet FLUX (Path A) failed.

## Generation summary

### Step 1 — Walk anchor lock
- Tool: `flux_kontext_max`
- Refs: redesign anchor (primary) + procedural teddy (motion)
- Output: `.tmp/teddy_bear_walk_anchor_v1.png`
- Status: PASS — became the primary identity master for Step 2

### Step 2 — Frame expansion (8 frames)
Method: pair-symmetric expansion, F1↔F5 axis first, then F2/F6, F3/F7, F4/F8.

| Frame | Slot | Status | Notes |
|-------|------|--------|-------|
| F1    | first contact         | PASS    | Step 1 anchor copied as F1 |
| F2    | first rise            | PASS V2 | V1 = both feet airborne + arm raised → V2 fixed with subtle rise + compact arm range |
| F3    | first support shift   | PASS    | Mirror discipline soft (same leg side as F2), but body lean progression reads |
| F4    | first rebound         | PASS    | Same family as F3 with settling stance |
| F5    | second contact (mirror)| PASS V2| V1 = legs not mirrored → V2 fixed with explicit viewer-side coordinates |
| F6    | second rise (mirror)  | PASS    | Subtle rise matches F2 V2 tone |
| F7    | second support shift  | PASS    | Mirror discipline soft (same leg arrangement as F3) — accepted at sequence level |
| F8    | second rebound        | PASS    | Same family as F7 with settling stance |

## QA — sequence level

1. Same exact teddy redesign across all 8 frames? **PASS** — identity locked, no per-frame teddy drift
2. Stable front-facing gameplay walk vs side-walk? **PASS** — every frame front-facing
3. Plush bob / ear bounce / dangling-eye motion readable? **PASS** — subtle but rhythmic
4. Accessories preserved at gameplay scale? **PASS** — bow, heart, dangling eye, safety pin, bandages, paw patch, black bow all consistent
5. Strong enough to become canonical teddy walk-sheet candidate? **PASS** — accept

### Hard-reject triggers — none fired
- [ ] identity drift across frames
- [ ] walk reads like idle gallery
- [ ] dangling-eye missing in some frames
- [ ] ear recolor / face redesign / missing accessories
- [ ] style drift to sticker / plush illustration
- [ ] humanized gait
- [ ] side-facing walk bias

## Known soft notes (not reject-worthy)

- F1↔F5 contralateral mirror is strict (locked at V2). F2-F4 ↔ F6-F8 mirror is softer — body lean and pose progress mirror, but exact leg inversion is not always crisp.
- At gameplay scale (50×100 px estimate per frame) the leg-discrimination softness is invisible; rhythm reads as plush wobble rather than alternating-leg human gait.
- F2/F6 rise is on the subtle side, not athletic. Matches the "stuffed-toy gait, not human gait" intent.
- Both rebounds (F4, F8) settle into similar leg families as their preceding shift frames — reads as 2-step plush bob rather than textbook 4-step gait. Acceptable for boss plush walk.

## Reference stack actually used

- `.tmp/teddy_bear_stage3_redesign_anchor_v1.png` — identity master across all calls
- `.tmp/teddy_bear_walk_anchor_v1.png` — primary motion master starting Step 2
- `.tmp/teddy_bear_procedural_reference_v1.png` — motion / plush mech ref (Step 1, F1, F2 only)
- Per-pair: each frame conditioned primarily on its predecessor (F2 on F1, F3 on F2, F4 on F3) and on its mirror counterpart (F6 on F5, etc.)

Menhera mood ref intentionally NOT used in any call (per earlier decision to avoid gait humanization).

Rejected V1 direct full-sheet not used as ref in any call (per handoff hard rule).

## File status

Accepted artifacts:
- `.tmp/teddy_bear_stage3_redesign_anchor_v1.png` — accepted redesign anchor (unchanged)
- `.tmp/teddy_bear_walk_anchor_v1.png` — accepted Step 1 walk anchor frame
- `.tmp/teddy_bear_walk_f1_v1.png` through `.tmp/teddy_bear_walk_f8_v1.png` — accepted 8-frame sequence
- `.tmp/teddy_bear_walk_stitched_v2_preview.png` — 4×2 stitched preview (4096×2048)
- `.tmp/teddy_bear_walk_stitched_v2_preview_gameplay.png` — gameplay-scale preview (400×200)

Rejected / evidence-only artifacts (do NOT use as refs):
- `.tmp/teddy_bear_walk_v1.jpeg` — rejected direct full-sheet
- `.tmp/teddy_bear_walk_f5_v1.jpeg` — superseded by f5 V2

## Next-step options

This sheet is a **candidate**, not yet canonical. Per CLAUDE.md, do NOT overwrite any `items/` canonical asset without an explicit publish decision.

Possible next steps (user picks):

1. **Publish to canonical** — copy stitched preview as `items/teddy_bear_boss_sheet.png`, run offline nukki for transparent background, move forward to attack/dash sheets using this walk as identity anchor. Recommended if user accepts the sequence as-is.

2. **Narrow touch-up** — regenerate one or two specific frames to tighten mirror discipline (e.g. F7 with stricter "must invert F6 leg arrangement" language). Useful only if the soft mirror reads as a problem at gameplay test.

3. **Hold for in-game test first** — wire the stitched sheet temporarily through Codex to see live gameplay read before committing. Safest path; aligns with CLAUDE.md "visible body read at gameplay scale" rule.

Recommendation: **option 3** — wire and watch one stage of gameplay before publishing to canonical. The sheet is strong enough to test, and the soft mirror notes are small enough that gameplay rhythm will tell us whether they matter.
