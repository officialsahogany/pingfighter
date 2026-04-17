# Sprite Sheet QA Checklists — Reject / Regenerate Criteria

Run these checks after any sheet generation + nukki. If any row fails,
**reject and regenerate**. Do not patch with post-processing.

---

## 1. Identity lock (SKILL.md Section 8.2)

| # | Check | Pass |
|---|---|---|
| 1 | Hair color identical to walking sheet (no hue/saturation drift) | yes |
| 2 | Hairstyle / silhouette identical (curls, braids, length, bangs) | yes |
| 3 | Face impression reads as the same character at a glance | yes |
| 4 | Eye color and shape unchanged | yes |
| 5 | Skin tone unchanged | yes |
| 6 | Body proportions (head-count) unchanged | yes |
| 7 | Outfit design + trim + colors unchanged | yes |
| 8 | Species / signature accessories (tail, horns, cap, ribbon, gloves, etc.) all present | yes |
| 9 | Overall impression reads as "same person, different action" | yes |
| 10 | Art-style rendering matches walking sheet | yes |

Fail any row -> reject and regenerate.

---

## 2. Body scale lock (SKILL.md Section 8.1)

| # | Check | Pass |
|---|---|---|
| 1 | Head size within +/-5% of walking sheet | yes |
| 2 | Torso size within +/-5% of walking sheet | yes |
| 3 | Pelvis / hip size within +/-5% of walking sheet | yes |
| 4 | Speed is conveyed only by pose, lean, trail, motion lines | yes |
| 5 | Effects (dust, flame, trail) extend outward but body itself does not grow or shrink | yes |

Fail any row -> reject and regenerate. Do NOT try to fix by rescaling in the
sprite class — per-sheet runtime rescale is explicitly forbidden in
AGENTS.md.

---

## 3. Palette drift prevention (SKILL.md Section 8.3)

| # | Check | Pass |
|---|---|---|
| 1 | No hair color drift (e.g. pink -> magenta) | yes |
| 2 | No tone drift (e.g. pastel -> saturated) | yes |
| 3 | No impression drift (e.g. cute round face -> sharp mature face) | yes |
| 4 | No proportion drift (e.g. chibi 2-head -> semi-realistic 3-head) | yes |
| 5 | No outline-thickness drift (thick -> thin) | yes |

---

## 4. Turn sheet extras (SKILL.md Section 9)

| # | Check | Pass |
|---|---|---|
| 1 | Same character as walking sheet (identity lock) | yes |
| 2 | All eight fixed elements preserved | yes |
| 3 | Adjacent angle frames interpolate smoothly (15-degree steps) | yes |
| 4 | Only orientation / overlap / gaze change | yes |
| 5 | Reads as fresh redraw per angle, not a rotation filter | yes |
| 6 | Body scale within +/-5% of walking sheet | yes |
| 7 | 13-frame 7x2 grid, last cell blank | yes |
| 8 | Sign convention +90 right / 0 front / -90 left | yes |

---

## 5. Composition hygiene (all sheets)

| # | Check | Pass |
|---|---|---|
| 1 | Pure flat white background #FFFFFF in every cell | yes |
| 2 | No grid lines, borders, dividers, or labels | yes |
| 3 | All cells equal size, character centered | yes |
| 4 | Character front-facing in every frame (except turn sheet) | yes |
| 5 | Foot / baseline position consistent | yes |
| 6 | Each character fills only 45-55% of cell height | yes |
| 7 | Generous empty margin around each sprite | yes |

---

## 6. Nukki acceptance

| # | Check | Pass |
|---|---|---|
| 1 | No visible white halo around outline at 100% zoom | yes |
| 2 | Interior highlights (horns, gold trim, eyes) still opaque | yes |
| 3 | No blurred or feathered edges (hard alpha only) | yes |
| 4 | Both `.jpeg` and `.png` are committed (see SKILL.md Section 11.3) | yes |

---

## Global reject rule

If the sheet "looks like a different character" in any direct comparison
with the walking sheet, **reject and regenerate**. Identity drift is not
fixable downstream.
