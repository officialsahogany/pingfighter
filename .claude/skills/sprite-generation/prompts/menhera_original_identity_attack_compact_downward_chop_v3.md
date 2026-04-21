# Menhera Original-Identity Attack Compact Downward Chop v3

Use this after rejecting the earlier `front_down_smash_v2` candidate for reading
too much like an overhead arm-raise before impact.

This pass is specifically for a compact, front-facing, downward chop / slam
that does NOT rely on lifting the striking paw high above the head.

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

3. Motion-read inspiration only:
- assets/stage9hit2.png
- Use ONLY for the idea that the hit still reads front-facing while force is
  directed downward/frontward.
- Do NOT copy Akamu Rigo's identity, silhouette, costume, or exact pose.

4. Negative reference / failure mode:
- .tmp/menhera_original_identity_attack_front_down_smash_v2.png
- This candidate is REJECTED because it raised the striking paw too high and
  read like "arm up first, then slam."
- Do NOT reproduce that overhead raise silhouette.

Primary goal:
- Same Menhera as the canonical walk anchor
- Same or better quality tier as the current victory sheet
- Attack should feel like a COMPACT DOWNWARD CHOP / HAMMERING HIT
- The strike should read as front-facing and downward WITHOUT a big overhead wind-up

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
- row1: front guard, compact chamber, tighter pre-strike coil, forward/down pressure build
- row2: chop start, LOW DOWNWARD IMPACT, recoil, recovery

Important runtime note:
- Runtime currently holds frame 6 (row2 col2, zero-based impact index 5) a bit
  longer as the impact frame.
- Therefore frame 6 MUST be the clearest, strongest, most readable compact
  downward hit moment.

Required attack read:
- Menhera remains front-facing in every frame
- Eyes read forward / slightly downward, NOT sideways
- Torso stays mostly square to camera
- The striking paw must start from a compact guard / shoulder-height chamber,
  NOT from a high overhead raise
- The striking paw should NEVER read as fully lifted above the cap for multiple frames
- Avoid any big "victory pose" or "uppercut prep" silhouette
- The hit should feel like a vicious short downward chop, press, or hammering slam
  delivered from the front
- Force travels down toward the lower front ball plane
- The free arm may counterbalance, but must not hide the face
- Hair, ribbon, cloth-tail, and med-kit may react, but the face must stay readable

Pose limits:
- Keep the striking elbow and paw near face / shoulder / upper chest height during prep
- Do NOT place the striking paw straight above the head
- Do NOT make row1 look like "raising hand higher and higher"
- Instead, show compression, shoulder tuck, wrist angle change, and forward/down tension

Emotional tone:
- Menacing, focused, unstable, slightly yandere / menhera
- Front-facing hostile pressure
- Not sporty boxing, not a side hook, not a side jab, not an overhead slam pose

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
- Reject if the striking paw is raised overhead / above-cap as the main prep read
- Reject if row1 reads as "arm going up" instead of "attack coiling tighter"
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
    .tmp/menhera_original_identity_attack_compact_downward_chop_v3.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_attack_compact_downward_chop_v3.jpeg \
        .tmp/menhera_original_identity_attack_compact_downward_chop_v3.png
- Candidate only. Not canonical until QA passes against the current walk anchor.
```
