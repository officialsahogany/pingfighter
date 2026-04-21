# Menhera Turn Peak Key-Pose V1 Prompt

Use this when multi-frame turn generation keeps dropping identity details and we
need to lock one perfect peak transition pose first before deriving a full
sequence.

This is a SINGLE-FRAME reference generation pass, not a full sheet.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate ONE
single key-pose image for real-stage 3 boss Menheragirl (code current_stage == 3).

This is MENHERA TURN PEAK KEY-POSE V1.

Important:
- Generate ONLY ONE single full-body sprite image.
- This is NOT a multi-frame sheet.
- This is NOT a turn-angle chart.
- This is NOT a side-view/profile rotation attempt.
- This is a PEAK direction-change key pose only, to be used later as a
  reference for building the full turn sequence.

Current problem:
- Multi-frame turn generation keeps preserving some details while dropping
  others.
- We need to first lock ONE perfect Menhera peak transition pose that matches
  the canonical walk exactly in identity, scale, and readability.
- Once this one pose is correct, later passes can derive entry/recovery frames
  from it.

Reference split:

1. Identity / scale / frontal-read master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- The result must look like the EXACT SAME Menhera as this walk sheet.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.

3. Negative anti-reference only:
- .tmp/menhera_turn_characterful_direction_change_v3.png
- Use ONLY to avoid repeating known failures:
  - missing med-kit
  - missing heart cheek mark
  - too-small cap
  - wrong eye color
  - weak cloth-tail read

Primary brief:
- Create ONE peak transition pose for a front-facing direction-change gesture.
- Menhera keeps the same frontal combat-facing read as the walk.
- She slightly lifts her chin and looks a little upward / into the middle distance.
- One paw makes a loose outward sweep.
- One knee lifts slightly.
- The pose should feel like a weird cute Menhera "kuse" during a direction change.
- The pose must read as compact, stylish, dreamy, and character-specific.

Exact identity lock (must match the canonical walk exactly):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy cloud-like hair silhouette matching the walk anchor
- Hair must keep visible individual curl structure
- PINK is the dominant outer hair mass color
- CREAM is mostly limited to the front bangs / forelock area
- NOT a cream outer halo with pink interior
- Pink / white check nurse cap
- Cap must read as tall, puffy, and full on top of the head
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Eye color must stay gray / silver, NOT mauve / violet
- Exactly ONE heart cheek mark on one cheek only
- Pink outfit with white front panel
- EXACTLY 4 black bows stacked vertically down the white front panel
- Gray cat-paw gloves with pink toe beans
- Med-kit accessory with pink cross + bunny-ear motif
- Med-kit must stay in the SAME placement as items/menhera_boss_sheet.png
- Do NOT mirror or remove the med-kit
- Pink check-pattern cloth / square-tail motif must stay visible
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Pose design:
- This is NOT an attack.
- This is NOT a greeting wave.
- This is NOT a dance pose.
- This is NOT a dramatic spin.
- Chin lifted about 10-12 degrees.
- Pupils visibly shifted upward, not centered.
- Eyes must read dreamy / detached / looking slightly above the table.
- One paw sweeps outward and slightly downward or sideways.
- Do NOT show an open upright palm toward the viewer.
- One knee lifts visibly but modestly.
- The torso participates with a slight weight shift / soft body bob.
- Hair, ribbon, med-kit, hem, and cloth-tail should all support the gesture
  with small follow-through.

Very important silhouette rules:
- Keep the face and torso mostly front-facing.
- Do NOT turn this into a profile showcase.
- Do NOT let the character read like a different person from the walk.
- Do NOT lose the med-kit, heart cheek mark, cap volume, or four-bow front stack.

Composition:
- ONE single sprite image only
- Pure flat white background (#FFFFFF)
- NO grid lines, NO borders, NO dividers, NO labels
- Character centered
- Full body visible
- Leave generous margin around the sprite
- Match the same body class and gameplay-scale readability as the walk anchor

Gameplay-scale readability is mandatory:
- Eyes, lashes, heart cheek mark, cap silhouette, ribbon, syringe, gloves,
  bows, med-kit accessory, cloth-tail motif, and legwear must all stay readable
- Preserve clean separation between hair, face, arms, outfit, accessory, and legs
- Reduce muddy midtones
- The face must NOT read forehead-cut, clipped, or vertically squashed

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
- Reject if pink/cream hair placement flips
- Reject if the cap becomes too small
- Reject if the med-kit disappears or moves
- Reject if the heart cheek mark disappears
- Reject if the 4 bows collapse into 1 ribbon
- Reject if eye color drifts away from gray/silver
- Reject if the cloth-tail motif becomes too weak to read
- Reject if the pose reads like a greeting wave, attack, or dance
- Reject if the gaze still reads flat straight-ahead instead of dreamy upward
- Reject if the face / forehead read becomes clipped-looking

Output safety rule:
- Do NOT overwrite any runtime asset
- First generate:
    .tmp/menhera_turn_peak_keypose_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_turn_peak_keypose_v1.jpeg \
        .tmp/menhera_turn_peak_keypose_v1.png

- This is a reference candidate only, not a final runtime sheet.
```
