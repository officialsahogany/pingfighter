# Menhera Turn Sequence Recovery Analysis-Driven V1

Use this after the accepted peak key pose and, ideally, the entry strip have
passed QA. This generates only the recovery half of the gesture.

This prompt is designed for Gemini MCP's text-only generation path.

Workflow:
- Analyze `items/menhera_boss_sheet.png` for canonical identity
- Analyze `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png` for
  peak pose / motion cues
- If the entry strip passed, optionally also analyze
  `.tmp/menhera_turn_sequence_entry_analysisdriven_v2.png` for transition
  continuity
- Paste the compact extracted blocks into this template
- Generate the RECOVERY strip only

Recommended output:
- `.tmp/menhera_turn_sequence_recovery_analysisdriven_v1.jpeg`
- then:
  `py .claude/skills/sprite-generation/remove_bg.py .tmp/menhera_turn_sequence_recovery_analysisdriven_v1.jpeg .tmp/menhera_turn_sequence_recovery_analysisdriven_v1.png`

---

```text
Generate EXACTLY 4 frames in a single horizontal strip for PingFighter boss
Menheragirl.

Important:
- RECOVERY strip only
- NOT the full 8-frame turn sheet
- NOT a side-view angle chart
- NOT a profile rotation sequence
- left-to-right order: frame 5, frame 6, frame 7, frame 8

This strip must recover FROM the accepted peak key pose back into walk-ready
frontal movement.

CANONICAL IDENTITY LOCK
[PASTE the compact identity block extracted from items/menhera_boss_sheet.png]

ACCEPTED PEAK POSE LOCK
[PASTE the compact pose block extracted from .tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png]

OPTIONAL ENTRY CONTINUITY NOTES
[PASTE only brief continuity notes from the approved entry strip if available]

Non-negotiable keep details:
- exact same Menhera as the canonical walk anchor
- same chibi body class and same gameplay-size read
- same concentric hair read: pink outer mass with cream/blonde inner front bangs
- same outlined pink heart cheek mark on viewer's right cheek
- same gingham nurse cap with red cross detail and side syringe
- same dark gray paw gloves with visible pink pads
- same white center panel with the walk-anchor bow count and stacked arrangement
- same med-kit on viewer's right side
- same pink/white check cloth-tail near the med-kit
- same white thigh-highs, ankle X marks, and black shoes

Frame plan:
- Frame 5: immediate follow-through from the accepted peak pose
- Frame 6: release/rebound, lifted knee lowers, arm continues its arc
- Frame 7: settle toward neutral, torso/body bob resolves
- Frame 8: walk-ready frontal recovery, slight residual charm allowed but no lingering peak exaggeration

Motion rule:
- this must feel like a real recovery arc, not a mirrored replay of the entry strip
- the energy should dissipate cleanly from frame 5 to frame 8
- torso/body rhythm must remain visible through the settle
- hair, cap ribbon, cloth-tail, and med-kit can show small follow-through

Pose rule:
- preserve frontal read toward the player
- keep the gesture compact and character-specific
- dreamy gaze can soften back toward neutral by frames 7-8
- do not snap back abruptly in one frame

Hard reject conditions:
- reject if frame 5 does not feel like a continuation of the accepted peak pose
- reject if frames 5-8 mirror the entry strip instead of recovering from it
- reject if the cheek heart disappears or degrades into a blush dot
- reject if the bow count/arrangement drifts away from the walk anchor
- reject if the med-kit moves sides, disappears, or becomes unreadable
- reject if the strip becomes side-facing or profile-like
- reject if it reads like a greeting wave
- reject if it reads like an attack swing
- reject if frame 8 is not believable as a return to normal frontal walk language

Visual format:
- 16-bit retro pixel art
- thick black pixel outlines
- clean hard-edged pixels
- flat limited-saturation palette
- pure white background
- full body visible in every frame
- no text, no labels, no grid, no border
```
