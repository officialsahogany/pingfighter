# Stage 7 Akamu Rigo Sprite Runtime Contract

Stage 7 Akamu Rigo uses a front-facing AutoSprite set derived from the
original Python Stage 8 identity. The live implementation target is the
repo-local Godot project.

## Asset root and authority

Accepted runtime assets live at:

`godot/assets/sprites/bosses/stage7_akamu/`

The per-sheet provenance, SHA-256 hashes, AutoSprite IDs, grid, and QA status
are authoritative in:

`godot/assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_sprite_manifest.json`

All nine sheets use the same runtime format: 1024x512 RGBA, 4 columns x 2
rows, eight row-major frames, and 256x256 cells.

| State | Runtime file | Direction / playback |
|---|---|---|
| Idle | `stage7_akamu_boss_idle.png` | front-facing loop |
| Walk left | `stage7_akamu_boss_walk_left.png` | native left movement loop |
| Walk right | `stage7_akamu_boss_walk_right.png` | native right movement loop |
| Attack | `stage7_akamu_boss_attack.png` | hand-sign / throw windup and recovery |
| Dash left | `stage7_akamu_boss_dash_left.png` | burst movement, native left |
| Dash right | `stage7_akamu_boss_dash_right.png` | burst movement, native right |
| Victory | `stage7_akamu_boss_victory.png` | round victory |
| Defeat | `stage7_akamu_boss_defeat.png` | standing to seated/slumped defeat |
| Stun | `stage7_akamu_boss_stun.png` | front-facing stagger loop |

Do not mirror the walk sheets at runtime. Akamu's high ponytail and silver
hairpin are direction-readable identity features, and the accepted left and
right motions are separate AutoSprite generations.

## Identity lock

The primary legacy reference is `assets/stage8walking.png`. Preserve:

- long scarlet high ponytail and side hair;
- small silver hairpin;
- red eyes and pale face;
- dark plum wrap-style ninja jacket with wide sleeves and black neck guard;
- rust-red belt, olive shorts, thigh bands, and cream tabi boots;
- compact chibi proportions, dark pixel outline, and front-facing boss read.

`assets/stage8movechange3.png` is motion reference only because its
off-shoulder costume drifts from the shipped walk identity. `assets/stage9hit2.png`
is also reference-only; its filename and source show that the old runtime
borrowed a later-stage hit sheet.

The accepted AutoSprite character is `cmreqsh82000bhoupp5a34bvh`. All final
motions start from front pose `cmreqxeb1000ja7xk79ts747m`. Rejected profile,
weak-motion, and 3/4 candidates are recorded in the manifest so they are not
accidentally promoted later.

## Runtime priority

Use this exact pose priority:

```text
defeat > victory > stun > dash left/right > attack > native walk left/right > idle
```

Stun is a real status pose and must not be folded into generic boss-hit attack
feedback. Stage 7 explicit cast/skill keys drive attack before any compatibility
fallback. Cloud ascent/descent, Stun Escape, and Superspeed movement drive dash.

The renderer must retain the existing Stage 7 layers around the sprite:

- centered Lingpet dwarf shrink;
- composite-intangibility alpha;
- awakened/Superspeed wind-aura ring and five durability pips;
- recharge bar and shared boss status overlays.

## Offline preparation and QA

**Tool status (2026-07-14): historical reference — DO NOT re-run to "refresh"
the live sheets.** The WIP destruction event lost the dash left/right
split-session sources and the exact transforms behind the current live
walk_left / walk_right / attack sheets, so
`tools/prepare_stage7_akamu_sprites.py` cannot reproduce the committed 9-sheet
contract in the present environment (the canonical run below fails on the
missing dash L/R sources by design). The asset authority is the committed
runtime PNG set plus `stage7_akamu_boss_sprite_manifest.json` (sha256
re-measured 2026-07-14). The tool becomes runnable again only after per-side
dash sources (and matching walk/attack sources) are restored. The tool renders
into a run-unique staging directory OUTSIDE `res://` (so the Godot importer
cannot mint `.import` sidecars into the staged set) and ALWAYS stops at the
verified staging set — it has **no live-promotion path** (removed 2026-07-14:
per-file replacement cannot be made set-atomic against interrupts, so any
scripted promotion risks a mixed live directory). Updating the live sheets is
a manual, reviewed copy-and-commit of a verified staging set. The staged
manifest's `postprocess` / `native_direction_policy` strings are sealed to the
authoritative demotion/provenance notes via shared module constants, so a tool
re-run cannot roll those notes back. Committed regression tests:
`tools/test_prepare_stage7_akamu_promotion.py` (verification rejections,
policy-string seal, and no-promotion-entry-point guard).

Historical invocation, from the repository root with the bundled/Pillow-capable
Python runtime:

```powershell
python tools/prepare_stage7_akamu_sprites.py
```

The tool converts accepted 3x3 AutoSprite source exports into deterministic
4x2 runtime atlases. It uses one fixed nearest-neighbor scale per sheet and
checks the first-frame body-size lock (within 5%), transparent frame margins,
and source/output edge contact. The defeat sheet keeps the same identity scale
but applies an offline per-frame ground anchor so the seated collapse neither
clips the 256px cell nor jumps in the result scene.

The generated detailed QA report remains at
`.tmp/stage7_akamu_sprite/stage7_akamu_runtime_qa.json`; durable accepted hashes
and provenance are copied into the runtime manifest.

No runtime `_draw()` or `_process()` path may call `Image.get_image()`, scan
alpha, resize cells, or build textures. The Stage 7 actor prewarms one imported
sheet per step before battle and draws fixed atlas regions afterward.

## Result-screen reuse

The Stage 7 clear-result flow loads the same
`stage7_akamu_boss_defeat.png` sheet with the same 4x2/256/8 contract. If an
asset is missing in a development checkout, the code-native Akamu fallback may
render without blocking the result scene; the shipped asset path is the normal
route.

## Deferred visual extension

The base boss sprite set is complete. Clone, Stun Escape, hologram, and
Superspeed ghost payloads still use the existing lightweight procedural
silhouette path. A later visual-polish slice may sample/tint the accepted boss
atlas for those payloads, but it must preserve their current gameplay timing,
draw order, cleanup, and render budgets.
