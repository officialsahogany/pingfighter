# Menhera Original-Identity Turn Dreamy Lifted Gaze V2 Prompt

Use this when Menhera's turn sheet should connect more naturally with the
current playful frontal walk, with a slightly lifted head and middle-distance
gaze so left/right transitions feel gentler and more coherent.

This is a TURN-ONLY auxiliary support pass.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
turn sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is ORIGINAL-IDENTITY TURN DREAMY LIFTED GAZE V2.

Important:
- Turn is an AUXILIARY facing-transition sheet only.
- Turn is NOT a replacement for the main walk cycle.
- The goal is to make brief left/right transitions feel naturally connected to
  the CURRENT canonical playful walk.

Current situation:
- The current canonical walk is now more playful and lively in the limbs.
- The user wants turn to feel connected to that walk, instead of feeling like a
  separate harsher or flatter pose set.
- The turn should feel slightly more natural, with:
  - a slightly lifted head
  - a looking-farther / middle-distance gaze
  - a mild dreamy / aloof / detached feeling
  - smooth connection to the current walk's playful energy

Reference split:

1. Identity / body / scale / mood master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- Turn must look like the EXACT SAME Menhera as this walk sheet.
- Turn must inherit the same overall emotional tone / body class / playful softness.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.

3. Broad angle-coverage intent only:
- items/menhera_boss_turn.png
- Use ONLY if useful for broad angle coverage and 13-frame composition intent.
- Do NOT preserve any older mismatch if it conflicts with the current walk anchor.

Goal:
- Keep the exact canonical Menhera identity from the current walk anchor
- Match or exceed the current victory sheet's quality tier
- Provide brief turn-transition support only
- Make turn feel emotionally and rhythmically connected to the current walk
- Keep the same character read across angles

Exact identity lock (must match the canonical walk exactly):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy hair silhouette matching the walk anchor
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Exactly ONE heart cheek mark on one cheek only
- Pink outfit with white front panel
- Four black front bows
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross + bunny-ear motif
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Turn sheet layout:
- Preferred: 13-frame turn sheet, 7x2 grid, last cell blank, aspectRatio 16:9, imageSize 2K
- row1: +90, +75, +60, +45, +30, +15, 0
- row2: -15, -30, -45, -60, -75, -90, blank
- Pure flat white background (#FFFFFF)
- NO grid lines, NO borders, NO dividers, NO labels
- Body scale within +/-5% of the walk anchor

Turn direction and emotional connection:
- This is for BRIEF left/right facing transitions only
- The sheet must feel like the same character stepping out of the current walk,
  not like a separate dramatic pose sheet
- Keep a gentle connection to the current walk's playful energy:
  subtle ribbon motion, subtle hem / cloth follow-through, mild paw / arm rhythm
- Do NOT make turn stiff or statue-like
- Do NOT make turn aggressive or side-profile heavy unless the angle truly requires it

Head / gaze direction:
- Keep the head slightly lifted compared with a neutral straight-ahead stare
- The gaze should feel like she is looking a little farther into the middle distance
- This should read as mildly dreamy / aloof / detached
- Do NOT over-tilt upward
- Do NOT make the eyes read like she is sharply looking sideways
- Even when the body turns, the face should keep Menhera's soft detached mood

Angle behavior:
- Smooth 15-degree interpolation between neighboring frames
- Each angle must be a fresh redraw, not a filtered rotation
- Preserve face scale, hair mass, cap, ribbon, syringe, med-kit, and cloth-tail consistency
- Mid-angles must NOT collapse into fake frontal copies
- Mid-angles must also NOT become a different sharper / meaner / more profile-heavy character

Gameplay-scale readability is mandatory:
- Eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, gloves, bows,
  med-kit accessory, legwear, and cloth/tail motif must stay readable at
  in-game size when the angle allows it
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

Fallback rule:
- If the model collapses the 3/4 angles, use the skill's strip fallback ladder
  rather than brute-forcing the same failed full sheet repeatedly
- A documented usable subset is acceptable only if the full set repeatedly fails

Hard reject conditions:
- Reject if the result looks like a different Menhera from the current walk anchor
- Reject if the sheet feels disconnected in mood from the current walk
- Reject if the dreamy / lifted-head connection is lost and the turn feels flat or harsh
- Reject if mid-angles collapse into fake frontal copies
- Reject if the sheet becomes too side-profile heavy to connect naturally with the walk
- Reject if the gaze becomes sharp side-looking instead of slightly lifted / middle-distance
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png
- Reject if body scale drifts or face scale pops between adjacent angles

Output safety rule:
- Do NOT overwrite items/menhera_boss_turn.png yet
- First generate:
    .tmp/menhera_original_identity_turn_dreamy_lifted_gaze_v2.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_turn_dreamy_lifted_gaze_v2.jpeg \
        .tmp/menhera_original_identity_turn_dreamy_lifted_gaze_v2.png
- Candidate only. Not canonical until QA passes against the current walk anchor.
```
