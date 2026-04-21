# Menhera Original-Identity Attack Front-Down Smash v2

Use this when the current Menhera attack sheet is readable but still feels too
side-punch / side-thrust oriented in-game.

This pass keeps the current restored Menhera identity and quality tier, but
changes the attack read so it feels like a front-facing downward smash while
still looking forward, similar in gameplay readability to Stage 8 Akamu Rigo's
front-read hit motion.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
attack sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is a targeted ATTACK-ONLY realignment pass.

Reference split:

1. Identity / body / scale master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- Attack must look like the EXACT SAME Menhera as this walk sheet.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, pixel separation, and gameplay-scale
  readability.
- Do NOT copy any old identity drift from earlier generations.

3. Motion-read reference only:
- assets/stage9hit2.png
- This is the attack-read sheet currently used by Stage 8 runtime and is the
  closest local reference for the desired front-facing downward hit feeling.
- Use ONLY for motion readability:
  "front-facing, eyes still forward, attack force traveling downward/frontward"
- Do NOT borrow Akamu Rigo's identity, silhouette, palette, costume, or body type.

4. Broad existing Menhera attack context only:
- items/menhera_boss_attack.png
- Use ONLY to preserve the idea that this is still Menhera's attack timing slot.
- Do NOT preserve its current side-looking / horizontal-thrust bias.

Primary goal:
- Same Menhera as the canonical walk anchor
- Same or better quality tier as the current victory sheet
- Attack should read as a FRONT-FACING DOWNWARD SMASH, not a side punch
- At impact, Menhera should still read as looking toward the player / forward
  with only a slight downward gaze toward the ball plane

Exact identity lock (must match the canonical walk anchor exactly):
- Fluffy curly short pink + cream hair mass with rounded silhouette
- Pink / white check nurse cap
- Red cross on the cap
- Side red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Single heart cheek mark on one cheek only
- Pink outfit with white front panel
- Black front bow stack
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Attack sheet composition:
- EXACTLY 8 frames in a 4x2 grid
- aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Keep foot / baseline position coherent
- Head / torso / pelvis scale within +/-5% of the walk anchor
- Effects may extend outward, but body read must not shrink

Frame intent:
- row1: front guard, raise striking paw, overhead wind-up, compressed apex
- row2: downswing start, DOWNWARD IMPACT, recoil, recovery

Important runtime note:
- Runtime currently holds frame 6 (row2 col2, zero-based impact index 5) a bit
  longer as the impact frame.
- Therefore frame 6 MUST be the clearest, strongest, most readable front-facing
  downward smash moment.

Required attack read:
- Menhera remains front-facing in every frame
- Eyes read forward / slightly downward, NOT side-looking right
- Torso stays mostly square to camera
- Shoulders may compress and arms may arc, but do NOT solve force by rotating the
  whole character into a side profile or 3/4 side punch
- The striking paw should travel from above/front down toward the lower front
  ball plane, like an overhand paw smash / hammering hit
- The free arm may counterbalance, but must not hide the face
- The impact should feel like "downward/frontward slam" rather than "straight
  horizontal jab"
- Hair, ribbon, cloth-tail, and med-kit should show follow-through, but the face
  must remain readable

Emotional tone:
- Menacing, focused, unstable, slightly yandere / menhera
- Front-facing hostile pressure
- Not sporty boxing, not a side hook, not a side jab

Gameplay-scale readability is mandatory:
- Eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, bows, gloves,
  med-kit accessory, cloth-tail motif, and legwear must stay readable at
  in-game size
- Keep clean separation between hair, face, arms, outfit, accessory, and legs
- Reduce muddy midtones

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
- Reject if the result looks like a different Menhera
- Reject if the attack reads as a right-facing side punch / side jab / side hook
- Reject if the strongest impact frame is horizontal instead of downward
- Reject if gaze becomes sideways instead of forward / slightly downward
- Reject if body read is smaller than the walk anchor
- Reject if the med-kit accessory disappears
- Reject if the bow stack disappears
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png
- Reject if impact readability comes from making the face unreadable
- Reject if layout is anything other than EXACTLY 4 columns x 2 rows

Output safety rule:
- Do NOT overwrite items/menhera_boss_attack.png yet
- First generate:
    .tmp/menhera_original_identity_attack_front_down_smash_v2.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_attack_front_down_smash_v2.jpeg \
        .tmp/menhera_original_identity_attack_front_down_smash_v2.png
- Candidate only. Not canonical until QA passes against the current walk anchor.
```
