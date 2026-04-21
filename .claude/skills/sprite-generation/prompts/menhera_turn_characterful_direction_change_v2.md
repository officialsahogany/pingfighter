# Menhera Turn Characterful Direction-Change V2 Prompt

Use this after V1 passed the basic sheet format and frontal-read checks but
failed on hair silhouette identity, gesture intent, dreamy lifted gaze, and
body-language connection to the walk.

This is a TURN-ONLY auxiliary support pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
turn sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is MENHERA TURN CHARACTERFUL DIRECTION-CHANGE V2.

Important:
- Turn is an AUXILIARY facing-transition sheet only.
- Turn is NOT a replacement for the main walk cycle.
- Turn is NOT a side-view rotation chart.
- Turn is NOT a +90 -> 0 -> -90 angle sheet.
- The goal is to make brief left/right direction changes feel naturally
  connected to the CURRENT canonical frontal walk.

Current situation:
- V1 proved that a frontal turn-support sheet is possible.
- But V1 still failed in four specific ways:
  1. hair silhouette drifted away from the walk anchor
  2. the peak gesture read like a greeting wave
  3. the torso/body rhythm was too frozen
  4. the dreamy lifted-chin / far-away gaze barely appeared
- This V2 pass must correct those exact failures while keeping the same
  format, identity lock, and gameplay readability tier.

Reference split:

1. Identity / body / frontal-read / hair-silhouette master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- Turn must look like the EXACT SAME Menhera as this walk sheet.
- The HAIR SILHOUETTE must match this walk sheet exactly.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.

Do NOT use older rejected turn sheets as shape references if they push the
result toward flat bob hair, greeting-wave posing, or unrelated acting.

Primary brief:
- Keep the exact canonical Menhera identity from the current walk anchor.
- Build a BRIEF 8-frame turn / direction-change transition sheet.
- The whole sheet must still read as the SAME frontal combat-facing Menhera.
- The direction change should be expressed through characterful gesture, not
  camera-angle rotation.
- The motion should feel like a quirky little Menhera "kuse":
  a slightly lifted chin, dreamy / detached upward-middle-distance gaze,
  one paw/arm making a light loose outward sweep, and a tiny one-leg lift or
  pivot.

Exact identity lock (must match the canonical walk exactly):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy cloud-like hair silhouette matching the walk anchor
- Pink / cream distribution must feel like natural fluffy curls, NOT a rigid
  left-right split block pattern
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Exactly ONE heart cheek mark on one cheek only
- Pink outfit with white front panel
- Four black front bows
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross + bunny-ear motif
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Hair rule (very important, strongest correction):
- Match the walk-sheet hair silhouette EXACTLY.
- Hair must read as a fluffy rounded cloud mass around the head.
- Do NOT flatten it into a bob.
- Do NOT reduce it to side curls attached to a flat cap line.
- Do NOT split pink and cream into a clean bilateral half-and-half block.
- The walk anchor's soft rounded fluffy volume is the required silhouette.

Turn motion language:
- This is a brief left/right direction-change gesture, not an attack, not a
  greeting wave, not a dance loop, and not a dramatic spin.
- Menhera should feel slightly dreamy / detached / odd in a cute way.
- The head must lift a little during the key transition frames.
- The gaze should feel middle-distance / far-away, with the eyes drifting
  slightly upward rather than staring straight forward.
- One arm / paw may lightly sweep outward with a loose soft flourish.
- One leg / knee should lift visibly during the peak transition pose.
- A tiny pivot is allowed.
- Hair, ribbon, med-kit, hem, and cloth-tail should rebound subtly with the
  gesture so the motion feels connected to the walk.

Very important pose corrections:
- Raised paw / palm-up greeting-wave read is FORBIDDEN.
- The paw sweep must arc outward and slightly downward or sideways.
- Do NOT raise the paw toward the viewer like a hello / bye-bye hand wave.
- Do NOT present an open upright palm as the main silhouette.
- The gesture should feel like a loose outward flick / sweep, not a greeting.

Body-language corrections:
- The torso must NOT stay frozen.
- Add visible body bob, weight shift, and slight hip sway through frames 2-6.
- At least one knee-lift / one-leg accent must be clearly visible at the peak.
- The turn should feel like the whole body briefly participates, not like only
  the arms got swapped.

Head / gaze correction:
- Chin tilted up about 10 degrees on frames 3-5.
- Eyes drift slightly upward on frames 3-5.
- Do NOT make the eyes look sharply sideways.
- Do NOT keep the gaze locked into a flat straight-at-camera stare.
- The look should feel dreamy / detached / looking a little beyond the table.

Walk connection rules:
- Entry frames must feel like they came directly out of the current walk.
- Exit frames must feel like they can drop directly back into the current walk.
- Walk and turn must feel like one continuous motion language.
- Preserve the same buoyant rhythm:
  - light body bob
  - soft weight shift
  - subtle chibi rebound
  - small follow-through in hair, ribbon, hem, med-kit, and cloth-tail
- Do NOT keep the torso frozen while only the head or hand twitches.

Sheet composition:
- EXACTLY 8 frames in a 4x2 grid
- aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF)
- NO grid lines, NO borders, NO dividers, NO labels
- Character centered in every frame
- Body scale stays within +/-5% of the walking sheet
- Keep foot / baseline logic coherent so runtime can enter and exit cleanly

Recommended frame plan:
- Row 1:
  1. walk-compatible carry-in
  2. small plant / compress with visible weight shift
  3. lifted-chin wind-up, slight hip sway begins, arm preparing an outward sweep
  4. peak transition pose: lifted chin, dreamy upward-middle-distance gaze,
     outward sweeping paw, visible one-knee lift or tiny pivot accent
- Row 2:
  5. rebound from the peak pose, knee lowering, arm sweep trailing out
  6. recovery step with soft settling arm motion and lingering body sway
  7. settle back toward neutral frontal walk language
  8. walk-compatible return

Gameplay-scale readability is mandatory:
- Eyes, lashes, heart cheek mark, cap silhouette, ribbon, syringe, gloves,
  bows, med-kit accessory, legwear, and cloth-tail motif must stay readable
  at in-game size
- Preserve clean separation between hair, face, arms, outfit, accessory, and legs
- Reduce muddy midtones
- The peak transition pose must NOT make the face read chopped, forehead-cut,
  or vertically squashed

Style rules:
- 16-bit retro pixel art
- Chibi proportions
- Thick black pixel outlines
- Flat limited-saturation palette
- Clean hard-edged pixels
- NO painterly rendering
- NO soft shading
- NO photorealism

Hard reject conditions:
- Reject if the result looks like a different Menhera from the current walk anchor
- Reject if the hair silhouette drifts into a flatter bob or left-right split color block
- Reject if the sheet reads like a side-profile rotation chart
- Reject if the sheet feels disconnected from the current walk's motion language
- Reject if the lifted-head / far-away gaze feeling is lost
- Reject if the arm sweep becomes a big greeting wave, palm-up wave, attack, or random dance
- Reject if there is no clearly readable knee-lift / one-leg accent around the peak pose
- Reject if frames 2-6 still feel torso-frozen
- Reject if the face / forehead read becomes clipped-looking
- Reject if the result becomes blurrier or softer than items/menhera_boss_victory.png
- Reject if body scale or face scale drifts across frames

Output safety rule:
- Do NOT overwrite items/menhera_boss_turn.png yet
- First generate:
    .tmp/menhera_turn_characterful_direction_change_v2.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_turn_characterful_direction_change_v2.jpeg \
        .tmp/menhera_turn_characterful_direction_change_v2.png

- Candidate only. Not canonical until QA passes against the current walk anchor.
```
