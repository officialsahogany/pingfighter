# Menhera Walk Frontal-Recovery Prompt

Use this when the current Menhera walk candidate is more lively but fails
front-facing gameplay read and must be regenerated without promoting the
bad candidate to canonical.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is a FRONTAL-RECOVERY pass. The current walk candidate improved motion
energy but failed frontal-neutrality QA in gameplay: it reads as persistently
looking left / side-biased during stable movement. That is a hard fail.

Primary objective:
- Recover a truly forward-facing stable walk read
- Preserve lively whole-body motion
- Preserve the intended newer Menhera identity details
- Do NOT promote another side-biased candidate

Reference split (VERY IMPORTANT):
- Frontal-read / stable-walk reference:
  .tmp/menhera_backup_2026-04-18/menhera_boss_sheet.png
  Use this ONLY as the reference for how front-facing / neutral the boss should
  read during stable left/right movement.
- Identity / design-token reference:
  items/menhera_boss_sheet.png
  Use this ONLY for the intended newer Menhera identity tokens listed below.
  Do NOT copy its side-biased head / face read.

Identity lock for the desired newer Menhera version (must keep these):
- NO cat ears
- Exactly ONE ribbon
- Pink hair
- Pink nurse cap
- Olive eyes
- Black cat-paw gloves
- Thin black cat tail
- Pink nurse dress with black trim
- Pink striped stockings
- Chibi petite-human proportions
- Thick black pixel outlines

Do NOT regress to the older backup identity:
- Do NOT restore black cat ears
- Do NOT restore gray gloves
- Do NOT restore the older softer / paler face treatment
- Do NOT use the backup as the identity source; use it only for frontal walk read

Motion qualities to preserve from the rejected lively candidate:
- Clear leg alternation
- Whole-body body bob
- Tail counter-arc / tail follow-through
- Small head sway
- Hem / cloth flutter
- Soft buoyant chibi rebound

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
- Reject if the stable walk still reads as consistently looking left or right
- Reject if moving right still feels like the boss is looking left
- Reject if moving left still feels like the boss is looking right
- Reject if the face reads more side-facing than the backup frontal reference
- Reject if liveliness improved but frontal neutrality regressed
- Reject instead of expecting Codex/runtime to rescue the sheet with flips/remaps

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_boss_sheet_frontal_recovery_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_boss_sheet_frontal_recovery_v1.jpeg \
        .tmp/menhera_boss_sheet_frontal_recovery_v1.png
- Candidate only. It is NOT canonical until it passes frontal-neutrality QA
  against the previous accepted walk.
```
