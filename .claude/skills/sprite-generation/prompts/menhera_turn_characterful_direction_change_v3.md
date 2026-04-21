# Menhera Turn Characterful Direction-Change V3 Prompt

Use this after V2 fixed the basic gesture problems but still failed on exact
identity lock versus the current walk anchor: hair color placement, bow count,
med-kit side, cap volume, dreamy gaze strength, and motion-arc continuity.

This is a TURN-ONLY auxiliary support pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
turn sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is MENHERA TURN CHARACTERFUL DIRECTION-CHANGE V3.

Important:
- Turn is an AUXILIARY facing-transition sheet only.
- Turn is NOT a replacement for the main walk cycle.
- Turn is NOT a side-view rotation chart.
- Turn is NOT a +90 -> 0 -> -90 angle sheet.
- The goal is to make brief left/right direction changes feel naturally
  connected to the CURRENT canonical frontal walk.

Current situation:
- V2 improved the outward paw sweep and gave a readable knee-lift.
- But V2 still failed identity lock against the walk anchor in several
  decisive ways:
  1. hair color placement inverted
  2. hair texture became too cotton-candy / sheep-wool instead of defined curls
  3. front bow count collapsed from 4 to 1
  4. med-kit side got mirrored
  5. nurse cap became too small
  6. dreamy lifted gaze remained too weak
  7. row 2 motion arc felt like a repeat / mirror instead of recovery
- This V3 pass must fix those exact failures while keeping the same frontal
  direction-change gesture format.

Reference split:

1. Identity / body / frontal-read / hair-color-placement master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- Turn must look like the EXACT SAME Menhera as this walk sheet.
- Hair silhouette, hair color placement, cap size, bow count, and med-kit side
  must match this walk anchor exactly.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.

3. Negative anti-reference only:
- .tmp/menhera_turn_characterful_direction_change_v2.png
- Use ONLY to avoid repeating the known failures:
  - cream outer halo hair
  - single bow at the collar
  - mirrored med-kit
  - small wedge cap
  - weak upward gaze
  - row 2 repeating row 1 instead of completing the motion arc

Primary brief:
- Keep the exact canonical Menhera identity from the current walk anchor.
- Build a BRIEF 8-frame turn / direction-change transition sheet.
- The whole sheet must still read as the SAME frontal combat-facing Menhera.
- The direction change should be expressed through characterful gesture, not
  camera-angle rotation.
- The motion should feel like a quirky little Menhera "kuse":
  a slightly lifted chin, dreamy upward-middle-distance gaze, one paw making a
  loose outward sweep, and a tiny one-leg lift / pivot accent.

Exact identity lock (must match the canonical walk exactly):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy cloud-like silhouette matching the walk anchor
- Hair must keep visible individual curl structure, not cotton candy fluff
- PINK is the dominant outer hair mass color
- CREAM is mostly limited to the front bangs / forelock area
- NOT a cream outer halo with pink interior
- Pink / white check nurse cap
- Cap must read as tall, puffy, and full on top of the head, not a small wedge
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Exactly ONE heart cheek mark on one cheek only
- Pink outfit with white front panel
- EXACTLY 4 black bows stacked vertically down the white front panel
- Gray cat-paw gloves with pink toe beans
- Med-kit accessory with pink cross + bunny-ear motif
- Med-kit must hang on the SAME side as in items/menhera_boss_sheet.png
- Do NOT mirror the med-kit
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Hair rule (strongest identity correction):
- Match the walk-sheet hair silhouette EXACTLY.
- Match the walk-sheet hair color placement EXACTLY.
- PINK must remain the dominant outer fluffy mass.
- CREAM should stay concentrated in the front bangs / forelock region.
- Do NOT invert the color structure.
- Do NOT turn the hair into a cream cloud with a pink center.
- Do NOT blur the curls into sheep wool / cotton candy texture.
- Keep the defined curly clumps visible inside the rounded silhouette.

Front torso / accessory lock:
- EXACTLY 4 black bows must be visible down the white front panel.
- Do NOT collapse them into one collar ribbon.
- The med-kit must remain on the same side as the walk anchor.
- If the med-kit flips sides, the result is wrong even if the rest looks good.
- The nurse cap must stay large, puffy, and clearly readable from gameplay size.

Turn motion language:
- This is a brief left/right direction-change gesture, not an attack, not a
  greeting wave, not a dance loop, and not a dramatic spin.
- Menhera should feel slightly dreamy / detached / odd in a cute way.
- The head must lift during the key transition frames.
- The gaze should feel like she is looking a little above and beyond the table.
- One paw may lightly sweep outward with a loose soft flourish.
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

Head / gaze correction (stronger than V2):
- Chin tilted up about 10-12 degrees on frames 3-5.
- Pupils visibly shifted upward on frames 3-5.
- NOT centered pupils.
- NOT a flat straight-at-camera stare.
- Do NOT make the eyes look sharply sideways.
- The look should clearly read dreamy / detached / upward-middle-distance.

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

Motion-arc continuity rule (very important):
- Row 2 must CONTINUE the motion arc from row 1.
- Row 2 must NOT feel like a repeat, mirror, or near-copy of row 1.
- Frame 4 is the peak.
- Frame 5 must read as rebound from that peak.
- Frame 6 must read as recovery with lingering sway.
- Frame 7 must read as settling.
- Frame 8 must read as walk-compatible return.
- The sequence must feel like one continuous action with a clear rise,
  peak, rebound, recovery, and settle.

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
  3. lifted-chin wind-up, slight hip sway begins, paw preparing an outward sweep
  4. peak transition pose: lifted chin, clearly upward-shifted pupils,
     dreamy far-away gaze, outward sweeping paw, visible one-knee lift or tiny pivot
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
- Reject if hair color placement flips into cream-dominant outer mass
- Reject if hair texture becomes sheep-wool / cotton-candy instead of defined fluffy curls
- Reject if the 4-bow front stack collapses into 1 bow / 1 ribbon
- Reject if the med-kit side is mirrored
- Reject if the nurse cap becomes too small or wedge-like
- Reject if the sheet reads like a side-profile rotation chart
- Reject if the sheet feels disconnected from the current walk's motion language
- Reject if the lifted-head / upward far-away gaze feeling is still too weak
- Reject if the arm sweep becomes a big greeting wave, palm-up wave, attack, or random dance
- Reject if there is no clearly readable knee-lift / one-leg accent around the peak pose
- Reject if frames 5-8 fail to complete the recovery arc
- Reject if the face / forehead read becomes clipped-looking
- Reject if the result becomes blurrier or softer than items/menhera_boss_victory.png
- Reject if body scale or face scale drifts across frames

Output safety rule:
- Do NOT overwrite items/menhera_boss_turn.png yet
- First generate:
    .tmp/menhera_turn_characterful_direction_change_v3.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_turn_characterful_direction_change_v3.jpeg \
        .tmp/menhera_turn_characterful_direction_change_v3.png

- Candidate only. Not canonical until QA passes against the current walk anchor.
```
