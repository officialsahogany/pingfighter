# Menhera Original-Identity Walk Motion Boost V2 Prompt

Use this after the original-identity Menhera set has been accepted and the user
likes the identity / quality / frontal read, but wants the walking motion to
feel cuter and a little more alive in gameplay.

This is a WALK-ONLY refinement pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is ORIGINAL-IDENTITY WALK MOTION BOOST V2.

Current goal:
- Keep the CURRENT accepted Menhera identity exactly as-is
- Keep the CURRENT accepted front-facing gameplay read
- Keep the CURRENT accepted quality / crispness tier
- Increase cute walk liveliness slightly
- Make lateral movement read more clearly through steps, small arm swing,
  and slight hair sway
- Do NOT turn this into a bouncy exaggerated march
- Do NOT turn this into a hidden side-facing walk

Canonical identity / scale / quality anchor:
- items/menhera_boss_sheet.png
- This is the exact character anchor for the pass.
- The result must look like the SAME Menhera, same body class, same quality tier.

Do NOT use older rejected Menhera variants as references.

Identity lock (must remain identical to the current accepted walk):
- Fluffy curly short pink + cream hair mass
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- No cat ears
- Large gray / silver eyes with strong lashes
- Heart cheek mark
- Pink outfit with white front panel
- Four black front bows
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross + bunny-ear motif
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

What to improve specifically:
- Slightly clearer step read between adjacent frames
- Slightly clearer cute arm swing during movement
- Slightly clearer hair sway / ribbon follow-through
- Slightly clearer hem / cloth follow-through
- Slightly clearer sense that the body is actually walking laterally

Motion language target:
- Cute, tidy, composed, front-facing walk
- Not stiff
- Not overly bouncy
- Not exaggerated marching
- Not side-facing
- Not dramatic torso twisting

Very important:
- The arms may swing a little, but the character should still feel front-facing
- The hair may sway a little, but the face must still read clearly and frontally
- The steps should read more clearly, but body scale and baseline should stay stable

Hard frontal rules:
- Stable movement must still read as "facing the player while moving laterally"
- Moving right must NOT feel like she is looking left
- Moving left must NOT feel like she is looking right
- Do NOT use hair asymmetry, head turn, shoulder exposure, cheek exposure,
  or torso turn to fake more motion

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
- Face, eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, gloves,
  bows, med-kit accessory, legwear, and cloth/tail motif must stay readable
  at small in-game size
- Preserve clean separation between hair, face, arms, outfit, accessory,
  and legs
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
- Reject if the walk becomes more side-biased than the current accepted walk
- Reject if moving right feels like she is looking left
- Reject if moving left feels like she is looking right
- Reject if the motion boost comes mainly from torso turn or head turn
- Reject if the result loses the current accepted crispness / readability tier
- Reject if the med-kit accessory, four bows, cloth/tail motif, or glove read degrades

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_original_identity_walk_motion_boost_v2.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_walk_motion_boost_v2.jpeg \
        .tmp/menhera_original_identity_walk_motion_boost_v2.png

- Candidate only. It is NOT canonical until it passes QA against the current
  accepted walk and confirms the rest of the set does not need rework.
```
