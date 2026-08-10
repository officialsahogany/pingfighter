# Sprite Sheet QA Checklists — Reject / Regenerate Criteria

Run these checks after any sheet generation + nukki. If any row fails,
**reject and regenerate**. Do not patch with post-processing.

---

## 0.00. Pre-flight: edit the asset the user ACTUALLY sees

Before regenerating / repacking / "fixing" any reaction or cut-in asset,
trace the runtime consumer and confirm WHICH file the user's described visual
maps to. One user phrase can map to DIFFERENT files per character, and an
obvious-looking catalog mapping can be unused for the very character you are
fixing. Editing the wrong file wastes a full iteration and the user still
sees no change.

Reference failure (lingpet click/cut-in reactions, 2026-06-21): a request to
fix maribo's "클릭 라투디" was first applied to `maribo_click_live2d_pingpong_98f.png`
(the `click_reaction_anim` catalog key) — but that key is consumed only by the
character-info panel loader (`PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID`) for SIX pets
(lunabi/nekuring/monkeyring/onimaru/orosha/rahoset) and is **unused for maribo**
(maribo's panel falls back to `cutin_art`). What the user actually saw was the
**acquire cut-in DISMISS** (`획득 라투디 → 클릭`), which for maribo is
`maribo_cutin_dismiss_anim.png` resolved via `lingpet_acquire_cutin_overlay_host`'s
`FALLBACK_CUTIN_DISMISS_SHEET_PATH` (maribo has NO catalog `cutin_dismiss_anim`
key), at the 5x5/25f default grid — a different file, grid, and code path than the
shared `click_live2d` sheet that koyora/nekuring reuse for their dismiss.

Pre-flight checklist:
- Grep the asset filename and the catalog visual-key across `godot/scripts` and
  confirm a real consumer reads it FOR THIS character (not just that it exists in
  the catalog). A key present in the catalog but absent from every consumer's
  per-pet allow-list is dead for that pet.
- Identify the exact screen/flow the user named (acquire cut-in reveal vs
  acquire-dismiss vs in-battle companion click vs character-info panel). These
  are SEPARATE assets: `cutin_anim` (reveal), `cutin_dismiss_anim`/FALLBACK
  (dismiss), `companion_click_reaction_anim` (battle), `click_reaction_anim`
  (panel, 6 pets only).
- Watch for FALLBACK_* constants in the host: a pet with no catalog key may still
  draw a dedicated fallback file. Check the host's resolve/fallback path, not just
  the catalog.
- When in doubt, confirm the displayed grid (cols/rows/frame count) in the host
  matches the file you intend to edit before touching it.

Paired cut-in match contract (reveal <-> dismiss, or any two clips that play
back-to-back as ONE shot): the second clip must match the first in SIX axes —
size, position, motion-continuity (start from the first clip's hold pose),
TEXTURE, and COLOR. Texture and color are easy to miss and were the last
regression in the maribo acquire-cutin work (2026-06-21):
- TEXTURE: process the new clip with the SAME upscale model as the reference
  clip. The maribo reveal used `realesr-animevideov3` (smooth/painterly);
  rebuilding the dismiss with `realesrgan-x4plus-anime` (crisp anime lines) read
  as a different surface even at matched size/color. Match the model, don't mix.
- COLOR: a separate AutoSprite generation of the same character can land on a
  different color cast (the dismiss came out paler/cooler than the reveal). Do
  NOT fix this with a value-contrast punch (that boosts past the reference and
  still mismatches) — color-MATCH it: Reinhard transfer of the new clip's body
  mean+std to the reference clip's body mean+std (clamp the std ratio ~0.7-1.4),
  one fixed transform for all frames. Verify by measuring alpha-masked body
  avg-RGB of both clips, not by eyeballing on a dark editor bg.
- Drop any independent "punch"/grade on a clip that must match a reference — the
  reference defines the target; matching means matching its statistics.

Effective-fps contract for runtime-played animation sheets (frame count vs
duration): a sprite-sheet animation's smoothness is `frame_count ÷ (playback_seconds
× action_portion)`, NOT the render fps. A LONG-duration clip needs MANY frames or it
plays at single-digit fps and reads "뚝뚝/choppy" even at 60fps render. When
downscaling / decoupling / re-authoring an animated sheet, preserve the frame count
relative to its playback window — do NOT cut frames for VRAM without checking the
effective fps. Reference regression (2026-06-24): the lingpet acquire-cut-in dismiss
for koyora/nekuring/monkeyring/orosha was decoupled from a 98-frame click sheet to a
small dedicated 25-frame sheet (to shrink hatch VRAM), but it plays over 3.35-4.25s
→ 25 ÷ (3.9×0.88) ≈ 7fps = choppy. Two WRONG fixes were tried first: (a) shrinking
the texture size_limit (that's the VRAM/upload-hitch lever, orthogonal to anim fps),
(b) next-frame alpha cross-fade blending (hid nothing, added a 6-9Hz translucent
flicker). The RIGHT fix kept the long duration AND restored smoothness AND kept VRAM
low: regenerate the dedicated dismiss at the FULL 98 frames but small cells
(7168×3584, 14×7, 512px) + VRAM compression (`compress/mode=2`, `vram_texture=true`)
→ 27fps at ~24MB (lower than the 56MB 25-frame lossless). Seal it with a smoke that
ASSERTS the computed effective fps (`frame_count ÷ (seconds × action) ≥ ~22`), not
just the sheet dims — that locks the root cause against future frame cuts /
duration stretches (`lingpet_egg_runtime_smoke` dismiss block is the reference).

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

Model / order refinement for tight STILL anime art (close-ups, cut-in
busts, icons) — distinct from animated VFX frames:

- **Never Lanczos-upscale the crop BEFORE Real-ESRGAN.** If a close-up
  magnifies a small native region (e.g. a face cropped out of a 1024
  full-body sprite cell), pre-scaling it up with Lanczos softens it and
  Real-ESRGAN can no longer recover crisp lines. Crop the NATIVE region,
  run Real-ESRGAN on the native pixels, then DOWNSCALE into the final
  cell. The only enlargement should be the ESRGAN pass; everything after
  is a sharp downscale.
- **For still anime art prefer `realesrgan-x4plus-anime -s 4` over the
  `realesr-animevideov3` default.** The animevideo model is tuned for
  video frames and visibly smooths still line art; the x4plus-anime model
  keeps eyes / hair / outlines crisp. (The `-s 2` animevideo default
  stays correct for animated VFX / motion sheets.) The Viper phantom-kick
  face close-up v6->v7 is the reference: v6 (Lanczos pre + animevideo x2)
  read soft/"구려"; v7 (native crop -> x4plus-anime x4 -> downscale) was
  visibly sharper at the same framing. Record the model + order in the
  manifest.
- **Detail is still capped by native source resolution.** A tight
  close-up only has the source region's real pixels; the sharp model
  improves lines but cannot invent face detail. If maximum crispness
  matters more than tightness, widen the framing (more native pixels per
  displayed area) or regenerate the source at higher native detail.
- **If the final content size is <= the native AutoSprite cell, do NOT
  Real-ESRGAN at all — use a plain near-native downsize.** Real-ESRGAN
  only earns its keep when you are magnifying (final displayed pixels >
  native pixels for that region). When the source cell already meets or
  exceeds the final cell content (e.g. a 1024 AutoSprite cell repacked
  into a 968 content area), an "upscale x2 then downscale back below
  native" pass gains zero real resolution and only adds the model's
  smoothing plus unsharp ringing — a soft interior + crunchy edge halo
  that reads as the uncanny "AI-upscaled" look. Repack near-native
  instead: premultiplied-alpha resize the native cell straight down to
  the content size (the Koyora / Lunabi lingpet click-reaction pipeline),
  optional single MILD unsharp only. Reference failure: `maribo_click_live2d_pingpong_98f`
  was the lone lingpet click sheet pushed through `realesr-animevideov3`
  x2 (1024 -> 2048 -> 968) + strong unsharp on top of an already-soft
  native render; it shipped looking visibly "different" from its
  natural-soft siblings and was re-repacked near-native on 2026-06-20.
- **Sibling-family sharpness-band QA (sheets that ship as a SET).** When
  an asset belongs to a family rendered the same way and shown side by
  side over time (lingpet click reactions / cut-ins, per-character skill
  cut-ins, a boss motion set), do not judge sharpness in isolation — an
  asset that is the lone Real-ESRGAN'd / lone heavily-unsharped member
  reads "off" even if it looks fine alone. Measure an objective
  edge-energy proxy (variance-of-Laplacian over the alpha-masked,
  size-normalized content) for the new asset AND a few shipped siblings,
  and confirm the new one lands inside the sibling band rather than
  spiking far above it. Reference: the maribo click sheet measured ~2377
  vs the natural-soft peer band (lunabi 1051 / nekuring 1158); the lone
  spike WAS the "different quality" the player noticed. A genuinely
  detail-dense subject (koyora ~2340, busy fox-miko) may legitimately sit
  high — judge against same-style siblings, and prefer raising soft
  members by regenerating a higher-detail native source over faking edge
  energy with Real-ESRGAN + unsharp.
- **"Looks low quality" is not always a sharpness problem — measure
  before you sharpen.** When a finished asset reads "graphics not good,"
  do NOT reflexively reach for upscaling / Real-ESRGAN / unsharp. First
  measure the asset's edge energy against (a) its OWN source illustration
  and (b) same-style siblings. If the asset already matches its source's
  sharpness (and sits in the sibling band), the complaint is NOT
  resolution/sharpness — sharpening can only over-process it. The usual
  real culprit for a pale / pastel / low-contrast subject is weak VALUE
  CONTRAST (light-on-light, e.g. pink body + pale cyan armor) reading
  flat next to high-contrast siblings (dark/saturated subjects). The fix
  is a value-contrast / saturation / local-contrast pass (RGB only, alpha
  preserved), NOT a sharpen. Reference: the maribo click sheet measured
  1023 vs its own source 1055 and peers ~1050-1158 — already at source
  sharpness — yet still read "not good"; a user-approved mild
  contrast/saturation "punch" (contrast ~1.2 / sat ~1.18 / gentle local
  contrast), not any upscale, resolved it. Keep the punch tasteful: a
  strong boost reads candy/artificial and fights a pastel pet's identity.

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

**Scope limit — the flat-magenta rule is for SELF-KEYING pipelines only.**
When the animation matte comes from AutoSprite `removeBg` (a segmentation
model, not a chroma keyer), the key color buys nothing and the magenta
background becomes the SPILL SOURCE: the video model paints magenta
reflections into hair gaps and edge pixels that removeBg then keeps at
full opacity, unreachable by any downstream cleanup. Measured on Mika
iofit (4 takes, same anchor/prompt): rim mottle 5,234 / 5,048 / 4,783 px
(magenta anchor — turbo t1/t2/pro; tier and retakes do NOT help) vs
**800 px on a near-black `#020202` anchor (−85%)**, interior noise −17%,
and the purple silhouette outline visible in every magenta take is simply
absent (take_compare_board). For removeBg-matted animation anchors,
composite the clean transparent cutout over near-black (or a neutral tone
far from the character's palette — avoid near-black only if the character
is itself near-black); keep flat `#ff00ff` for pipelines that key the
background themselves (chroma_key.py, strict-magenta hard keying).

The near-black anchor has its OWN failure mode to gate: removeBg keeps
near-black background chunks as opaque character pixels ("ink blobs") in
face/ponytail gaps, neck-side pockets, and sleeve-body gaps — RGB median
[2,2,4] = pure background, 1.4–3.4k px/frame measured on Mika. It is
deterministically removable because the blobs are LARGE near-neutral
areas (character darks differ: navy hair [61,61,71], line art = thin
strokes protected by an area gate): seed on `max(RGB) < 12` components
(area-gated), geodesic-grow over a dark-mix domain, alpha→0. Tune the
growth by DISTANCE-from-core, never by loosening the color domain
globally — a loose dark scan (luma<40, sat<30) lights up eyes, skirt
folds, shield art and glove shadows (measured false-positive bomb),
while core-seeded growth keeps interior art safe because it is far from
any core. Mika shipped values: core ≥24 px, grow 8 steps over
`luma < 34 & sat < 26` (the first pass at 4 steps / 28 / 20 left mixed
residue bands in ponytail gaps and neck-side pockets).
Two ordering traps: run the removal AGAIN at the very end of the clean
(the feather resurrects removed borders as >128 semi-alpha with
still-near-black RGB — measured 126 px residue), and make the QC gate
re-run the SAME detector on the FINAL cleaned frame (residue > 0 =
build failure), mirroring the visible-magenta gate.

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

## 0.4b. Live2D matte keying gate (build post-process)

§0.4 governs the SOURCE art. This gate governs the build script that turns an
AutoSprite sheet into a runtime sheet. Different failure class, different owner.

| # | Check | Pass |
|---|---|---|
| 1 | The chroma removal is a CONTINUOUS unmix (`alpha *= 1 - keyness`), never a binary kill (`alpha[keyed] = 0`) | yes |
| 2 | The key strength `T` is ESTIMATED PER FRAME, not a hardcoded constant | yes |
| 3 | Attenuation is applied globally under a palette size-gate — NOT restricted to a distance band from the silhouette | yes |
| 4 | `visible_magenta_count == 0` at the cleaned source-cell stage (gate, not a report) | yes |
| 5 | No opaque erosion: pixels at `alpha >= 245` before the change are still `>= 200` after | yes |
| 6 | Grid-phase clustering `R < 0.25` on the upscaled alpha (see below) | yes |
| 7 | The upscaled alpha ramp is REQUANTIZED (SDF band) to match the reference character's on-screen ramp — measure semi-alpha run lengths at real display scale and match the accepted-clean reference (Io: median 2 / p90 4 px). Continuous unmix alone PRESERVES removeBg ultra's mushy 4–9px matte, which reads as a body-colored fuzz band ("번짐") once the hard kill that was accidentally trimming it is removed. Fix = subpixel SDF (0.5 level-set preserved) upscaled then requantized with a band tuned by screen-scale eyeball QA (Mika: band 1.8 → ramp 5/12 → 2/5, area −0.004%); too-narrow bands notch thin hair wisps | yes |
| 8 | SDF hardening's side effect is handled: narrowing the ramp PROMOTES formerly-faint semi-transparent rim contamination to full opacity (the wide-matte era's nearest-solid RGB fill grabbed flower/skin colors over thin hair — invisible at alpha 100–200, exposed as a peach/brown/purple mottle band once opaque). Counter as a PAIR: (a) bias the level-set slightly inward (~0.75 source px, silhouette −2% — the restrained version of what the old hard kill did), and (b) pull rim-band RGB (final-alpha basis, ~6.5px @1320) toward the nearest LOCAL interior color when Lab ab-distance > ~20 under a luma guard — local reference auto-protects flowers / red tassels / gold trim. Verify on a 1x + 4x screen-scale board (Mika: rimfix_final_board) | yes |

**Why binary kill is wrong.** A partially covered edge pixel is by definition
`observed = subject * a + bg * (1 - a)`, so it *is* partly key-colored. A
threshold test therefore matches most of the antialiasing band and deletes it.
Measured on Mika v8: 70–77% of the partial-alpha band erased, silhouette area
−5.4%, perimeter +15–25%, 239 thin components (hair tips, tassels) lost, and
100% of the pipeline's added temporal jitter traced to that one line.

**Grid-phase R** is the fingerprint. Take the subpixel x where the upscaled
alpha crosses 128 per row, fold it modulo the upscale ratio, and take the
circular-mean resultant length. A binary kill snaps edges onto the source grid
(Mika v8: 0.49 / 0.54); a continuous unmix does not (v9: 0.17 / 0.14).

**Never band-limit the attenuation.** removeBg leaves ENCLOSED background holes
(background visible through a gap between limbs) fully opaque, 78–81 px deep
inside the silhouette. A `distance <= N` guard skips them and revives visible
key color (measured 325–364 px/frame). The palette size-gate already protects
the character's own colors — that is what does the protecting, not the band.

**Do not remove the sub-pixel feather** (`GaussianBlur σ≈0.42`) while "cleaning
up" the keyer. Ablation shows it REDUCES frame-to-frame boil (128.8 → 142.5
when removed). The nearby `<=8 / >=247` clamps are measured no-ops; leave them.

**Matte acceptance gates must be motion-normalized.** An absolute
"quietest-tile wobble" threshold measures how STILL the take is, not how clean
the matte is — it rejects lively takes and passes near-frozen ones. Bucket by
actual motion (RGB temporal deviation of always-opaque interior pixels) and
compare wobble within a bucket.

**AutoSprite native resolution is 640×640 yuv420p.** `frameSize` above 640 is
pure upscale, and 4:2:0 means the chroma driving any key is effectively
320×320. Probed 2026-07-20: the `max` video tier is also 640×640 (97 frames),
so no tier buys a larger matte — do not spend credits re-testing this. Asset-path
tools (`animate_asset`, `generate_asset_spritesheet`) cap `frameSize` at 512,
offer no `compression` parameter, and have no `removeBg: "none"`; only the
character path (`regenerate_spritesheet`, free) exposes those.

Reference implementation: `preview_outputs/mika_hwangyeok_io_grade_source_v4/
build_io_grade_runtime_sheets_v9.py` (module docstring carries the full
measurement record).

---

## 0.5. Character-select Live2D card loop gate

Run this for character-select cards, standing previews, Live2D-style UI
loops, and any sheet whose main job is a polished menu presentation rather
than a one-shot gameplay attack.

| # | Check | Pass |
|---|---|---|
| 1 | The generation route fits the framing goal: use `create_asset` / `animate_asset` first when a fixed card crop or bust / thigh crop must be preserved; use `upload_character` / `generate_spritesheet` only when full-body reinterpretation is acceptable. This is not a soft preference — the character path's `idle`/`custom` kinds are SIDESCROLLER game-sprite grammar and will reinterpret a front-facing bust anchor as a side-profile full body with invented legs/boots (the `direction: "right"` field in the returned spritesheet metadata is the fingerprint; measured on Mika iofit 2026-07-20, both idle and custom). Character-path perks (`removeBg: "none"`, `compression: "none"`, frameSize up to 1024) do NOT justify switching routes for card loops | yes |
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
| 19 | Cell fill ratio is treated as the DOMINANT sharpness lever, before any matte-algorithm work: the anchor's subject fills ~85% of the upload canvas vertically (union-bbox across ALL frames must stay ≤ ~0.95 with zero edge-touch), and the motion prompt suppresses vertical excursions (`no zoom`, `no vertical rise`, prop action at chest height). Measured 2026-07-20: Io ships at 0.92 fill vs old Mika 0.59 — 1.57x subject pixels from the SAME 512 matte and pipeline is why Io reads clean; reframing Mika to 0.85 lifted on-screen subject 528→643px and cut idle rim contamination 896→225px. Do not spend credits on higher tiers or bigger frameSize chasing sharpness the framing already owns (native video is 640×640 at every tier) | yes |
| 20 | A click / reaction prompt animates ONE prop at a time. Asking for two simultaneous prop actions ("swing mirror + sweep shield") makes the model drop or morph one prop mid-take (measured: mirror deformed at f18 then vanished f24+); a single in-place verb ("shake the bell-mirror at chest height, shield stays still") preserves prop integrity AND the round trip. If the raw take already round-trips (low `mad(f0,f48)`), retime with a native even resample — do NOT fold it through the old forward+reverse ping-pong, which would double the gesture | yes |

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
| 7 | If the boss IS an explicit size-class exception (large-frame, tall vertical-silhouette, or design-led oversized / undersized), the override is documented in the focused boss runtime contract or asset manifest AND in the implementation / handoff note | yes |
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
