# Teddy Bear Dash -- Gemini Full-Sheet V2 Retake

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

## Why a retake is justified

Dash v1 already landed the hard part:
- real dash motion
- strong f4/f5 speed read
- clear 8-frame burst arc
- stable front-facing read
- stable eye-side identity

So do NOT redesign the action.

This retake is only to fix:
- body scale drift versus walk
- detail-class drift versus walk
- viewer-side ambiguity on safety pin / paw bow
- over-large cream ribbon
- heart occlusion

## Identity truth

Accepted teddy identity reference for QA:
- walk candidate:
  `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png`
- attack candidate:
  `.tmp/teddy_bear_attack_gemini_v2.png`

The walk sheet is the stronger size / detail-class truth.

## Motion truth to preserve

Preserve v1's strengths:
- ready -> crouch -> push-off -> burst -> glide -> decel -> rise -> recovery
- f4/f5 are strongest speed-read frames
- dangling button swings with velocity
- 8 distinct frames

## Retake constraints

Clamp body read to walk:
- dash teddy must occupy the same visible body class as walk
- do not let dash appear bigger in-game

Clamp detail class to walk:
- same outline weight
- same flat shading
- same palette saturation
- same plush rendering level

Viewer-side locks:
- viewer-left eye = red X button always
- viewer-right eye = empty socket + dangling button always
- safety pin always on viewer-left upper chest
- black paw bow always on viewer-right paw

Heart and ribbon:
- heart stays centered and fully visible
- cream ribbon stays modest, not large and billowing

## Output

Save:
- `.tmp/teddy_bear_dash_gemini_v2.jpeg` or `.png`
- `.tmp/teddy_bear_dash_gemini_v2_zoom.png`
- `.tmp/teddy_bear_dash_gemini_v2_report.md`

## QA gates

Report explicitly:

1. Is the teddy still front-facing in every frame?
2. Does the dash avoid side-profile / 3/4 run behavior?
3. Is the v1 burst-slide motion arc still preserved?
4. Are f4/f5 still clearly the strongest speed-read frames?
5. Does the dangling eye survive as socket + hanging button + thread?
6. Do safety pin and black paw bow stay pinned to the same viewer-side in all 8 frames?
7. Does the heart remain fully visible in all 8 frames?
8. Does the body scale now match the walk class?
9. Does the pixel-art detail class now match the walk sheet?

## Decision

End with one of:
- `ACCEPT for runtime-facing candidate`
- `REJECT and stop`

Fast-mode rule:
- this is the one allowed retake after v1 HOLD
- do not start a deeper ladder automatically
