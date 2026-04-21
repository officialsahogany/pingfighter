# Menhera Victory FLUX Full-Sheet V3 Celebration-First Report

**Status: HOLD — REJECT AS PUBLISHING CANDIDATE. V3 DID land a genuine peak triumph frame (f5) — the biggest acting weakness of the P2 publish was solved. BUT the sheet split into TWO distinct Menhera identities across its two rows (row 1 = canonical fluffy Menhera, row 2 = twin-tail + red-ribbon Menhera pulled from the old victory backup). Under the handoff's stop-and-ask rule ("if FLUX gets stronger celebration but breaks face identity, HOLD and reject"), V3 cannot be promoted. Recommendation: descend to peak + frame expansion with canonical walk as the sole identity anchor.**

---

## 1. Reference stack used

| Slot | File | Intended role | Actual outcome |
|---|---|---|---|
| `input_image` | `items/menhera_boss_sheet.png` | IDENTITY MASTER — sole canonical anchor | respected on row 1 only |
| `input_image_2` | `.tmp/menhera_victory_runtime_backup_20260418/menhera_boss_victory_old.png` | MOTION / CELEBRATION MASTER (acting only, NOT identity) | **leaked its identity into row 2** (twin-tail + red-ribbon Menhera visible on f5/f6/f8) |
| `input_image_3` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board for prop preservation | partial help |
| `input_image_4` | (unused) | per handoff, current live victory was "use after generation as negative reference only" | not passed as input |

Model: `flux_kontext_max`, `aspect_ratio = 16:9`, `output_format = png`.
Output: 1392×752 RGB.

FLUX explicitly did NOT honor the prompt's instruction "when input 1 and
input 2 conflict on face / identity, input 1 wins." Row 2 visibly
inherits old-victory identity cues. This is not a prompt tuning
problem the asset side can talk its way past — the single-reference
identity-blend is an attractor when the motion-master sheet itself has
a different character design.

## 2. Did V3 solve the current runtime victory's acting problem?

**Partially — but at unacceptable identity cost.**

| Acting rule | P2 publish (currently applied) | V3 |
|---|---|---|
| Clear "I won" energy on at least one peak frame | NO — all 8 cells read as conservative / idle-adjacent celebration | **YES — f5 shows a clearly triumphant closed-eye happy face with both paws raised and body lifted** |
| Upward celebration beat (hop / bounce / lift) | absent | visible on f5 (lifted body energy) |
| Expression progression across the arc | absent — almost same expression on every cell | present — row 1 quiet build, row 2 peak + satisfied smiles |
| Body rhythm rises and releases | no, mostly lateral idle | yes on f5 and partially f6, f8 |
| Does NOT read as walk / turn / idle sway | partial — the P2 applied sheet was reported to read like turn extension | V3 row 2 is unambiguously celebration; row 1 is still fairly neutral |

So on acting alone, V3 is a meaningful improvement. But it is not
isolable from the identity damage.

## 3. Canonical walk identity lock — PASS / FAIL per row

| Locked element | Canonical walk | V3 row 1 (f1–f4) | V3 row 2 (f5–f8) |
|---|---|---|---|
| Fluffy pink outer hair + CREAM / BLONDE inner bangs | present, asymmetric | **preserved** | **NOT preserved** — row 2 hair reads as twin-tail with sleeker hair body; cream/blonde bangs are still there but the overall silhouette is now a different hairstyle class |
| Rounded fluffy hair silhouette | present | preserved | **broken** — pigtail-style silhouette |
| Pink/white GINGHAM nurse cap with red cross + syringe | present, generous gingham + syringe visible | preserved, large gingham cap | **cap is much smaller**, gingham less prominent; red-cross preserved |
| Red ribbons on head | canonical has one small front ribbon | one small front ribbon on cap | **two large red pigtail ribbons on either side of the head** (this is a design that does not exist on the canonical walk and does exist on the old-victory backup — classic identity leakage from input 2) |
| Large gray/silver eyes with strong lashes | present | preserved | preserved but closed-eye happy-face on f5 / f8 (allowed on peak only) |
| Pink heart cheek mark on viewer-right | present | preserved | preserved on correct side |
| Pink dress with white center front panel + bows | 4 bows | 4 visible | 3 visible (acceptable under the handoff's flexibility clause) |
| Gray cat-paw gloves + pink pads | present | preserved | preserved on raised paws |
| Med-kit pouch with pink cross on same side | present | preserved on f2, f3, f4 (occluded on f1 by arm) | **reduced prominence or occluded on most cells** |
| Pink check cloth-tail motif near med-kit | present | preserved | preserved |
| White thigh-highs — NO pink trim | plain white | plain white | plain white |
| Black X ankle | present | present | present |
| Thick black pixel outlines | present | preserved | preserved |
| 16-bit pastel clarity class | canonical | matches | matches |
| Body scale ±5% of walk | baseline | ~matches | body reads slightly taller / more slender from the pigtail-silhouette change |

Net: **row 1 passes identity lock. Row 2 fails.** The two rows do NOT
read as the same Menhera.

This is exactly the hard-reject condition listed in the handoff:
"one or more frames read like a different Menhera" — triggered on all
four row-2 cells.

## 4. Is the peak frame actually joyful / triumphant?

**Yes — f5 is a genuine peak triumph frame.** Closed-eye happy face
(allowed on peak), open happy mouth, both paws raised with pink pads
forward, body slightly lifted off neutral. This is the first time in
this Menhera victory branch that a sheet has contained an unmistakable
"I won" frame.

The tragedy of V3 is that this peak is wearing the wrong identity.

## 5. Is the expression progression controlled?

**Partially controlled.**

| Frame | Intended | Observed |
|---|---|---|
| f1 | post-win recognition | calm neutral, canonical Menhera |
| f2 | joy starts to rise | still neutral, minor pose variation — no expression rise |
| f3 | excited gather / paw lift | still largely neutral |
| f4 | upward push into celebration | still neutral, canonical identity |
| f5 | PEAK TRIUMPH | strong triumph, identity drift to row-2 character |
| f6 | held celebration | calmer face than f5, identity still row-2 |
| f7 | soft satisfied afterglow | calm smile, row-2 identity |
| f8 | final happy hold | open-mouth smile, row-2 identity |

So expression progression works for row 2 (built peak → settle →
afterglow) but row 1 does not ramp up — there's no visible build from
f1 through f4. The sheet's celebration arc is really a "calm row 1 /
celebratory row 2" split, not a continuous 8-frame crescendo.

## 6. V3 as publishing candidate — GO / NO GO

**NO GO.** Under the handoff's own stop-and-ask clause:

> if FLUX gets stronger celebration but breaks face identity, HOLD
> and reject

V3 exactly matches this condition. The celebration acting is genuinely
better than P2, but the identity breaks. Canonical walk is the sole
identity anchor under R1; any sheet where 4 of 8 frames read as a
visibly different Menhera cannot be promoted.

A relaxed interpretation ("row 1 is canonical and that's enough for a
turn-style sheet, accept row 2 drift as a runtime cosmetic") is not
valid here because:
- Victory sheets typically play the later frames (peak + hold), which
  is exactly the row-2 block in this arc. Shipping row 2 means
  shipping the drift front-and-center.
- The handoff's §중요 결론 문구 for publish acceptance is "canonical
  walk remains the sole identity anchor" — a sheet with two
  identities cannot hold that line.

V3's acting upgrade is real, but not recoverable in-place.

## 7. Recommended next step

**Descend to peak + frame expansion, anchored on canonical walk only.**

The V3 experiment told us two useful things:
1. **FLUX can land a genuine peak triumph frame for Menhera victory**
   when the motion master permits it. So the peak we want is
   achievable.
2. **FLUX cannot be trusted to obey "input 2 is motion only, not
   identity" in a single multi-reference full-sheet call.** Identity
   leakage from the motion master is the attractor.

Both lessons point to the turn-workflow pipeline:

1. **Peak V1 first** — single 1024×1024 call, image-to-image, using
   canonical walk as primary anchor. Prompt for the specific peak
   emotional read (closed-eye delighted squint, both paws raised with
   pink pads forward, body lifted), but with the canonical Menhera
   hairstyle / cap / outfit / props locked. Do NOT include the old
   victory in the reference stack for this call — we want identity
   lock, not motion imitation. Acting energy comes from the prompt.
2. **QA peak v1** at 1024×1024 for 4-bow, pink pads, med-kit,
   face-in-the-canonical-family, no pigtail / red-ribbon design leak.
3. **Expand to 7 derived frames** (f1, f2, f3, f4, f6, f7, f8) with
   peak v1 as primary anchor, same stack as turn expansion (peak +
   canonical walk + dense identity board). f5 = peak v1.
4. **Stitch 4×2 at 2752×1536** with uniform scaling like the P2
   publish pipeline. JPEG + `remove_bg.py` nukki. Edge QA. Gameplay
   QA vs walk + vs P2 applied victory + vs old victory.
5. Promote only if all three comparisons hold.

Budget expectation (compare to turn branch): ~8 FLUX calls + narrow
touch-ups if needed. Identical cost structure to the turn branch that
ran to completion.

The alternate path — "one more full-sheet try with a stricter identity
clause and without old victory in slot 2" — is cheaper but has a clear
failure mode already observed: without the motion master, the sheet
lands at P2-style flat celebration (that's literally the V1 → P2
outcome). The motion master is needed to get celebration energy; the
motion master is what leaked the identity. Full-sheet direct cannot
square that circle.

## 8. Output files (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_v3.png` | 1392×752 RGB, 4×2 V3 sheet (row 1 canonical, row 2 identity drift) |
| `menhera_flux_kontext_victory_v3.jpeg` | JPEG q=95 export |
| `menhera_flux_kontext_victory_v3_args.json` | FLUX request args log |
| `menhera_flux_kontext_victory_v3_zoom.png` | 4× NN zoom for per-frame QA |
| `menhera_flux_kontext_victory_v3_frame_{1..8}.png` | Per-frame 3× zooms |
| `menhera_flux_kontext_victory_v3_vs_old_victory.png` | Side-by-side V3 (left) vs old victory backup (right) — confirms the twin-tail + red-ribbon design in V3 row 2 came from the motion master |
| `menhera_flux_kontext_victory_v3_vs_runtime_v2.png` | Side-by-side V3 vs current applied P2 victory |
| `menhera_flux_kontext_victory_v3_report.md` | This report |

Canonical asset + runtime unchanged.
`items/menhera_boss_victory.{png,jpeg}` is still the P2 publish.
Turn R1 branch unaffected.

## 9. Codex handoff note (no runtime change in this pass)

```
Menhera victory FLUX full-sheet V3 completed with mixed result.
Acting upgraded (real peak triumph frame achieved at f5), identity
broke (row 2 pulled twin-tail + red-ribbon design from the old-victory
backup motion master). V3 is NOT a publishing candidate.

- items/menhera_boss_sheet.png                                  -> canonical walk (unchanged, sole identity anchor)
- items/menhera_boss_victory.png                                -> P2 publish (currently applied in runtime, unchanged)
- .tmp/menhera_victory_runtime_backup_20260418/menhera_boss_victory_old.png -> old pre-swap victory backup (unchanged)
- .tmp/menhera_flux_kontext_victory_v3.png                      -> FAILED V3 full-sheet (audit only, NOT for runtime)
- .tmp/menhera_flux_kontext_victory_v3_vs_old_victory.png       -> identity-leak evidence
- .tmp/menhera_flux_kontext_victory_v3_report.md                -> this report

Runtime policy unchanged:
  - currently applied P2 victory stays in place at items/menhera_boss_victory.*
  - hop-only turn fallback stays in place, RENDER_TURN_FRAMES = False,
    TURN_GRID_COLS=8 loader still open on the turn branch
  - canonical walk remains sole identity anchor

Asset-side next step (recommended, NOT this pass):
  - descend to peak + frame expansion using canonical walk only as
    primary anchor, drop the old-victory motion master from the
    reference stack (prompt provides acting energy instead)
  - follow the turn-branch pipeline pattern: peak v1 → QA →
    f1/f2/f3/f4/f6/f7/f8 expansion on peak anchor → 4x2 stitch →
    nukki → gameplay QA → swap
  - do NOT treat V3 row 2 as a usable anchor in any future pass

No runtime wiring changes required from this pass.
```

## 10. Summary (answers to the handoff's §최종 보고 형식)

1. **Reference stack usage**: canonical walk as identity master
   (honored on row 1 only); old victory as motion/celebration master
   (**leaked its identity into row 2**); dense identity board (partial
   help). Slot 4 unused.
2. **Current applied runtime victory acting problem solved?**
   **Partially — yes on acting (f5 is a real peak triumph), no on
   identity (row 2 drift)**. Not net-upgrade as a publishing pack.
3. **Canonical walk identity lock — PASS/FAIL?**: **Row 1 PASS,
   row 2 FAIL.** Hard-reject triggered.
4. **Does the celebration arc read as a true victory motion?**
   **Row 2 yes (strong peak + held + settle). Row 1 still reads as
   quiet idle.** The full 8-frame arc is split, not continuous.
5. **Publish candidate, or descend to peak + frame expansion?**
   **DESCEND.** Same pipeline as turn branch. Drop old-victory from
   the reference stack in the descent — use canonical walk + prompt
   as the acting driver instead.

No code changes. Runtime unchanged. R1 turn close-out still applies.
