# Menhera Turn Peak Key-Pose Gemini Analysis V1

Use this when Gemini MCP cannot accept reference images for generation and we
need to convert the accepted Menhera references into a dense text identity spec
first.

Run this with `gemini-analyze-image`, not the generation tool.

Recommended analysis order:

1. Analyze `items/menhera_boss_sheet.png`
2. Analyze `.tmp/menhera_turn_peak_keypose_v3.png`

Use the strongest available analysis model / detail level.

Goal:
- Extract a strict text description of Menhera's canonical identity from the
  walk anchor.
- Extract the accepted peak-pose motion cues from peak key-pose V3.
- Produce copy-paste-ready blocks for a later text-to-image prompt.

---

```text
Analyze this image as a production reference for a retro pixel-art game sprite.

I do NOT want a general description.
I want a strict identity-lock extraction that can be pasted into a later
text-to-image prompt with minimal ambiguity.

Output requirements:
- Be concrete, not poetic
- Prefer short bullet points
- If a detail is uncertain, mark it as uncertain instead of inventing
- Include left/right orientation using BOTH:
  - character's left/right
  - viewer's left/right
- When possible, estimate approximate color families or relative placement
- Focus on gameplay-scale readable identity details

Return the result in exactly these sections:

1. OVERALL BODY CLASS
- chibi proportion notes
- head/body ratio
- silhouette width/height impression
- frontal vs side-facing read

2. HAIR IDENTITY
- overall silhouette shape
- outer mass color vs inner/front bang color placement
- curl / clump structure
- left/right asymmetry if any
- what would count as identity drift

3. FACE IDENTITY
- eye color and eye shape
- lash read
- cheek mark side, shape, approximate size, and exact read
- mouth / expression baseline
- what would count as identity drift

4. HAT / HEAD ACCESSORIES
- cap silhouette
- check pattern read
- ribbon placement
- syringe placement
- what would count as identity drift

5. TORSO / OUTFIT IDENTITY
- outfit colors
- white front panel layout
- exact bow count and arrangement
- glove type and paw-pad detail
- what would count as identity drift

6. SIDE ACCESSORIES
- med-kit side placement
- pink cross visibility
- bunny-ear detail
- cloth-tail placement and pattern
- what would count as identity drift

7. LEG / FOOT IDENTITY
- thigh-high read
- ankle X mark placement and visibility
- shoe silhouette if readable

8. NON-NEGOTIABLE IDENTITY LOCK
- list only the details that MUST survive generation
- keep this section compact and copy-paste ready

9. IF THIS IMAGE IS A POSE REFERENCE
- describe only the pose/motion cues
- chin tilt
- pupil/gaze direction
- arm gesture
- knee lift
- torso weight shift / bob
- what must not be changed when reusing the pose

Important:
- Do not rewrite this into a story
- Do not praise the image
- Do not summarize loosely
- Treat this as asset-spec extraction for a game pipeline
```

Suggested workflow:
- Run once on `items/menhera_boss_sheet.png` for canonical identity
- Run once on `.tmp/menhera_turn_peak_keypose_v3.png` for peak-pose cues
- Paste the two extracted blocks into
  `menhera_turn_peak_keypose_gemini_generate_from_analysis_v1.md`
