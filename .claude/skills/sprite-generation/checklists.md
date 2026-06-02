# Sprite Sheet QA Checklists — Reject / Regenerate Criteria

Run these checks after any sheet generation + nukki. If any row fails,
**reject and regenerate**. Do not patch with post-processing.

---

## 0. AutoSprite source gate

Run this first for every new or regenerated sprite sheet, including boss /
character sheets, player sheets, runtime VFX sheets, and animated item / perk
sheets.

| # | Check | Pass |
|---|---|---|
| 1 | Final sheet source frames were generated through AutoSprite MCP | yes |
| 2 | AutoSprite source/job ID or downloaded source path is recorded in the handoff/QC notes | yes |
| 3 | Gemini, FLUX, built-in imagegen, local interpolation, old 8-frame anchors, or runtime drawing were not substituted as the final sheet source | yes |
| 4 | Any frame-count expansion/reduction, mirroring, cleanup, or layout change was deterministic post-processing from AutoSprite-derived frames | yes |
| 5 | If AutoSprite was unavailable, production stopped for MCP repair or explicit user approval before any fallback was used | yes |

Fail any row -> do not ship the sheet as final. Regenerate with AutoSprite or
document the explicit user-approved exception.

---

## 0.1. Real-ESRGAN upscale gate

Run this whenever the user asks for "upscale", "upscaling", "hires",
"업스케일", "업스케일링", or "real / Real-ESRGAN처럼" on any bitmap asset:
item icon, HUD art, boss / character sprite, Live2D-style sheet, runtime VFX,
or animated item / perk sheet.

| # | Check | Pass |
|---|---|---|
| 1 | The request was treated as actual Real-ESRGAN asset processing, not as a runtime draw-scale / Godot import-filter / CSS-scale / simple-resize request | yes |
| 2 | The local Real-ESRGAN executable was used: `tools/realesrgan/realesrgan-ncnn-vulkan.exe` | yes |
| 3 | The model and scale were recorded in the manifest / handoff; default is `realesr-animevideov3` with `-s 2` unless the user specifies another scale | yes |
| 4 | Transparent PNGs were upscaled by RGB + alpha separation: alpha-bleed or safe matte RGB input -> Real-ESRGAN RGB upscale -> source alpha resized and recombined | yes |
| 5 | Sprite sheets / animation sheets were split by source cell or frame, upscaled consistently, and reassembled into the same grid / frame order with updated cell size metadata | yes |
| 6 | The result dimensions match the intended scale, and transparent corners / alpha bbox / per-cell edge-touch checks were rerun on the upscaled asset | yes |
| 7 | Runtime loaders, manifests, tests, and previews point at the Real-ESRGAN asset when the upscaled version is the accepted runtime asset | yes |

Fail any row -> do not call the upscale done. Do not substitute imagegen,
Gemini, FLUX, local interpolation, or ordinary resize as the final upscale
unless the user explicitly approves that exception after Real-ESRGAN is
blocked.

---

## 0.4. Character Live2D source-art chroma-key gate

Run this before accepting any character Live2D source illustration / 원화 /
full-body anchor that will later need nukki, rigging, sheet generation, or
runtime cutout use.

| # | Check | Pass |
|---|---|---|
| 1 | The generation prompt required a perfectly flat solid chroma-key background: default `#ff00ff` magenta, or `#00ff00` green when magenta conflicts with the character palette | yes |
| 2 | The prompt explicitly forbade black / white / dark studio / gradient / scenic / checkerboard / transparent-looking backgrounds for the raw source | yes |
| 3 | The chosen chroma-key color does not appear in the character, costume, props, glow, VFX, eyes, hair accents, or UI-facing motif | yes |
| 3b | The chroma-key color is not even hue-ADJACENT to a major character color. A pink / rose / red-violet character must use green (`#00ff00`), NOT magenta — pink is too close to magenta and removeBg leaves a pink/magenta rim. A green / lime character must use magenta. Hue-adjacency causes fringe even when the exact key color is absent | yes |
| 4 | The background is one uniform color to every canvas edge: no shadow, floor plane, rim-light spill, texture, compression haze, glow wash, or vignette | yes |
| 5 | Full body, hair tips, weapons, props, hoverboards / mounts, and effects are fully inside the canvas with generous margin; nothing touches the edge | yes |
| 6 | The accepted handoff keeps both the raw chroma-key source and the cleaned alpha PNG, and records key color plus removal / cleanup method | yes |
| 7 | The cleaned PNG has an alpha channel, transparent corners, a non-edge-touching alpha bbox, and no visible magenta / green fringe on dark and light preview backgrounds | yes |
| 8 | If this source becomes an AutoSprite `upload_character` base, the uploaded image is a CLEAN transparent (already-nukki'd) cutout OR a perfectly flat key — never a dirty / non-flat / hue-adjacent magenta. A dirty-key or hue-adjacent base makes EVERY generated motion sheet re-introduce fringe at the removeBg step, sheet after sheet, no matter how good the prompt is | yes |

Fail any row -> do not treat the source art as a production Live2D anchor.
Regenerate on a proper chroma-key background, redo the nukki pass, or despill
to a clean transparent base before animating, upscaling, or wiring the asset.

Recovery for an already-built character whose base was a dirty / hue-adjacent
key: do NOT keep regenerating motion sheets from it and fighting fringe in
post. Despill the source to a clean transparent cutout, tight-reframe it to
the established base footprint, and `upload_character` it as a NEW character;
generate the motion sheets from that clean character instead. Reference case:
Maribo (pink dolphin) read lower-quality than Lunabi (dark-purple bat) purely
because maribo's v003 source was a NON-FLAT magenta (corners R218-235 / G10-36
/ B185-209) and pink is hue-adjacent to magenta, so removeBg left a magenta /
pink rim on every sheet; Lunabi's flat `#ff00ff` source + dark body had no such
problem. Fixed by despilling v003 to a clean transparent base and re-uploading
as a new character before generating the click-reaction sheet.

---

## 0.5. Character-select Live2D card loop gate

Run this for character-select cards, standing previews, Live2D-style UI
loops, and any sheet whose main job is a polished menu presentation rather
than a one-shot gameplay attack.

| # | Check | Pass |
|---|---|---|
| 1 | The generation route fits the framing goal: use `create_asset` / `animate_asset` first when a fixed card crop or bust / thigh crop must be preserved; use `upload_character` / `generate_spritesheet` only when full-body reinterpretation is acceptable | yes |
| 2 | The prompt designs the loop from the start: small cyclic motion, natural return to start, no one-way attack finish pose, no camera turn, no side-profile drift | yes |
| 3 | Do not "solve" a one-way action by forced ping-pong unless the user explicitly accepts that mechanical rebound; if it looks artificial, regenerate with a loop-first prompt | yes |
| 4 | If a blade, jetpack flame, hair, coat, or other large secondary element moves, the path returns to the first pose organically instead of teleporting or reversing at a visibly hard pivot | yes |
| 5 | AutoSprite result metadata was checked after generation: `frameCount`, `columns`, `frameWidth`, `frameHeight`, and actual PNG dimensions match the intended runtime grid | yes |
| 6 | If AutoSprite returns 49 frames / 7x7 after a 64-frame request, record that source and only expand deterministically from AutoSprite-derived frames; do not present non-AutoSprite interpolation as a new source generation | yes |
| 7 | First/last loop continuity was measured: compare `frame0 -> frame1` against `lastFrame -> frame0`; the loop seam should be near a normal adjacent-frame delta, not several times larger | yes |
| 8 | Visual playback was inspected in motion, not only as a full sheet thumbnail; full-sheet grid view is not enough to prove a seamless Live2D-style loop | yes |
| 9 | Every frame has transparent corners and zero alpha on all cell edges; if the moving weapon/effect touches an edge, make a safe inset version or regenerate with more margin | yes |
| 10 | Transparent source padding is allowed for AutoSprite / nukki safety, but runtime rendering must trim transparent source bounds so the card character does not appear shrunken | yes |
| 11 | Runtime fallback order is explicit: accepted loop sheet -> previous safe loop / motion sheet -> static cutout -> older legacy sheet, so the card never breaks when a new PNG fails to load | yes |
| 12 | Godot import and smoke checks ran after adding the PNG / `.import`: headless load plus the focused character-select smoke test or equivalent | yes |
| 13 | Interior transparency holes were checked on a loud contrast background, especially hair-to-jetpack / hair-to-weapon gaps; no gray/white matte islands remain inside the silhouette | yes |
| 14 | For long chained card loops such as `49 + 49 + 49`, do not merely concatenate independent completed loops; generate each segment with the same first-frame and last-frame pose anchor so the segment seams share a real neutral pose | yes |
| 15 | Prefer the uploaded original transparent pose as the shared anchor for chained card loops. A newly generated anchor pose can improve numeric seam continuity but may bake in card frames, backgrounds, borders, or lighting that are not part of the cutout | yes |
| 16 | Measure chained-loop segment seams separately, especially `A49 -> B1`, `B49 -> C1`, and `C49 -> A1`. Keep a seam preview strip and numeric diff notes in the handoff; reject or re-anchor if the boundary reads as a cut | yes |
| 17 | For any high-frame Live2D-style loop at 49 frames or more per segment, the final runtime timeline must return to the starting pose naturally: `lastFrame -> frame0` should be seamless, and chained `49 + 49` / larger loops must share the same neutral start/end anchor unless the user explicitly accepts a visible one-shot finish | yes |
| 18 | When **regenerating** a loop for more / different motion (not a first build), the final shipped sheet's frame-to-frame motion was **measured against the previous sheet** (e.g. mean per-cell delta of `frame_i` vs `frame_0`), not assumed from the manifest's source label. A reused prep / repack script with a hardcoded source path (`RAW = '...'`) can silently re-process the OLD frames, shipping a rescaled sheet whose **motion is unchanged** while the manifest claims the new AutoSprite source. Reference failure: a `v4_steady_head_size_matched` cut-in manifest named the steady-loop spritesheet but reused the v3 `prep_cells.py`, so it re-upscaled the low-motion v3 frames (max frame-diff stayed 7.5) and the in-game cut-in still read as a static picture only floating up/down. Pass = measured motion actually changed in the intended direction | yes |

Fail any row -> do not ship the card loop as final. Regenerate from a
loop-first AutoSprite prompt or document the accepted exception in the
handoff.

---

## 0.6. Character-select confirm click Live2D one-shot gate

Run this for character-select click / confirm Live2D-style one-shots such as
Smasher and Viper confirm animations. This is separate from the idle card loop
gate because the first-frame handoff, voice timing, and one-shot finish are the
main failure points.

| # | Check | Pass |
|---|---|---|
| 1 | The accepted click sheet starts from the current idle card pose / crop language, not from an unrelated reinterpreted pose | yes |
| 2 | Idle -> click alignment was checked in the actual runtime renderer, including `trim_rect`, `stage_scale`, and `stage_x/y_offset_ratio`; raw cell centering alone is not enough | yes |
| 3 | The click first frame does not jump left/right/up/down against the idle Live2D preview when clicked; if it does, fix the runtime offset or regenerate from a better idle anchor before sign-off | yes |
| 4 | Prefer a unified idle-to-click one-shot generated from the accepted idle pose. Do not concatenate unrelated `idle loop + transition + click` segments unless the user explicitly accepts the stitched feeling | yes |
| 5 | If any segments are chained, every seam is measured separately (`idleLast -> clickFirst`, `A49 -> B1`, `B49 -> C1`, etc.) and a seam preview strip plus numeric notes are kept in the handoff | yes |
| 6 | For mouth / voice confirm shots, the prompt asks for visible mouth-shape motion during the spoken syllables; a tiny first-frame mouth twitch does not count as lip motion | yes |
| 7 | Voice sync was tested against the animation: `confirm_intro_voice_delay` starts near the intended mouth-open frames, and the line does not finish before the readable mouth motion begins | yes |
| 8 | Voice mix is part of acceptance: current `confirm_intro_voice_volume_db` is checked in the character-select screen and is not judged only from the raw mp3 loudness | yes |
| 9 | The selected voice preset is saved with runtime asset path, source audio path, voice ID, model ID, seed, settings, text / intended text, output format, SHA256, runtime delay, and runtime volume | yes |
| 10 | Frame-count expansion is explicit: record AutoSprite source frame count, repeat / hold factor, final rows / columns / frame count, frame interval, and min duration in the manifest or QC notes | yes |
| 11 | Expansion / reduction is deterministic from AutoSprite-derived frames only; do not present pitch, motion, or local interpolation as a fresh AutoSprite generation | yes |
| 12 | If 49-frame AutoSprite output is held to 98 or 147 frames, the user-facing handoff names that clearly so later iteration does not confuse it with newly generated motion | yes |
| 13 | The final sheet has transparent corners, no cell-edge alpha, a clean union alpha bbox, and no detached matte debris when viewed on a loud contrast background | yes |
| 14 | A precomputed trim rect is stored in runtime data for large click sheets so first playback does not rely on expensive or unstable first-use scanning | yes |
| 15 | Runtime data and tests agree on sheet path, columns, rows, frame count, interval, min duration, trim behavior, alignment offsets, voice path, voice delay, and voice volume | yes |
| 16 | Godot import was refreshed after adding or replacing PNG / MP3 files, and the `.import` files exist before claiming the asset is wired | yes |
| 17 | A focused character-select smoke test or equivalent proves the click intro can start, lock the selection screen, load the sheet / voice, and prewarm both assets | yes |
| 18 | The final handoff states whether the click sheet is a new unified generation, a deterministic hold-expanded sheet, or a user-approved stitched exception | yes |

Fail any row -> do not ship the confirm click Live2D one-shot as final.
Regenerate from a better idle-anchored AutoSprite prompt, retune runtime
alignment / voice timing, or document the explicit user-approved exception.

---

## 1. Identity lock (SKILL.md Section 8.2)

| # | Check | Pass |
|---|---|---|
| 1 | Hair color identical to walking sheet (no hue/saturation drift) | yes |
| 2 | Hairstyle / silhouette identical (curls, braids, length, bangs) | yes |
| 3 | Face impression reads as the same character at a glance | yes |
| 4 | Eye color and shape unchanged | yes |
| 5 | Skin tone unchanged | yes |
| 6 | Body proportions (head-count) unchanged | yes |
| 7 | Outfit design + trim + colors unchanged | yes |
| 8 | Species / signature accessories (tail, horns, cap, ribbon, gloves, etc.) all present | yes |
| 9 | Overall impression reads as "same person, different action" | yes |
| 10 | Art-style rendering matches walking sheet | yes |

Fail any row -> reject and regenerate.

---

## 2. Body scale lock (SKILL.md Section 8.1)

| # | Check | Pass |
|---|---|---|
| 1 | Head size within +/-5% of walking sheet | yes |
| 2 | Torso size within +/-5% of walking sheet | yes |
| 3 | Pelvis / hip size within +/-5% of walking sheet | yes |
| 4 | Speed is conveyed only by pose, lean, trail, motion lines | yes |
| 5 | Effects (dust, flame, trail) extend outward but body itself does not grow or shrink | yes |

Fail any row -> reject and regenerate. Do NOT try to fix by rescaling in the
sprite class — per-sheet runtime rescale is explicitly forbidden in
AGENTS.md.

---

## 3. Palette drift prevention (SKILL.md Section 8.3)

| # | Check | Pass |
|---|---|---|
| 1 | No hair color drift (e.g. pink -> magenta) | yes |
| 2 | No tone drift (e.g. pastel -> saturated) | yes |
| 3 | No impression drift (e.g. cute round face -> sharp mature face) | yes |
| 4 | No proportion drift (e.g. chibi 2-head -> semi-realistic 3-head) | yes |
| 5 | No outline-thickness drift (thick -> thin) | yes |
| 6 | No cross-sheet clarity drift (one sheet obviously cleaner / crisper than the others) | yes |
| 7 | No value-separation drift (one sheet muddy / washed out while another has clear face / trim read) | yes |

---

## 4. Front-biased walk acceptance gate

Run this section specifically for any human / chibi walk sheet that is
supposed to remain front-biased / front-facing in gameplay.

| # | Check | Pass |
|---|---|---|
| 1 | Stable left travel still reads as the boss facing the player, not as secretly looking left or right | yes |
| 2 | Stable right travel still reads as the boss facing the player, not as secretly looking left or right | yes |
| 3 | Hair mass / ribbon placement / hat tilt / cheek exposure do NOT pull the face into a persistent 3/4 read | yes |
| 4 | Eye placement / eye exposure do NOT make one side of the face read consistently more open in a side-biased way | yes |
| 5 | Shoulder / torso angle does NOT make the body feel turned to one side during stable walk playback | yes |
| 6 | Moving right does NOT feel like the boss is looking left | yes |
| 7 | Moving left does NOT feel like the boss is looking right | yes |
| 8 | Candidate walk is not more side-facing than the previous accepted walk | yes |
| 9 | Candidate walk is not being excused just because it is livelier / cleaner / more polished | yes |
| 10 | If the user asked for "frontal walk + hop on turn," the walk remains frontal and the pivot accent is not smuggled into stable walk frames | yes |

Fail any row -> reject and regenerate. Do NOT try to fix with runtime
facing remaps, blind sprite flips, or by redefining which direction uses
which frame set.

---

## 4.5. Separate L/R walk pair gate (current convention, SKILL.md §13.1)

The default walk-sheet deliverable is now a **separate left-walk sheet
+ separate right-walk sheet pair**, drawn natively per direction (no
runtime mirror flip). Run this section for any new walk brief.

| # | Check | Pass |
|---|---|---|
| 1 | Two separate files exist: `[name]_boss_walk_left.{jpeg,png}` and `[name]_boss_walk_right.{jpeg,png}` | yes |
| 2 | Each file is 8 frames in a 4x2 grid (NOT a 6-frame, NOT a single combined L+R sheet) | yes |
| 3 | LEFT sheet: every cell faces off-frontal toward viewer's LEFT; right shoulder slightly back, left shoulder forward | yes |
| 4 | RIGHT sheet: every cell faces off-frontal toward viewer's RIGHT; left shoulder slightly back, right shoulder forward | yes |
| 5 | Both sheets read as the SAME chibi character at the SAME scale (run §1 identity lock and §2 body scale lock comparing the pair, not just a single sheet vs walk anchor) | yes |
| 6 | Direction-asymmetric props stay on the SAME ANATOMICAL BODY SIDE in both sheets (mentally label each prop by character anatomy, then verify the prop appears on the matching anatomy side in both directions) | yes |
| 7 | Hair flower / ear ornament / hairpin appears on the same anatomical side of head in both sheets | yes |
| 8 | Instrument / weapon / tool carried on hip stays on the same anatomical hip in both sheets | yes |
| 9 | Sash, ribbon, hair, and cloth trails go OPPOSITE the motion direction in each sheet (left-walker trails right, right-walker trails left) | yes |
| 10 | Ribbon length is consistent across the pair (no asymmetric streamer where one direction has a much longer trail than the other) | yes |
| 11 | Walk energy matches across the pair (knee lift height, body bob amplitude, stride length) — one bouncy + one calm asymmetry visibly pops on direction change | yes |
| 12 | Both sheets pass the §8 composition hygiene checks (no grid lines, no borders, pure white background, etc.) | yes |
| 13 | Both sheets pass the §9 nukki acceptance (no halo, hard alpha edges, fragile-prop edges intact) | yes |
| 14 | Both sheet prompts came from the SAME prompt family (chibi-style lock, anti-grid wording, ribbon-length lock, clothing-color lock, prop-visibility lock all shared between the two prompts; only the facing direction and per-prop anatomical-side wording differ) | yes |
| 15 | If the user accepted one direction first, the second-direction prompt was generated by editing the accepted prompt's facing/anatomy clauses only, NOT a fresh independent prompt | yes |

Fail any row -> reject and regenerate the relevant sheet of the pair.
Single-sheet + runtime-flip is NOT an acceptable shortcut for any new
walk-sheet brief — that pattern silently inverts direction-asymmetric
props onto the wrong anatomical side and is the bug this convention
prevents.

If only one sheet of the pair drifts, regenerate THAT sheet against the
accepted partner using the partner's exact prompt family (with facing /
anatomy flips). Do NOT rebuild both prompts from scratch unless both
sheets fail.

---

## 5. Gameplay-scale motion readability

| # | Check | Pass |
|---|---|---|
| 1 | Walk, attack, dash, turn, and victory share the same readability tier at gameplay size | yes |
| 2 | No single sheet looks obviously sharper, pinker, or cleaner than the rest in direct comparison | yes |
| 3 | Walk cycle still feels alive during left/right travel, not torso-frozen with only limb shuffle | yes |
| 4 | Whole-body rhythm survives downscaling: body bob, weight shift, hair / cloth / accessory motion still read | yes |

---

## 6. Attack trigger alignment (SKILL.md Section 8.4.1)

Run this section for contact-based strike / hit sheets, especially any
attack meant to connect with the ball.

| # | Check | Pass |
|---|---|---|
| 1 | Attack sheet has a clear prep -> impact -> recovery arc rather than only a late readable hit | yes |
| 2 | Early prep frames contain meaningful coil / intent, not dead-air posing | yes |
| 3 | One frame is a clearly readable impact frame that runtime can align with contact | yes |
| 4 | Sheet still reads correctly if runtime starts it slightly before predicted contact | yes |
| 5 | Sheet still looks natural under a SHORT, conservative pre-contact lead window rather than needing a very early trigger | yes |
| 6 | Visible downswing / chop does NOT complete before the ball arrives when using the intended anticipatory trigger | yes |
| 7 | The intended impact frame is documented in QA / hand-off when it is non-obvious | yes |
| 8 | If the sheet is supposed to be a snap hit with almost no prep, that choice is explicit rather than accidental | yes |

Fail any row -> reject / regenerate or at minimum document that the
sheet is a special-case instant-hit attack rather than a normal
anticipatory-trigger attack.

---

## 7. Turn sheet extras (SKILL.md Section 9)

| # | Check | Pass |
|---|---|---|
| 1 | Same character as walking sheet (identity lock) | yes |
| 2 | All eight fixed elements preserved | yes |
| 3 | Reads as a brief direction-change gesture, not a side-profile rotation chart | yes |
| 4 | Keeps the same front-facing / front-biased combat read as the walk instead of turning into a profile showcase | yes |
| 5 | Entry and exit frames connect cleanly back into the accepted walk | yes |
| 6 | Body scale within +/-5% of walking sheet | yes |
| 7 | Includes a boss-specific habit / accent (head lift, arm cue, knee lift, pivot, ribbon rebound, etc.) instead of generic filler acting | yes |
| 8 | Does NOT read like unrelated acting pasted on top of the walk cycle | yes |
| 9 | No angle labels / numbers / BLANK text printed into cells | yes |
| 10 | Peak transition frames do NOT read as face-clipped, forehead-cut, or vertically squashed compared to the accepted walk | yes |
| 11 | Raw cell -> inset crop -> trimmed frame -> gameplay-size comparison confirms the clipped-looking read is not already present before runtime | yes |

---

## 8. Composition hygiene (all sheets)

| # | Check | Pass |
|---|---|---|
| 1 | Pure flat white background #FFFFFF in every cell | yes |
| 2 | No grid lines, borders, dividers, or labels | yes |
| 3 | All cells equal size, character centered | yes |
| 4 | Character front-facing in every frame (except turn sheet) | yes |
| 5 | Foot / baseline position consistent | yes |
| 6 | Each character fills only 45-55% of cell height | yes |
| 7 | Generous empty margin around each sprite | yes |
| 8 | Shipped column / row count matches the renderer's `SHEET_COLS` / `SHEET_ROWS` constants verified by pixel-scanning character centers in the actual PNG — do not trust the prompt-side spec alone. Generators can return N-1 chars per row (or shift bottom row by one cell) while the renderer still slices N cols, causing visible neighbor-cell bleed during animation. If the shipped layout disagrees with the renderer, regenerate the sheet to match the renderer's grid before promotion; do not "fix" by re-tuning runtime constants to the shipped layout, since that hides the asset-side regression for future bosses. | yes |

---

## 9. Nukki acceptance

| # | Check | Pass |
|---|---|---|
| 1 | No visible white halo around outline at 100% zoom | yes |
| 2 | Interior highlights (horns, gold trim, eyes) still opaque | yes |
| 3 | No blurred or feathered edges (hard alpha only) | yes |
| 4 | Both `.jpeg` and `.png` are committed (see SKILL.md Section 11.3) | yes |
| 5 | For a walk pair, BOTH `_walk_left.{jpeg,png}` and `_walk_right.{jpeg,png}` are committed | yes |

---

## 10. Cross-boss size standard (Stage 3 Menhera body class)

The Stage 3 Menhera in-game body class is the STANDARD size for every
petite human / chibi boss, not a "preferred baseline". Run this section
at Godot runtime promotion time, before declaring integration done.

| # | Check | Pass |
|---|---|---|
| 1 | The owning Godot boss renderer / catalog records explicit canvas, source-rect, stage-scale, frame-count, and cadence metadata for the sheet | yes |
| 2 | Menhera's legacy `176 x 88` parity target is used as the body-read reference, or an equivalent Godot canvas / scale target is documented | yes |
| 3 | Legacy Python class-default values (Menhera `79 x 88`, Tauren `83 x 92`, Honglyeon `100 x 88`, similar) are NOT copied into the new Godot boss configuration | yes |
| 4 | Side-by-side gameplay-size comparison vs Menhera shows matching body class: head height, face size, torso silhouette all read at the same tier | yes |
| 5 | The new boss does NOT read materially smaller than Menhera (would have looked too small at gameplay scale) | yes |
| 6 | The new boss does NOT read materially larger than Menhera (would have looked oversized at gameplay scale) | yes |
| 7 | If the boss IS an explicit size-class exception (large-frame, tall vertical-silhouette, or design-led oversized / undersized), the override is documented per-boss in `CLAUDE.md` AND in the implementation / handoff note | yes |
| 8 | Visible body fill ratio inside the canvas matches Menhera's class (a sheet whose figure fills 60% of canvas reads smaller in-game than one filling 80%, even at the same canvas dims) | yes |

Fail any row -> the integration is NOT done. Either retune the Godot
renderer/catalog metadata to hit the Menhera tier, regenerate the source
sheet so its figure fills the canvas correctly, or document an explicit
size-class exception per the rule. Do NOT ship a body-size mismatch silently;
sheet sizes drifting across bosses is exactly the failure mode this
rule prevents.

---

## Global reject rule

If the sheet "looks like a different character" in any direct comparison
with the walking sheet, **reject and regenerate**. Identity drift is not
fixable downstream.

If one sheet reads materially cleaner, crisper, pinker, or more legible
than the rest of the same motion set at gameplay size, reject the weaker
sheets and regenerate them. Mixed clarity tiers are not acceptable.

If a turn workflow drifts back toward a side-profile / multi-angle
rotation chart, restate the front-biased direction-change gesture brief
and regenerate. Do NOT promote angle coverage to the goal when the walk
itself is front-facing.

If a turn frame looks face-clipped or forehead-cut at gameplay size, do
NOT assume runtime crop is the cause. First compare raw cell -> inset
crop -> trimmed frame -> gameplay-size render. If the bad read already
exists before runtime fitting, reject / regenerate the art instead of
asking Codex to keep shrinking the turn sheet.

If a new walk sheet is more side-biased than the previous accepted walk,
it does NOT become the new canonical even if it is more lively, more
polished, or technically cleaner. Keep or restore the older accepted
walk until a replacement passes the Section 4 frontal-read gate.

If a walk sheet fails the frontal-read gate, do NOT hand it off to Codex
as runtime work. The correct action is reject / regenerate / rollback on
the asset side.
