# Smasher Attack Realign Handoff

Use this when rebuilding the Godot Smasher attack sheet after the accepted
left/right walking sheets are already present. This is an asset-generation
handoff for Claude / Gemini, not a runtime workaround request.

The current port has a serious cross-sheet identity mismatch:

- The accepted left/right walk sheets show one Smasher design.
- The current attack sheet reads like a different character: different
  equipment side layout, larger pale helmet read, different armor/body
  proportions, and a different hoverboard/prop feel.
- Do not solve this by changing Godot draw sizes or hiding the mismatch in
  runtime. Regenerate the attack sheet so it truly matches the walk sheets.

## Canonical Runtime References

Primary visual references:

- `godot/assets/sprites/smasher_subculture_left_walk_sheet.png`
- `godot/assets/sprites/smasher_subculture_right_walk_sheet.png`

Python mirror references, when useful:

- `items/smasher_subculture_left_walk_sheet.png`
- `items/smasher_subculture_right_walk_sheet.png`

Current attack sheet path:

- `godot/assets/sprites/smasher/smasher_attack_sheet.png`

Use the current attack sheet only for rough motion intent and runtime grid
contract. Do not use it as the identity/style reference.

## Non-Negotiable Identity Lock

The new attack sheet must look like the exact same Smasher from the accepted
left/right walk sheets:

- Rear-view chibi armored hoverboard rider.
- Dark navy / cobalt armor, black pixel outline, compact torso, small boots.
- Rounded dark-blue helmet with the same vertical highlight/stripe structure
  and the same visible head size as the walk sheets.
- Cyan shield / hex module belongs on viewer-left in the neutral rear-view
  read, matching the accepted walk sheets.
- Pink paddle / racket belongs on viewer-right in the neutral rear-view read,
  matching the accepted walk sheets. During the swing it may cross the body,
  but ready and recovery must return to the accepted side layout.
- Slim cyan hoverboard / board-ring language must match the walk sheets.
- Same palette balance as the walk sheets: dark armor plus cyan accents plus
  pink paddle. Do not drift into a giant pale helmet, lighter mascot body, or
  old attack-sheet proportions.

Reject immediately if a candidate looks like a different Smasher even before
runtime scaling.

## Runtime Sheet Contract

Final ship asset:

- Path: `godot/assets/sprites/smasher/smasher_attack_sheet.png`
- Sheet size: `1376x768`
- Grid: `4 columns x 2 rows`
- Cell size: `344x384`
- Frame count: `8`
- Transparent PNG with clean alpha.
- No baked cream/white/black background in final PNG.
- Corners must be transparent.

The Godot runtime currently reads this sheet through:

- `godot/scripts/resources/battle_resources.gd`
- `godot/scripts/stages/stage1/stage1_player_sprite_renderer.gd`
- `godot/scripts/stages/stage1/stage1_player_actor_renderer.gd`

The actor renderer currently draws the attack at a normalized default size of
`128x143`. This scale exists to keep the old 344x384 cell from becoming huge;
it is not permission for the art to have a different identity. The visible
body read must still match the walk sheets at gameplay scale.

If a generated source starts as `16:9` / `2K`, postprocess it into the exact
runtime contract above before promotion. Do not leave the runtime expecting
344x384 cells while shipping a differently sized grid unless the code change
is deliberate and documented.

## Motion Direction

Keep the motion as a rear-view Smasher smash, not a front-facing showcase and
not a profile turn:

- Frame 1: ready stance, matches accepted walk identity and equipment sides.
- Frame 2: compact wind-up.
- Frame 3: shoulder/torso coil, paddle begins crossing body.
- Frame 4: max charge, readable tension.
- Frame 5: swing release.
- Frame 6: impact frame, strongest paddle motion, clear contact energy.
- Frame 7: follow-through, body still same scale/read as walk.
- Frame 8: recovery, returns toward accepted rear-view walk stance.

Effects may extend outward, but they must not shrink, cover, or redesign the
helmet, torso, paddle, cyan shield, or hoverboard.

## Prompt Payload

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
Godot Smasher attack sheet so it matches the accepted Smasher left/right walk
sheets exactly.

This is a cross-sheet realignment pass. The current attack sheet is rejected as
an identity mismatch. Use it only for the rough rear-view smash motion idea and
the 8-frame 4x2 runtime contract. Do NOT copy its character design.

Canonical visual references:
- godot/assets/sprites/smasher_subculture_left_walk_sheet.png
- godot/assets/sprites/smasher_subculture_right_walk_sheet.png

Goal:
- Create a new rear-view Smasher attack sheet that looks like the exact same
  character as the accepted walk sheets.
- Preserve the accepted walk-sheet palette, helmet shape, armor proportions,
  equipment side layout, hoverboard language, and small gameplay-scale read.
- Prioritize same-character continuity over dramatic attack posing.

Fixed design elements that must match the walk sheets:
- Rear-view chibi armored hoverboard rider.
- Dark navy / cobalt armor with black pixel outlines.
- Rounded dark-blue helmet with the same vertical highlight/stripe structure.
- Compact torso and small boots, same body scale as the walk sheets.
- Cyan shield / hex module on viewer-left in ready/recovery.
- Pink paddle / racket on viewer-right in ready/recovery.
- Slim cyan hoverboard / board-ring language matching the walk sheets.

Strict rejection rules:
- Reject if the helmet becomes a giant pale dome like the current bad attack
  sheet.
- Reject if the paddle and cyan shield permanently swap sides compared to the
  accepted walk sheets.
- Reject if the armor, torso, hoverboard, face/head read, or outline style
  looks like a different character.
- Reject if the body reads larger or smaller than the accepted walk sheets at
  gameplay scale, even if the cell size is technically correct.

Sheet composition:
- 8-frame attack sheet, 4x2 grid.
- Final runtime PNG must be 1376x768 with 344x384 cells.
- row1: ready, wind-up, torso/shoulder coil, max charge.
- row2: swing release, impact, follow-through, recovery.
- Transparent final PNG with clean alpha.
- No grid lines, borders, dividers, labels, or baked background.
- Keep the foot/hoverboard baseline stable across frames.
- Keep generous cell margins so no paddle, shield, glow, or board trail touches
  cell edges.

Motion:
- Rear-view smash motion, not a front-facing or profile redraw.
- The pink paddle may cross the body during the swing, but ready and recovery
  must return to viewer-right.
- The cyan shield/hex module may react slightly, but it must remain identifiable
  and tied to the accepted walk-sheet side/read.
- Impact frame should clearly show contact force without covering the body or
  making the Smasher read as a new design.

Style:
- Clean retro pixel art, chibi proportions, thick black pixel outlines,
  hard-edged pixels, limited saturated accents.
- Match the accepted walk sheets' color temperature and contrast.
- NO painterly rendering, NO photorealism, NO soft anime illustration, NO
  redesign.

Output:
- Produce a source candidate, remove background / clean alpha if needed, then
  restitch/export the final runtime PNG:
    godot/assets/sprites/smasher/smasher_attack_sheet.png
- If a source JPEG/PNG is kept, place it near the working candidate or under
  `.tmp/`, but the final runtime PNG above is the required deliverable.
- Do not modify runtime code unless the final grid contract intentionally
  changes, which should be avoided for this pass.
```

## QA Before Acceptance

Claude must do these checks before calling the asset ready:

1. Compare `left walk`, `right walk`, `attack ready`, `attack impact`, and
   `attack recovery` at gameplay draw size.
2. Confirm the new attack sheet keeps the same visible body read: head height,
   helmet shape, torso width, armor silhouette, hoverboard width, cyan shield,
   and pink paddle.
3. Confirm the ready/recovery equipment side layout matches the accepted walk
   sheets: cyan module viewer-left, pink paddle viewer-right.
4. Confirm transparent corners and no opaque cell background.
5. Confirm alpha bbox does not touch cell edges in any frame.
6. Confirm Godot headless load after replacing the asset:
   `Godot_v4.6.2-stable_win64_console.exe --headless --path <project> --quit`
7. If the live Godot project is used, sync the final PNG into
   `C:\Users\woduq\Documents\pingfighter\assets\sprites\smasher\` and verify
   the mirror/live file hashes match.

End of handoff.
