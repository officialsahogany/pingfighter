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
| 6 | No cross-sheet clarity drift (one sheet obviously cleaner / crisper than the others) | yes |
| 7 | No value-separation drift (one sheet muddy / washed out while another has clear face / trim read) | yes |

---

## 4. Front-biased walk acceptance gate

Run this section specifically for any human / chibi walk sheet that is
supposed to remain front-biased / front-facing in gameplay.

| # | Check | Pass |
|---|---|---|
| 1 | Stable left travel still reads as the boss facing the player, not as secretly looking left or right | yes |
| 2 | Stable right travel still reads as the boss facing the player, not as secretly looking left or right | yes |
| 3 | Hair mass / ribbon placement / hat tilt / cheek exposure do NOT pull the face into a persistent 3/4 read | yes |
| 4 | Eye placement / eye exposure do NOT make one side of the face read consistently more open in a side-biased way | yes |
| 5 | Shoulder / torso angle does NOT make the body feel turned to one side during stable walk playback | yes |
| 6 | Moving right does NOT feel like the boss is looking left | yes |
| 7 | Moving left does NOT feel like the boss is looking right | yes |
| 8 | Candidate walk is not more side-facing than the previous accepted walk | yes |
| 9 | Candidate walk is not being excused just because it is livelier / cleaner / more polished | yes |
| 10 | If the user asked for "frontal walk + hop on turn," the walk remains frontal and the pivot accent is not smuggled into stable walk frames | yes |

Fail any row -> reject and regenerate. Do NOT try to fix with runtime
facing remaps, blind sprite flips, or by redefining which direction uses
which frame set.

---

## 5. Gameplay-scale motion readability

| # | Check | Pass |
|---|---|---|
| 1 | Walk, attack, dash, turn, and victory share the same readability tier at gameplay size | yes |
| 2 | No single sheet looks obviously sharper, pinker, or cleaner than the rest in direct comparison | yes |
| 3 | Walk cycle still feels alive during left/right travel, not torso-frozen with only limb shuffle | yes |
| 4 | Whole-body rhythm survives downscaling: body bob, weight shift, hair / cloth / accessory motion still read | yes |

---

## 6. Attack trigger alignment (SKILL.md Section 8.4.1)

Run this section for contact-based strike / hit sheets, especially any
attack meant to connect with the ball.

| # | Check | Pass |
|---|---|---|
| 1 | Attack sheet has a clear prep -> impact -> recovery arc rather than only a late readable hit | yes |
| 2 | Early prep frames contain meaningful coil / intent, not dead-air posing | yes |
| 3 | One frame is a clearly readable impact frame that runtime can align with contact | yes |
| 4 | Sheet still reads correctly if runtime starts it slightly before predicted contact | yes |
| 5 | Sheet still looks natural under a SHORT, conservative pre-contact lead window rather than needing a very early trigger | yes |
| 6 | Visible downswing / chop does NOT complete before the ball arrives when using the intended anticipatory trigger | yes |
| 7 | The intended impact frame is documented in QA / hand-off when it is non-obvious | yes |
| 8 | If the sheet is supposed to be a snap hit with almost no prep, that choice is explicit rather than accidental | yes |

Fail any row -> reject / regenerate or at minimum document that the
sheet is a special-case instant-hit attack rather than a normal
anticipatory-trigger attack.

---

## 7. Turn sheet extras (SKILL.md Section 9)

| # | Check | Pass |
|---|---|---|
| 1 | Same character as walking sheet (identity lock) | yes |
| 2 | All eight fixed elements preserved | yes |
| 3 | Reads as a brief direction-change gesture, not a side-profile rotation chart | yes |
| 4 | Keeps the same front-facing / front-biased combat read as the walk instead of turning into a profile showcase | yes |
| 5 | Entry and exit frames connect cleanly back into the accepted walk | yes |
| 6 | Body scale within +/-5% of walking sheet | yes |
| 7 | Includes a boss-specific habit / accent (head lift, arm cue, knee lift, pivot, ribbon rebound, etc.) instead of generic filler acting | yes |
| 8 | Does NOT read like unrelated acting pasted on top of the walk cycle | yes |
| 9 | No angle labels / numbers / BLANK text printed into cells | yes |
| 10 | Peak transition frames do NOT read as face-clipped, forehead-cut, or vertically squashed compared to the accepted walk | yes |
| 11 | Raw cell -> inset crop -> trimmed frame -> gameplay-size comparison confirms the clipped-looking read is not already present before runtime | yes |

---

## 8. Composition hygiene (all sheets)

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

## 9. Nukki acceptance

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

If one sheet reads materially cleaner, crisper, pinker, or more legible
than the rest of the same motion set at gameplay size, reject the weaker
sheets and regenerate them. Mixed clarity tiers are not acceptable.

If a turn workflow drifts back toward a side-profile / multi-angle
rotation chart, restate the front-biased direction-change gesture brief
and regenerate. Do NOT promote angle coverage to the goal when the walk
itself is front-facing.

If a turn frame looks face-clipped or forehead-cut at gameplay size, do
NOT assume runtime crop is the cause. First compare raw cell -> inset
crop -> trimmed frame -> gameplay-size render. If the bad read already
exists before runtime fitting, reject / regenerate the art instead of
asking Codex to keep shrinking the turn sheet.

If a new walk sheet is more side-biased than the previous accepted walk,
it does NOT become the new canonical even if it is more lively, more
polished, or technically cleaner. Keep or restore the older accepted
walk until a replacement passes the Section 4 frontal-read gate.

If a walk sheet fails the frontal-read gate, do NOT hand it off to Codex
as runtime work. The correct action is reject / regenerate / rollback on
the asset side.
