# Menhera Turn Sequence Entry Framewise V1

Use this after `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png`
has passed QA, but the 4-frame horizontal entry strip failed due to identity
drift, mirrored pose direction, and detail loss.

This workflow abandons multi-frame strip generation for the entry half.

Recommended decision:
- Generate frames 1, 2, and 3 as separate SINGLE-IMAGE square outputs
- Reuse the accepted peak key pose directly as frame 4
- Stitch the four frames offline after QA

Why this workflow:
- The accepted peak pose succeeded as a single-image 1:1 generation
- The horizontal strip failed on identity lock and left/right pose lock
- Reusing the already-accepted peak avoids unnecessary redraw drift

Outputs:
- `.tmp/menhera_turn_entry_f1_analysisdriven_v1.jpeg/.png`
- `.tmp/menhera_turn_entry_f2_analysisdriven_v1.jpeg/.png`
- `.tmp/menhera_turn_entry_f3_analysisdriven_v1.jpeg/.png`
- Frame 4 = reuse `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png`

Before generating:
- Analyze `items/menhera_boss_sheet.png` for canonical identity
- Analyze `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png` for
  accepted peak-pose side assignment and motion cues
- Paste the compact blocks into the prompts below

---

## Shared Rules For Frames 1-3

```text
Generate ONE single full-body sprite image for PingFighter boss Menheragirl.

Important:
- ONE image only
- square composition only
- generous white margin
- NOT a sprite sheet
- NOT a multi-frame strip
- NOT a side-view rotation
- overall frontal read toward the player

CANONICAL IDENTITY LOCK
[PASTE the compact identity block extracted from items/menhera_boss_sheet.png]

ACCEPTED PEAK POSE LOCK
[PASTE the compact pose / side-assignment block extracted from .tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png]

Non-negotiable identity keep rules:
- exact same Menhera as the canonical walk anchor
- same chibi body class and gameplay-scale read
- same concentric hair read: pink outer mass with cream/blonde inner front bangs
- same gray/silver eyes
- same outlined pink heart cheek mark on viewer's right cheek
- same gingham nurse cap with red cross detail and side syringe
- same dark gray paw gloves with visible pink pads
- same white center panel with the walk-anchor bow count and arrangement
- same med-kit on viewer's right side
- same pink/white check cloth-tail near the med-kit
- same white thigh-highs, ankle X marks, and black shoes

Non-negotiable side / orientation lock:
- preserve the SAME left/right assignment as the accepted peak pose
- do NOT mirror the gesture
- the outward-extending paw must build toward the SAME side used by the accepted peak pose
- the lifted-leg side must remain consistent with the accepted peak pose
- the med-kit must stay on the same side as the walk anchor and the accepted peak pose

Hard reject conditions:
- reject if hair drifts away from concentric pink outer + cream/blonde inner front bangs
- reject if eye color drifts away from gray/silver
- reject if the heart cheek mark disappears or becomes a blush dot
- reject if the bow count/arrangement drifts from the walk anchor
- reject if the ankle X marks disappear
- reject if the pose is mirrored relative to the accepted peak pose
- reject if the image reads like a greeting wave
- reject if the image reads like an attack swing
- reject if the character becomes side-facing or profile-like

Visual format:
- 16-bit retro pixel art
- thick black pixel outlines
- clean hard-edged pixels
- flat limited-saturation palette
- pure white background
- full body fully visible
- no text, no labels, no border, no grid
```

---

## Frame 1 Prompt

Output target:
- `.tmp/menhera_turn_entry_f1_analysisdriven_v1.jpeg`

```text
Generate FRAME 1 of Menhera's entry turn gesture.

Motion brief:
- walk-compatible carry-in
- still close to neutral frontal movement
- only a slight readiness / asymmetry begins
- the future gesture side should be hinted, but not fully committed yet
- keep the pose compact and readable
- this must feel like the start of a build toward the accepted peak pose

Do not:
- lift the knee too early or too high
- fully extend the paw yet
- flatten the character into a static idle
```

---

## Frame 2 Prompt

Output target:
- `.tmp/menhera_turn_entry_f2_analysisdriven_v1.jpeg`

```text
Generate FRAME 2 of Menhera's entry turn gesture.

Motion brief:
- visible plant / compress
- body weight shift becomes readable
- torso bob participates
- the correct-side paw begins a modest outward preparation
- the correct-side knee starts to gather upward, but not at peak yet
- this frame should feel like a clear middle build between frame 1 and frame 3

Do not:
- mirror the pose relative to the accepted peak
- jump all the way to the peak pose
- keep the torso frozen while only changing the arm
```

---

## Frame 3 Prompt

Output target:
- `.tmp/menhera_turn_entry_f3_analysisdriven_v1.jpeg`

```text
Generate FRAME 3 of Menhera's entry turn gesture.

Motion brief:
- lifted-chin wind-up just before the accepted peak
- dreamy upward gaze becomes clearly readable
- the correct-side paw is now strongly preparing the outward sweep
- the correct-side knee is visibly lifted but still slightly below the accepted peak
- torso/body rhythm clearly supports the motion
- this must read as the immediate predecessor to the accepted peak pose

Do not:
- copy the accepted peak exactly
- mirror the pose direction
- turn it into a greeting wave or attack swing
```

---

## Stitching Rule

After QA passes:
- frame 1 = `.tmp/menhera_turn_entry_f1_analysisdriven_v1.png`
- frame 2 = `.tmp/menhera_turn_entry_f2_analysisdriven_v1.png`
- frame 3 = `.tmp/menhera_turn_entry_f3_analysisdriven_v1.png`
- frame 4 = `.tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png`

Then stitch them left-to-right into the final entry strip candidate.
