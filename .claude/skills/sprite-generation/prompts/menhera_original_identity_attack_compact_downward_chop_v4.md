# Menhera Original-Identity Attack Compact Downward Chop v4

Use this after rejecting `attack_compact_downward_chop_v3` for identity drift
even though its compact downward-chop motion direction was correct.

This pass keeps the successful compact front-facing downward-chop motion intent,
but hard-locks Menhera's canonical identity tokens and silhouette.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
attack sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is a targeted ATTACK-ONLY correction pass.

Reference split:

1. Identity / body / scale master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- Attack must look like the EXACT SAME Menhera as this walk sheet.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, pixel separation, and gameplay-scale
  readability.

3. Identity-preservation reference only:
- .tmp/menhera_original_identity_attack_front_down_smash_v2.png
- This candidate preserved Menhera identity much better.
- Use ONLY to remember identity / accessory retention quality.
- Do NOT copy its overhead raise / arm-up prep silhouette.

4. Motion-success reference only:
- .tmp/menhera_original_identity_attack_compact_downward_chop_v3.png
- This candidate achieved the correct compact downward-chop motion.
- Use ONLY for motion direction:
  compact coil -> low downward chop impact
- Do NOT copy its identity drift.

5. Stage-8 motion readability inspiration only:
- assets/stage9hit2.png
- Use ONLY for the idea that the hit still reads front-facing while force is
  directed downward/frontward.
- Do NOT copy Akamu Rigo's identity, silhouette, costume, or exact pose.

Primary goal:
- Same Menhera as the canonical walk anchor
- Same or better quality tier as the current victory sheet
- Keep v3's compact downward-chop motion direction
- Remove all v3 identity drift

Exact identity lock (must match the canonical walk anchor exactly):
- Rounded fluffy curly short pink + cream hair silhouette
- Hair color must remain BALANCED pink + cream, not blonde-dominant
- Pink / white CHECK GINGHAM nurse cap
- Red cross on the cap
- Visually prominent side red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- NO pigtails
- NO twin-tails
- NO side hair bunches that create a new silhouette
- Large gray / silver eyes with strong lashes
- Single heart cheek mark on one cheek only
- Pink outfit with white front panel
- Vertical black front bow STACK (2-3 bows visibly preserved)
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross
- Pink CHECK-PATTERN cloth / square-tail motif behind the body
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
- row1: front guard, compact chamber, tighter pre-strike coil, forward/down pressure build
- row2: chop start, LOW DOWNWARD IMPACT, recoil, recovery

Important runtime note:
- Runtime currently holds frame 6 (row2 col2, zero-based impact index 5) a bit
  longer as the impact frame.
- Therefore frame 6 MUST be the clearest, strongest, most readable compact
  downward hit moment.

Compact chop pose rules:
- Menhera remains front-facing in every frame
- Eyes read forward / slightly downward, NOT sideways
- Torso stays mostly square to camera
- Striking paw stays at chest / shoulder / face height during prep
- NO overhead raise
- Do NOT place the striking paw straight above the cap
- Row1 must NOT read like "arm goes higher and higher"
- Instead show compression, shoulder tuck, wrist angle change, and forward/down tension
- The hit should feel like a vicious short downward chop, press, or hammering slam
  delivered from the front
- Force travels down toward the lower front ball plane
- Frame 6 = compact downward chop with low paw + clear impact FX
- The free arm may counterbalance, but must not hide the face

Accessory / silhouette preservation rules:
- Cap MUST retain pink/white gingham pattern, not solid pink
- Side red ribbon MUST remain clearly readable, not a tiny edge nub
- Black front bow STACK MUST remain readable, not reduced to a single bow
- Pink check-pattern cloth / square-tail motif MUST remain visible behind the body
  in at least half of the frames
- Hair silhouette must stay rounded fluffy and close to the walk anchor
- Do NOT solve motion by inventing new hair masses or side bunches

Gameplay-scale readability is mandatory:
- Eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, bows, gloves,
  med-kit accessory, cloth-tail motif, and legwear must stay readable at
  in-game size
- Keep clean separation between hair, face, arms, outfit, accessory, and legs
- Reduce muddy midtones

Emotional tone:
- Menacing, focused, unstable, slightly yandere / menhera
- Front-facing hostile pressure
- Not sporty boxing, not a side hook, not a side jab, not an overhead slam pose

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
- Reject if pigtails / twin-tails / side hair bunches appear
- Reject if cap gingham pattern is lost
- Reject if the side red ribbon becomes tiny or unreadable
- Reject if the black bow stack collapses to a single bow
- Reject if the pink check cloth-tail motif disappears or is unreadable in most frames
- Reject if hair palette becomes blonde-dominant instead of balanced pink + cream
- Reject if the striking paw is raised overhead / above-cap as the main prep read
- Reject if row1 reads as "arm going up" instead of "attack coiling tighter"
- Reject if the attack reads as a right-facing side punch / side jab / side hook
- Reject if the strongest impact frame is horizontal instead of downward
- Reject if gaze becomes sideways instead of forward / slightly downward
- Reject if body read is smaller than the walk anchor
- Reject if the med-kit accessory disappears
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png
- Reject if impact readability comes from making the face unreadable
- Reject if layout is anything other than EXACTLY 4 columns x 2 rows

Output safety rule:
- Do NOT overwrite items/menhera_boss_attack.png yet
- First generate:
    .tmp/menhera_original_identity_attack_compact_downward_chop_v4.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_attack_compact_downward_chop_v4.jpeg \
        .tmp/menhera_original_identity_attack_compact_downward_chop_v4.png
- Candidate only. Not canonical until QA passes against the current walk anchor.
```
