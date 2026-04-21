# Menhera Original-Identity Walk Playful Arms V5 Prompt

Use this when the current canonical Menhera walk still feels too subdued in
gameplay and the user wants noticeably more cheerful, adorable lateral motion,
especially in the arms and legs, while preserving strict frontal readability.

This is a WALK-ONLY regeneration pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is ORIGINAL-IDENTITY WALK PLAYFUL ARMS V5.

Current situation:
- The CURRENT canonical walk has the correct identity, frontal gameplay read,
  and quality tier.
- A newer lively candidate proved that stronger motion can work, but we now
  want the motion to be EVEN MORE playful in the limbs.
- The user specifically wants:
  - more cheerful, lively left/right movement
  - bigger arm and leg motion
  - arms that feel slightly coy / coquettish / cute / a little "showing off"
  - still fully readable as the same Menhera
  - still front-facing, not 3/4

This V5 pass must:
- KEEP the current canonical Menhera identity exactly
- KEEP the current frontal gameplay read exactly
- KEEP the current quality / crispness tier exactly
- Make the walk feel more cheerful, lively, and adorable than the current canonical walk
- Put most of the extra energy into arms, legs, ribbon, hem, med-kit, and cloth-tail
- NOT introduce layout drift
- NOT introduce hair silhouette drift
- NOT introduce side-facing bias

Reference split:

1. Identity / scale / frontal-read master:
- items/menhera_boss_sheet.png
- This is the canonical walk anchor.
- The result must look like the SAME exact Menhera as this walk sheet.

2. Motion inspiration only:
- .tmp/menhera_original_identity_walk_cute_lively_v4.png
- Use this ONLY for the positive motion qualities:
  - clearer step read
  - more obvious lively movement
  - cuter rhythm
- Do NOT copy any of its mild identity drift.

3. Do NOT use older rejected Menhera identity-drift variants as references.

Hard identity lock (must remain identical to the current canonical walk):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy silhouette matching the canonical walk
- Pink should remain visibly strong in the hair, not reduced to a thin outer rim
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- No cat ears
- Large gray / silver eyes with strong lashes
- Exactly ONE heart cheek mark on one cheek only
- Pink outfit with white front panel
- Four black front bows clearly preserved
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
- Keep the black front bow count readable as FOUR, not 1-2
- Do NOT solve motion by rotating the head or torso

What to improve specifically:
- Much clearer cheerful step rhythm than the current canonical walk
- Bigger cute arm swing than the canonical walk
- Arms should feel slightly coy / coquettish / playful, like tiny chibi "aegyo"
  gestures while still functioning as a walk cycle
- Bigger leg lift / step alternation so the walk reads more actively
- Cute paw / glove presentation, with alternating lift and settle
- More noticeable ribbon flutter, hem flutter, med-kit sway, and cloth-tail follow-through
- Clear feeling that Menhera is energetically moving sideways while still facing front

Motion language target:
- Cheerful, lively, adorable, slightly bratty / cute
- Chibi trot energy
- Slightly coquettish arm rhythm
- Playful but still tidy
- More animated than the current canonical walk
- More animated than the v4 candidate in arms and legs
- NOT chaotic
- NOT exaggerated marching
- NOT side-facing
- NOT dramatic torso twisting
- NOT a full-body bounce caricature

Very important:
- The arms may swing noticeably more than before
- The arms may have a tiny "aegyo / coquettish" flourish, as long as it still reads as a walk
- The legs may alternate more clearly and lift a bit higher
- The character must STILL feel front-facing
- The motion should come from:
  - step rhythm
  - paw swing
  - cute wrist / elbow rhythm
  - alternating arm openness / closeness
  - slightly more pronounced leg lift
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
- Reject if the arms still feel too stiff / too reserved / nearly as static as the canonical walk
- Reject if the extra cuteness comes from redesign instead of motion

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_original_identity_walk_playful_arms_v5.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_walk_playful_arms_v5.jpeg \
        .tmp/menhera_original_identity_walk_playful_arms_v5.png

- Candidate only. It is NOT canonical until it passes QA against the current
  accepted walk and confirms the rest of the set does not need rework.
```
