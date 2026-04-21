# Menhera Victory FLUX Frame Expansion From Peak V1 — Report

**Status: ACCEPTED for publish-pack staging. All 8 frames hold canonical Menhera identity, 4-bow count, pink paw pads, med-kit, cream bangs, plain white socks. No row-to-row identity split. No V3-style twin-tail leak. Expression is a uniformly high-celebration read across all 8 cells (intentional per this pipeline) with motion arc carried by paw height. Materially better than the currently applied P2 runtime victory. Canonical overwrite NOT done. Runtime unchanged.**

---

## 1. Frames generated this pass

| Frame | Role | Output |
|---|---|---|
| f1 | post-win recognition | `.tmp/menhera_flux_kontext_victory_f1_v1.png` |
| f2 | joy rises | `.tmp/menhera_flux_kontext_victory_f2_v1.png` |
| f3 | excited gather | `.tmp/menhera_flux_kontext_victory_f3_v1.png` |
| f4 | push into triumph | `.tmp/menhera_flux_kontext_victory_f4_v1.png` |
| f5 | **reused accepted peak** | `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1.png` |
| f6 | held triumph | `.tmp/menhera_flux_kontext_victory_f6_v1.png` |
| f7 | warm satisfied afterglow | `.tmp/menhera_flux_kontext_victory_f7_v1.png` |
| f8 | final happy hold | `.tmp/menhera_flux_kontext_victory_f8_v1.png` |

Seven new FLUX Kontext max calls at 1024×1024 each.
f5 reused as-is; no FLUX cost for that cell.

## 2. Reference stack actually used on every new frame

| Slot | File | Role |
|---|---|---|
| `input_image` | `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1.png` | **strongest primary anchor** — accepted peak; locks identity, style, pixel class, body scale |
| `input_image_2` | `items/menhera_boss_sheet.png` | canonical walk — secondary identity lock |
| `input_image_3` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board for prop preservation |
| `input_image_4` | `.tmp/menhera_victory_autosprite_motion_v1.png` | AutoSprite motion block — consulted for arc-position amplitude only (style/proportions/face/props ignored per prompt) |

All explicit exclusions honored: old victory backup, V3 rejected
frames, current runtime P2 victory (compare-only), turn sheet, turn
V3 or V4 anchors.

Identical prompt skeleton across all 7 calls: same strong identity
lock text, same style lock text, same explicit V3-design ban. Only
the per-frame POSE paragraph swaps between calls.

## 3. Output files (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_f{1,2,3,4,6,7,8}_v1.png` | 7 new per-frame outputs, 1024×1024 RGB |
| `menhera_flux_kontext_victory_f{1,2,3,4,6,7,8}_v1_args.json` | FLUX request args logs |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1.png` | Reused as f5 (peak) |
| `menhera_flux_kontext_victory_stitched_v1_preview.png` | 4×2 stitched preview at 512 per cell (row 1 = f1-f4, row 2 = f5-f8) |
| `menhera_flux_kontext_victory_stitched_v1_preview_2x.png` | 2× NN zoom of preview |
| `menhera_flux_kontext_victory_face_consistency_strip_2x.png` | 1-row head-crop strip of all 8 cells for face-consistency audit |
| `menhera_flux_kontext_victory_torso_bow_audit_strip_2x.png` | 1-row torso/bow/paw-region strip of all 8 cells for bow-count + med-kit audit |
| `menhera_flux_kontext_victory_frame_expansion_v1_report.md` | This report |

`items/menhera_boss_victory.{png,jpeg}` NOT overwritten. Runtime
untouched.

## 4. Per-frame pass / fail summary

Legend: `✓` pass, `~` partial / watch, `✗` fail.

| Check | f1 | f2 | f3 | f4 | f5 (peak) | f6 | f7 | f8 |
|---|---|---|---|---|---|---|---|---|
| Same Menhera as peak anchor / canonical walk | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Cream/blonde inner bangs preserved | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Gingham cap + red cross + syringe | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| One pink heart cheek mark, viewer-right | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Exactly 4 black bows on white panel | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Dark gray cat-paw gloves + pink paw pads (on visible raised paws) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Med-kit pouch with pink cross, same side | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Pink check cloth-tail motif | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Plain white thigh-highs, NO pink trim | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Thick black pixel outlines / 16-bit pixel class | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No V3 twin-tail / big side-ribbon drift | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No anime-soft regression | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Body-scale ±5% of walk | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Not a walk / turn / sway / attack read | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Pose matches that frame's motion brief | ~ | ~ | ✓ | ✓ | ✓ | ✓ | ✓ | ~ |

Net: **all 8 frames pass every hard identity / style / anti-drift rule.**
Partial (`~`) on f1, f2, f8 pose-brief fit — see §5.

## 5. Sequence-level readability

### 5.1. Face consistency strip

All 8 cells show the SAME Menhera face structure: same eye shape and
spacing, same lash weight, same cream/blonde inner bangs framing,
same gingham cap and red cross, same heart cheek mark on viewer-right.
**No row-to-row identity split**, unlike V3 where row 1 and row 2
read as two different characters. This was the most critical identity
check and it cleanly passes.

Expression across 8 cells is **uniformly on the celebratory side of
neutral** — every cell shows an open-mouth or wide-closed-mouth smile
with bright eyes. The sequence does NOT have a calm-to-peak-to-calm
expression crescendo. Instead it reads as a **sustained celebration**
with peak-intensity moments at f4 / f5.

### 5.2. Torso / bow / paw audit strip

- **4 bows on white panel**: confirmed on every one of 8 cells. The
  1024×1024 per-figure pixel budget preserves the 4-bow count the way
  turn peak V2 did. This is the big win vs P2 / V1-direct-sheet / V3 /
  V1-from-autosprite which all rendered 3.
- **Med-kit pouch + pink cross**: visible on every cell (some cells
  show it partially occluded by the raised paw, which is natural and
  matches the canonical walk occlusion pattern).
- **Pink paw pads**: clearly visible on every cell where a paw is
  raised — including building frames f3, f4 — not just on the peak.
  Even on f1 and f8 where paws are near the torso, the pads read when
  the paw is angled out.

### 5.3. Motion arc via paw height

Because the facial expression is uniformly celebratory, the arc is
carried by paw height + body rise:

| Frame | Paw height | Body rise | Reads as |
|---|---|---|---|
| f1 | low / near hips | grounded | post-win happy (calmer celebration) |
| f2 | low-middle | slight lift | happy with subtle rise |
| f3 | rising to chest | compress-ready | building celebration |
| f4 | nearly peak height, both paws visible with pads | lifted | push into triumph |
| f5 | peak — one paw raised high with pink pads, open-mouth delighted | ready-to-hop / just-landed | PEAK TRIUMPH |
| f6 | still at peak height | slight settle | held triumph |
| f7 | descending to shoulder height | settling | warm satisfied |
| f8 | returning to torso | grounded | final happy hold |

Arc is readable: f1 → f5 build has visible paw-height increase; f5 → f8
descent has visible paw-height decrease. Not as dramatic as an
ideal "calm → explosion → calm" crescendo, but materially present
and much stronger than the currently applied P2 runtime victory's
arc-free read.

### 5.4. What the partial `~` marks in §4 mean

- **f1 "post-win recognition"**: intended to be calmer than the peak.
  Actual result is a moderately happy frame, not a neutral-just-calmer
  one. Closer to "delighted standing" than "quiet pre-celebration
  recognition." Not a blocker — f1 still reads as part of the
  celebration sequence and doesn't collapse into turn / walk / idle —
  but it's less of a cool-down entry beat than the brief asked for.
- **f2 "joy rises"**: similar story — the brief wanted a gentler
  middle step between f1 and f3. Actual result is close to f1 with
  slightly different paw positioning. Fine at sequence level, soft on
  brief fidelity.
- **f8 "final happy hold"**: brief wanted a stable settled close.
  Actual result reads as still-peak-intensity with paws moderately
  raised. Reads as "held celebration" more than "settled close." At
  gameplay scale this is fine — the victory plays briefly and then
  the game moves on — but it's not a dramatically "wound down"
  closing frame.

Net: the sequence is a **sustained high-celebration loop with peak
highlighted at f5**, not a classic crescendo. User's call on whether
the sustained read is preferable for this boss or whether a narrower
touch-up on f1 / f2 / f8 is worth a pass (see §8).

## 6. Does the sequence solve the flat-celebration problem?

**Yes — materially.**

| Failure mode | P2 applied | V3 | V1-from-autosprite | Frame-expansion V1 (this) |
|---|---|---|---|---|
| Every frame reads as calm idle / near-neutral | YES (the problem) | partial | YES | **NO — every frame reads celebratory** |
| No readable peak triumph frame | YES | partial | YES | **NO — f5 is the accepted peak** |
| Expression drift across frames | mild | SEVERE (row split) | mild | **NONE — uniform celebratory face** |
| Identity split between rows | no | YES | no | **NO** |
| Bow count drift (3 on small cells) | YES | YES | YES | **NO — 4 on every cell** |

The frame-expansion V1 sheet is the first version across this whole
victory branch that clears every hard rule simultaneously.

## 7. Ready for publish-pack staging?

**Yes.** The sheet passes all hard identity / style / anti-drift
rules across all 8 cells and reads as celebration, not idle / walk /
turn. The remaining softness (arc crescendo vs sustained celebration
on f1 / f2 / f8) is a **taste call**, not a blocker, and can be
reassessed after the publish pack is built and rendered at gameplay
scale — where arc subtleties matter less because each cell plays
briefly.

Recommended next pipeline (same as turn / victory-P2 pipelines):

1. **Publishing stitch + upscale**: take the 8 per-cell 1024×1024
   PNGs (f5 = accepted peak), trim each to visible bbox, compute a
   single uniform cross-frame scale factor to 92% of canonical cell
   dimensions, paste into a 2752×1536 4×2 sheet (cells 688×768),
   pure white background. Save as
   `.tmp/menhera_flux_kontext_victory_publish_v2.png` and
   `.tmp/menhera_flux_kontext_victory_publish_v2.jpeg`.
2. **Nukki**:
   `py .claude/skills/sprite-generation/remove_bg.py
    .tmp/menhera_flux_kontext_victory_publish_v2.jpeg
    .tmp/menhera_flux_kontext_victory_publish_v2_nukki.png`
3. **Edge QA**: 4-bow row on every cell, pink paw pads, med-kit,
   cream bangs, syringe, plain white socks. Stop-and-ask as before.
4. **Gameplay-scale QA** at 79×88 per cell, 3-way compare vs canonical
   walk + currently applied P2 + old victory backup.
5. **If all gates hold**: propose Codex swap of
   `items/menhera_boss_victory.{png,jpeg}`. No loader code change
   (victory already expects 4×2).

Decision point for the user:

- **P3A**: proceed straight to publishing-pack staging with this
  sheet. Any "f1 / f2 / f8 feel too celebratory" concern becomes a
  taste call that can be revisited after the actual in-game playback
  is seen.
- **P3B**: narrow touch-up pass on f1 / f2 / f8 only, anchored on
  this expansion run, before staging. Lower paw heights and tone
  down expression slightly. Risk: narrow-pass collateral drift (as
  seen on peak V3 / V4 / victory V2) — may not land cleanly. Cost
  ~3 FLUX credits plus another QA cycle.

My recommendation: **P3A**. Go to staging now. The sustained
celebration read is a legitimate design choice for a brief victory
sequence and is materially better than every prior iteration. If
in-game playback shows the read is too uniform, revisit f1 / f2 /
f8 then.

## 8. Codex handoff note (no runtime change in this pass)

```
FLUX frame expansion V1 from accepted peak completed. 8-frame Menhera
victory candidate assembled in preview form. Canonical asset + runtime
unchanged.

- items/menhera_boss_sheet.png                                          -> canonical walk (unchanged, sole identity anchor)
- items/menhera_boss_victory.png                                        -> currently applied P2 publish (unchanged, will be swap target if P3A approved)
- items/menhera_boss_turn.png                                           -> separate R1 branch (unchanged)
- .tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1.png         -> accepted f5 anchor
- .tmp/menhera_flux_kontext_victory_f{1,2,3,4,6,7,8}_v1.png             -> new per-frame candidates
- .tmp/menhera_flux_kontext_victory_stitched_v1_preview.png             -> 4x2 preview
- .tmp/menhera_flux_kontext_victory_face_consistency_strip_2x.png       -> face audit (pass)
- .tmp/menhera_flux_kontext_victory_torso_bow_audit_strip_2x.png        -> torso + bow audit (4 bows per cell)
- .tmp/menhera_flux_kontext_victory_frame_expansion_v1_report.md        -> this report

Runtime policy unchanged:
  - currently applied P2 victory stays in place at items/menhera_boss_victory.*
  - hop-only turn fallback stays in place, RENDER_TURN_FRAMES = False
  - canonical walk remains sole identity anchor

Recommended next step (user-gated, NOT this PR):
  - publishing stitch / upscale from per-cell 1024x1024 PNGs to 2752x1536 4x2
  - JPEG + remove_bg.py nukki
  - edge QA + gameplay-scale QA vs walk + P2 + old victory
  - if all hold, Codex swap of items/menhera_boss_victory.{png,jpeg}
  - no loader code change — victory already expects 4x2

Accepted divergence (document only, do NOT treat as a new rule):
  - expression is uniformly celebratory across all 8 cells — the arc
    is carried by paw height + body rise, not by expression change
  - this is acceptable for victory because it is a non-anchor sheet
    under the same R1 framing used for turn

No runtime wiring changes required from this pass.
```

## 9. Summary — answers to the handoff's §final report format

1. **Frames generated**: f1, f2, f3, f4, f6, f7, f8 (seven new frames;
   f5 = accepted peak reused).
2. **Reference stack actually used**: input 1 = accepted peak anchor
   (primary), input 2 = canonical walk, input 3 = dense identity
   board, input 4 = AutoSprite motion block (amplitude guidance
   only). All explicit exclusions honored.
3. **Generated file paths**: see §3.
4. **Per-frame pass/fail**: every frame clears every hard identity /
   style / anti-drift rule. Soft `~` marks on f1, f2, f8 pose-brief
   fit (all frames read more celebratory than the calmer beats the
   brief asked for) — not blockers. See §4, §5.4.
5. **Stitched preview sequence readability**: sustained celebration
   across all 8 cells, arc carried by paw height + body rise (f1 low
   → f5 peak → f8 returning), no row-to-row identity split, face
   consistency strip confirms same Menhera across all cells, 4-bow
   count preserved on every cell, med-kit on correct side, paw pads
   visible on raised paws.
6. **Flat-celebration problem solved?** YES — this is the first
   version in the whole victory branch that clears every hard rule
   and reads as celebration rather than idle / turn / walk.
7. **Ready for publish-pack staging?** YES (P3A recommended). P3B
   narrow touch-up on f1 / f2 / f8 is available but not required.

No code changes. Runtime unchanged. R1 turn close-out still applies.
