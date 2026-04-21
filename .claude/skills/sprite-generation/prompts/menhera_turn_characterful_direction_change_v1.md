# Menhera Turn Characterful Direction-Change V1 Prompt

Use this when Menhera's turn sheet should be rebuilt under the NEW turn
definition: not an angle-rotation chart, but a brief frontal direction-change
gesture that stays connected to her walk.

This is a TURN-ONLY auxiliary support pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
turn sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is MENHERA TURN CHARACTERFUL DIRECTION-CHANGE V1.

Important:
- Turn is an AUXILIARY facing-transition sheet only.
- Turn is NOT a replacement for the main walk cycle.
- Turn is NOT a side-view rotation chart.
- Turn is NOT a +90 -> 0 -> -90 angle sheet.
- The goal is to make brief left/right direction changes feel naturally
  connected to the CURRENT canonical frontal walk.

Current situation:
- Menhera's walk stays front-facing during left/right travel.
- Because of that, turn should NOT be built as a profile-angle showcase.
- The user wants a brief characterful transition gesture instead:
  - slightly lifting her head
  - looking a little far away / into the middle distance
  - lightly sweeping / tossing one arm or paw outward
  - possibly lifting one leg / knee briefly
  - keeping the same frontal-read Menhera identity
  - keeping clear connection to the current walk cycle

Reference split:

1. Identity / body / frontal-read master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- Turn must look like the EXACT SAME Menhera as this walk sheet.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.

Do NOT use older rejected turn sheets as shape references if they push the
result toward side-profile rotation or mismatched face read.

Primary brief:
- Keep the exact canonical Menhera identity from the current walk anchor.
- Build a BRIEF 8-frame turn / direction-change transition sheet.
- The whole sheet must still read as the SAME frontal combat-facing Menhera.
- The direction change should be expressed through characterful gesture, not
  camera-angle rotation.
- The motion should feel like a quirky little Menhera "kuse":
  a slightly lifted chin, dreamy / detached upward-middle-distance gaze,
  one paw/arm making a light loose sweep, and a tiny one-leg lift or pivot.

Exact identity lock (must match the canonical walk exactly):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy hair silhouette matching the walk anchor
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

Turn motion language:
- This is a brief left/right direction-change gesture, not an attack, not a
  greeting wave, not a dance loop, and not a dramatic spin.
- Menhera should feel slightly dreamy / detached / odd in a cute way.
- The head may lift a little, as if she is briefly looking a bit above and
  beyond the immediate play space.
- The gaze may feel middle-distance / far-away, but do NOT make her stare hard
  to the side.
- One arm / paw may lightly sweep outward or upward with a loose soft flourish.
- The other arm should support the balance of the pose rather than hanging dead.
- One leg / knee may lift lightly during the peak transition pose.
- A tiny pivot or soft hop accent is allowed.
- Hair, ribbon, med-kit, hem, and cloth-tail should rebound subtly with the
  gesture so the motion feels connected to the walk.

Very important pose rules:
- Keep the face and torso MOSTLY front-facing throughout the sequence.
- Do NOT turn the turn sheet into a profile showcase.
- Do NOT use strong 3/4 view as the main source of motion.
- Do NOT make the motion read like the camera is orbiting around Menhera.
- Do NOT make the peak pose so big that it reads like an attack or a taunt.
- Do NOT make the arm sweep look like waving hello to the player.
- Keep it compact, strange, cute, and character-specific.

Walk connection rules:
- Entry frames must feel like they came directly out of the current walk.
- Exit frames must feel like they can drop directly back into the current walk.
- Walk and turn must feel like one continuous motion language.
- The same buoyant rhythm should be preserved:
  - light body bob
  - soft weight shift
  - subtle chibi rebound
  - small follow-through in hair, ribbon, hem, med-kit, and cloth-tail
- Do NOT keep the torso frozen while only the head or hand twitches.
- The whole body should participate in the gesture in a compact way.

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
  2. small plant / compress
  3. lifted-chin + arm-sweep wind-up
  4. peak transition pose: lifted head, far-away gaze, one paw/arm flourish,
     light knee lift or tiny pivot accent
- Row 2:
  5. rebound from the peak pose
  6. recovery step with soft settling arm motion
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
- Reject if the sheet reads like a side-profile rotation chart
- Reject if the sheet feels disconnected from the current walk's motion language
- Reject if the lifted-head / far-away gaze feeling is lost
- Reject if the arm sweep becomes a big greeting wave, attack, or random dance
- Reject if the peak pose is too harsh, too aggressive, or too large
- Reject if the face / forehead read becomes clipped-looking
- Reject if the result becomes blurrier or softer than items/menhera_boss_victory.png
- Reject if body scale or face scale drifts across frames

Output safety rule:
- Do NOT overwrite items/menhera_boss_turn.png yet
- First generate:
    .tmp/menhera_turn_characterful_direction_change_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_turn_characterful_direction_change_v1.jpeg \
        .tmp/menhera_turn_characterful_direction_change_v1.png

- Candidate only. Not canonical until QA passes against the current walk anchor.
```
