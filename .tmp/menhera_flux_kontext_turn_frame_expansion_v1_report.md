# Menhera Turn FLUX Kontext Frame Expansion — V1 Report

**Status: 8-frame micro-turn sequence assembled in preview form. Identity lock + 4-bow count + pixel class all hold across all frames. Sequence reads as a clean carry-in → peak → return arc. Canonical turn NOT overwritten.**

## 1. Frames generated this pass

| Frame | Role | How | Output |
|---|---|---|---|
| f1 | carry-in (near-neutral from walk) | new FLUX Kontext max generation | `.tmp/menhera_flux_kontext_turn_f1_v1.png` |
| f2 | tiny compress / plant | new FLUX Kontext max generation | `.tmp/menhera_flux_kontext_turn_f2_v1.png` |
| f3 | slight chin-lift wind-up | new FLUX Kontext max generation | `.tmp/menhera_flux_kontext_turn_f3_v1.png` |
| f4 | PEAK redirect | **reused** existing accepted anchor | `.tmp/menhera_flux_kontext_peak_v2.png` |
| f5 | rebound from peak | new FLUX Kontext max generation | `.tmp/menhera_flux_kontext_turn_f5_v1.png` |
| f6 | recovery step | new FLUX Kontext max generation | `.tmp/menhera_flux_kontext_turn_f6_v1.png` |
| f7 | settle toward neutral | new FLUX Kontext max generation | `.tmp/menhera_flux_kontext_turn_f7_v1.png` |
| f8 | walk-compatible return (loop closure) | **reused f1** | (same file as f1) |

Six new FLUX Kontext max calls, each 1024×1024 RGB PNG.

## 2. Reference stack used on every new frame

| Slot | File | Role |
|---|---|---|
| `input_image` | `.tmp/menhera_flux_kontext_peak_v2.png` | strongest primary anchor (proven identity + pixel class + 4-bow) |
| `input_image_2` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board |
| `input_image_3` | `items/menhera_boss_sheet.png` | canonical walk |
| `input_image_4` | `items/menhera_boss_victory.png` | quality / clarity class reference |

The prompt template is identical across frames for the identity lock,
style lock, and motion bans; only the per-frame POSE paragraph changes.
The sock-top pink-accent drift seen on peak V2 was explicitly
suppressed in every frame prompt ("PLAIN WHITE thigh-high socks, NO
pink accents or bows at sock top"). No per-frame identity prop went
back to V1/V2 AutoSprite failure modes.

## 3. Output files (`.tmp/`)

| File | Content |
|------|---------|
| `menhera_flux_kontext_turn_f{1,2,3,5,6,7}_v1.png` | Six new per-frame outputs, 1024×1024 RGB PNG each |
| `menhera_flux_kontext_turn_f{1,2,3,5,6,7}_v1_args.json` | FLUX request args logs |
| `menhera_flux_kontext_peak_v2.png` | Reused as f4 (peak) |
| `menhera_flux_kontext_turn_stitched_v1_preview.png` | 4×2 stitched preview (4096×1024-class at 512/cell), ordered row1 = f1 f2 f3 f4, row2 = f5 f6 f7 f8 (=f1) |
| `menhera_flux_kontext_turn_frame_expansion_v1_report.md` | This report |

`items/menhera_boss_turn.png` is **NOT** overwritten. No `.jpeg` export
yet — nukki and the final 4×2 publishing pass are deferred until after
sequence QA has signed off.

## 4. Per-frame QA (PASS / PARTIAL / FAIL)

Legend: `✓` pass, `~` partial / watch, `✗` fail.

| Check | f1 | f2 | f3 | f4 (peak v2) | f5 | f6 | f7 | f8 (=f1) |
|---|---|---|---|---|---|---|---|---|
| Same Menhera as peak V2 / canonical walk | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Cream / blonde inner bangs preserved | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Gingham cap + red cross + syringe | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| One pink heart cheek mark, correct side | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Exactly 4 black bows on white panel | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Gray cat-paw gloves + pink pads | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Med-kit on same side as anchor | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Pink check cloth-tail motif | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| White thigh-highs, NO pink sock-top accents | ✓ | ✓ | ✓ | ~ (accents on peak v2 persist but not amplified) | ✓ | ✓ | ✓ | ✓ |
| Thick black pixel outlines / 16-bit pixel class | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No anime-soft / anti-aliased regression | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Front-facing body + face | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No greeting wave / attack swing / side profile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Body scale within +/-5% of peak | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Motion matches the brief for this frame | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Net: all eight frames hold identity, 4-bow, med-kit side, pixel class,
and pose brief. The only persistent partial is the sock-top pink accent
that was already present on the peak V2 anchor. New frames did not
amplify it and several new frames suppressed it, so this drift is
static rather than worsening. Acceptable to defer to a later narrow
polish pass.

## 5. Sequence-level readability (stitched preview)

Reading row 1 (f1 f2 f3 f4) left to right:

- f1 and f2 are deliberately near-identical — both hold carry-in
  posture with a whisper of weight shift between them. Acceptable:
  this is the intended low-amplitude build.
- f3 clearly introduces the wind-up: chin lifts, one paw begins to
  separate from the torso and show its pads forward, slight knee
  gather reads.
- f4 (peak V2) lands as the single strong redirect accent — paw
  clearly raised with pads visible, compact body.

Reading row 2 (f5 f6 f7 f8=f1):

- f5 softens the peak without snapping: raised paw is noticeably
  lower than f4 and closer to the torso, chin descending.
- f6 continues the descent: paw nearly back at torso, legs resolving.
- f7 is essentially canonical-walk neutral — both paws at sides /
  med-kit, legs close together, face level.
- f8 (=f1) closes the loop cleanly because f1 and f7 are both
  near-neutral beats that share the same body read.

Net arc reads as: carry-in → whisper of plant → readable wind-up →
peak → soft relaxation → recovery → settle → loop. No greeting-wave,
tray-hold, dance, or side-profile failure mode appears on any frame.
The arc is conservative — consistent with the front-biased /
micro-turn brief and compatible with the existing hop-only runtime.

## 6. Is frame-8 reuse of f1 enough?

**Yes, for this iteration.** f7 already lands as a near-canonical
neutral settle and f1 is the near-canonical carry-in — they pair into a
visually clean loop closure without a synthesized f8. A dedicated f8 is
only worth the extra generation if a later QA pass surfaces a visible
pop at the f7 → f8 seam during actual runtime playback. Current
preview does not justify that cost.

## 7. Is this a canonical turn-sheet candidate now?

**Almost.** The identity, style, and sequence reads are all
materially on canonical target. What still separates this from a
canonical overwrite:

1. **Publishing pack is preview only.** The 4×2 preview is a
   PIL-stitched lanczos-resized composite of per-frame PNGs, not the
   canonical-form `items/menhera_boss_turn.{jpeg,png}` pair produced
   by the usual sheet pipeline.
2. **Nukki has not been run.** Per the `sprite-generation` skill, the
   nukki step (hard-edge 2-step flood-fill algorithm at
   `.claude/skills/sprite-generation/remove_bg.py`) on the JPEG export
   is the source of truth for the PNG, with matching raw JPEG kept
   for re-tuning. The current per-frame PNGs are FLUX Kontext max
   direct outputs — they have near-white backgrounds but have not been
   through the canonical nukki path.
3. **Gameplay-scale render has not been verified.** Cross-sheet
   clarity, body-read parity with walk / attack / dash / victory at
   in-game size, and turn-playback seam behavior against the live
   runtime have not been re-checked for this asset.
4. **Minor static drifts remain**: sock-top pink accent on peak V2
   (inherited), and the cap front-ribbon language that shifted toward
   small side accents. Neither blocks canonical promotion but both
   are worth a narrow cleanup pass before shipping.

So: promote to *publishing QA candidate*, not yet canonical. Keep
`items/menhera_boss_turn.png` and runtime behavior unchanged.

## 8. Recommended next actions (user decides)

1. **Narrow polish pass** on peak V2 only, if we want the sock-top
   accent / front-ribbon drift cleaned up before lock-in. Optional.
2. **Publishing pack build:**
   - Build a clean 4×2 JPEG at the canonical source size by pasting
     the eight per-frame PNGs onto a pure white canvas with consistent
     character-size fit.
   - Save to `.tmp/menhera_boss_turn_flux_candidate_v1.jpeg`.
   - Run `py .claude/skills/sprite-generation/remove_bg.py
     .tmp/menhera_boss_turn_flux_candidate_v1.jpeg
     .tmp/menhera_boss_turn_flux_candidate_v1.png`.
3. **Canonical-scale QA**: compare candidate against
   `items/menhera_boss_sheet.png`, `items/menhera_boss_victory.png`,
   and the existing `items/menhera_boss_turn.png` at gameplay size
   using the turn-sheet QA table in `sprite-generation/checklists.md`.
4. **Only then** decide on canonical overwrite and the Codex handoff
   that re-enables visible turn-sheet playback in
   `entities/menhera_boss_sprite.py` per `AGENTS.md`.

## 9. Codex handoff note

```
FLUX Kontext frame-expansion V1 completed for Menhera turn. The eight
frames are now available as candidate assets, but runtime state is
unchanged and canonical overwrite has NOT happened.

- items/menhera_boss_sheet.png                               -> canonical walk (unchanged)
- items/menhera_boss_turn.png                                -> previous turn (unchanged)
- items/menhera_boss_victory.png                             -> quality reference (unchanged)
- .tmp/menhera_flux_kontext_peak_v2.png                      -> accepted peak anchor (f4)
- .tmp/menhera_flux_kontext_turn_f{1,2,3,5,6,7}_v1.png       -> new per-frame candidates
- .tmp/menhera_flux_kontext_turn_stitched_v1_preview.png     -> 4x2 preview for sequence QA
- .tmp/menhera_flux_kontext_turn_frame_expansion_v1_report.md -> QA report

Runtime policy unchanged:
  - front-biased canonical walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off

Next step (user-gated, NOT this PR):
  - build a canonical 4x2 JPEG + nukki PNG pair from these frames
  - run turn-sheet gameplay-scale QA
  - if it passes, publish items/menhera_boss_turn.{jpeg,png} via the
    sprite-generation skill, then hand off a separate enable-turn-
    playback work item to Codex per AGENTS.md
  - do NOT re-enable turn playback or change render branch logic in
    this PR on the strength of the preview alone

No runtime wiring changes required from this experiment.
```
