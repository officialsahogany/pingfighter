# Menhera Turn Peak Pose via FLUX Kontext MCP — V1 Report

**Status: STRONGEST CANDIDATE YET. Identity + style class materially pass. Mild bow-count drift + pose reads more neutral-charm than clear peak-redirect. Canonical turn NOT overwritten.**

## 1. Model / method

- Tool: `flux_kontext_max` (FLUX.1 Kontext [max], image-to-image edit)
- Mode: multi-reference image-to-image with a single text prompt
- Output: ONE single full-body peak-pose candidate, 1024×1024 PNG on
  near-white background, RGB (no alpha — nukki still needed before any
  runtime use)
- `aspect_ratio = 1:1`, `safety_tolerance = 2`, seed not pinned

## 2. References actually used

| Slot | File | Role |
|---|---|---|
| `input_image` | `.tmp/menhera_autosprite_reference_board_v2.png` | primary dense identity board (cap detail, face detail, torso/bows detail, med-kit/gloves/cloth-tail detail, full-body canonical) |
| `input_image_2` | `items/menhera_boss_sheet.png` | canonical walk anchor |
| `input_image_3` | `items/menhera_boss_victory.png` | quality / readability tier reference |
| `input_image_4` | `.tmp/menhera_turn_autosprite_v2_frame_3.png` | AutoSprite V2 motion-amplitude hint only (explicitly scoped to "micro-turn peak amplitude", NOT as an identity anchor) |

Prompt scope was a single peak-pose micro-turn brief (front-biased,
small chin lift, tiny outward paw preparation, tiny knee gather,
compact whole-body redirect accent), with explicit bans on greeting
wave, attack swing, dance, tray hold, side profile, and 3/4 turn, plus
a full identity-prop list and explicit style bans (no anti-aliasing,
no anime-soft shading, no painterly rendering, no modern mobile-game
chibi look, match the same clarity class as the walk and victory).

## 3. Output files (`.tmp/`)

| File | Content |
|------|---------|
| `menhera_flux_kontext_peak_v1.png` | FLUX Kontext max output, 1024×1024 RGB PNG |
| `menhera_flux_kontext_peak_v1_args.json` | FLUX request args log (auto-written by the MCP tool) |
| `menhera_flux_kontext_peak_v1_zoom.png` | 2× nearest-neighbor zoom for QA readability |
| `menhera_walk_cell3_for_compare.png` | Canonical walk cell (row 0 col 3) side-by-side anchor |
| `menhera_flux_kontext_peak_v1_report.md` | This report |

`items/menhera_boss_turn.png` is **NOT** overwritten.

## 4. Identity lock QA vs canonical

| Element | Canonical | FLUX Kontext V1 | Result |
|---|---|---|---|
| Cream / blonde inner front bangs | present, asymmetric with pink outer fluff | **preserved**, clear cream/blonde on one side flanked by pink outer | PASS (slight side-placement drift vs canonical; not disqualifying) |
| Pink fluffy outer hair with rounded silhouette | present | **preserved** | PASS |
| Pink/white gingham nurse cap | gingham check pattern | **present** — gingham check visibly reconstructed with red cross | PASS |
| Syringe on cap | present | **present** (small accent on one side of cap) | PASS |
| Red front ribbon | present | **present** (small front accent on cap brim) | PASS (weaker than canonical but readable) |
| No black cat ears | absent | absent | PASS |
| Gray / silver eyes with strong lashes | present | present | PASS |
| One pink heart cheek mark (one side) | present | present on correct side | PASS |
| Pink outfit with white center front panel | present | present | PASS |
| Exactly 4 black bows on white panel | 4 | **3 clearly visible** (4th may be hidden under hem) | PARTIAL — mild bow-count drift, candidate for a refinement pass |
| Dark gray cat-paw gloves | present | **present** on both hands | PASS |
| Pink paw pads on gloves | present | **visibly present** on both gloves | PASS (this was V1/V2 AutoSprite's biggest miss) |
| Med-kit pouch on same side as walk | present | **present** — small white pouch with pink cross at hip | PASS |
| Pink check cloth-tail motif | present | **present** — pink cloth tail with tan/check accent near med-kit | PASS |
| White thigh-high socks | present | present | PASS |
| Black X ankle accessories | present | present | PASS |
| Petite chibi body | present | present | PASS |
| Thick black pixel outlines | thick | **thick, pixelated** | PASS |

## 5. Style class QA

| Rule | Result | Note |
|---|---|---|
| 16-bit retro pixel art | PASS | clearly pixelated large-block rendering, not anime illustration |
| Chibi proportions | PASS | |
| Thick black pixel outlines | PASS | consistent with canonical |
| Flat limited-saturation pastel palette | PASS with minor caveat | some soft pink hair highlight remains but is within the pastel pixel-art class, not anime-soft |
| Clean hard-edged pixels | PASS | |
| No anti-aliased anime softness | PASS | |
| No painterly shading | PASS | |
| No modern mobile-game chibi rendering | PASS | |
| Same clarity class as `menhera_boss_sheet.png` and `menhera_boss_victory.png` | **materially PASS** | the candidate reads in the same PingFighter pixel-art family as the canonical walk and the victory reference; subtle face/eye rendering is a touch softer than the crispest canonical frame but is inside the accepted clarity band |

## 6. Pose QA

| Rule | Result |
|---|---|
| Body and face FRONT-FACING | PASS |
| Small chin lift | weakly present |
| Dreamy upward gaze | weakly present — gaze reads mostly neutral, slightly raised |
| Tiny outward paw preparation | **present** — one paw is raised slightly with pads showing |
| Tiny knee gather | weakly present |
| Compact whole-body redirect accent | **present in aggregate**, but the pose reads more as "slight-charm idle peak" than a strongly telegraphed "direction-change peak" |
| NOT greeting wave | PASS |
| NOT attack swing | PASS |
| NOT dance / theatrical | PASS |
| NOT tray hold | PASS |
| NOT side profile / 3/4 turn | PASS |

## 7. Comparison across all three attempts

| Dimension | AutoSprite V1 (single frame upload, free turn) | AutoSprite V2 (dense board, conservative micro-turn) | FLUX Kontext max V1 (dense board + walk + victory, peak pose) |
|---|---|---|---|
| Cream/blonde inner bangs | lost | recovered | **preserved and visible** |
| Gingham cap pattern | lost | weak | **visible** |
| Syringe on cap | absent | weak | **present** |
| Front ribbon | absent | weak | **present** |
| 4-bow count | 3 | 3 | 3 (still mild drift) |
| Paw-pad gloves | lost | partial | **fully present** |
| Med-kit | lost (tray) | partial | **clearly present** |
| Check cloth-tail | lost (plain cat tail) | partial | **present with check accent** |
| Style class vs PingFighter pixel | anime-soft (FAIL) | moderately closer, still softer than canonical | **solid PingFighter pixel class** |
| Greeting wave / tray-hold failure modes | present | eliminated | eliminated |
| Overall: usable anchor for next step | No | as motion ideation only | **Yes, as the next-step peak anchor** |

## 8. Is this peak pose a usable anchor for entry / recovery / full turn?

**Yes, this is the first candidate that qualifies as an anchor pose.**
Identity is preserved, style class is in the canonical PingFighter
family, and the pose is close to the micro-turn brief. The two
caveats are:

1. Bow count is 3, not 4 — worth one targeted refinement pass (narrow
   prompt: "add a fourth black vertical bow below the third, same size
   and spacing") before treating this exact PNG as the reference peak.
2. The pose reads slightly more as "cute neutral with a paw out" than
   a clearly telegraphed "chin lifted, about to redirect." For the
   full turn sheet, the entry/recovery frames can compensate by
   surrounding this as the peak and letting the arc do the direction-
   change work.

Runtime behavior is unchanged — this is still asset-side work only.

## 9. Canonical overwrite?

**No.** Keep `items/menhera_boss_turn.png` as is. This is a single
peak-pose candidate, not a full 8-frame sheet. Canonical promotion
waits until:

- A corrected 4-bow version of this peak pose is accepted, and
- Entry (`plant → chin-lift → peak`) and recovery (`peak → rebound →
  settle → walk-return`) frames are generated in the same FLUX Kontext
  class with the same identity anchors, and
- A stitched 4×2 sheet passes the full turn-sheet QA checklist from
  `sprite-generation/checklists.md`.

Runtime stays on front-biased walk + hop-only direction-change accent
until that full pipeline lands.

## 10. Recommended next actions (for the user to decide on)

1. **Refinement pass** on this peak pose: same references, same
   prompt, narrow edit instruction to enforce exactly 4 black vertical
   bows stacked on the white front panel. Output as
   `.tmp/menhera_flux_kontext_peak_v2.png`.
2. Once peak v2 passes identity + bow-count QA, generate entry and
   recovery frames with the same reference stack, anchoring each
   new image on peak v2 via `input_image` while keeping the dense
   identity board in a secondary slot.
3. Stitch into a 4×2 8-frame turn sheet, run the sprite-generation
   skill's nukki on the stitched JPEG/PNG, then run the
   `sprite-generation/checklists.md` turn-sheet QA.
4. Only after all of the above, revisit Codex handoff for a visible
   turn-playback re-enable pass per `AGENTS.md`.

## 11. Codex handoff note

```
Menhera turn peak pose experiment via FLUX Kontext max completed.
Canonical turn asset unchanged.

- items/menhera_boss_sheet.png                  -> canonical walk (unchanged)
- items/menhera_boss_turn.png                   -> previous turn (unchanged, do not promote anything yet)
- items/menhera_boss_victory.png                -> quality reference (unchanged)
- .tmp/menhera_flux_kontext_peak_v1.png         -> FIRST usable peak-pose anchor (NOT for runtime)
- .tmp/menhera_flux_kontext_peak_v1_zoom.png    -> 2x zoom for QA (NOT for runtime)
- .tmp/menhera_flux_kontext_peak_v1_report.md   -> QA report
- .tmp/menhera_turn_autosprite_sheet_v{1,2}.png -> prior AutoSprite candidates, retained as motion ideation only (NOT for runtime)

Runtime policy unchanged:
  - front-biased canonical walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off until a FULL stitched
    FLUX-based 8-frame turn sheet passes sprite-generation QA
    (not just this peak pose)

FLUX Kontext max now demonstrated as a viable final renderer for
Menhera turn assets. AutoSprite remains in motion-ideation /
pose-blocking role. Gemini MCP remains the other known-good path.

No runtime wiring changes required from this experiment.
```
