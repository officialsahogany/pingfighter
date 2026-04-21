# Menhera Turn Peak Key-Pose V2 Prompt

Use this after peak key-pose V1 recovered most major identity features but still
missed several must-lock signature details: heart cheek mark, exact 4-bow front
stack, dome-tall cap silhouette, bunny-ear med-kit detail, ankle X marks, and a
strong enough upward dreamy gaze.

This is a SINGLE-FRAME reference generation pass, not a full sheet.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate ONE
single key-pose image for real-stage 3 boss Menheragirl (code current_stage == 3).

This is MENHERA TURN PEAK KEY-POSE V2.

Important:
- Generate ONLY ONE single full-body sprite image.
- This is NOT a multi-frame sheet.
- This is NOT a turn-angle chart.
- This is NOT a side-view/profile rotation attempt.
- This is a PEAK direction-change key pose only, to be used later as a
  reference for building the full turn sequence.

Current situation:
- V1 already recovered most of the difficult identity pieces:
  hair color placement, curl structure, gray/silver eyes, med-kit placement,
  frontal read, outward paw sweep, knee lift, and cloth-tail visibility.
- But V1 still failed on several MUST-LOCK signature details:
  1. heart cheek mark missing
  2. 4 black bows not arranged as the canonical centerline stack
  3. nurse cap too flat and too wide
  4. bunny-ear motif on the med-kit missing
  5. black X ankle accessories missing
  6. dreamy upward gaze / chin lift still too weak
- This V2 pass must keep the V1 gains while correcting those exact misses.

Reference split:

1. Identity / scale / frontal-read master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- The result must look like the EXACT SAME Menhera as this walk sheet.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.

3. Negative anti-reference only:
- .tmp/menhera_turn_peak_keypose_v1.png
- Use ONLY to avoid repeating the known misses:
  - missing heart cheek mark
  - wrong bow distribution
  - flat wide cap
  - missing bunny-ear detail on med-kit
  - missing ankle X marks
  - weak upward gaze

Primary brief:
- Create ONE peak transition pose for a front-facing direction-change gesture.
- Menhera keeps the same frontal combat-facing read as the walk.
- She slightly lifts her chin and looks upward / into the middle distance.
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
- Nurse cap silhouette must be DOME-shaped and TALLER than wide
- Cap should feel like a tall puffy nurse cap, not a flat wide beret/disc
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Eye color must stay gray / silver, NOT mauve / violet
- Heart cheek mark on the LEFT cheek (viewer’s right) is REQUIRED
- It must be a clearly outlined heart shape, NOT a blush dot
- Pink outfit with white front panel
- EXACTLY 4 black bows arranged VERTICALLY down the centerline of the white front panel
- The 4 bows must run from collar area down toward the hem in one central stack
- NOT one collar bow plus two hip bows
- Gray cat-paw gloves with pink toe beans
- Med-kit accessory with pink cross + bunny-ear motif
- Med-kit must stay in the SAME placement as items/menhera_boss_sheet.png
- Do NOT mirror or remove the med-kit
- Bunny-ear motif on top of the med-kit is REQUIRED
- Two small triangular bunny ears must protrude from the kit's top edge
- Pink check-pattern cloth / square-tail motif must stay visible
- White sheer thigh-highs
- Black X mark visible on EACH ankle just above the shoe
- Chibi petite-human proportions
- Thick black pixel outlines

Pose design:
- This is NOT an attack.
- This is NOT a greeting wave.
- This is NOT a dance pose.
- This is NOT a dramatic spin.
- Chin must be clearly tilted upward enough that a slight underside-of-jaw read is visible.
- Pupils must be drawn distinctly higher within the eye than the centerline.
- NOT centered pupils.
- NOT a flat straight-at-camera stare.
- Eyes must read dreamy / detached / looking slightly above the table.
- One paw sweeps outward and slightly downward or sideways.
- Do NOT show an open upright palm toward the viewer.
- One knee lifts visibly but modestly.
- The torso participates with a slight weight shift / soft body bob.
- Hair, ribbon, med-kit, hem, and cloth-tail should all support the gesture
  with small follow-through.

Very important silhouette and placement rules:
- Keep the face and torso mostly front-facing.
- Do NOT turn this into a profile showcase.
- Do NOT let the character read like a different person from the walk.
- Do NOT lose the med-kit, heart cheek mark, cap dome volume, ankle X marks,
  or the exact 4-bow center stack.

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
  bows, med-kit accessory, bunny ears, cloth-tail motif, ankle X marks,
  and legwear must all stay readable
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
- Reject if the heart cheek mark is missing or turns into a blush dot
- Reject if the 4 bows are not a clear vertical centerline stack
- Reject if the cap is flat, wide, or beret-like instead of dome-tall
- Reject if the med-kit bunny-ear detail is missing
- Reject if the med-kit disappears, moves, or mirrors
- Reject if the ankle X marks are missing
- Reject if eye color drifts away from gray/silver
- Reject if the gaze still reads flat straight-ahead instead of dreamy upward
- Reject if the pose reads like a greeting wave, attack, or dance
- Reject if the face / forehead read becomes clipped-looking

Output safety rule:
- Do NOT overwrite any runtime asset
- First generate:
    .tmp/menhera_turn_peak_keypose_v2.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_turn_peak_keypose_v2.jpeg \
        .tmp/menhera_turn_peak_keypose_v2.png

- This is a reference candidate only, not a final runtime sheet.
```
