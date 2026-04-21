# Menhera Turn Peak Key-Pose Kontext V1

Use this when testing a reference-conditioned edit model such as
FLUX.1 Kontext against Menhera's accepted walk anchor.

Goal:
- Prove that a reference-conditioned workflow can hold Menhera's identity
  more reliably than prompt-only Gemini generation.
- Generate ONE single peak turn key-pose image only.
- This is a compact A/B test, not a full sheet pass.

Recommended inputs:

1. Primary identity anchor:
- `items/menhera_boss_sheet.png`
- Use this as the canonical walk reference.

2. Optional pose target / quality reminder:
- `.tmp/menhera_turn_peak_keypose_v3.png`
- Use this only if the tool supports a second reference image and you want
  the pose to stay close to the accepted peak candidate.

Recommended output:
- `.tmp/menhera_turn_peak_keypose_kontext_v1.png`

---

```text
Using the attached reference image(s), generate ONE single full-body pixel-art
sprite of the exact same Menheragirl from PingFighter.

This is not a sprite sheet.
This is not a turn-angle chart.
This is not a side-profile rotation.
Create only ONE peak direction-change key pose.

Identity lock:
- Match the exact character from the walk anchor
- same face, same chibi body class, same head/torso/pelvis scale
- same fluffy pink outer hair mass with cream front bangs
- same gray/silver eyes
- same pink-and-white check nurse cap with red ribbon and syringe
- same pink outfit with white front panel
- exactly 4 black bows stacked vertically on the center white panel
- same gray paw gloves with pink toe beans
- same med-kit accessory with pink cross and small bunny-ear detail
- same pink check cloth-tail
- same white thigh-highs
- same black X ankle marks
- same outlined pink heart mark on the cheek
- thick black pixel outlines

Pose brief:
- front-facing direction-change gesture, still reading toward the player
- slightly lifted chin
- dreamy detached upward gaze, not side-looking
- one paw sweeping outward and slightly downward
- one knee lifted modestly
- soft body bob / weight shift through the torso
- cute, odd, character-specific Menhera habit

Important keep rules:
- keep the character frontal overall
- keep body scale within about +/-5% of the walk anchor
- preserve gameplay-scale readability of face and signature accessories
- keep the med-kit on the same side as the walk anchor
- keep the cheek heart clearly visible as a heart, not a blush dot

Hard reject conditions:
- do not turn this into a profile or 3/4 rotation chart frame
- do not make it read like a greeting wave
- do not make it read like an attack swing
- do not drop the heart cheek mark
- do not collapse the 4-bow center stack
- do not mirror or remove the med-kit
- do not change eye color away from gray/silver
- do not flatten the hair into a bob
- do not replace the nurse cap with a flat beret/disc

Visual format:
- 16-bit retro pixel art
- clean hard-edged pixels
- flat white background
- full body fully visible
- centered composition
- no grid, no labels, no border, no text
```

Suggested use:
- First try with only `items/menhera_boss_sheet.png`
- If the service supports multiple references, add
  `.tmp/menhera_turn_peak_keypose_v3.png` as a pose reminder
- QA the result against the walk anchor before attempting entry/recovery strips
