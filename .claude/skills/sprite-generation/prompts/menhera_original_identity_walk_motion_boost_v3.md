# Menhera Original-Identity Walk Motion Boost V3 Prompt

Use this after `walk_motion_boost_v2` failed due to layout drift and hair
identity drift, but the user still wants the walk cycle to feel a little more
alive in gameplay.

This is a WALK-ONLY regeneration pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is ORIGINAL-IDENTITY WALK MOTION BOOST V3.

Current situation:
- The CURRENT accepted canonical walk already has the correct identity,
  quality tier, and frontal gameplay read.
- The failed V2 candidate improved motion, but hard-failed on:
  - wrong layout (5x2 instead of 4x2)
  - hair identity drift into pigtails / twin-tails
  - additional small token drift

This V3 pass must:
- KEEP the current accepted Menhera identity exactly
- KEEP the current accepted frontal gameplay read exactly
- KEEP the current accepted quality / crispness tier exactly
- Add only a SMALL motion boost
- NOT introduce any layout drift
- NOT introduce any hair silhouette drift

Reference split:

1. Identity / scale / frontal-read master:
- items/menhera_boss_sheet.png
- This is the canonical character anchor.
- The result must look like the SAME exact Menhera as this walk sheet.

2. Motion inspiration only:
- .tmp/menhera_original_identity_walk_motion_boost_v2.png
- Use this ONLY for the positive motion qualities:
  - clearer step read
  - slightly more arm swing
  - slightly more hair / ribbon / cloth follow-through
- DO NOT copy any of its failures.

3. Do NOT use older rejected Menhera variants as references.

Hard identity lock (must remain identical to the current accepted walk):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy silhouette matching the current accepted walk
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- No cat ears
- Large gray / silver eyes with strong lashes
- Exactly ONE heart cheek mark on one cheek only, matching the current accepted walk
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

What to improve specifically:
- Slightly clearer step read between adjacent frames
- Slightly clearer cute arm swing during movement
- Slightly clearer hair sway / ribbon follow-through
- Slightly clearer hem / cloth follow-through
- Slightly clearer sense that the character is actually walking laterally

Motion language target:
- Cute, tidy, composed, front-facing walk
- A little more alive than the current accepted walk
- Not stiff
- Not overly bouncy
- Not exaggerated marching
- Not side-facing
- Not dramatic torso twisting

Very important:
- The arms may swing a little, but the character must still feel front-facing
- The hair may sway a little, but the face must still read clearly and frontally
- The steps should read more clearly, but body scale and baseline must stay stable
- The walk should feel more alive through steps and follow-through, not through redesign

Hard frontal rules:
- Stable movement must still read as "facing the player while moving laterally"
- Moving right must NOT feel like she is looking left
- Moving left must NOT feel like she is looking right
- Do NOT use head turn, cheek exposure, shoulder exposure, torso turn,
  or hair asymmetry to fake more motion

Walk sheet composition:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character centered in every frame
- Keep foot / baseline position consistent
- Character remains front-facing in every frame
- Body scale must remain within +/-5% of the current accepted walk
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
- Reject if the walk becomes more side-biased than the current accepted walk
- Reject if moving right feels like she is looking left
- Reject if moving left feels like she is looking right
- Reject if the motion boost comes mainly from torso turn or head turn
- Reject if the result loses the current accepted crispness / readability tier
- Reject if the syringe, heart mark, med-kit accessory, four bows, cloth/tail motif,
  or glove read degrades

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_original_identity_walk_motion_boost_v3.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_walk_motion_boost_v3.jpeg \
        .tmp/menhera_original_identity_walk_motion_boost_v3.png

- Candidate only. It is NOT canonical until it passes QA against the current
  accepted walk and confirms the rest of the set does not need rework.
```
