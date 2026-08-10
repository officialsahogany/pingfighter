# Walk Sheet Prompt Template — Separate L/R Pair (current convention)

The walk-sheet deliverable is now a **separate left-walk sheet + separate
right-walk sheet pair**, drawn natively per direction (no runtime mirror
flip). See SKILL.md §13.1 for the convention rationale and
`checklists.md` §4.5 for the pair acceptance gate.

Workflow:

1. Generate the FIRST direction sheet using Template A below.
2. Run nukki on the first sheet.
3. Run §1 identity, §2 scale, §3 palette, §4 (front-biased gate if
   applicable), §8 composition, §9 nukki checks on the first sheet.
4. Reject and regenerate until the first sheet passes.
5. Generate the SECOND direction sheet using Template B below — copy
   Template A verbatim and ONLY edit:
   - facing direction wording (LEFT vs RIGHT)
   - per-prop anatomical-side wording (which body side each direction-
     asymmetric prop sits on, since the camera now sees the opposite
     side of the character)
   - sash / ribbon / hair trail direction (always opposite the motion
     direction)
6. Run the same §1-§9 checks on the second sheet, then run §4.5
   separate-L/R-pair gate on the pair.
7. If only the second sheet drifts, regenerate the second sheet using
   the first sheet's accepted prompt family. Do NOT rebuild both
   prompts from scratch unless both fail.

Stage mapping reminder: Godot `current_stage == 5` is current Stage 5
Hongryun/Honglyeon; Godot `current_stage == 6` is current Stage 6 Tetriser,
ported from legacy Python Stage 7. Python Stage 6 Nemesis is excluded.

Replace `[name]`, `[boss name]`, `[real stage number]`,
`[code stage number]`, and the per-boss blocks in brackets.

---

## Template A — first direction (default: RIGHT, since most reference
## anchors are right-facing)

```
Per d:\main\bosspong\AGENTS.md and the sprite-generation skill, generate
the RIGHT-walking sprite sheet for real-stage [real stage number] boss
[boss name] (code current_stage == [code stage number]). This is the
RIGHT half of a separate L/R walk pair.

Goal:
- [character description]
- [item in hand / atmosphere / expression]
- Prioritize [desired impression] over cuteness
- If a previous accepted walk sheet exists, treat it as the rollback
  reference until the new pair passes QA
- The new walk is NOT allowed to become more side-facing than the last
  accepted walk just because it is livelier or more polished

Fixed design elements (must not drift in later sheets, must match the
companion LEFT-walk sheet exactly):
- [outfit]
- [hair color and style — explicit; e.g. "compact bun, NO long hair
  falling down the back, NO ponytail"]
- [eye color and shape — explicit; e.g. "large round dark brown chibi
  eyes"]
- [signature props / effects — name each one and its anatomical body
  side; e.g. "red hibiscus flower pinned to her RIGHT side of head",
  "buk drum carried at her LEFT hip"]
- Thick black pixel outline

Anatomical side mapping for THIS sheet (RIGHT-walking, character faces
viewer-RIGHT):
- Props on her RIGHT body side appear on the VIEWER-LEFT side of the
  figure. (Example: red flower on her right side of head -> viewer-LEFT
  of head in this sheet.)
- Props on her LEFT body side appear on the VIEWER-RIGHT side of the
  figure. (Example: drum on her left hip -> viewer-RIGHT in this sheet.)
- Sash / ribbon / hair / cloth trails go OPPOSITE motion direction:
  toward VIEWER-LEFT.

Size / composition rules:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 1K for
  fast-mode taste check or 2K for precise-mode promotion (read
  sprite-generation `SKILL.md` §10.1 / §10.2 first; 2K hits the chat-history limit on the
  next request, so prefer 1K when iterating in the same session)
- Pure flat white background (#FFFFFF) in every cell
- ABSOLUTELY NO grid lines, NO borders, NO dividers, NO labels, NO
  numbering between cells
- Each cell exactly equal size, character centered
- Generous transparent margin around each figure
- Each character fills only about 50-55% of cell height
- Identical character design / palette / scale across all 8 frames

Walk facing (off-frontal-RIGHT for this sheet):
- ALL 8 cells face slightly off-front toward VIEWER'S RIGHT, NOT strict
  frontal, NOT full side profile
- RIGHT shoulder slightly forward (closer to camera), LEFT shoulder
  slightly back
- Reads as walking TOWARD VIEWER'S RIGHT while still showing most of
  her front to the camera
- Do NOT draw any left-facing frames anywhere on this sheet; the LEFT
  direction lives in the companion LEFT-walk sheet, NOT here

8-frame RIGHT-walk cycle (each frame is a clearly different walk
phase — NOT limb-wiggle-only — show real body bob, weight shift, hip
and shoulder counter-sway, hair drift, ribbon trail, sash flutter):
- F1 (top-left): RIGHT-FOOT CONTACT — right foot planted forward, body
  weight on right foot, body at LOWEST height
- F2: RIGHT-FOOT PUSH-OFF — right heel lifting, left knee starting to
  rise, body beginning to RISE
- F3: PASSING POSE with LEFT KNEE HIGH — body at HIGHEST point
- F4: LEFT-FOOT REACHING FORWARD — left leg extending forward (toward
  viewer-right) about to land
- F5: LEFT-FOOT CONTACT — body at LOWEST height again
- F6: LEFT-FOOT PUSH-OFF — body RISING
- F7: PASSING POSE with RIGHT KNEE HIGH — body at HIGHEST point
- F8: RIGHT-FOOT REACHING FORWARD — leads back into F1
- Body bob MUST be visibly different — F3 and F7 highest, F1 and F5
  lowest

Style rules:
- 16-bit retro pixel art, EXTREME chibi proportions (3-head-tall, head
  ~35-40% of body height, oversized chibi eyes, round chubby face),
  thick black pixel outlines
- Flat limited-saturation pastel palette, clean hard-edged pixels
- NO painterly rendering, NO soft anime shading, NO photorealism, NO
  illustrative manga style, NO 5-head adult proportions
- Silhouette continuity: head, hair, shoulders, torso read as ONE
  closed shape — no transparent gap between side hair and shoulders

Gameplay-scale readability (mandatory from first generation):
- Face, eyes, bangs, white sleeves, vest trim, sash, drum, silhouette
  must read clearly when downsampled to small in-game size
- Reduce muddy midtones; keep clear light / mid / dark separation

Critical canvas rule (read twice):
- The canvas is ONE FLAT SOLID WHITE BACKGROUND with NO visual
  separators between cells. NO black rectangles, NO grid, NO panel
  borders, NO cell separators, NO frames around any cell.
- Only the 8 character pixel-art figures appear on the white canvas.

Hard reject conditions:
- Reject if the sheet is more side-biased than the previous accepted
  walk
- Reject if direction-asymmetric props drift onto the wrong anatomical
  side
- Reject if grid lines, borders, or cell dividers are drawn (regenerate
  with stronger anti-grid wording rather than crop / mask in post)
- Reject if chibi proportions drift toward 5-head anime adult style
- Reject instead of expecting runtime flips, remaps, or facing hacks to
  rescue the sheet

Output:
- First generate items/[name]_boss_walk_right.jpeg (or
  assets/[name]_boss_walk_right.jpeg for path-exception bosses like
  Dalji)
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/[name]_boss_walk_right.jpeg \
        items/[name]_boss_walk_right.png
- Do NOT modify game code in this step; sheet creation only
- Do NOT consider the new file promoted to canonical until BOTH
  direction sheets pass §4.5 separate-L/R-pair gate
```

---

## Template B — second direction (LEFT, generated AFTER first sheet
## passes its own §1-§9 QA)

```
Per d:\main\bosspong\AGENTS.md and the sprite-generation skill, generate
the LEFT-walking sprite sheet for real-stage [real stage number] boss
[boss name] (code current_stage == [code stage number]). This is the
LEFT companion to a previously generated and accepted RIGHT-walk sheet
at items/[name]_boss_walk_right.png. The character, body proportions,
head size, eye size, ribbon length, and overall silhouette MUST match
the right-walk sheet exactly — same person, same scale, same visual
weight. The runtime engine will NOT mirror this sheet.

[copy the entire RIGHT-walk Template A verbatim, then edit ONLY:]
- "RIGHT" wording -> "LEFT" everywhere it refers to walking direction
- Anatomical side mapping block: props on her RIGHT body side now
  appear on VIEWER-RIGHT (not viewer-LEFT); props on her LEFT body
  side now appear on VIEWER-LEFT (not viewer-RIGHT); trails now go
  toward VIEWER-RIGHT (opposite of left motion)
- 8-frame cycle: swap "RIGHT-FOOT" <-> "LEFT-FOOT" in every pose label,
  swap "LEFT KNEE HIGH" <-> "RIGHT KNEE HIGH"
- "off-frontal-RIGHT" -> "off-frontal-LEFT"; "RIGHT shoulder slightly
  forward" -> "LEFT shoulder slightly forward"
- Output filename: _walk_right -> _walk_left

Do NOT change:
- Identity locks (hair color / style, eye style, outfit, props,
  proportions, palette)
- Style rules
- Composition rules
- Anti-grid wording
- Ribbon length lock
- Clothing color lock
- Drumstick / weapon / instrument visibility lock
- Gameplay-scale readability requirements
- Output: nukki + commit jpeg + png
```

---

## Why no separate "first sheet from scratch" template for LEFT

The proven path is: accept the RIGHT sheet first, then generate LEFT by
editing only the facing / anatomy / trail clauses. Bottom-up regenerating
LEFT from a fresh prompt usually produces an identity drift relative to
the accepted RIGHT (different hair shade, different body proportions,
different ribbon length), which then has to be rejected and redone with
the partner-anchored prompt anyway. Skip the detour and start with
Template A's accepted prompt as the seed for Template B.

If your first accepted direction is LEFT instead of RIGHT (common when
the character's signature pose works better facing left), use the same
pattern in reverse — Template A becomes the LEFT brief, Template B
becomes the RIGHT brief, and the only edits are the facing / anatomy /
trail flips.

---

## Legacy single-sheet pattern (deprecated, do NOT use for new work)

The older single-sheet + runtime-flip pattern (one combined sheet with
top row = left walk, bottom row = right walk, runtime horizontally
flips one row at load time) is deprecated. It silently inverts
direction-asymmetric props onto the wrong anatomical side and is the
exact bug the new convention prevents.

Existing shipped sheets that still use the old pattern remain on disk
as historical record until they are individually regenerated. Do NOT
generate new walk sheets in the old layout.
