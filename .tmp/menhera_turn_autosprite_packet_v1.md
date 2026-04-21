# Menhera Turn AutoSprite Packet V1

Purpose:
- First `autosprite` experiment for Stage 3 Menheragirl.
- Scope is TURN only.
- Do not touch walk / attack / dash / victory / defeat in this pass.

Current runtime status:
- Walk is the accepted canonical anchor.
- Turn visuals are still disabled at runtime until a new turn asset passes QA.

Canonical references:
- Identity / body / frontal-read master:
  - `items/menhera_boss_sheet.png`
- Quality / readability tier only:
  - `items/menhera_boss_victory.png`

Do not use as shape anchors:
- older rejected turn candidates
- angle-chart turn sheets
- side-view rotation examples

Output safety:
- Do NOT overwrite `items/menhera_boss_turn.png` first.
- Save first candidate under `.tmp`.

Recommended first output names:
- `.tmp/menhera_turn_autosprite_sheet_v1.png`
- `.tmp/menhera_turn_autosprite_sheet_v1_qa.png`

## Goal

Generate a brief front-facing direction-change gesture for Menhera.

This is not:
- a profile rotation chart
- a side-view turn sheet
- a replacement walk cycle
- an attack, taunt, or greeting wave

This should feel like:
- a compact, characterful little direction-change accent
- dreamy lifted chin
- slightly far-away gaze
- one soft paw/arm flourish
- tiny knee lift or pivot / hop accent
- same frontal combat-facing Menhera as the walk sheet

## AutoSprite Primary Prompt

Use the following as the first attempt with `items/menhera_boss_sheet.png` as the
main identity reference and `items/menhera_boss_victory.png` only as a finish /
readability reference.

```text
Create a TURN-ONLY sprite sheet for PingFighter Stage 3 boss Menheragirl.

Important:
- This is an auxiliary facing-transition sheet only
- NOT a walk replacement
- NOT a side-view rotation chart
- NOT a +90 to 0 to -90 angle sequence
- Keep Menhera front-facing toward the player through the whole sequence

Required visual style:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation palette
- clean hard-edged pixels
- NO painterly rendering
- NO soft shading
- NO photorealism

Sheet format:
- exactly 8 frames
- 4 columns x 2 rows
- pure white background
- no grid lines
- no labels
- no border
- full body fully visible in every frame
- character centered in every frame
- generous white margin around the character

Identity lock: must match the current canonical walk exactly
- fluffy short pink outer hair mass with cream / blonde inner front bangs
- rounded fluffy hair silhouette, not a flat bob
- pink and white gingham nurse cap
- red ribbon on the cap
- syringe attached on the cap
- NO black cat ears
- large gray / silver eyes with strong lashes
- exactly one pink heart cheek mark on one cheek only
- pink outfit with white center front panel
- exactly 4 black bows vertically stacked on the white front panel
- dark gray cat-paw gloves with visible pink toe beans
- right-side med-kit accessory with pink cross and bunny-ear hint
- pink check-pattern cloth-tail motif near the med-kit
- white sheer thigh-highs
- black X ankle accessories
- petite chibi human body class

Motion brief:
- this is a brief characterful direction-change gesture
- keep face and torso mostly frontal throughout
- express the direction change through gesture, not camera rotation
- slightly lift the chin
- dreamy or middle-distance upward gaze
- one paw / arm softly sweeps outward with a loose flourish
- the other arm supports balance
- one knee lifts a little during the peak
- tiny pivot or hop accent is allowed
- hair, ribbon, med-kit, hem, and cloth-tail rebound subtly
- keep whole-body rhythm, not just hand motion

Recommended frame plan:
- frame 1: walk-compatible carry-in
- frame 2: small plant / compress
- frame 3: lifted-chin wind-up
- frame 4: peak transition pose
- frame 5: rebound from peak
- frame 6: recovery step
- frame 7: settle toward neutral frontal walk
- frame 8: walk-compatible return

Gameplay readability is mandatory from the first generation:
- face, eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, gloves,
  bows, med-kit, legwear, and cloth-tail must stay readable at small in-game size
- clear separation between hair, face, arms, outfit, accessory, and legs
- reduce muddy midtones
- keep the face readable and not chopped-looking

Scale rules:
- body scale must stay within about +/-5 percent of the canonical walk sheet
- do not let the turn read smaller than the walk in gameplay
- effects and motion accents must not shrink the visible body read

Hard reject conditions:
- reject if she reads like a different Menhera
- reject if the result becomes side-facing or profile-like
- reject if the motion reads like a greeting wave
- reject if the motion reads like an attack swing
- reject if the face / forehead looks clipped or squashed
- reject if bow count changes from 4
- reject if the med-kit changes side
- reject if gray / silver eyes drift to another color
- reject if the result is blurrier or softer than the victory reference
```

## Best-Case Acceptance Checklist

Approve only if all are true:
- Same Menhera as `items/menhera_boss_sheet.png`
- Stable frontal read across all 8 frames
- Peak pose feels like a direction-change accent, not an attack or wave
- Body read matches walk at gameplay size
- Frame 7 to frame 8 can drop back into walk naturally
- Small-size readability survives on face and accessories

## Fallback Plan If The Full 8-Frame Sheet Drifts

If the direct sheet fails, switch to a framewise workflow.

Order:
1. Generate one accepted peak pose first
2. Generate entry frames 1 to 3 as single images
3. Generate recovery frames 5 to 7 as single images
4. Reuse frame 1 as frame 8 for loop closure if needed
5. Stitch offline only after QA

Suggested fallback output names:
- `.tmp/menhera_turn_autosprite_peak_v1.png`
- `.tmp/menhera_turn_autosprite_f1_v1.png`
- `.tmp/menhera_turn_autosprite_f2_v1.png`
- `.tmp/menhera_turn_autosprite_f3_v1.png`
- `.tmp/menhera_turn_autosprite_f5_v1.png`
- `.tmp/menhera_turn_autosprite_f6_v1.png`
- `.tmp/menhera_turn_autosprite_f7_v1.png`

## Peak Pose Fallback Prompt

```text
Create ONE single full-body pixel sprite of the exact same Menheragirl from the
current canonical walk sheet.

Important:
- one image only
- not a sprite sheet
- not a profile rotation
- overall frontal read toward the player
- pure white background

Keep exactly:
- same fluffy pink outer hair and cream / blonde inner front bangs
- same gray / silver eyes
- same one-heart cheek mark
- same cap, ribbon, and syringe
- same 4 black bows on the white front panel
- same gray cat-paw gloves with pink pads
- same med-kit on the same side
- same chibi body class and body read

Pose:
- peak direction-change gesture
- lifted chin
- dreamy upward middle-distance gaze
- one paw softly sweeps outward
- one knee modestly lifted
- compact whole-body pivot accent
- cute, odd, character-specific, but not a wave and not an attack

Style:
- 16-bit retro pixel art
- thick black pixel outlines
- clean hard-edged pixels
- flat limited-saturation palette
- no soft shading
- no painterly rendering
```

## QA Notes To Compare After Generation

Compare against:
- `items/menhera_boss_sheet.png`
- `items/menhera_boss_victory.png`

Check:
- hair silhouette continuity
- face read and eye color
- cheek heart presence
- 4-bow count
- med-kit side lock
- glove shape and paw-pad visibility
- frontal-read preservation
- gameplay-size body-read parity

## Handoff Back To Codex After Asset QA Passes

If a candidate passes:
- keep it in `.tmp` first
- do not overwrite runtime asset yet
- then ask for runtime adoption / visual smoke-check against:
  - `entities/menhera_boss_sprite.py`
  - `pingfighter.py`
