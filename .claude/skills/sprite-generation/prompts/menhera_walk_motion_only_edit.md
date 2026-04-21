# Menhera Walk Motion-Only Edit Prompt

Use this after rolling back Menhera's walk sheet to the last accepted
front-facing canonical version. This prompt is for a constrained edit pass that
keeps the exact accepted character and sheet layout while improving only the
safe motion channels.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, perform a
CONSTRAINED EDIT pass on the current accepted walking sprite sheet for
real-stage 3 boss Menheragirl (code current_stage == 3).

This is a MOTION-ONLY EDIT PASS.
It is NOT a full regeneration.
It is NOT a redesign pass.
It is NOT an identity-migration pass.

Current canonical anchor:
- items/menhera_boss_sheet.png
  This is the accepted frontal walk anchor after rollback.
  Treat it as the authoritative identity, layout, framing, and body-class
  reference for this pass.

Non-references for this pass:
- .tmp/menhera_boss_sheet_frontal_recovery_v1.png
- .tmp/menhera_boss_sheet_frontal_recovery_v2.png
- Any rejected side-biased or two-ribbon variants
Do NOT borrow design changes from failed recovery candidates.

Primary objective:
- Keep the EXACT SAME current accepted Menhera character
- Keep the EXACT SAME frontal-neutral stable walk read
- Preserve the EXACT SAME 8-frame 4x2 sheet layout
- Increase liveliness only through safe motion edits
- Improve motion WITHOUT causing identity drift, layout drift, or
  frontal-read regression

This pass is successful only if the result looks like the SAME accepted walk
sheet, but with better lower-body rhythm and follow-through.

Fixed design elements (must remain identical to the current accepted sheet):
- Pale pastel pink bob haircut / same hair silhouette
- Pink nurse cap with pink cross
- One pink ribbon on the character's right side
- Black cat ears
- Olive eyes
- Black cat-paw gloves
- Thin cat tail
- Pink nurse dress with black trim
- Chibi petite-human proportions
- Thick black pixel outlines

Hard scope lock:
- Use the current items/menhera_boss_sheet.png as the edit anchor, not as a
  loose inspiration
- Do NOT redraw the whole sheet from scratch
- Do NOT reinterpret the character
- Do NOT modernize, stylize, repaint, or "improve" the face
- Do NOT change the framing, crop, margins, cell order, frame count, or grid
- Do NOT change body scale, head size, face size, or overall silhouette class
- Do NOT change the character's stable front-facing read

Preferred edit method:
- If the tool supports image editing / masking, lock the head, face, bangs,
  hair silhouette, nurse cap, ribbon, ears, shoulders, chest, gloves, and upper
  torso in all 8 frames
- Restrict visible edits mainly to:
  - skirt hem
  - hips / upper legs
  - knees / lower legs / feet
  - tail motion
  - tiny whole-body vertical bob within the same cell
- If the tool cannot preserve those locked regions reliably, reject this pass
  instead of generating a fresh full-sheet redraw

Allowed motion changes:
- Clearer leg alternation across the 8 frames
- Stronger but still cute weight shift
- Slightly clearer body bob
- Better skirt-hem flutter
- Better tail counter-arc / follow-through
- Slightly clearer step timing and rebound

Optional motion changes only if identity stays exact:
- Very small forearm / hand follow-through
- Very small dress-body sway
- Very small vertical whole-body bob

Motion language target:
- Front-facing lateral travel
- Softly buoyant chibi rhythm
- Cute but readable walk cycle
- More alive than the current accepted sheet
- NO hidden 3/4 walk
- NO torso turn used as a shortcut for motion energy

Hard bans:
- NO full-sheet brute-force regeneration
- NO side-facing or 3/4-facing head
- NO side-facing or 3/4-facing torso
- NO left-looking or right-looking stable-walk bias
- NO second ribbon
- NO ribbon-side swap
- NO cap color drift
- NO missing pink cross on the cap
- NO ear removal or ear redesign
- NO glove redesign
- NO face redesign
- NO 4x3 output
- NO extra frames
- NO layout drift
- NO body-size drift

Size / composition rules:
- Remain an 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character remains centered in every frame
- Keep foot / baseline behavior coherent across frames
- Match the current accepted sheet's scale and framing as closely as possible
- Preserve generous empty margin around each sprite
- Preserve gameplay-scale readability

Frontal-read rules:
- Body and face remain front-facing in every frame
- Stable movement must still read as "facing the player while moving laterally"
- Moving right must NOT feel like the boss is looking left
- Moving left must NOT feel like the boss is looking right
- Do NOT use hair mass, cheek exposure, eye placement, hat tilt, shoulder angle,
  or torso angle to fake energy at the cost of frontal neutrality

Success criteria:
- Top half of the character still reads as the SAME accepted canonical Menhera
- The result keeps the SAME identity, SAME framing, and SAME sheet structure
- Motion improvement is visible mainly in legs, hem, tail, and bounce timing
- The sheet feels livelier without becoming a different character

Hard reject conditions:
- Reject if the result looks like a different Menhera
- Reject if the face / head / hair / cap / ribbon / ears drift at all
- Reject if the result becomes more side-biased than the current accepted walk
- Reject if the layout is anything other than 8 frames in a 4x2 grid
- Reject if motion improvement comes from turning the head or torso
- Reject instead of expecting Codex/runtime to rescue the sheet with flips,
  remaps, or manual compositing

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_boss_sheet_motion_edit_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_boss_sheet_motion_edit_v1.jpeg \
        .tmp/menhera_boss_sheet_motion_edit_v1.png
- Candidate only. It is NOT canonical until it passes motion-only QA against
  the current accepted walk anchor.
```
