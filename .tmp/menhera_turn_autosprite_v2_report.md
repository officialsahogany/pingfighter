# Menhera Turn via AutoSprite MCP — V2 Report

**Status: EXPERIMENT COMPLETE. CANDIDATE STILL NOT FULLY CANONICAL, BUT MATERIALLY CLOSER. Canonical turn NOT overwritten.**

## 1. What V2 changed vs V1

| Dimension | V1 | V2 |
|---|---|---|
| Reference upload | Single front-facing walk cell (`menhera_autosprite_reference_v1.png`) | Dense identity board (`menhera_autosprite_reference_board_v2.png`): canonical walk full-body + alternate full-body + victory-style full-body + cap detail + face detail + torso/bows detail + med-kit/gloves/cloth-tail detail |
| Character description | Short, single-reference | Heavy identity description with explicit identity-prop list + explicit style-ban list (no anti-aliased, no anime gradient, no painterly, no mobile-game chibi) |
| Motion brief | Creative turn (chin lift, loose flourish, hop accent, rebound, recovery) | Conservative micro-turn (almost identical to canonical walk; frames = tiny plant / tiny chin-lift / restrained peak / tiny rebound / settle / walk return) |
| Motion amplitude | Full direction-change gesture | Very small, restrained; no big arm flourish, no big knee lift |
| Explicit bans | No side profile, no greeting wave, no attack swing | Same + no raised hand, no tray hold, no dance, no theatrical acting |

V2 did use the dense identity board upload as the actual character base
image (AutoSprite character id `cmo3neh96006ip0c2k14guhu9`, slug
`menhera-nurse-girl-v2-pingfighter-s3-identity-board`). Cost: 5 credits
for this animation + 0 credits for the upload. Remaining: 1490 / 1500.

## 2. Output files (`.tmp/`)

| File | Content |
|------|---------|
| `menhera_autosprite_reference_board_v2.png` | Dense identity board upload source (user-provided) |
| `menhera_turn_autosprite_sheet_v2.png` | Raw sheet from AutoSprite (768×768, 3×3, 8 frames + 1 empty cell) |
| `menhera_turn_autosprite_atlas_v2.json` | Frame atlas, 256×256 per cell |
| `menhera_turn_autosprite_sheet_v2_zoom.png` | 4× nearest-neighbor zoom for QA readability |
| `menhera_turn_autosprite_v2_frame_{0..7}.png` | Individual frames at 512×512 for QA |
| `menhera_turn_autosprite_v2_report.md` | This report |

`items/menhera_boss_turn.png` is **NOT** overwritten.

## 3. QA vs canonical + V1

### 3.1. Identity lock

| Element | V1 | V2 | V2 vs canonical |
|---|---|---|---|
| Cream/blonde inner front bangs | lost (all pink) | **preserved** across all frames | PASS (major recovery) |
| Pink fluffy outer hair | present | present | PASS |
| Hair silhouette volume | slightly trimmed | slightly trimmed but closer to canonical | partial |
| Gingham nurse cap pattern | lost (plain) | red cross + cap present; gingham check not clearly legible at 256px | weak partial |
| Syringe on cap | absent | small accent element visible on cap edge in several frames; not clearly readable | weak partial |
| Red front ribbon | absent | streamers visible, front ribbon weak | partial |
| No black cat ears | PASS | PASS | PASS |
| Gray/silver eyes with strong lashes | drifted slightly blue/soft | closer to canonical gray + lashes | partial improvement |
| One pink heart cheek mark | PASS | PASS (correct side) | PASS |
| Pink dress + white center panel | PASS | PASS | PASS |
| Exactly 4 black bows | only 3 visible | 3 visible at 256px; 4th possibly occluded by arm | still weak |
| Gray cat-paw gloves with pink pads | gloves plain | gloves present with small pink accents at bottom | partial |
| Med-kit on same side | ambiguous / tray-like | small pink rounded pouch visible at hip | partial recovery |
| Pink check cloth-tail motif | plain pink cat-tail | pink tail with darker accent, closer to cloth-tail | partial |
| White thigh-highs | PASS | PASS | PASS |
| Black X ankle accessories | subtle | subtle | PASS |
| Thick black pixel outlines | soft anti-aliased | thicker, some anti-alias remaining on hair | partial |
| Flat limited-saturation palette | soft anime-class | closer to flat pastel; hair still has a soft highlight | partial |

### 3.2. Motion brief

| Rule | V1 | V2 |
|---|---|---|
| NOT side-profile rotation chart | PASS | PASS |
| NOT +90 / 0 / -90 sequence | PASS | PASS |
| NOT greeting wave | FAIL (multiple waves) | **PASS** |
| NOT tray-hold idle | FAIL (tray present) | **PASS** |
| NOT attack swing | PASS | PASS |
| NOT dance / theatrical | partial fail | PASS |
| Conservative amplitude | too large | **PASS (small, restrained)** |
| Frontal read every frame | mostly | full PASS |
| Readable carry-in → peak → return arc | FAIL | partial — motion is small but reads more as "8 slightly varied idle poses" than a clean single turn arc with a named peak |
| Walk-compatible exit/entry | FAIL | partial |

### 3.3. Style class

V2 is materially closer to PingFighter 16-bit pixel art than V1 but has
not fully crossed the threshold. Hair still shows a soft pastel
highlight that reads more illustrated than flat-pixel, and outline
thickness is closer to canonical but still softer at gameplay size.
Under CLAUDE.md §3.1.1 (cross-sheet clarity consistency) this is not yet
a "same clarity class as `menhera_boss_sheet.png` / `menhera_boss_victory.png`"
result.

## 4. V1 → V2 delta summary

**Clear wins:**
- Cream/blonde inner bangs recovered (was the biggest V1 drift)
- Med-kit pouch recovered (was generic small object in V1)
- Greeting-wave / tray-hold failure modes eliminated
- Motion amplitude now conservative and appropriate for a micro-turn
- Style class moved noticeably closer to PingFighter pixel art

**Still weak:**
- Gingham check, syringe, front ribbon, and 4-bow count are hard to verify at 256px frame size; AutoSprite still simplifies fine accessory detail
- Style still has soft shading on hair and slightly anti-aliased
  outlines — not yet the flat SNES-sprite class of the canonical walk
- The 8 frames do not read as a single tight "micro-turn arc" yet —
  they read as conservative idle variations; runtime needs a clean
  transition arc to swap into and out of the walk cleanly

## 5. Canonical candidate verdict

**Not yet a canonical turn candidate.** V2 is usable as a visual
reference or as pose-blocking ideation, but as a runtime turn sheet it
would still introduce a visibly softer / more anime-ish readability
class than the rest of the Menhera set, and it does not reliably carry
the full identity prop list at gameplay size.

Do **not** overwrite `items/menhera_boss_turn.png`. Keep the existing
runtime policy: front-biased canonical walk + hop-only direction-change
accent, no visible turn-sheet playback.

## 6. AutoSprite role recommendation

Per the V2 handoff's own reject condition, V2 still lands in "motion
ideation / reference support, not final turn-sheet generator" for
Menhera specifically. Concrete role split going forward:

- **Final turn-sheet renderer** for Menhera: **Gemini MCP** via the
  `sprite-generation` skill (`prompts/turn.md`), same pipeline used for
  the canonical walk and the accepted victory sheet.
- **AutoSprite**: use as
  - motion / pose-blocking ideation when a turn brief is unclear
  - a second opinion on peak-pose framing via `generate_pose`
  - a quick consistency probe when we are unsure whether a brief drifts
    into greeting-wave / tray-hold territory — V2 proved the
    "conservative micro-turn + dense identity board" recipe actually
    suppresses the V1 failure modes, so it is useful as a structural
    validator even if the final pixels come from Gemini

Before giving up on AutoSprite as a final renderer for this specific
character, one more knob is available: `quality=legendary`. That
changes cost (higher per-animation) and may slightly harden the style
lock, but confidence that it would cross the PingFighter pixel-class
threshold on Menhera is low. Not recommended to spend more credits on
that path without a separate user sign-off — the structural recipe is
already derisked by V2.

## 7. Codex handoff note

```
Menhera turn V2 experiment via AutoSprite MCP (dense identity board +
conservative micro-turn) completed. Canonical turn asset unchanged.

- items/menhera_boss_sheet.png        -> canonical walk (unchanged)
- items/menhera_boss_turn.png         -> previous turn (unchanged, do not promote anything)
- items/menhera_boss_victory.png      -> quality reference (unchanged)
- .tmp/menhera_turn_autosprite_sheet_v2.png  -> experimental candidate (NOT for runtime)
- .tmp/menhera_turn_autosprite_atlas_v2.json -> matching atlas (NOT for runtime)

Runtime policy unchanged:
  - front-biased canonical walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off until a replacement passes QA

AutoSprite recommendation:
  - do NOT use AutoSprite output as the final Menhera turn renderer
  - AutoSprite V2 recipe (dense identity board + conservative micro-turn
    + identity-heavy characterDescription) is retained as a motion /
    pose-blocking ideation tool
  - final Menhera turn art should come from Gemini MCP via the
    sprite-generation skill (prompts/turn.md)

No runtime wiring changes required from this experiment.
```
