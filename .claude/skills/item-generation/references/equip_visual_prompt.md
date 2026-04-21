# Character Equip Visual — Copy-Paste Prompt

For passive items that visually attach to the player character when
equipped (e.g. chargebag on the back, technical_vest on the torso,
bulletproof_hat on the head, bulkup on the arms).

Replace `[ITEM_NAME]`, `[CONCEPT]`, `[ATTACH_POINT]`, `[POSE_NOTE]`
before sending to Gemini MCP. See `SKILL.md` §7 for the rules behind
this prompt.

```
Pixel art character equip visual for "[ITEM_NAME]" — [CONCEPT].
This is NOT an inventory icon. This is an OVERLAY that renders ON
the player character skin at the [ATTACH_POINT] attach point.

Canvas: match the attach-point tile size used by
entities/body_parts/item_parts_registry.py (pose-locked, not a
standalone portrait).

Pose and rig:
- [POSE_NOTE] — draw the asset in the pose it will composite in.
- Match the player paddle / character outline weight and palette.
- No full character silhouette — ONLY the equip piece and whatever
  small body-part context it needs to align correctly.

Style:
- 16-bit retro pixel art, flat limited-saturation palette
- 1–2 px thick black pixel outline, consistent with the player skin
- NO painterly rendering, NO soft shading, NO photoreal product shot

HUD-scale readability: at in-game scale the equip piece should be
visibly "on" the character, not a floating silhouette. Keep any
straps, glow, or trim clearly attached to the body.
```

## Attach-point values

These map to the `apply_item_to_skin()` hook in
`entities/body_parts/item_parts_registry.py`. Use one of these as
`[ATTACH_POINT]`:

| Attach point | Example items |
|---|---|
| head top | bulletproof_hat, spiked_helmet |
| head front | dowsing_goggles, yachaman_soul |
| torso front | technical_vest, bulkup, adversity_armor, shrapnel_armor |
| arms | commando_arm, smartphone, gold_digger, venom_mist_gauntlet |
| waist / belt | gravitybelt, speedgear, sensor |
| knees | knee_pads, dashgear, soul_burst |
| feet | speedboots, spikeboots |
| back | slot_add, chargebag, dowsing_pendulum, battery |
| accessory | star_detector, fuel_pouch, bluetooth_ring, foul_whistle, dashholder, cooltime, revival, gold_bar, lucky_coin, sage_ring |

## Pose notes to reuse

- `[POSE_NOTE]` examples for common attach points:
  - **head top** — flat top-down view of the helmet / hat, slight
    3/4 to hint the brim.
  - **torso front** — front-facing vest / armor plate, no arms.
  - **arms** — single forearm + hand in neutral paddle grip, outer
    side visible.
  - **back** — rear view of the pack / cape, straps visible.
  - **feet** — pair of boots in neutral stance, outline only.

## Runtime wiring

This skill only owns the asset. The actual overlay hook lives in
`entities/body_parts/item_parts_registry.py` and is called from
`pingfighter.py`'s `store_passive_item()` branch for the item.
Wiring the new attach point is a runtime step —
`docs/item_runtime_checklist.md` §equip-visual covers it.

## Output

Follow whatever existing equip-visual asset the registry uses on
disk. Common paths:
- `items/[item_name]_equip.png`
- `entities/body_parts/[item_name].png`

Match the scheme used by an existing registered item (chargebag /
technical_vest / commando_arm) rather than inventing a new path.
