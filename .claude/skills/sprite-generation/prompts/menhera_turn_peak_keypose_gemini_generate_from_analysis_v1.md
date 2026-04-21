# Menhera Turn Peak Key-Pose Gemini Generate From Analysis V1

Use this after running the analysis pass on:
- `items/menhera_boss_sheet.png`
- `.tmp/menhera_turn_peak_keypose_v3.png`

This is still a text-to-image generation pass, but it is driven by dense
reference extraction instead of vague freehand prompting.

Recommended output:
- `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.jpeg`
- then:
  `py .claude/skills/sprite-generation/remove_bg.py .tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.jpeg .tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png`

---

```text
Generate ONE single full-body sprite image for PingFighter boss Menheragirl.

Important:
- ONE image only
- NOT a sprite sheet
- NOT a turn-angle chart
- NOT a side-profile rotation
- This is a single peak direction-change key pose

Use the following identity-lock spec exactly.

CANONICAL IDENTITY LOCK
[PASTE the compact identity block extracted from items/menhera_boss_sheet.png]

PEAK POSE / MOTION LOCK
[PASTE the pose-cue block extracted from .tmp/menhera_turn_peak_keypose_v3.png]

Additional generation rules:
- exact same character as the canonical walk anchor
- same chibi body class
- body scale within about +/-5% of the walk anchor
- preserve gameplay-scale readability of face and accessories
- keep the character overall front-facing toward the player
- dreamy lifted-chin direction-change gesture
- one paw sweeps outward and slightly downward
- one knee lifts modestly
- soft torso weight shift / body bob

Mandatory keep details:
- cheek heart must read as a clear pink outlined heart, not a blush dot
- exactly 4 black bows vertically stacked on the white front panel
- med-kit must stay on the same side as the walk anchor
- med-kit pink cross and bunny-ear hint must remain visible
- gray/silver eyes must stay gray/silver
- hair must stay fluffy and rounded, not flatten into a bob
- cap must stay dome-like, not a flat beret/disc

Hard reject conditions:
- reject if the result reads like a different Menhera
- reject if the heart cheek mark disappears
- reject if the med-kit is mirrored, moved, or removed
- reject if the 4-bow center stack collapses
- reject if eye color drifts away from gray/silver
- reject if the pose reads like a greeting wave
- reject if the pose reads like an attack swing
- reject if the image becomes side-facing / profile-like

Visual format:
- 16-bit retro pixel art
- thick black pixel outlines
- clean hard-edged pixels
- flat limited-saturation palette
- pure white background
- full body fully visible
- centered composition
- no text
- no grid
- no labels
- no border
```

Suggested use:
- Paste the analysis output directly into the two placeholder blocks
- Keep the inserted blocks compact; do not paste the whole analysis essay
- QA against `items/menhera_boss_sheet.png` after nukki
