# Menhera Walk Frontal-Recovery V2 Prompt

Use this after `v1` restored frontal neutrality but still drifted on
identity tokens (two ribbons, wrong nurse cap) and lost too much motion
energy.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is FRONTAL-RECOVERY V2.

V1 result summary:
- PASS: frontal-neutrality recovered; all 8 frames read as forward-facing in stable movement
- FAIL: two-ribbon drift, nurse-cap drift, motion energy weakened too much

Primary objective for V2:
- KEEP the frontal-neutrality success of V1
- RESTORE stronger lively whole-body rhythm
- LOCK the exact required identity tokens with no drift
- Do NOT generate another side-biased walk
- Do NOT generate another two-ribbon / wrong-cap variant

Reference split (STRICTLY SEPARATED):

1. Frontal-neutrality / face symmetry / stable-walk orientation reference:
   .tmp/menhera_boss_sheet_frontal_recovery_v1.png
   Use this ONLY for:
   - both eyes reading symmetrically
   - face reading fully frontal
   - stable movement reading as facing the player
   Do NOT copy V1's ribbon count or nurse-cap drift.

2. Motion-energy reference:
   items/menhera_boss_sheet.png
   Use this ONLY for:
   - stronger leg alternation
   - clearer body bob
   - stronger tail counter-arc / follow-through
   - stronger hem flutter
   - better whole-body rhythm
   Do NOT copy its side-biased head / face read.

3. Canonical acceptance / rollback awareness:
   .tmp/menhera_backup_2026-04-18/menhera_boss_sheet.png
   This remains the safer accepted frontal baseline to beat for final QA.
   V2 must be at least as frontal-readable as this baseline while keeping
   the newer Menhera identity tokens below.

Required identity lock (NON-NEGOTIABLE):
- NO cat ears
- EXACTLY ONE ribbon total
- Ribbon placement: ONE ribbon only, on the character's right side
- Pink hair
- White nurse cap with a pink cross
- Do NOT use a solid pink cap
- Olive eyes
- Black cat-paw gloves with pink toe beans
- Thin black cat tail
- Pink nurse dress with black trim and white front panel
- Pink striped stockings
- Chibi petite-human proportions
- Thick black pixel outlines

Hard identity drift bans:
- NO second ribbon anywhere
- NO ribbon mirrored to both sides
- NO solid pink nurse cap
- NO missing pink cross on the nurse cap
- NO cat ears
- NO gray gloves
- NO older backup facial treatment

What to preserve from V1:
- Full frontal face read
- Symmetric eye exposure
- No left-looking / right-looking bias
- Stable movement still reads as facing the player

What to restore from the rejected lively candidate:
- Stronger pose differentiation across the 8 walk frames
- Clearer body bob and weight shift
- More visible tail counter-arc
- More visible hem / cloth flutter
- Slightly stronger head / hair follow-through
- More energetic walk loop without turning the face or torso sideward

Hard frontal-walk rules:
- This is a FRONT-FACING walk, NOT a hidden 3/4 walk
- Body and face stay mostly front-facing across all 8 frames
- Stable movement must read as "facing the player while moving laterally"
- Moving right must NOT feel like the boss is looking left
- Moving left must NOT feel like the boss is looking right
- Do NOT let hair mass, ribbon placement, eye placement, cheek exposure,
  hat tilt, shoulder angle, or torso angle create a persistent left-looking
  or right-looking bias
- Keep both eyes readable enough that the face still reads frontal at gameplay size
- The head / face should feel direction-neutral during stable walk playback

Walk motion requirements (PingFighter default):
- Express lateral movement through legs, arm swing, body bob, weight shift,
  subtle hip / shoulder counter-sway, hair sway, ribbon motion, cloth flutter,
  and tail motion
- Do NOT freeze the torso while only the limbs cycle
- Do NOT solve energy loss by rotating the head or torso into a 3/4 walk
- Keep the boss feeling lively, buoyant, and cute without sacrificing frontal combat read
- Full side-facing walk is NOT allowed for this pass

Size / composition rules:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character centered in every frame
- Character view remains front-facing in every frame
- Keep foot / baseline position consistent
- Identical design / palette / scale across all frames
- Leave generous empty margin around each sprite
- Each character fills only about 45-55% of each cell's height
- Use this walk as the future body-scale reference only IF it passes QA

Gameplay-scale readability is mandatory from first generation:
- Face, eyes, bangs, mouth, gloves, arms, and silhouette must remain readable
  at small in-game size
- Clear separation between hair, face, arms, torso, gloves, dress, and tail
- Reduce muddy midtones
- Preserve pastel softness, but do NOT solve readability by pushing harsh saturation,
  harsh anime contrast, painterly rendering, or realism

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- Flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

Hard reject conditions:
- Reject if stable movement still reads as consistently looking left or right
- Reject if moving right still feels like the boss is looking left
- Reject if moving left still feels like the boss is looking right
- Reject if ribbon count is anything other than exactly one
- Reject if the nurse cap is not white with a pink cross
- Reject if motion remains noticeably weaker than the rejected lively candidate
- Reject if liveliness improves by sacrificing frontal neutrality
- Reject instead of expecting Codex/runtime to rescue the sheet with flips/remaps

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_boss_sheet_frontal_recovery_v2.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_boss_sheet_frontal_recovery_v2.jpeg \
        .tmp/menhera_boss_sheet_frontal_recovery_v2.png
- Candidate only. It is NOT canonical until it passes frontal-neutrality QA
  and identity-token QA against the previous accepted walk.
```
