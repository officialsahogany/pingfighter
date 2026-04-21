# Menhera Turn Sequence Entry Analysis-Driven V2

Use this after `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png`
has passed QA and is accepted as the current peak turn key-pose reference.

This prompt is designed for Gemini MCP's text-only generation path.

Workflow:
- Analyze `items/menhera_boss_sheet.png` for canonical identity
- Analyze `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png` for
  peak pose / motion cues
- Paste the compact extracted blocks into this template
- Generate the ENTRY strip only

Recommended output:
- `.tmp/menhera_turn_sequence_entry_analysisdriven_v2.jpeg`
- then:
  `py .claude/skills/sprite-generation/remove_bg.py .tmp/menhera_turn_sequence_entry_analysisdriven_v2.jpeg .tmp/menhera_turn_sequence_entry_analysisdriven_v2.png`

---

```text
Generate EXACTLY 4 frames in a single horizontal strip for PingFighter boss
Menheragirl.

Important:
- ENTRY strip only
- NOT the full 8-frame turn sheet
- NOT a side-view angle chart
- NOT a profile rotation sequence
- left-to-right order: frame 1, frame 2, frame 3, frame 4

This strip must lead INTO the accepted peak key pose.

CANONICAL IDENTITY LOCK
[PASTE the compact identity block extracted from items/menhera_boss_sheet.png]

ACCEPTED PEAK POSE LOCK
[PASTE the compact pose block extracted from .tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png]

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
- Frame 1: walk-compatible carry-in, close to neutral frontal movement
- Frame 2: plant/compress, soft weight shift begins
- Frame 3: lifted-chin wind-up, dreamy upward gaze becomes readable, paw starts extending, knee begins lifting
- Frame 4: match the accepted peak pose as closely as possible

Motion rule:
- the strip should feel like a clean build into the accepted peak
- torso/body rhythm must participate
- body bob and weight shift should be visible
- do not freeze the body and only swap the arm

Pose rule:
- overall frontal read toward the player
- one paw extends outward with pink pad visibility
- one knee lifts modestly
- dreamy detached upward gaze
- compact quirky direction-change gesture, not acting for the camera

Hard reject conditions:
- reject if frame 4 drifts away from the accepted peak pose
- reject if the cheek heart disappears or degrades into a blush dot
- reject if the bow count/arrangement drifts away from the walk anchor
- reject if the med-kit moves sides, disappears, or becomes unreadable
- reject if the strip becomes side-facing or profile-like
- reject if it reads like a greeting wave
- reject if it reads like an attack swing
- reject if frames 1-3 do not clearly build into frame 4

Visual format:
- 16-bit retro pixel art
- thick black pixel outlines
- clean hard-edged pixels
- flat limited-saturation palette
- pure white background
- full body visible in every frame
- no text, no labels, no grid, no border
```
