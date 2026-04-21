# Menhera Turn via AutoSprite MCP — v1 Report

**Status: EXPERIMENT COMPLETE. CANDIDATE REJECTED. Canonical turn NOT overwritten.**

## 1. What we tried

- **Full 8-frame AutoSprite pass** (not framewise fallback).
- Workflow:
  1. Extracted one clean front-facing Menhera cell from `items/menhera_boss_sheet.png`
     (row 0, col 3) and saved to `.tmp/menhera_autosprite_reference_v1.png`
     (888×888 white-square canvas).
  2. Uploaded that reference via AutoSprite `request_upload_url` →
     curl PUT → `upload_character`. Character created:
     `id=cmo3mxpib00c2et3994bw1k48` (Menhera Nurse Girl / PingFighter Stage 3).
     Uploading the user's own image is free (0 credits).
  3. Called `generate_spritesheet` with
     `kind=custom`, `frameCount=8`, `quality=standard`,
     `removeBg=ultra`, `withSound=false`,
     using a ≤600-char custom turn prompt matching the handoff brief
     (front-biased, characterful direction-change gesture, no angle chart,
     no greeting wave, no attack swing, identity locked to base image).
     **Cost: 5 credits.** Remaining: 1495 / 1500.
  4. Polled `get_job_status` once after 60s; `succeeded`.
  5. Pulled spritesheet + atlas.

## 2. Output files in `.tmp/`

| File | Content |
|------|---------|
| `menhera_autosprite_reference_v1.png` | Single-frame Menhera upload source |
| `menhera_turn_autosprite_sheet_v1.png` | Raw sheet from AutoSprite (768×768, 3-col×3-row, 8 frames + 1 empty cell) |
| `menhera_turn_autosprite_atlas_v1.json` | Frame atlas, 256×256 per cell |
| `menhera_turn_autosprite_sheet_v1_zoom.png` | 4× nearest-neighbor zoom for QA readability |
| `menhera_turn_autosprite_frame_{0..7}.png` | Individual frames at 512×512 for QA |

No PNG was written to `items/menhera_boss_turn.png`. Canonical turn is
untouched. The previous angle-chart turn remains at
`.tmp/menhera_boss_turn_anglechart_backup_20260418.png` from the prior session.

## 3. QA vs `items/menhera_boss_sheet.png` + `items/menhera_boss_victory.png`

### 3.1. Identity lock

| Locked element | Canonical | AutoSprite v1 | Result |
|---|---|---|---|
| Cream/blonde inner front bangs | present | lost (all pink) | FAIL |
| Pink/white gingham nurse cap | gingham check | plain pink + red cross | FAIL |
| Syringe attached on cap | present | not drawn | FAIL |
| Red ribbon on cap | present | only rear streamers, no front ribbon | FAIL |
| 4 black bows on white panel | 4 | 3 visible (sometimes fewer) | FAIL |
| Dark gray cat-paw gloves with pink pads | present | plain gray mitts, no pink pads | FAIL |
| Med-kit accessory on same side as walk | present | replaced by ambiguous small pink object | FAIL |
| Pink check-pattern cloth-tail motif | present | drifted to plain pink cat-tail with pink tip | FAIL |
| One pink heart cheek mark | one side | preserved, correct side | PASS |
| Pink outfit w/ white center front panel | present | present | PASS |
| White thigh-highs | present | present | PASS |
| Black X ankle accessories | present | present (subtle) | PASS |
| Gray/silver eyes with strong lashes | gray/silver | drifted slightly toward blue-gray, softer lashes | partial |
| Petite chibi human body | present | present | PASS |
| Thick black pixel outlines | thick | soft anti-aliased outlines | FAIL |

### 3.2. Motion brief

| Requirement | Result |
|---|---|
| NOT a side-profile rotation chart | PASS (all frames stay mostly frontal) |
| NOT +90 → 0 → −90 angle sequence | PASS |
| NOT a greeting wave | FAIL (frames 0, 4, 6 read exactly like a greeting wave — raised paw) |
| NOT an attack swing | PASS |
| NOT a taunt/dance loop | partial (frames 1/5/7 read like tray-hold idle) |
| Walk-compatible carry-in / return | FAIL (frame 0 opens with a raised paw, not a neutral carry) |
| Compress / wind-up / peak / rebound / recovery arc | FAIL (not discernible — frames read as unrelated idle poses) |
| Chin lift + dreamy upward gaze at peak | FAIL (no peak pose identifiable) |
| Knee lift + tiny hop/pivot accent at peak | FAIL |
| Compact whole-body rhythm | FAIL |

### 3.3. Style class

AutoSprite rendered the sheet in its own soft semi-anime chibi style, not
PingFighter's 16-bit flat pixel class. Outlines are anti-aliased, shading
is soft, palette is more saturated than the canonical. The sheet is a
different readability class from `menhera_boss_sheet.png` and
`menhera_boss_victory.png`. Per CLAUDE.md §3.1.1 this alone is a reject.

### 3.4. Scale read

- Body scale lock vs walk: NOT directly comparable (256×256 vs canonical
  688×768 per cell) but the body-read ratio inside the cell looks
  plausible (40–55% fill). Not a disqualifier on its own.

## 4. Hard-reject conditions hit

- Different Menhera (identity drift on cap, bangs, gloves, med-kit, bows, tail)
- Greeting-wave read
- Style class noticeably softer / more anime than the canonical set
- Bow count drift from 4 → 3

## 5. Verdict

**Not a canonical turn candidate.** Do NOT overwrite
`items/menhera_boss_turn.png`. Keep current runtime state (visible turn
playback disabled / hop-only fallback) until we have a proper sheet.

## 6. Why framewise fallback is unlikely to rescue this path

AutoSprite's failure mode here is not a single bad sequence — it is:

1. **Style class shift.** The engine renders soft semi-anime chibi
   regardless of how pixel-flat the reference image is. Running
   framewise (`generate_pose` for peak, then entries/recoveries)
   would produce the same style class, so stitched frames would still
   break the cross-sheet clarity rule (CLAUDE.md §3.1.1).
2. **Accessory identity drift.** The engine regularized Menhera's
   gingham cap, syringe, cream bangs, cat-paw pads, med-kit, and
   cloth-tail into generic nurse-maid art. That drift survives into
   any pose generated from the same base, so framewise would not
   recover the lost identity elements either.

Framewise is only useful when the engine already lands the style and
identity correctly and only the sequence coherence is broken. That is
not this failure mode. Recommended next steps:

- **Stay with Gemini MCP** via the `sprite-generation` skill
  (`prompts/turn.md`) for future Menhera turn passes. Gemini has been
  pixel-style-disciplined on Menhera in prior iterations.
- If AutoSprite is still wanted as a second opinion, try
  `quality=legendary` **with a heavier character description** that
  explicitly names "flat 16-bit pixel art, thick black pixel outlines,
  limited-saturation pastel, NO anti-aliasing, NO soft shading."
  Confidence is low that this overrides AutoSprite's base art style,
  but it is the only knob left before framewise.
- Meanwhile the **runtime escape hatch** in CLAUDE.md / AGENTS.md is
  correct: front-biased walk + hop-only direction-change accent, no
  visible turn-sheet playback, until replacement art exists.

## 7. Codex handoff note

```
Menhera turn experiment via AutoSprite MCP completed. No canonical
turn overwrite. Asset state unchanged:

- items/menhera_boss_sheet.png        -> canonical walk (unchanged)
- items/menhera_boss_turn.png         -> previous turn (unchanged, do not promote anything)
- items/menhera_boss_victory.png      -> quality reference (unchanged)
- .tmp/menhera_turn_autosprite_*.png  -> experimental candidates (NOT for runtime)

No runtime wiring required from this experiment. Keep the existing
Menhera turn policy in pingfighter.py / entities/menhera_boss_sprite.py:
  - front-biased walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off until a replacement passes QA

If a later AutoSprite run (legendary + stronger style prompt) or a
new Gemini pass lands a usable turn sheet, it will arrive as a new
items/menhera_boss_turn.png + .jpeg pair with a handoff note re-enabling
visible turn playback. Do not change runtime behavior on the basis of
this experiment alone.
```
