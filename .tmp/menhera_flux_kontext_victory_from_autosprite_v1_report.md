# Menhera Victory AutoSprite Motion → FLUX Render — V1 Report

**Status: HOLD — MIXED RESULT. STEP 1 (AutoSprite motion block) produced a usable victory arc with a clear f5 peak triumph. STEP 2 (FLUX final render) preserved canonical identity cleanly (no V3-style twin-tail / red-ribbon leak) BUT did NOT absorb the AutoSprite peak motion — the final sheet reads flat, similar to the already-applied P2 publish. Stop-and-ask triggered: "FLUX preserves identity but celebration is still too flat". Recommendation: descend to peak-first approach.**

---

## 1. STEP 1 — AutoSprite motion block

### 1.1. Input

- `characterId`: `cmo3neh96006ip0c2k14guhu9` (existing V2 dense identity board upload from the earlier turn branch; no new character / upload cost)
- `kind = custom`, `frameCount = 8`, `quality = standard`, `removeBg = ultra`
- Prompt scope: front-facing unmistakable victory celebration 8-frame arc with vertical upward beat and explicit f5 peak triumph
- Cost: 5 AutoSprite credits. Remaining: 1485 / 1500.

### 1.2. Output

- `.tmp/menhera_victory_autosprite_motion_v1.png` (768×768 RGBA, 3×3 layout, 8 frames + 1 empty cell — standard AutoSprite packing)
- `.tmp/menhera_victory_autosprite_motion_v1_zoom.png` (4× NN zoom for QA)

### 1.3. QA

| AutoSprite QA question | Result |
|---|---|
| Does the sequence clearly read as victory? | YES — especially f4, f5, f7 which show raised arms + open-mouth happy faces |
| Is there a true peak triumph frame? | **YES — f5: both arms raised high, open-mouth delighted face** |
| Does motion rise vertically rather than sway laterally? | MOSTLY — arm raises are the primary verticality; body hop is weaker |
| Can this serve as motion-only blocking for FLUX? | **YES — f5 is the kind of peak anchor the FLUX pass needs** |
| Identity precision (intentionally NOT the acceptance criterion at this step) | AutoSprite style as expected — softer anime-chibi with its own prop simplifications. Not usable as final pixel. |

STEP 1 **PASS**. The motion block is a legitimately better acting
reference than the current runtime P2 victory. Forwarded to STEP 2.

## 2. STEP 2 — FLUX Kontext max final render

### 2.1. Input stack

| Slot | File | Intended role |
|---|---|---|
| `input_image` | `items/menhera_boss_sheet.png` | **ABSOLUTE** identity master |
| `input_image_2` | `.tmp/menhera_victory_autosprite_motion_v1.png` | MOTION / CELEBRATION acting reference ONLY (not identity / style / props) |
| `input_image_3` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board for prop preservation |

Explicit exclusions (honored): old victory backup, current runtime
victory, turn sheet.

Prompt scope: identity from input 1, acting from input 2, style locked
to input 1's pixel class. Hard anti-drift clauses against V3 failure
modes (twin-tail design, side red-ribbons, anime-soft rendering, pink
sock trim, etc.).

Model: `flux_kontext_max`, `aspect_ratio = 16:9`, output 1392×752 RGB.

### 2.2. Output

- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1.png` (1392×752 RGB, 4×2)
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1.jpeg` (JPEG q=95)
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_zoom.png` (4× NN zoom)
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_frame_{1..8}.png` (per-frame 3× zoom)
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_vs_runtime.png` (vs currently-applied P2 victory)
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_vs_walk.png` (vs canonical walk)
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_vs_motionblock.png` (vs AutoSprite motion block from STEP 1)

### 2.3. QA — identity

| Locked element | V3 (earlier failed pass) | FLUX-from-autosprite V1 | Verdict |
|---|---|---|---|
| Canonical Menhera across all 8 frames | FAIL (row 2 twin-tail leak) | **PASS** — all 8 cells read as same canonical Menhera | ✓ fixed |
| Fluffy pink outer hair + cream/blonde inner bangs | FAIL row 2 | PASS all 8 | ✓ |
| Gingham cap + red cross + syringe | partial | PASS | ✓ |
| No twin-tail hairstyle leak | FAIL row 2 | **NO LEAK** | ✓ |
| No big red side-ribbons | FAIL row 2 | **NO LEAK** | ✓ |
| Gray eyes + heart cheek on viewer-right | PASS on row 1 | PASS all 8 | ✓ |
| Gray cat-paw gloves + pink pads | PASS | PASS | ✓ |
| Med-kit on same side | partial | present on most cells where not paw-occluded | ✓ |
| Pink check cloth-tail motif | PASS | PASS | ✓ |
| Plain white thigh-highs | PASS | PASS (no pink trim returning) | ✓ |
| Thick black pixel outlines / 16-bit pixel class | PASS | PASS | ✓ |
| 4 black bows on white panel | 3 visible | 3 visible | partial (accepted under P2 flexibility) |

**Identity PASS.** Most important win: **V3's twin-tail + big red
ribbon leak is completely absent** in this pass. Using the AutoSprite
motion block instead of old-victory as input 2 worked — AutoSprite's
motion block's own style is soft / generic enough that FLUX treated
it as acting guidance without pulling a competing character design
into the sheet.

### 2.4. QA — acting (the failure)

| Acting rule | AutoSprite motion block (input 2) | Current runtime P2 victory | FLUX-from-autosprite V1 |
|---|---|---|---|
| At least one clear peak triumph frame | **YES — f5 both arms raised + happy face** | NO | **NO** — no cell shows raised paws at triumph height |
| Visible upward beat (hop / bounce / lift) | yes | no | no |
| Open-mouth delighted smile on peak | yes | no | no |
| Expression progression across the arc | yes (builds + peak + settles) | flat | flat (neutral across most cells) |
| Body rhythm rises and releases vertically | yes | no | no |
| Not a walk / turn / idle sway | celebration clearly | partial (was reported to read as turn extension) | still too flat — reads mostly as conservative idle / neutral variations with small pose variance |

**Acting FAIL.** Despite the AutoSprite motion block having a clean
peak at f5, the FLUX final render did NOT imprint that peak into any
of its 8 cells. The paws stay near the hips in all 8 frames. No cell
shows the "I won" raised-paw + open-mouth happy face that f5 of the
motion block had.

This triggers the handoff's explicit stop-and-ask clause:

> if FLUX preserves identity but celebration is still too flat, HOLD
> and say full-sheet direct is not enough for acting

### 2.5. Old-victory-like leak check

None. The hard anti-drift rules held. No twin-tail, no big side
ribbons, no anime-soft regression, no sock-top pink, no loss of
syringe / paw pads / med-kit. The motion-master-swap (old victory →
AutoSprite motion block) eliminated the V3 identity-leak attractor
cleanly.

## 3. Is this a true upgrade over the currently applied runtime victory?

**No — it is a LATERAL move.** Compared to P2:

| Dimension | P2 applied victory | FLUX-from-autosprite V1 |
|---|---|---|
| Identity lock vs canonical walk | strong | strong |
| Celebration acting | flat | still flat |
| Peak triumph frame | absent | absent |
| Expression progression | minimal | minimal |
| Twin-tail identity leak risk | none | none |

P2 is already a clean-identity / flat-acting sheet. V1 from the
AutoSprite-motion pipeline is **also** a clean-identity / flat-acting
sheet. Swapping P2 for V1 does not improve the live-runtime "reads
like turn extension, not celebration" problem — it just replaces one
flat-celebration sheet with another, with marginally different pose
variations.

## 4. Pipeline learning — what this pass told us

The V3 → V1-from-autosprite sequence confirms a two-part attractor:

1. **When the motion master has a competing character design
   (old victory), FLUX preserves motion but breaks identity** (V3).
2. **When the motion master is a soft / generic AutoSprite render,
   FLUX preserves identity but fails to absorb the motion**
   (this pass).

Single-call `flux_kontext_max` multi-reference cannot square these two
failure modes against each other while keeping the canonical pixel
class. The motion conditioning is consistently weaker than the
identity conditioning when the motion master's style differs sharply
from input 1's style. AutoSprite's softer rendering caused FLUX to
effectively downweight input 2's poses.

## 5. Recommendation — descend to peak-first

Single full-sheet direct generation is not going to give us both
identity and acting in one call on this branch. We must descend.

### Option X1 — peak-first from AutoSprite motion block (recommended)

1. **Peak only** via `flux_kontext_max` at 1024×1024 aspect 1:1:
   - `input_image` = `items/menhera_boss_sheet.png` (canonical walk)
   - `input_image_2` = cropped f5 frame from the AutoSprite motion
     block (peak pose only, single cell, not the full 8-frame sheet)
   - `input_image_3` = `.tmp/menhera_autosprite_reference_board_v2.png`
   - Prompt targets the peak pose explicitly: both paws raised with
     pink pads forward, open-mouth delighted face, slight hop, body
     lifted, all rendered in canonical pixel class.
2. QA the peak at 1024×1024: 4-bow, paw pads, med-kit, no identity
   leak, no style leak from AutoSprite.
3. If peak passes, do frame expansion (f1/f2/f3/f4/f6/f7/f8) using
   the peak as primary anchor, with per-frame prompts for the rise/
   build/settle states. Same pipeline used successfully on the turn
   branch.
4. Stitch 4×2 at 2752×1536 with uniform cross-frame scaling.
5. JPEG + `remove_bg.py` nukki. Edge QA. Gameplay QA vs walk + P2 +
   old victory.
6. Promote only if all three hold.

This path used a cropped single-cell peak pose as input 2, which
bypasses the "soft style diluting motion conditioning" problem — FLUX
at 1024×1024 with a single cell has enough pixel budget to imprint a
specific pose.

### Option X2 — accept current P2 victory and move on

Recognize that the "turn-extension feel" of the current P2 applied
victory is cosmetic at gameplay scale and not worth more FLUX credits
to solve. Leave victory alone and pivot to other work. Least-cost
path. Only recommended if the user has another higher-priority branch
to open.

### Not recommended

- Another full-sheet direct pass with a different motion master.
  Confirmed failure pattern from V3 + V1-from-autosprite.
- Another AutoSprite motion block regeneration with stronger wording.
  Not needed — f5 of the existing motion block is already an
  acceptable peak reference. The bottleneck is FLUX conditioning,
  not AutoSprite acting.

My recommendation: **Option X1.** Turn branch proved the peak-first +
frame-expansion pipeline works end-to-end; victory can use the same
pipeline with the AutoSprite f5 pose as the peak-anchor seed.

## 6. Output files (`.tmp/`)

### STEP 1

| File | Contents |
|---|---|
| `menhera_victory_autosprite_motion_v1.png` | 768×768 RGBA, 3×3 layout with 8 celebration frames |
| `menhera_victory_autosprite_motion_v1_zoom.png` | 4× NN zoom for QA |

### STEP 2

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_from_autosprite_v1.png` | 1392×752 RGB, 4×2 final render (identity PASS, acting FAIL) |
| `menhera_flux_kontext_victory_from_autosprite_v1.jpeg` | JPEG q=95 |
| `menhera_flux_kontext_victory_from_autosprite_v1_args.json` | FLUX request args log |
| `menhera_flux_kontext_victory_from_autosprite_v1_zoom.png` | 4× NN zoom |
| `menhera_flux_kontext_victory_from_autosprite_v1_frame_{1..8}.png` | Per-frame 3× zoom |
| `menhera_flux_kontext_victory_from_autosprite_v1_vs_runtime.png` | vs currently-applied P2 victory |
| `menhera_flux_kontext_victory_from_autosprite_v1_vs_walk.png` | vs canonical walk |
| `menhera_flux_kontext_victory_from_autosprite_v1_vs_motionblock.png` | vs STEP 1 motion block (shows motion did not transfer) |
| `menhera_flux_kontext_victory_from_autosprite_v1_report.md` | This report |

Canonical asset + runtime unchanged.
`items/menhera_boss_victory.{png,jpeg}` is still the P2 publish.
Turn R1 branch unaffected.

## 7. Summary — answers to the handoff's §final QA

1. **AutoSprite motion block usable?** YES — STEP 1 produced a clean
   celebration arc with a clear f5 peak triumph.
2. **FLUX preserved canonical walk identity?** YES — fluffy hair,
   cream/blonde bangs, gingham cap, heart cheek (viewer-right), paw
   pads, med-kit, plain white socks all locked. V3's twin-tail + red-
   ribbon leak is completely absent.
3. **Final sequence reads as true victory celebration?** **NO — flat.**
   FLUX did not absorb the AutoSprite peak pose into any of its 8
   cells. Arms stay near hips across all frames. No peak triumph,
   no upward beat.
4. **Old-victory-like leak?** None. Hard anti-drift rules held.
5. **Upgrade over current applied runtime victory?** **No — lateral
   move** (both are clean identity / flat acting).
6. **Publish candidate or descend?** **Descend.** Recommended path:
   Option X1 — peak-first using the AutoSprite f5 cell cropped as
   the peak-pose motion reference, then frame-expand using the
   turn-branch pipeline.

No code changes. Runtime unchanged. Turn R1 close-out still applies.
