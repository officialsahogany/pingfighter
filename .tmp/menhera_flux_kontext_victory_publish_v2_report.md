# Menhera Victory Publish From Frame Expansion V1 — P3A Report

**Status: P3A accepted. Victory frame-expansion publish pack is approved as a runtime-only non-anchor auxiliary sheet. Canonical walk remains the sole identity anchor.**

---

## 1. Publish pack generated successfully?

**Yes.** 8 accepted frames (f1–f4 expansion, f5 = accepted peak, f6–f8
expansion) stitched into a runtime-ready 4×2 sheet at canonical walk
dimensions.

Packing: this is packaging, not regeneration.
1. Each per-cell 1024×1024 PNG trimmed to its visible bounding box.
2. A **single uniform cross-frame scale factor** computed from the
   largest trimmed dimension to fit within 92% of a canonical
   688×768 cell. All 8 figures scale by the same factor — no frame
   ends up larger or smaller than another.
3. Each scaled figure pasted centered onto a pure-white 688×768 cell.
4. Composed into pure-white 2752×1536 canvas as 4×2.
5. Exported as PNG and JPEG q=95.

Trimmed sizes per frame:

```
f1: 623x890
f2: 669x916
f3: 622x882
f4: 604x906
f5: 683x938  (accepted peak)
f6: 611x852
f7: 698x929
f8: 686x958
max: 698x958
uniform scale: 0.7370 (single factor across all 8)
output: 2752x1536, 4x2
```

## 2. Nukki pair generated successfully?

**Yes.**
`py .claude/skills/sprite-generation/remove_bg.py
 .tmp/menhera_flux_kontext_victory_publish_v2.jpeg
 .tmp/menhera_flux_kontext_victory_publish_v2_nukki.png`
completed. Output is 2752×1536 RGBA with crisp hard-edge alpha from
the skill's 2-step flood-fill + halo kill algorithm.

## 3. Post-nukki edge QA — PASS

Per-cell pre / post torso crops (`_victoryv2_edgeqa_{pre,post}_f{1..8}.png`)
inspected for the stop-and-ask list:

| Edge region | Pre-nukki | Post-nukki |
|---|---|---|
| 4-bow vertical stack on white panel | 4 intact on every cell (confirmed earlier in the frame-expansion torso audit strip) | **4 intact on every cell** |
| Pink paw pads (on raised paws) | visible | **visible, no alpha punch-out** |
| Med-kit pouch edge + pink cross | clean edge | **clean edge, no halo** |
| Cream / blonde inner front bangs | present | **present, no color bleed** |
| Syringe on cap | visible | **visible, no outline break** |
| Plain white thigh-high socks (NO pink trim) | plain white | **plain white** |

No halo, no alpha punch-out around props, no outline break on any of
the 8 cells. The stop-and-ask condition ("halo, alpha punch-out,
outline break, or prop damage appears") did not trigger.

## 4. Drift QA — publish V2 vs canonical walk + current P2 + old victory

The 4-row gameplay-scale comparison
(`menhera_flux_kontext_victory_publish_v2_gameplay_4x.png`) stacks:

- Row 1: canonical walk (the identity master)
- Row 2: publish V2 NEW victory (this pass's output)
- Row 3: current runtime P2 victory (the sheet we're replacing)
- Row 4: old victory backup (the sheet from before the P2 swap)

### 4.1. Publish V2 vs canonical walk (identity lock)

| Check | Verdict |
|---|---|
| Same Menhera face across all 8 cells | PASS — consistent with row 1 |
| Fluffy pink outer hair + cream/blonde inner bangs | PASS — matches walk |
| Gingham nurse cap + red cross + syringe | PASS |
| One pink heart cheek mark on viewer-right | PASS |
| Dark gray cat-paw gloves + pink paw pads (on raised paws) | PASS |
| Med-kit pouch with pink cross, same hip side | PASS |
| Pink check cloth-tail motif | PASS |
| Plain white thigh-highs — NO pink sock trim | PASS (R1 sock guardrail held) |
| Thick black pixel outlines / 16-bit pixel class | PASS |
| Body read at gameplay size | within ±5% of walk on every cell |
| Any V3-style twin-tail / side-ribbon leak | **ABSENT** |

Identity lock holds cleanly against the canonical walk.

### 4.2. Publish V2 vs current runtime P2 (acting upgrade)

| Check | P2 (row 3) | Publish V2 (row 2) |
|---|---|---|
| Frame-to-frame face identity | consistent | **consistent — same as P2** |
| Celebration read at gameplay scale | flat / neutral across cells | **clearly celebratory across cells** |
| Peak triumph frame | none | **f5 is a clear peak** |
| Paw-height variation across cells | flat | **visible rise and fall arc** (f1 low → f5 raised → f8 returning) |
| Expression brightness | muted | **bright happy smile across cells** |
| Body-rhythm vertical rise | absent | **visible on f3/f4/f5** |
| "Reads like turn extension" failure mode | present | **absent** |

Publish V2 is materially a celebration read upgrade over P2 without
any identity regression. This is exactly the acting gap P2 couldn't
close.

### 4.3. Publish V2 vs old victory backup (drift-avoidance check)

| Check | Old victory (row 4) | Publish V2 (row 2) |
|---|---|---|
| Twin-tail pigtail hairstyle | present on several cells | **ABSENT on every cell** |
| Large red side-ribbons on head | present on several cells | **ABSENT on every cell** |
| Random closed-eye emoji face on non-peak cells | present | **ABSENT** |
| Alternate small cap design | appears | **ABSENT — canonical gingham cap on every cell** |
| Row-to-row identity split | yes | **NO — uniform identity across all 8** |
| Pink sock-top trim | present on some cells | **ABSENT — plain white on every cell** |

Publish V2 is a clean identity-only rendition of the celebration arc.
None of the old-victory identity-leak attractors appear.

## 5. Is this a real upgrade over the currently applied runtime victory?

**Yes — on every metric except "idle-quiet entry beat":**

- Identity lock: **equivalent** to P2 (both strong)
- Celebration readability: **V2 >> P2** (V2 has clear rise/peak/descent;
  P2 is flat)
- Peak triumph frame: **V2 has one (f5)**; P2 has none
- Props preservation: **equivalent** (both clean)
- Gameplay-scale same-Menhera read: **both clean**
- R1 guardrail compliance: **both clean** (plain white socks, no
  identity leak)
- Accepted non-blocker: V2 f1/f2/f8 are somewhat more celebratory
  than P2's quieter entry/close frames. Taste call, not a blocker.

Net: **V2 is a real upgrade.** Users / players seeing the victory
sequence play will get a visibly more celebratory boss reaction than
they do today with P2.

## 6. Can Codex swap `items/menhera_boss_victory.{png,jpeg}` now?

**Yes, with the usual local playback QA gate.**

Key points for Codex:

- Target paths: `items/menhera_boss_victory.png` and
  `items/menhera_boss_victory.jpeg`.
- Target dimensions: `2752×1536`, 4×2 — **same as the current live
  file**. No loader code change (victory already assumes 4×2, unlike
  turn which needed a `TURN_GRID_COLS / ROWS` flip).
- Swap order:
  1. Back up current `items/menhera_boss_victory.{png,jpeg}` (git
     working tree is fine — the old victory backup in
     `.tmp/menhera_victory_runtime_backup_20260418/` is already the
     pre-P2 version; git preserves the P2 version that V2 is
     replacing).
  2. Copy `.tmp/menhera_flux_kontext_victory_publish_v2.png` (or
     `..._nukki.png` — both 2752×1536; the nukki PNG is runtime-ready
     with hard-edge alpha) → `items/menhera_boss_victory.png`.
  3. Copy `.tmp/menhera_flux_kontext_victory_publish_v2.jpeg` →
     `items/menhera_boss_victory.jpeg`.
- Local playback QA before shipping:
  - trigger victory pose in-game
  - confirm 4×2 slicing lands cleanly on all 8 frames
  - confirm face consistency across the victory cycle
  - confirm no face-clipping on any frame
  - confirm body read matches walk at gameplay size
  - confirm no regression on non-victory states
    (walk / attack / dash / turn loaders are independent of this
    swap)
- Rollback: if any of the above fails, restore from git — no other
  state to undo. The R1 turn guardrails remain in force; this swap
  does not reopen turn work.

## 7. Output files (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_publish_v2.png` | 2752×1536 RGB 4×2 victory publish sheet (pre-nukki) |
| `menhera_flux_kontext_victory_publish_v2.jpeg` | JPEG q=95 for nukki input + alt runtime target |
| `menhera_flux_kontext_victory_publish_v2_nukki.png` | 2752×1536 RGBA post-`remove_bg.py` (hard-edge alpha) |
| `menhera_flux_kontext_victory_publish_v2_zoom.png` | half-size quick-view |
| `menhera_flux_kontext_victory_publish_v2_vs_walk.png` | full-scale side-by-side vs canonical walk |
| `menhera_flux_kontext_victory_publish_v2_vs_runtime_p2.png` | vs currently applied P2 |
| `menhera_flux_kontext_victory_publish_v2_vs_old_victory.png` | vs old victory backup |
| `menhera_flux_kontext_victory_publish_v2_gameplay.png` | 4-row gameplay-scale render (walk / publish V2 / P2 / old) at 79×88 per cell |
| `menhera_flux_kontext_victory_publish_v2_gameplay_4x.png` | 4× NN zoom of the 4-row gameplay render |
| `_victoryv2_edgeqa_pre_f{1..8}.png` | torso crops pre-nukki |
| `_victoryv2_edgeqa_post_f{1..8}.png` | torso crops post-nukki |
| `menhera_flux_kontext_victory_publish_v2_report.md` | this report |

`items/menhera_boss_victory.{png,jpeg}` NOT overwritten in this pass.

## 8. Codex handoff note

```
Victory V2 publish pipeline passed P3A QA. Asset swap is safe pending
local playback QA. Canonical walk remains the sole identity anchor.

- items/menhera_boss_sheet.png                                        -> canonical walk (unchanged, sole identity anchor)
- items/menhera_boss_victory.png                                      -> current P2 publish (will be swap target)
- items/menhera_boss_victory.jpeg                                     -> current P2 JPEG (will be swap target)
- items/menhera_boss_turn.png                                         -> separate R1 branch (unchanged)
- .tmp/menhera_flux_kontext_victory_publish_v2.png                    -> NEW 2752x1536 4x2 publish candidate (pre-nukki)
- .tmp/menhera_flux_kontext_victory_publish_v2.jpeg                   -> NEW 4x2 JPEG
- .tmp/menhera_flux_kontext_victory_publish_v2_nukki.png              -> NEW runtime-ready PNG (post remove_bg.py)
- .tmp/menhera_flux_kontext_victory_publish_v2_gameplay_4x.png        -> 4-row gameplay QA (walk / new / P2 / old victory)
- .tmp/menhera_flux_kontext_victory_publish_v2_report.md              -> this report

Runtime swap requirements (Codex scope):
  - NO loader code change required — victory already assumes 4x2 via
    walk-style FRAME_ORDER in entities/menhera_boss_sprite.py.
  - Copy .tmp/menhera_flux_kontext_victory_publish_v2.png (or
    _nukki.png) to items/menhera_boss_victory.png.
  - Copy .tmp/menhera_flux_kontext_victory_publish_v2.jpeg to
    items/menhera_boss_victory.jpeg.
  - Rely on git working tree for rollback of the replaced files.
  - Run local playback QA: trigger victory in-game, verify slicing,
    face consistency across the cycle, no face-clipping, body-read
    parity with walk, no regression on walk / attack / dash / turn.
  - If QA fails: revert the two files from git. No other state to
    undo.

Accepted divergence (document only, do NOT treat as a new rule):
  - V2's expression is uniformly celebratory across the 8-cell cycle;
    the motion arc is carried by paw height + body rise rather than
    by expression change. This is a cosmetic runtime-only property of
    this sheet.
  - V2's white center panel preserves the canonical 4-bow count on
    every cell (unlike the earlier P2, which was 3 per cell).

R1 turn branch is unaffected by this swap. No other assets move.
Victory V2 is runtime-only non-anchor: DO NOT use it as a future
identity anchor for any regen. Canonical walk + approved prop
references remain the anchor set for attack / dash / defeat future
work.

No runtime wiring changes required from the asset-side pass.
```

## 9. Final recommendation — answers to the handoff's §final format

1. **Publish pack generated successfully?** YES.
2. **Nukki pair generated successfully?** YES.
3. **Post-nukki edge QA pass/fail?** PASS — 4 bows, pink paw pads,
   med-kit edges, cream bangs, syringe, plain white socks all
   intact; no halo, no alpha punch-out, no outline break.
4. **Gameplay-scale QA vs walk / current P2 / old victory?**
   - vs walk: PASS — same Menhera identity at gameplay scale
   - vs current P2: PASS — clearly more celebratory, clear peak at
     f5, visible paw-height arc; no identity regression
   - vs old victory: PASS — no twin-tail drift, no big side-ribbons,
     no closed-eye emoji face, no pink sock trim, no row-to-row
     split
5. **Real upgrade over current runtime victory?** YES, on every
   metric except f1/f2/f8 entry/close calmness which is an accepted
   non-blocker taste call.
6. **Codex can safely swap `items/menhera_boss_victory.{png,jpeg}`?**
   YES, pending local playback QA. No loader code change required.

## 10. Key conclusion phrases

- **P3A accepted**
- **Victory frame-expansion publish pack is approved as a runtime-only
  non-anchor auxiliary sheet**
- **Canonical walk remains the sole identity anchor**

No code changes. Runtime unchanged. R1 turn close-out still applies.
