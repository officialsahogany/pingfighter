# Legacy Accepted-Sheet Archive

Historical note: this archive was assembled while the target label was
**디스크하츠 - 링피아**. The current Godot product is **환격전**; its English
title is undecided, and old names remain compatibility/provenance identifiers.

This is the accepted-sheet provenance archive formerly embedded in
`CLAUDE.md`. It preserves old Menhera / Dalji art decisions, identity locks,
Python/Pygame wiring traps, and historical handoff_codex notes for parity
research. Do not treat this file as a current implementation checklist.

For live runtime work, use:
- `AGENTS.md`
- `.claude/skills/sprite-generation/SKILL.md`
- `docs/sprites/boss_sprite_runtime_contract.md`
- `docs/sprites/stage1_dalji.md`
- the owning Godot stage / boss module under `godot/`

---

## Archived Notes

The long per-boss notes below preserve accepted art decisions, identity locks,
and old implementation traps. Words like "Current" in these historical bullets
mean "current accepted artifact at the time that note was written", not
"edit Python now". For live implementation, use the compact contract docs,
the current Godot asset tree, and the owning Godot stage / boss module.

- **Current Stage 3 Menhera turn policy (R1 accepted):**
  `items/menhera_boss_sheet.png` remains the sole identity anchor.
  FLUX-derived turn V3 is accepted only as a runtime playback auxiliary
  sheet and is explicitly **non-anchor**. Do NOT use Menhera turn V3 or
  V4 as regeneration reference for attack / dash / victory / defeat.
- **Current Stage 3 Menhera victory policy (P3A accepted):**
  `items/menhera_boss_sheet.png` remains the sole identity anchor.
  FLUX frame-expansion victory publish V2 is accepted only as a runtime
  playback auxiliary sheet and is explicitly **non-anchor**. Do NOT use
  the applied Menhera victory runtime sheet, the older victory backup,
  or rejected V3 variants as regeneration reference for future attack /
  dash / turn / defeat / victory work.
- **Current Stage 1 Dalji walk facing policy (v9 identity-normalized pair,
  per-boss override of the global front-biased rule):** the v9 walk uses a
  **separate left-walk sheet + separate right-walk sheet** model, NOT a
  single combined sheet with runtime horizontal-flip. Two assets at
  `assets/dalji_boss_walk_left.png` (8 frames, 4x2 grid, all frames
  off-frontal LEFT) and `assets/dalji_boss_walk_right.png` (8 frames,
  4x2 grid, all frames off-frontal RIGHT) are the joint canonical identity
  anchor as a pair. The Dalji walk does **not** use strict frontal lock --
  the accepted facing model is direction-aware off-frontal: when moving
  right, the body / face read slightly off-front toward the viewer's right;
  when moving left, slightly off-front toward the viewer's left. This is
  intentional and overrides the general "front-biased walk must read as
  forward-facing in motion" / "do not trade frontal readability for
  liveliness" rules **for Dalji only**. Other bosses still default to
  front-biased unless a similar per-boss override is recorded here.
  Attack / dash / turn / victory / defeat regenerations for Dalji must
  match the v9 pair's directional facing model, not snap back to strict
  frontal.
  **Anatomy preservation across the pair (CRITICAL — what makes the
  separate-sheet model worth its prompt cost):** the character's
  fixed-anatomy props stay on the same body side in both sheets, which a
  blind runtime mirror flip would visibly invert. Specifically:
  - red hibiscus flower stays on her **right side of head** (= viewer-LEFT
    when facing right, viewer-RIGHT when facing left).
  - small black sangmo cap stays centered on top of the bun.
  - white ribbon stays short and contained (about 1.5 x bun height,
    NEVER longer than the torso, NEVER loops around head / hair / face /
    bun).
  - buk drum stays on her **left hip** (= viewer-RIGHT when facing right,
    viewer-LEFT when facing left), with two passive drumsticks visible.
  - red sash ends trail OPPOSITE the motion direction (toward viewer-LEFT
    when walking right, toward viewer-RIGHT when walking left).
  Both sheets must read as the same chibi character: 3-head super-deformed
  proportions, large round brown eyes, brown bangs (NO headband), compact
  bun (no long hair falling down the back, no ponytail), pure white
  long-sleeve undershirt under the black vest (NOT light blue / lavender),
  pure white pants, brown shoes. These are the v9 prompt locks; future
  Dalji walk regenerations must keep them.
  **No runtime mirror flip.** The runtime must still load separate
  `walk_left` and `walk_right` PNG files directly; do not reintroduce a
  load-time flip path in `entities/stage1_boss_sprite.py`.
  **Current v9 identity-normalized walk pair (2026-04-28):** the right
  sheet remains the canonical face / hair anchor. The previous native
  v8 left sheet read as a different character (larger head / face, wider
  silhouette, different eye and hair read), so `assets/dalji_boss_walk_left.png`
  was replaced by an offline mirrored derivative of the canonical
  `walk_right` PNG and saved as its own left-walk asset. This is an
  asset-side identity lock, not a runtime mirror. Body scale is now exact
  across the walk pair at gameplay scale (both ~88.99px body height on the
  96x112 boss canvas). Backup:
  `.tmp/dalji_turn_codex_v3/backups/dalji_boss_walk_left_pre_codex_identity_fix.png`.
  Future native left-walk regeneration is allowed only if side-by-side
  runtime-scale QA proves the face / hair / body read matches the
  canonical right sheet as closely as the mirrored v9 asset.
  **Promotion gate:** v8 was promoted on a c7-RIGHT × c5-LEFT pair after
  6 rejections (c1 wrong layout; c2-LEFT ribbon-too-long; c3-LEFT grid-
  line draw; c4-LEFT chibi identity drift to anime 5-head; c6-RIGHT
  hair-length / undershirt-color drift). The keeper pair came from a
  prompt family with explicit chibi-style lock + anti-grid wording +
  ribbon-length lock + clothing-color lock + drumstick-visibility lock.
  Re-derived prompts that drop any of those locks tend to regress.
  Legacy path note: Dalji was the existing exception to the old
  `items/[name]_boss_sheet.png` staging convention -- the Python runtime
  loader at `entities/stage1_boss_sprite.py` read everything under
  `assets/...`, so prior regenerated sheets overwrote the `assets/` paths,
  not `items/`. For current 환격전 work, use this only as
  provenance / parity context and promote accepted sheets into the Godot
  asset path owned by the Stage 1 boss renderer.
  v7 single-sheet rollback reference is preserved at
  `.tmp/dalji_walk_v8_gemini/dalji_boss_walk_v7_pre_v8_backup.png`. The
  legacy `assets/dalji_boss_walk.png` is intentionally kept on disk
  until the runtime loader migrates from "single sheet + load-time flip"
  to "two-sheet load with no flip" (legacy cross-agent note:
  `.tmp/dalji_walk_v8_gemini/handoff_codex.md`).
- **Current Stage 1 Dalji turn facing policy (per-boss override of the
  global "turn is no longer an angle-rotation brief" rule):** because
  Dalji's walk uses direction-aware off-frontal facing (not front-biased),
  the turn sheet IS an angle-rotation brief, NOT the
  head-lift / shoulder-hitch / hop-pivot characterful gesture used by
  front-biased bosses. Spec: 8 horizontal frames in a 4x2 grid showing a
  smooth body / face yaw rotation from approximately `+45deg` (matching
  the v9 `walk_right` facing) through frontal to approximately `-45deg`
  (matching the v9 `walk_left` facing). Exact per-frame angles are
  flexible as long as the rotation reads smooth and monotonic across the
  8 frames -- no equal-step requirement. The `+/-45deg` endpoints must
  still connect cleanly to the v9 `walk_right F1` and `walk_left F1`
  facings so the walk -> turn -> walk handoff has no facing snap.
  **Source art is right -> left rotation only:** runtime can play the
  full sequence or a short target-biased slice from it (current Codex
  runtime uses `F4-F8` for right -> left and `F5-F1` for left -> right) so
  the boss does not visibly travel one way while staring the other way.
  Do NOT draw a separate left -> right rotation row. Same identity anchor
  (v9 walk pair), body scale +/-5% of the walk pair gameplay-scale body
  height, no palette / proportion drift, output to
  `assets/dalji_boss_turn.png` (1536x1024 PNG, 4x2 grid, cell 384x512).
  Runtime wiring (loader, cache, playback trigger from walk-direction
  edge, reverse playback for the opposite edge) IS already present in
  `entities/stage1_boss_sprite.py` (`load_turn_sprite_sheet`,
  `_start_turn_transition`, `_build_turn_playback_indices`,
  `_get_turn_frame_index`); a turn-sheet swap that keeps the 1536x1024 /
  4x2 / 384x512 layout requires NO loader change.
  **Current shipping turn (v3 Codex identity-fix, 2026-04-28)** is an
  identity-first fallback derived from the canonical `walk_right` PNG:
  F1-F4 use the current walk-right face / hair language, and F5-F8 are
  the matching left-facing half saved in the turn sheet. This deliberately
  prioritizes no face / hair drift over a fully native Gemini yaw arc,
  because v2 c7 was scale-correct but still read different from the walk
  pair in-game. Body scale is locked to the v9 walk body height
  (~89.03px at `BOSS_IMG_STAGE1` 96x112 canvas; walk pair ~88.99px).
  Backup of the previous turn:
  `.tmp/dalji_turn_codex_v3/backups/dalji_boss_turn_pre_codex_identity_fix.png`.
  Generated-but-rejected attempts and processed candidates are kept under
  `.tmp/dalji_turn_codex_v3/`.
  **Identity drift trap surfaced during c6 -> c7 (NEW):** the v9 walk pair
  reads as retro-chibi specifically because of (a) two brown side hair
  locks framing the face down to chin level, (b) a small compact bun (not
  a large round dome bun), (c) a small flat black sangmo cap (not a tall
  dome-shaped cap), and (d) medium retro-chibi eye proportions (not
  large kawaii anime eyes). c6 dropped all four and even though every
  other identity / scale / palette / no-grid / flower-presence check
  passed, the result still read as a different character. Future Dalji
  turn / attack / dash / victory / defeat regenerations must include
  explicit prompt locks for those four features, especially the side
  hair locks (Gemini defaults to a no-side-locks pulled-back hairstyle
  unless asked otherwise). Verify each of the four against the walk pair
  PNG side by side before accepting -- numeric body-scale PASS is
  necessary but not sufficient.
  Future Dalji turn regeneration: expect 6-8 Gemini MCP iterations to
  land identity locks (especially "flower visible in all 8 frames", "no
  grid lines between cells", and the four c6->c7 face/hair locks above);
  reserve final per-cell uniform scale step to lock body to walk pair
  average rather than relying on Gemini to produce the right gp body
  size on its own.
- **Current Stage 1 Dalji attack canonical concept (sangmo-whip v11 =
  v9 + tuned chibi upscale 1.08x, supersedes v10 over-large /
  v9 silhouette-only / v8 raw / v7 / v6 / v2 FLUX-expansion /
  drumstick-strike v1):** the Dalji attack is a **continuous
  sangmo whirl with head tilted DOWNWARD looking at the ball below
  the boss** — the white ribbon attached to the rod on top of her
  small black sangmo cap is the weapon, not the drumsticks. F5 is the
  ball-contact apex; F1-F4 build the whirl momentum, F6-F8 let the
  whirl pass through and settle back to ready. Drumsticks remain
  visible at the buk drum but are passive. Do NOT regress to the
  legacy "drumstick swing" interpretation even though the prior
  `dalji_boss_attack` filename ("sangmo-tether attack") could be
  misread that way. Source path: `assets/dalji_boss_attack.png`
  (per-boss exception, same as walk). Layout: 1536x1024, 4x2 grid,
  cell 384x512 — matches walk and the existing
  `load_attack_sprite_sheet()` loader, so no loader change is required
  when this sheet is replaced. Frame plan: F1 ready (ribbon at rest)
  → F2 whirl-start → F3 buildup → F4 pre-strike windup → F5 contact
  apex (ribbon whips downward and forward toward the ball below) →
  F6 follow-through → F7 recovery → F8 return to ready (loops back to
  F1).
  **Per-frame head-down pose is REQUIRED across all 8 cells** — the
  boss sits at the top of the screen and the ball is below, so the
  attack frames must read as the boss looking down at the ball. Body
  stays front-biased; only the head/face tilts down (chin tucked) and
  the ribbon arc, body posture, and arm/leg energy change between
  frames. **Per-cell identity locks vs walk anchor (do NOT drift):**
  small subtle black sangmo cap on top of bun (no flag emblem); thin
  rod with white ribbon; black sleeveless vest with red+yellow trim
  worn over a WHITE LONG-SLEEVE undershirt (arms must show white
  fabric, NOT bare skin); black headband with red hibiscus flower at
  front-left of forehead; red sash with two long ends hanging on her
  left; light/white pants; brown shoes; large round brown chibi eyes;
  buk drum + two passive drumsticks. The headband and flower must
  remain visible even with bangs / head-down pose. Asset generation
  pattern (v6, current canonical): a single Gemini
  `gemini-generate-image` call producing the full 4x2 sheet
  (aspectRatio `3:2`, imageSize `1K` — 1K is the safe default after
  any prior 2K output is in chat history; 2K only on a fresh session).
  Resize the result to 1536x1024 with LANCZOS, then run the offline
  nukki CLI. Per CLAUDE.md §Boss Sprite Work, **future Dalji attack
  regenerations MUST stay on Gemini MCP** — do NOT call FLUX or
  AutoSprite. Repeatable iteration lessons captured during v3-v6:
  (a) Gemini will draw thin grid lines between cells unless the prompt
  explicitly forbids them (use "ABSOLUTELY NO grid lines, NO borders,
  NO cell dividers" wording);
  (b) Gemini may merge the sangmo cap into the bun if the cap brief is
  too short — describe it as "small round black cap on TOP of the bun,
  plain solid black, no emblem";
  (c) the white long-sleeve undershirt under the black vest is easy
  to lose if the vest is described as a single "black top" — explicitly
  call out "BLACK SLEEVELESS VEST over WHITE LONG-SLEEVE UNDERSHIRT,
  arms NOT bare skin";
  (d) **CANONICAL DALJI HAS NO HEADBAND** — earlier v6/v7 prompts
  incorrectly added a "WIDE BLACK HEADBAND" because the brown bangs
  in the walk sheet were misread as a separate black band. The
  canonical character has natural brown bangs covering the forehead
  and a single red hibiscus flower pinned DIRECTLY to the hair on
  the left side (viewer-right), like a hair clip. Always describe as
  "BROWN bangs hang naturally over the forehead — NO headband, NO
  band of any kind" and "red flower pinned DIRECTLY to the hair, NOT
  to a band". Verify by reading the actual walk-sheet PNG before
  prompting, not by recalling earlier (possibly wrong) descriptions;
  (e) Gemini will draw the white ribbon arc looping AROUND the head
  (encircling the bun / passing in front of the face) by default,
  which causes the brown hair area to read as WHITE at gameplay scale
  (the ribbon's white pixels visually overwhelm the small head
  silhouette and look like a hair-color change). Constrain the ribbon
  path explicitly: "ribbon NEVER crosses, encircles, loops around, or
  overlaps the HEAD / HAIR / FACE / BUN; ribbon stays clearly to ONE
  SIDE of the body (viewer-left or viewer-right) or extends straight
  up / down past the torso, never around the head." Pair this with
  "BROWN hair STAYS BROWN in every frame — do NOT change to white,
  blonde, gray". This was the v6 → v7 fix.
  Backups: drumstick v1 in `.tmp/dalji_attack_v1/`, v2 FLUX-expansion
  in `.tmp/dalji_attack_v3_gemini/dalji_boss_attack_v2_FLUX_applied_pre_v6_backup.png`,
  v6 (Gemini one-shot, head encircled by ribbon) in
  `.tmp/dalji_attack_v3_gemini/dalji_boss_attack_v6_applied_pre_v7_backup.png`,
  v7 (added phantom black headband) in
  `.tmp/dalji_attack_v3_gemini/dalji_boss_attack_v7_applied_pre_v8_backup.png`,
  v8 raw + nukki + frames in `.tmp/dalji_attack_v3_gemini/`,
  v8-pre-v9 backup (raw Gemini sheet before silhouette uniformity scale) at
  `.tmp/dalji_attack_v9_uniform/dalji_boss_attack_v8_pre_v9_backup.png`.
  **Silhouette uniformity step (v8 -> v9, 2026-04-28):** v8 alpha-bbox h
  swung from 82.7gp (F6/F7 follow-through / recovery) to 96.9gp (F3
  buildup peak) -- a 14.2px range at gameplay scale that read as "공격할
  때 살짝 작아짐" (boss seems to shrink during attack) because runtime
  `_aspect_fit` scales the whole 384x512 cell uniformly and pins cell
  bottom at canvas bottom, so the silhouette compresses when the white
  ribbon is no longer extending the alpha bbox upward. v9 fixes this
  with per-cell uniform scale of each cell's alpha-bbox region to a
  common 422-source-px target (= 92.31gp = average of all 8 v8 frames),
  anchored at the original bbox bottom (preserve feet position) and
  centered horizontally on the original bbox center. Per-frame scale
  factors: F1 0.979, F2 0.966, F3 0.953, F4 0.957, F5 0.964, F6 1.114
  (+11.3%), F7 1.116 (+11.6%), F8 0.988. Net: per-frame bbox h locked
  at 422 (0% spread) across all 8 frames; F1-F5 ribbon arc shrinks
  1-5% (imperceptible at gameplay scale), F6/F7 chibi+ribbon grows
  ~11% (recovery frames now match the rest of the swing instead of
  reading as a "second smaller character"). No loader / animation
  speed / F5-anticipatory-trigger math change required -- this is a
  pure asset-side post-process.
  **Chibi-face cell-fitting step (v9 -> v10 -> v11, 2026-04-28):**
  v9 only fixed silhouette uniformity, but the user noticed the
  attack chibi face still read SMALLER than the walk chibi face once
  walk/idle/turn/defeat/stun all converged to gp ~89. Root cause:
  `_aspect_fit` scales each whole cell independently, and walk vs
  attack cells have different scale factors (walk 344x384 cell scale
  0.279 width-limited; attack 384x512 cell scale 0.219 height-
  limited). The v9 alpha bbox was 422 source = 92.31 gp at attack
  cell scale, BUT that bbox includes the swung ribbon arc on top —
  the chibi BODY proper inside that bbox was only ~351 source =
  77.22 gp at gameplay scale, ~12 gp smaller than the walk chibi
  body. **v10 (1.153x upscale) overshot** — chibi body landed at
  87.77 gp, matching walk-alpha (88.99) instead of walk-chibi (77.97),
  and the user reported "now it's slightly bigger". v11 retuned to
  **1.08x upscale** (midpoint between v9 chibi 77 and v10 chibi 88):
  chibi body gp 83.97 (walk-chibi +7.7%, walk-alpha -5.6%), alpha
  bbox gp 99.75 (less ribbon arc clipping than v10). v11 is the
  user-validated sweet spot — neither too small (v9) nor too big
  (v10). v9-pre-v10 backup at
  `.tmp/dalji_attack_v10_chibi_face/dalji_boss_attack_v9_pre_v10_backup.png`;
  v11 derived from same v9 baseline at
  `.tmp/dalji_attack_v11_chibi_tune/dalji_boss_attack_v11_scaled.png`.
  **Generalization rule for future swing-type attack sheets (whip,
  slash, chain, sweep, axe, banner — anything with a large overhead
  arc / weapon trail above the chibi head):** v9-style silhouette
  uniformity is necessary but NOT sufficient. The full QA gate is:
  1. Per-cell uniform alpha-bbox scale (v9 step) to lock silhouette
     range within ~5gp. Reject and apply this if the strike-arc
     peak and follow-through trough differ by more than ~5% of
     canvas height.
  2. Then measure chibi BODY only via row-mass>80 scan (excluding
     thin overhead arc / motion lines / weapon trails).
  3. If chibi body gp falls short of walk chibi gp by more than
     ~5%, apply a SINGLE additional uniform upscale on top of step
     1 to bring chibi body **midway between walk-chibi and walk-
     alpha** (NOT all the way to walk-alpha — that overshoots, see
     v10 trap below). Anchor at per-cell feet position. Accept the
     ribbon / weapon arc top getting clipped by the cell boundary
     — chibi face / body match matters more than weapon edge
     preservation. This is the v9 → v11 pattern; future regen
     must run BOTH steps before shipping.
  4. The traps to avoid:
     - Matching only alpha-bbox to walk-alpha-bbox makes silhouettes
       match but leaves chibi face visibly smaller because alpha
       includes the overhead arc that walk doesn't have. Always
       measure chibi BODY for sheets with overhead structure.
     - Matching chibi body all the way to walk-alpha (v10) overshoots
       — alpha bbox includes walk's cap/hair structure that the
       chibi-body row-mass scan also catches in attack frames, so
       the result feels bigger than walk. Target the midpoint
       between walk-chibi (77 gp at attack cell scale) and walk-
       alpha (89 gp) — v11's 84 gp is the user-validated sweet spot.
  **Runtime timing — F5-aligned anticipatory triggering (per-boss
  override of the global "anticipatory triggering by default" rule
  with explicit alignment math).** Earlier v6 in-game playback fired
  the strike too early because the original
  `attack_animation_speed = 0.05s` made F5 land at trigger + 12 game
  frames while the anticipation windows expected it later. Current
  canonical timing:
  - `entities/stage1_boss_sprite.py` `attack_animation_speed = 0.075s`
    so each animation frame is held for 4.5 game frames at 60 fps,
    placing F5 (index 4) at `trigger + 4 × 4.5 = 18` game frames after
    `trigger_attack(start_frame=0)`.
  - `pingfighter.py` Dalji anticipatory window table picks
    `start_frame = N` so F5 lands at trigger + `(4 - N) × 4.5` game
    frames, which is centered on the chosen `frames_to_contact` window:
    16-20 → N=0, 12-16 → N=1, 8-12 → N=2, 4-8 → N=3, 0-4 → N=4.
  Result: F5 displays approximately AT predicted ball contact across
  all five anticipation buckets, so the visible strike never fires
  before the ball arrives. The two values are coupled — never retune
  one without re-deriving the other from the same per-boss math.
- **Current Stage 1 Dalji whip / sangmo-spin canonical concept (v2 =
  v1 c3 + 1.05x chibi-face upscale, supersedes v1 c3 baseline,
  2026-04-28):** when the boss
  activates the 상모돌리기 (whip) skill, she should perform a **ballerina
  pirouette yaw rotation** — body stays vertically locked in place,
  facing rotates around the vertical axis (front -> right profile ->
  back -> left profile -> front). She does NOT tumble like a top
  (z-axis planar rotation). This is a per-boss visual direction set
  by the user, not a global rule.
  Asset spec: `assets/dalji_boss_whip.png`, 1536x1024 PNG, 4x2 grid,
  cell 384x512 — same layout as attack / turn so the same loader
  geometry can be reused. 8 frames, evenly distributed 45° steps,
  clockwise spin viewed from above:
  - F1: 0° front, F2: 45° 3/4 front-right, F3: 90° right profile,
    F4: 135° back-3/4-right, F5: 180° back, F6: 225° back-3/4-left,
    F7: 270° left profile (mirror of F3), F8: 315° 3/4 front-left
    (mirror of F2). F1<->F5 front/back opposites; F2/F8, F3/F7,
    F4/F6 are mirror pairs.
  Pose lock (must be identical across all 8 frames, only viewing
  angle changes): standing tall on both feet, both arms extended
  horizontally at shoulder level (ballerina 2nd position), head
  upright. NO crouch, NO bend, NO leg lift, NO attack motion. The
  body is a static pirouette pillar that only rotates yaw.
  Sangmo ribbon: drawn as a **spinning white oval halo** above the
  small flat black cap in every frame (motion-blur disc on top of the
  thin black rod), NOT as a discrete pose-changing weapon. This is
  what makes the spin read as "the sangmo is whirling" rather than as
  "the character is just turning around".
  Identity locks (must match v8 walk pair, c7 turn, v9 attack):
  brown bun + side hair locks framing face, brown bangs (NO headband),
  retro chibi brown eyes, single red hibiscus flower, small flat
  black sangmo cap, black sleeveless vest with red+yellow trim over
  WHITE long-sleeve undershirt, red sash with two trailing ends on
  left, white pants, brown shoes, buk drum on left hip with two
  passive drumsticks.
  **Runtime mapping — angle to frame index (per-boss override of the
  legacy `pygame.transform.rotate` whip behavior).** The original whip
  effect called `pygame.transform.rotate(boss_img, whip_rotation_angle)`
  on whichever boss image was in flight (walk / attack / idle), which
  produced a planar z-axis spin (top-like tumbling). The new model
  keeps the existing time-driven `whip_rotation_angle` math
  (`(get_ticks() * 15 / 16.67) % 360`) but maps the angle to one of 8
  yaw frames in `entities/stage1_boss_sprite.py`
  (`load_whip_sprite_sheet`, `get_whip_frame`, `_scaled_frames_whip`).
  The `pingfighter.py` whip block now calls
  `stage1_boss_sprite.get_whip_frame(angle, (BOSS_IMG_STAGE1_WIDTH,
  BOSS_IMG_STAGE1_HEIGHT))` and substitutes the result for `boss_img`,
  setting `boss_img_prescaled = True` so the downstream render path
  does not double-scale. If the sheet failed to load, the getter
  returns `None` and the previously-resolved walk/attack/idle frame
  passes through unchanged — graceful fallback. Do NOT reintroduce a
  `pygame.transform.rotate(boss_img, angle)` planar-spin path on top
  of the new yaw sheet; the two are visually conflicting.
  **Generation lessons (c1 -> c2 -> c3, 3 iterations):**
  - c1 had grid lines between cells — explicit "ABSOLUTELY NO grid
    lines, NO borders, NO cell dividers" wording is required;
  - c1/c2 had uneven rotation distribution (F1-F3 all near-frontal,
    then jump to F4 back) — must explicitly state "EVENLY DISTRIBUTED
    45° STEPS, F3 and F7 must be MIRROR IMAGES, F1 and F5 must be
    FRONT vs BACK opposites" and require visible facing-direction
    change between every adjacent pair;
  - Gemini does not reliably preserve direction-asymmetric prop
    positions (flower on character anatomical RIGHT side of head)
    across yaw rotation — c3 has flower on the wrong side vs walk
    pair convention. This is acceptable for whip because the spin is
    fast (~0.4 sec / rotation, ~50 ms per cell), so the eye reads
    spinning blur not specific prop positions. Future regen attempts
    can lock the flower side explicitly but should not block the
    accept gate over it.
  Pre-nukki body height spread was 0.9% (442-446 source px) and feet
  y was perfectly aligned (476 in every cell), so the per-cell
  uniform-scale step used for attack v9 / turn c7 was unnecessary
  for whip v1.
  Backups: c3 raw + nukki at `.tmp/dalji_whip_v1_gemini/`; the
  legacy `pygame.transform.rotate` planar-spin behavior is preserved
  in git history (the replaced 8-line block in `pingfighter.py`
  whip rotation effect section).
  **v1 → v2 chibi-face follow-up (2026-04-28):** v1 c3 chibi body
  measured at 86.35 gp (walk-chibi 78 +10.7%, walk-alpha 89 -3%) —
  technically larger than walk-chibi, but user reported "상모돌리기
  할때도 좀 작아". Root cause: spinning halo dominance — the large
  white halo above the head visually shrinks the chibi body in
  contrast (halo is read as effect, not character). Measurement says
  whip should be downscaled to match attack v11's 84 gp, but user
  perception says upscale. v2 applies 1.05x uniform upscale on top
  of v1 c3 to bring chibi body to ~92 gp (walk-alpha +4%) — slightly
  larger than other sheets, intentionally over-correcting for the
  halo contrast. Per-cell silhouette structure preserved. Backup:
  v1 pre-v2 at
  `.tmp/dalji_idle_whip_v2_tune/dalji_boss_whip_v1_pre_v2_backup.png`.
  **Generalization rule for future overhead-VFX sheets**: when a
  sheet has a large overhead VFX element (spinning halo, aura ring,
  active glow, charge field, etc.) the chibi body needs to be
  upscaled BEYOND walk-chibi match because the VFX visually shrinks
  the body via contrast. Target: chibi body at walk-alpha or
  slightly above, NOT walk-chibi or midpoint. Trade-off: alpha bbox
  may extend further past cell boundary, accept the VFX-edge clip.
- **Current Stage 1 Dalji dash canonical concept (v1 c1 accepted,
  Gemini one-shot full sheet, 2026-04-28):** when `boss_dashing` is
  active, Dalji should perform a **front-biased horizontal slide
  motion** rather than just stretching the live walk/attack/turn frame
  across the dash duration. Asset spec: `assets/dalji_boss_dash.png`,
  1536x1024 PNG, 4x2 grid, cell 384x512 — same layout as attack /
  turn / whip so the same loader geometry is reused. 8 frames in the
  standard dash sequence:
  - F1 ready/prep, F2 push-off, F3 low slide / full extension, F4-F5
    sustained slide, F6 deceleration, F7 recovery rise, F8 return to
    ready (loops back to F1).
  Source dashes RIGHTWARD with motion lines + dust trails extending
  toward viewer-LEFT; left dashes are produced by
  `pygame.transform.flip` at load time, same pattern as the attack
  sheet (per-boss exception to the v8 separate-L/R pair rule, justified
  by fast dash motion making prop-anatomy side mismatch invisible).
  Front-biased dash: face stays mostly forward across all 8 frames,
  motion expressed via leg extension + body lean + hair / sash /
  ribbon trails + motion lines + dust kicks. Never goes to full
  side-profile.
  **Per-cell uniform scale is REQUIRED for dash sheets** because
  low-slide poses (F3-F5) compress vertical alpha bbox dramatically
  while standing poses (F1, F8) keep their full height — pre-scale
  spread on c1 was 25.2% (316-413 source px), feet y range was 18 source
  px (3.94 px gp). Locked all 8 frames to the avg height (379 source
  px = 82.91 gp) with feet pinned at y=467, centered horizontally on
  each cell's bbox center. Per-frame scale factors: F1 0.929, F2 0.972,
  F3 1.125, F4 1.199 (max upscale), F5 1.016, F6 0.960, F7 0.943,
  F8 0.922.
  **gp body 82.91 vs walk 88.99 = -6.84%** (just outside the +/-5%
  strict gate). Acceptable for dash because pushing the target up to
  walk-matched 89 gp would mean +28% upscale on F4 — that breaks
  chibi proportions in the slide pose. Future dash regenerations should
  also accept the slight gp body drop rather than over-upscaling slide
  frames.
  **Generation lessons (single-iteration accept):**
  - First-attempt prompt with explicit per-frame plan
    (ready / push-off / slide / sustained / decel / recovery / ready)
    + motion-line direction lock (always toward viewer-LEFT for
    rightward dash) + sash/ribbon backward-trail lock landed identity,
    style, sequence, and grid-line-free output in one shot.
  - The 25.2% pre-scale spread is **inherent to dash poses**, not a
    Gemini quality issue — even a perfect Gemini render will need the
    per-cell uniform-scale + feet-anchor post-process step. Treat that
    step as a required part of any future dash regen, not optional
    polish.
  **Runtime mapping — progress to frame index (non-linear, slide-
  sustained).** Dash uses external state (`boss_dashing` flag +
  `boss_dash_timer` countdown from `boss_dash_duration_frames` to 0)
  rather than internal sprite-class timing. The pingfighter.py Stage 1
  Dalji render branch (right after `stage1_boss_sprite.get_current_frame()`)
  overrides `boss_img` with `stage1_boss_sprite.get_dash_frame(progress,
  dir, scale_size)` while `boss_dashing` is True, where
  `progress = 1.0 - (boss_dash_timer / boss_dash_duration_frames)`
  and `dir = boss_dash_direction (-1 left, +1 right)`. The getter does
  NOT use even `int(progress * 8)` mapping — instead the F3/F4 slide
  poses are HELD for the bulk of the dash window so the boss reads as
  "in slide" until the dash ends, matching the player-character dash
  convention:
  - progress < 0.08  -> F1 ready / prep (7%)
  - progress < 0.18  -> F2 push-off (10%)
  - progress < 0.55  -> F3 low slide / full extension (36%)
  - progress >= 0.55 -> F4 sustained slide (45%, held until dash ends)
  F5-F8 recovery / return-to-ready frames are intentionally **never
  shown** at runtime — when `boss_dashing` flips back to False, the
  walk / idle frame naturally takes over and visually closes the
  recovery beat. F5-F8 are kept in the sheet for future use (e.g. a
  cancel-into-attack transition could index into them) but the live
  Dalji dash override skips them. Returns None on missing sheet for
  graceful fallback.
  **Generalization rule for future dash sheets**: animated dash sheets
  with prep / push / slide / recovery arcs should default to this
  slide-sustained mapping (F1/F2 brief intro, F3/F4 dominate, recovery
  frames skipped) rather than even time-distribution. Even `int(p*n)`
  mapping makes the slide pose flash by quickly while recovery frames
  hog visible time, which reads as "boss prepares, slides, then poses
  for recovery" instead of the desired "boss slides for the whole
  dash duration."
  **Priority**: dash > walk/attack/turn (so dash slide pose reads
  during high-velocity travel; an attack frame frozen mid-slide would
  look weird).
  Backups: c1 raw + nukki + scaled at `.tmp/dalji_dash_v1_gemini/`.
- **Current Stage 1 Dalji victory canonical concept (v2 = v1 c3 +
  1.18x chibi-face upscale, supersedes v1 c3 walk-chibi-only match,
  2026-04-28):** when the boss wins a
  round / game (player score loss reaches the win condition), Dalji
  should perform a **front-facing celebration arc** — standing reset
  -> jump prep -> jump up with arms rising -> peak overhead V-shape
  pose with confetti -> descent -> land with dust puff -> V-sign /
  peace-sign hero pose -> hold V-sign. Asset spec:
  `assets/dalji_boss_victory.png`, 1536x1024 PNG, 4x2 grid, cell
  384x512 — same layout as attack / turn / whip / dash. 8 frames.
  Front-facing in every frame; left/right mirroring is intentionally
  NOT applied because the celebration reads the same regardless of
  which direction the boss was facing when the win triggered.
  Identity locks (matching v8 walk pair, v9 attack, c7 turn, v1 whip,
  v1 dash): brown bun + side hair locks framing face, brown bangs
  (NO headband), retro chibi brown eyes (closed-eye smiles ^_^
  acceptable in jump frames), single red hibiscus flower on character
  RIGHT side of head **(viewer-LEFT in front view — walk pair
  convention preserved on c3, unlike whip c3)**, small flat black
  sangmo cap with thin rod and white ribbon, black sleeveless vest +
  red/yellow trim over WHITE long-sleeve undershirt, red sash, white
  pants, brown shoes, buk drum on left hip + drumsticks. Modest
  celebration effects: sparkles in F1/F4/F7/F8, confetti dots in F4
  only, dust puff in F6 only.
  **Per-cell uniform scale + ORIGINAL feet y preserved** (different
  from attack v9 / dash v1 which lock feet to a single y across all
  frames). Locked all 8 frames to 380 source px body height (avg) but
  anchored each scaled bbox at its **original** alpha-bbox bottom so
  the F3-F5 mid-jump frames keep their lifted feet y (425-456 source
  px) while F1/F2/F6/F7/F8 grounded frames stay at baseline (460-476
  source px). The jump arc must read at runtime; flattening feet to
  one anchor would erase it. Per-frame scale factors (all under 4%):
  F1 0.995, F2 1.035, F3 1.019, F4 0.979, F5 1.008, F6 1.013, F7
  0.987, F8 0.969.
  **Generation lessons (c1 -> c2 -> c3, 3 iterations):**
  - c1: black grid lines between cells (hard fail)
  - c2: NO grid lines (good) but Gemini drew **frame name labels**
    ("RESET", "JUMP UP", "PEAK CELEBRATION", etc.) under each cell
    because the prompt used those words in the per-frame plan as
    section headers — Gemini interpreted the labels as on-image
    text. Fix in c3: replace named frame plans ("RESET", "PEAK
    CELEBRATION", ...) with neutral "Cell 1 / Cell 2 / Cell 3..."
    numbering AND add explicit "ZERO text characters of any kind"
    + "NO underlines" requirement at the top of the prompt.
  - **Generalization rule for future sprite-sheet prompts**: do not
    use ALL-CAPS frame names that look like section headers in the
    per-frame plan. Gemini will sometimes render those names as
    visible captions on the sheet. Use neutral "Cell N" / "Frame N"
    numbering and describe poses in plain prose.
  **Runtime mapping — Menhera-style internal animation timer (per-boss
  override of the dash external-progress pattern).** Unlike dash
  (which is driven by external `boss_dash_timer` / `boss_dash_duration_frames`
  countdown), victory uses an **internal sprite-class animation timer**
  matching the Menhera victory pattern. State on the sprite class:
  `is_victorious`, `victory_frame`, `victory_timer`,
  `victory_animation_speed=0.18s/frame`, `victory_finished`. Triggered
  via `trigger_victory()` from the shared
  `trigger_current_boss_victory_animation()` in pingfighter.py. The
  sprite class `update()` ticks the timer each frame (highest
  priority — runs before attack / hit / movement branches and returns
  early, so movement / attack / hit / direction-change logic is paused
  during celebration). Total animation: 0.18s × 8 = 1.44 sec from
  trigger to final hold pose. Holds on F8 (V-sign) indefinitely until
  `clear_victory()` is called. The pingfighter.py Stage 1 render
  branch checks `is_victorious` (after dash override) and substitutes
  `get_victory_frame()` for `boss_img` with `boss_img_prescaled=True`.
  **Priority chain at runtime**: victory > dash > whip > walk/attack/turn.
  `clear_victory()` is called from the shared end-of-round / reset
  block alongside `menhera_boss_sprite.clear_victory()`.
  Backups: c3 raw + nukki + scaled at `.tmp/dalji_victory_v1_gemini/`.
  **v1 → v2 chibi-face follow-up (2026-04-28):** v1 c3 chibi body
  measured at 74.79 gp (walk-chibi 78 -4%, walk-alpha 89 -16%) —
  visibly small in-game. User reported "승리포즈도 좀 작아 보임".
  Same root cause as the attack v9→v11 / idle v1→v2 / whip v1→v2
  chibi-face problem — walk-alpha includes the cap structure but
  victory's chibi-body row-mass scan undermeasures because celebration
  poses (raised arms, jumping) reduce torso width below the 80px
  threshold in some rows. v2 applies 1.18x uniform upscale on top of
  v1, anchored at PER-CELL feet y (preserving the F3-F5 jump arc —
  jump frames keep their lifted feet position). Result: chibi body
  gp 90.34 (walk-alpha +1.5%, between idle v2 88.21 and whip v2
  92.56). Backup: v1 pre-v2 at
  `.tmp/dalji_victory_v2_tune/dalji_boss_victory_v1_pre_v2_backup.png`.
- **Current Stage 1 Dalji defeat canonical concept (v1 c1 accepted,
  Gemini one-shot full sheet, 2026-04-28):** when the boss loses a
  round / game (player score reaches the win condition), Dalji should
  perform a **front-facing defeat reaction arc** — shock standing ->
  step back -> wobble (off-balance, early tear) -> half-knelt -> fully
  knelt with palms on ground -> deeper bow with tear + dust puff ->
  tear falling with deep bow -> hold deflated bow. Asset spec:
  `assets/dalji_boss_defeat.png`, 1536x1024 PNG, 4x2 grid, cell
  384x512 — same layout as all other Dalji sheets. 8 frames.
  Front-facing in every frame; left/right mirroring NOT applied
  (defeat reads the same regardless of pre-defeat facing). Identity
  locks (matching v8 walk pair, v9 attack, c7 turn, v1 whip, v1 dash,
  v1 victory): brown bun + side hair locks, brown bangs (NO headband),
  retro chibi brown eyes (sad expressions: wide-shocked, squeezed-
  half-shut, fully closed), single red hibiscus flower on character
  RIGHT side of head (viewer-LEFT in front view — walk pair convention
  preserved), small flat black sangmo cap with thin rod and white
  ribbon, black sleeveless vest + red/yellow trim over WHITE long-
  sleeve undershirt, red sash, white pants, brown shoes, buk drum on
  left hip + drumsticks. Modest defeat effects: small tear drop in
  F3/F6/F7, small dust puff in F6 only. NO giant explosion / "K.O."
  graphics — sadness is elegant, character-focused.
  **Per-cell uniform scale + grounded feet anchor** — Gemini drew
  defeat chibi much larger than walk (avg 98.66 gp vs walk 88.99 gp,
  +10.86%) because defeat poses naturally fill more cell height.
  Locked all 8 frames to 407 source px = 89 gp (walk-matched) with
  feet pinned at y=494. Per-frame scale factors 0.857-0.971 (-14%
  to -3% downscale, all conservative). Result: gp body 89.03 = walk
  +0.05%, the best walk-match in the celebration / dejection family.
  **Generation lessons (single-iter accept):**
  - First-attempt prompt with neutral "Cell N" numbering (learned
    from victory c2 label trap) + explicit "ZERO text characters"
    + per-frame defeat plan (shock / step-back / wobble / half-knelt
    / fully knelt / sad+tear / deeper sad / hold) landed identity,
    palette, sequence, grid-line-free, label-free output in one shot.
  - Gemini draws defeat chibi much larger than walk by default. Per-
    cell uniform downscale to walk-matched 407 source px is required
    post-process — the prompt's "50-60% cell fill" guideline was
    only loosely respected.
  **Runtime mapping — Menhera-style internal animation timer (paired
  with victory).** Same internal-timer pattern as victory: state on
  the sprite class is `is_defeated`, `defeat_frame`, `defeat_timer`,
  `defeat_animation_speed=0.18s/frame`, `defeat_finished`. Triggered
  via `trigger_defeat()` from the shared
  `trigger_current_boss_defeat_animation()` in pingfighter.py. The
  sprite class `update()` checks defeat **BEFORE** victory and
  returns early so no other animation can interrupt; defeat takes
  priority over victory if both flags fire on the same frame.
  `trigger_defeat()` actively clears `is_victorious` to enforce
  this. Total animation: 0.18s × 8 = 1.44 sec from trigger to final
  hold pose. Holds on F8 (deflated bow) until `clear_defeat()`.
  pingfighter.py override: defeat override block placed AFTER victory
  override in the Stage 1 Dalji render branch — order doesn't matter
  for correctness because `trigger_defeat()` clears `is_victorious`,
  but the lexical order keeps "victory then defeat" visual-priority
  intent obvious. `clear_defeat()` is called from the shared end-of-
  round reset block alongside `clear_victory()`.
  **Priority chain at runtime**: defeat > victory > dash > whip >
  walk/attack/turn.
  **Generalization rule for paired victory + defeat sheets**: when
  adding both for a future boss, always make trigger_defeat() actively
  clear is_victorious, and always check defeat BEFORE victory in the
  sprite class update(). A boss that just lost cannot then start
  celebrating because of a stale flag — the defeat path must dominate.
  Backups: c1 raw + nukki + scaled at `.tmp/dalji_defeat_v1_gemini/`.
- **Current Stage 1 Dalji stun / electrocution canonical concept (v1
  c1 accepted, Gemini one-shot full sheet, 2026-04-28):** when
  `boss_stunned_timer > 0` (any stun source — leg shot, spider mine,
  plasma, head shot, AK47, smasher kick, blacksmith turret,
  strawberry bomb, optimus arm throw, judgment lightning, etc.),
  Dalji should perform a **looping "zapped" reaction** — frozen
  in place with rigid arms-out posture, hair lifted from electric
  charge, pale blue/grey skin tint, varied shocked eye/mouth shapes
  per cell (wide / X / swirl), small lightning sparks crackling
  around the body. Asset spec: `assets/dalji_boss_stun.png`,
  1536x1024 PNG, 4x2 grid, cell 384x512 — same layout as all other
  Dalji sheets. **8 LOOPING frames** (NOT a sequence — each cell is
  a slight variation of the same stunned state for electric
  vibration). Front-facing in every frame; left/right mirroring
  NOT applied (stun reads the same regardless of pre-stun facing).
  Identity locks (matching v8 walk pair, all other Dalji sheets):
  brown bun + side hair locks (HAIR LIFTED slightly in every frame),
  brown bangs (NO headband), single red hibiscus flower on character
  RIGHT side of head (viewer-LEFT in front view — walk pair
  convention preserved), small flat black sangmo cap with thin rod
  and white ribbon (rod / ribbon vibrates), round chibi eyes
  **VARYING** per cell (wide shocked / X-squeezed / spinning swirl
  — NOT the normal calm brown eyes), **pale blue/grey skin tint**
  (subtle electrocution color), black sleeveless vest + red/yellow
  trim over WHITE long-sleeve undershirt, red sash, white pants,
  brown shoes, drum + drumsticks. Modest electric effects: small
  jagged white-yellow lightning sparks in different positions per
  cell.
  **Per-cell uniform scale + grounded feet anchor** — Gemini drew
  stun chibi much larger than walk (avg 102.89 gp vs walk 88.99 gp,
  +15.6%) because lifted hair + cap rod + ribbon vibration push alpha
  bbox upward. Locked all 8 frames to 407 source px (89 gp = walk-
  matched) with feet pinned at y=487. Per-frame scale factors
  0.846-0.877 (-15% to -12% downscale, conservative). Result: gp
  body 89.03 = walk +0.05% (matches turn c7 / defeat v1 to the
  decimal — best walk-match tier).
  **Runtime mapping — external timer-driven, NO internal state on
  the sprite class** (different from victory / defeat which use
  internal Menhera-style timers; closer to dash external-progress
  pattern). State on the sprite class: `frames_stun`,
  `_scaled_frames_stun`, `stun_total_frames=8`. Activation lifecycle
  is owned entirely by the existing global `boss_stunned_timer` in
  pingfighter.py — no `is_stunned` flag, no `trigger_stun()`, no
  `clear_stun()` on the sprite class. The pingfighter.py Stage 1
  Dalji render branch (between dash and victory overrides) checks
  `if boss_stunned_timer > 0` and substitutes
  `stage1_boss_sprite.get_stun_frame(pygame.time.get_ticks(), ...)`
  for `boss_img`. The getter maps wall-clock time to one of 8
  looping frames via `(time_ms // 80) % 8` — 80ms per cell, 640ms
  full cycle (fast enough for short 0.3s stun, slow enough to read
  during long 2.1s+ stun).
  **Priority chain at runtime**: defeat > victory > **stun** > dash
  > whip > walk/attack/turn. Stun is below victory/defeat (game-end
  animations win) but above dash/walk (a stunned boss cannot dash
  or walk).
  **Existing head-stars overlay continues** — the rotating star
  effect at pingfighter.py line ~144413 stays as-is on top of the
  new stun pose. The existing electric arc overlay
  (`_draw_electric_stun_overlay`) for 천둥뇌구 also stays unchanged.
  The new stun sheet REPLACES the boss body image but does NOT
  replace the overlay effects.
  **Generation lessons (single-iter accept):**
  - Looping vibration brief works first try with explicit "8 cells
    are LOOPING variations of the same stunned state, NOT a
    narrative sequence" wording + per-cell eye/mouth/spark variation
    table.
  - Gemini draws stun chibi much larger than walk by default
    (lifted hair + cap rod alpha extension). Per-cell uniform
    downscale to walk-matched 407 source px is required post-process.
  - Skin tint shift (pale blue for electrocution) works without
    drifting overall palette — Gemini correctly applies tint only
    to skin pixels, not to vest / pants / sash / drum.
  Backups: c1 raw + nukki + scaled at `.tmp/dalji_stun_v1_gemini/`.
- **Current Stage 1 Dalji idle / breathing canonical concept (v2 =
  v1 + 1.075x chibi-face upscale, supersedes v1 walk-alpha-only
  match, 2026-04-28):** when Dalji is
  stationary (`direction == 0` and no other animation active), she
  should perform a **subtle looping breathing motion** instead of
  showing the previous static `walk_frames[0]` idle. Asset spec:
  `assets/dalji_boss_idle.png`, 1536x1024 PNG, 4x2 grid, cell
  384x512 — same layout as all other Dalji sheets. **8 LOOPING
  frames** (NOT a sequence — each cell is a slight variation of the
  same standing state for chest expand / head bob ease-in/ease-out
  cycle). Front-facing in every frame; left/right mirroring NOT
  applied. Per-cell breathing curve: C1 NEUTRAL -> C2 25% inhale ->
  C3 50% inhale -> C4 PEAK inhale (head 4 gp above baseline) -> C5
  75% release -> C6 50% -> C7 25% -> C8 NEUTRAL (loops). Identity
  locks (matching v8 walk pair, all other Dalji sheets): brown bun +
  side hair locks, brown bangs (NO headband), single red hibiscus
  flower on character RIGHT side of head (viewer-LEFT in front view),
  small flat black sangmo cap with thin rod and white ribbon (stays
  static — no electric lift), **normal warm flesh tone** (NOT pale
  blue stun tint), black sleeveless vest + red/yellow trim over
  WHITE long-sleeve undershirt, red sash, white pants, brown shoes,
  drum + drumsticks. Same calm small smile + bright open brown eyes
  in EVERY frame (no expression variation). NO sparkles, electric
  arcs, dust, or particles — pure calm breathing only.
  **Single uniform scale + grounded feet anchor (NEW per-sheet
  decision pattern).** Idle is the FIRST Dalji sheet where per-cell
  uniform scale (used for attack v9 / dash v1 / victory v1 / defeat
  v1 / stun v1) would be WRONG — the breathing motion IS the
  frame-to-frame variance, and per-cell normalize would erase it.
  Instead, applied a SINGLE scale factor (0.8618 = 407 / avg_h) to
  all 8 cells, mapping the AVG height to walk-matched 407 source px
  while PRESERVING the relative differences between frames. Result:
  - avg gp body 89.00 = walk +0.02% (best walk-match in the family)
  - Per-frame range 88.07-92.16 gp (breathing preserved at the
    correct scale, equivalent to walk's natural cycle bob)
  - Head bob preserved: 3.94 gp visible (4.81 gp pre-scale)
  - Feet 0px spread (anchored at y=505 in every frame)
  **Generalization rule for future micro-motion / loop sheets**: when
  the entire point of the asset is the frame-to-frame variance
  (breathing, idle sway, ambient flame flicker, etc.), use a SINGLE
  uniform scale to map the AVG to the target (preserving variance),
  NOT per-cell uniform scale (which erases variance). Per-cell scale
  is only correct when frame-to-frame variance is artist drift /
  noise to be normalized away (attack swing / dash slide / stun
  hair-lift / defeat collapse — all cases where the artist drew
  bigger or smaller per pose unintentionally and we want a uniform
  silhouette). Idle / breathing / ambient loops are the OPPOSITE
  case — variance is the feature.
  **Runtime mapping — internal to sprite class, no pingfighter.py
  override.** Unlike all other Dalji extra sheets which are wired in
  pingfighter.py via dedicated override blocks, idle is the FALLBACK
  branch inside `get_current_frame()` for `direction == 0` (boss
  stationary, no other animation active). Both the cached and raw-
  size paths in `get_current_frame()` now check
  `if self._scaled_frames_idle:` first and pick
  `self._scaled_frames_idle[(get_ticks() // 250) % 8]` for the
  current breathing frame. The legacy single static `idle_frame`
  (which was just `walk_frames[0]`) remains as a fallback when the
  idle sheet failed to load. Looping speed: 250ms per cell × 8 cells
  = 2.0 sec full breath cycle (calm relaxed pace).
  **Priority chain at runtime (UPDATED with idle as floor)**:
  defeat > victory > stun > dash > whip > walk/attack/turn > **idle**.
  Idle is the bottom of the chain — the default fallback for "nothing
  else is happening and the boss isn't moving."
  **Generation lessons (single-iter accept):**
  - Subtle looping motion brief works first try with neutral "Cell N"
    numbering + explicit per-cell breathing curve table (NEUTRAL ->
    25% -> 50% -> PEAK -> 75% -> 50% -> 25% -> NEUTRAL) + "feet do
    NOT move, only chest/head/shoulders breathe" lock.
  - Gemini correctly produces VERY subtle frame-to-frame differences
    when asked to ("the player should be able to tell she's alive
    and breathing but NOT see big movements") — no need to ask for
    extra dramatic motion to compensate.
  - SAME calm expression in every cell needed explicit reminder
    ("NO winking, NO shocked, NO closed eyes — same calm small
    smile in every cell") — Gemini will otherwise vary the
    expression for visual interest, breaking the "subtle" brief.
  **v1 → v2 chibi-face follow-up (2026-04-28):** v1 used single
  uniform scale to put alpha bbox at walk-alpha (89 gp), but the
  chibi BODY proper inside that alpha was only 77.77 gp at gameplay
  scale (cap rod takes ~12gp of vertical alpha space). User reported
  idle "전체적으로 좀 작아 보임" — same root cause as the attack
  v9→v10→v11 chibi-face problem. v2 applies an additional 1.075x
  uniform upscale on top of v1 (which was already a single-scale
  variance-preserving fit), bringing chibi body to ~88 gp at
  gameplay scale. The breathing variance (3.94 gp head bob) is
  preserved because the upscale is uniform across all 8 cells.
  Backups: c1 raw + v1 baseline at `.tmp/dalji_idle_v1_gemini/`,
  v1 pre-v2 backup at
  `.tmp/dalji_idle_whip_v2_tune/dalji_boss_idle_v1_pre_v2_backup.png`.
- **Current Stage 1 Dalji paengi (top-whip strike) canonical concept
  (v1 c1 accepted, Gemini one-shot full sheet, 2026-04-28):** when
  the boss activates the 팽이치기 (top-spinning) skill — existing
  pingfighter.py `activate_spinning_top()` at line ~116257 — the
  0.6 sec / 36-frame `whip_animation_timer` window plays a strike
  sequence: ready -> wind-up overhead -> swing down + forward to
  CRACK the white string toward the ground -> follow-through with
  dust -> recovery -> ready. Asset spec:
  `assets/dalji_boss_paengi.png`, 1536x1024 PNG, 4x2 grid, cell
  384x512 — same layout as all other Dalji sheets. 8 frames, F5 is
  the strike apex (white string at maximum extension as a sharp
  crack/snap shape). Front-facing in every frame; no left/right
  mirroring. Identity locks (matching walk pair, all other Dalji
  sheets): brown bun + side hair locks, brown bangs (NO headband),
  single red hibiscus flower on character RIGHT side of head
  (viewer-LEFT in front view), small flat black sangmo cap with
  thin rod and small white sangmo ribbon (separate from the long
  white STRIKE string she's swinging — two distinct white elements),
  retro brown chibi eyes (concentrated/focused expression in strike
  frames), black sleeveless vest + red/yellow trim over WHITE long-
  sleeve undershirt, red sash, white pants, brown shoes, drum +
  drumsticks (drum stays on hip — drumsticks NOT used for this
  skill, the wooden rod + white string is the weapon).
  **Per-cell 1.16x chibi-face upscale + per-cell feet anchor.**
  Pre-scale chibi gp 75.96 (walk-alpha -14.6%); post-scale chibi
  gp 91.60 (walk-alpha +2.93%, family-consistent with idle v2 /
  whip v2 / victory v2 — all in 88-93 gp range). Per-cell anchor
  preserves natural feet variation across strike poses.
  **Runtime mapping — external timer-driven, no internal sprite
  state.** Same dash-style external pattern as stun: state on the
  sprite class is `frames_paengi`, `_scaled_frames_paengi`,
  `paengi_total_frames=8`. NO `is_paengi` flag, NO `trigger_paengi()`,
  NO `clear_paengi()`. Activation lifecycle is owned entirely by the
  existing global `whip_animation_timer` in pingfighter.py (counts
  from 36 to 0 over 0.6 sec). The pingfighter.py Stage 1 Dalji
  render branch (between dash and stun overrides) checks
  `if whip_animation_timer > 0` and substitutes
  `stage1_boss_sprite.get_paengi_frame(timer, 36, scale_size)`. The
  getter maps timer countdown to frame index via
  `progress = 1 - timer/36 → idx = int(progress * 8)`. Returns None
  on missing sheet or timer<=0 for graceful fallback.
  **Priority chain at runtime (UPDATED with paengi)**: defeat >
  victory > stun > dash > **paengi** > whip > walk/attack/turn >
  idle.
  Backups: c1 raw + nukki + scaled at `.tmp/dalji_paengi_v1_gemini/`.
- **Offline nukki is a runnable CLI.** The algorithm lives in
  `.claude/skills/sprite-generation/remove_bg.py` and runs as
  `py .claude/skills/sprite-generation/remove_bg.py <src.jpeg> <dst.png>`.
  The in-class JPEG cleanup inside sprite classes is a runtime safety
  net only; the offline PNG is the source of truth.
