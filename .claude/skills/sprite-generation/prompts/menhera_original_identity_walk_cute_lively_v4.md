# Menhera Original-Identity Walk Cute Lively V4 Prompt

Use this when the current canonical Menhera walk is correct in identity and
front readability, but still feels too static in gameplay and the user wants a
cuter, livelier left/right travel feel with small adorable limb motion.

This is a WALK-ONLY regeneration pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is ORIGINAL-IDENTITY WALK CUTE LIVELY V4.

Current situation:
- The CURRENT canonical walk already has the correct Menhera identity,
  frontal gameplay read, and quality tier.
- However, in gameplay the left/right movement still feels too static.
- The user wants the walk to feel more lively, more "cute and bouncy in the
  limbs", with tiny adorable arm/leg motion and better step energy.

This V4 pass must:
- KEEP the current canonical Menhera identity exactly
- KEEP the current frontal gameplay read exactly
- KEEP the current quality / crispness tier exactly
- Make the movement feel noticeably more alive than the current canonical walk
- Add lively motion mainly through adorable limb rhythm and follow-through
- NOT introduce layout drift
- NOT introduce hair silhouette drift
- NOT introduce side-facing bias

Reference split:

1. Identity / scale / frontal-read master:
- items/menhera_boss_sheet.png
- This is the canonical walk anchor.
- The result must look like the SAME exact Menhera as this walk sheet.

2. Motion inspiration only:
- .tmp/menhera_original_identity_walk_motion_boost_v2.png
- Use this ONLY for the positive motion qualities:
  - clearer step read
  - more noticeable cute arm swing
  - more noticeable hem / cloth / ribbon follow-through
  - more obvious "actually walking" energy
- DO NOT copy its failures.

3. Do NOT use older rejected Menhera identity-drift variants as references.

Hard identity lock (must remain identical to the current canonical walk):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy silhouette matching the canonical walk
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- No cat ears
- Large gray / silver eyes with strong lashes
- Exactly ONE heart cheek mark on one cheek only, matching the canonical walk
- Pink outfit with white front panel
- Four black front bows
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross + bunny-ear motif
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Explicit anti-drift rules:
- EXACTLY 8 frames in a 4x2 grid
- EXACTLY 4 columns and 2 rows
- NOT 5 columns
- NOT 10 frames
- NO pigtails
- NO twin-tails
- NO side hair bunches that create a new silhouette
- Hair must stay a rounded fluffy curly silhouette matching the canonical walk
- NO second heart mark on the other cheek
- Keep row1 and row2 hair color distribution consistent
- Keep syringe visibility consistent enough that it still reads across the sheet
- Do NOT solve motion by rotating the head or torso

What to improve specifically:
- Much clearer step read between adjacent frames than the current canonical walk
- Cute tiny arm swing that feels lively and adorable
- Cute paw / glove rhythm, with subtle alternating lift and settle
- Clearer foot alternation and little chibi step energy
- Slightly more noticeable hair bounce, ribbon flutter, and hem follow-through
- Slightly more noticeable med-kit sway and cloth / tail follow-through
- Clearer feeling that she is happily / briskly moving sideways while still facing front

Motion language target:
- Cute, lively, slightly fidgety, "chibi trotting" lateral walk
- More playful and energetic than the current canonical walk
- Adorably active in the limbs
- A little 촐싹대는 feeling in arms and legs
- NOT chaotic
- NOT exaggerated marching
- NOT side-facing
- NOT dramatic torso twisting
- NOT a full-body bounce caricature

Very important:
- The arms may swing more than before, but the character must still feel front-facing
- The legs may alternate more clearly, but body scale and baseline must stay stable
- The motion should come from:
  - step rhythm
  - paw swing
  - small wrist / elbow rhythm
  - hem flutter
  - ribbon flutter
  - med-kit sway
  - cloth / tail follow-through
- The motion should NOT come mainly from:
  - face turn
  - torso turn
  - shoulder turn
  - asymmetric cheek exposure
  - side-facing bias

Hard frontal rules:
- Stable movement must still read as "facing the player while moving laterally"
- Moving right must NOT feel like she is looking left
- Moving left must NOT feel like she is looking right
- Do NOT use head turn, cheek exposure, shoulder exposure, torso turn,
  or hair asymmetry to fake more motion
- Frontality is more important than extra motion

Walk sheet composition:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character centered in every frame
- Keep foot / baseline position consistent
- Character remains front-facing in every frame
- Body scale must remain within +/-5% of the canonical walk
- Leave generous empty margin around each sprite

Gameplay-scale readability is mandatory:
- Face, eyes, lashes, heart cheek mark, cap silhouette, ribbon, syringe, gloves,
  bows, med-kit accessory, legwear, and cloth/tail motif must stay readable
  at small in-game size
- Preserve clean separation between hair, face, arms, outfit, accessory, and legs
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
- Reject if the result is not EXACTLY 8 frames in a 4x2 grid
- Reject if the hair drifts into pigtails / twin-tails / side bunches
- Reject if the walk becomes more side-biased than the canonical walk
- Reject if moving right feels like she is looking left
- Reject if moving left feels like she is looking right
- Reject if the motion boost comes mainly from torso turn or head turn
- Reject if the result loses the current crispness / readability tier
- Reject if the syringe, heart mark, med-kit accessory, four bows, cloth/tail motif,
  or glove read degrades
- Reject if the motion still feels nearly as static as the current canonical walk

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_original_identity_walk_cute_lively_v4.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_walk_cute_lively_v4.jpeg \
        .tmp/menhera_original_identity_walk_cute_lively_v4.png

- Candidate only. It is NOT canonical until it passes QA against the current
  accepted walk and confirms the rest of the set does not need rework.
```
