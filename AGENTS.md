# Repository Guidelines

PingFighter is a Python/Pygame boss-pong arcade game. This file is the shared implementation guide for Codex and other agent-style coding tools.

`AGENTS.md` covers code integration, runtime behavior, performance, testing, and repo-specific implementation rules for gameplay code and boss-sprite runtime work.
`CLAUDE.md` covers Claude/Gemini asset-generation workflow, prompt wording, sprite-sheet composition, and offline background-removal steps.
`docs/item_runtime_checklist.md` covers item runtime integration.
`docs/character_skill_perk_checklist.md` covers runtime character perk / skill integration (unlock perks, 5-orb skills, academy/NPC skill-offer flows, effective-level audits, tooltip/UI sync, save/load/reset QA).

When the documents overlap:
- `AGENTS.md` is the source of truth for boss-sprite implementation and runtime rules.
- `CLAUDE.md` is the source of truth for image-generation and asset-prep rules.
- `docs/item_runtime_checklist.md` is the source of truth for item runtime integration.
- `docs/character_skill_perk_checklist.md` is the source of truth for runtime character perk / skill integration.
- If the task touches runtime character perk / skill icons, orb HUD symbols,
  perk cards, academy / NPC perk-offer UI, skill tooltip sync, or
  gameplay / reward wiring for a character skill (including skill-
  specific gold bonuses), open
  `docs/character_skill_perk_checklist.md` and the related `CLAUDE.md`
  hidden-knowledge section before claiming the work is done.

Item work routing:
- If the task adds or modifies an active / passive / legendary / mythic
  item at runtime, open `docs/item_runtime_checklist.md` before
  claiming the work is done.
- If the task also needs a new item icon or a character equip visual,
  open `.claude/skills/item-generation/SKILL.md` too.
- For passive / legendary / mythic items, do not stop at
  `PASSIVE_SLOT_ORDER`; also audit developer-mode `all_items`, normal
  field pickup and intended `unknown_item` routes, shop / crane / gacha /
  treasure-hunt paths, equip-gated effect behavior, reset on death /
  main-menu return, roll / polish / enhancement application, and
  Pandora's passive exclusion list in `legendary_items.py`.

Sprite workflow mode switch:
- Asset-generation planning now also uses `.claude/sprite_workflow_settings.json`
  with `fast` / `precise` modes.
- Default is `fast`.
- `fast` affects asset-side depth only; it does NOT relax runtime safety
  checks in this file.
- Even in `fast`, do not skip the minimum runtime sanity checks required
  before claiming a sprite integration is done.

## Project Structure & Module Organization
- Entry point: `pingfighter.py`
- Main code folders: `core/`, `entities/`, `ai/`, `managers/`, `ui/`, `effects/`, `items/`
- Runtime assets: `images/`, `fonts/`, `bgm/`, `sounds/`
- Tests: `tests/` plus root-level `test_*.py`
- Boss sprite integrations usually touch `entities/`, `items/`, and stage-specific branches in `pingfighter.py`

## Critical Stage Mapping
- Code `current_stage == 5` is actual Stage 6 Honglyeon (Chinese Fire)
- Code `current_stage == 6` is actual Stage 5 Nemesis (Ocean/Battleship)
- Confirm this mapping before editing stage-specific logic, assets, or event code

## Build, Test, and Development Commands
- Run: `python pingfighter.py`
- Tests: `python -m pytest tests/` or `python tests/test_framework.py`
- Syntax smoke check: `py -3 -m py_compile pingfighter.py entities\\<sprite>.py`
- Format/Lint: `black .` and `pylint .`
- Windows package: `pyinstaller -y PingFighter_Windows.spec`

## Coding Style & Naming Conventions
- Python 3.10+, PEP 8, 4-space indentation
- Functions and modules: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE`
- Always load project assets with `resource_path(relative)`
- Use `os.path.join` for paths; do not hardcode slash-separated paths
- File I/O should explicitly use `encoding="utf-8"` when text is involved
- For new modal / dialogue UI, verify every font path exists at runtime; prefer `resource_path()` targets that are present in the repo and keep a visible fallback instead of silently swallowing render failure
- Treat modal-open flags and menu-request flags as one-shot signals; mouse and keyboard paths must both clear them consistently after consume / cancel
- When changing options / settings UI, confirm which menu entry points are actually live before editing. This repo can have multiple settings surfaces (`start_menu.py`, `option.py`, pause options, helper settings UIs), and a fix in a dormant screen does not count as integrated
- Do not assume the first settings-looking file is the live one. Search for the actual visible labels / tab names the player sees (for example `BGM 볼륨`, `효과음 볼륨`, `설정`, `사운드`) and trace the reachable call path before editing
- For new settings, wire one canonical settings key through every supported entry path and verify the runtime consumer reads that same key rather than a duplicate local variable, stale cache, or legacy settings file
- If a visual can come from both an on-disk asset and a procedural fallback, attempt the on-disk asset first and use the fallback only when file load fails
- When replacing an existing icon or other visual asset, audit special-case loader branches for early returns that could bypass the new file even when it exists on disk
- For runtime-drawn perk / skill icons, audit every live ID path that can
  reference the icon (perk id, unlock id, runtime skill id, legacy alias).
  A bespoke branch under one name is not enough if the real HUD path uses a
  different id.
- Judge runtime icon size by perceived subject fill in the smallest real UI
  box that uses it, not by a radius constant or the largest preview card.

## Boss Sprite Workflow
- Asset-generation details belong in `CLAUDE.md`
- Runtime integration belongs here
- Expected asset patterns:
  - `items/[name]_boss_sheet.{png,jpeg}`
  - `items/[name]_boss_attack.{png,jpeg}`
  - `items/[name]_boss_dash.{png,jpeg}` when dash is supported
  - `items/[name]_boss_turn.{png,jpeg}` when brief facing-transition support is used
- Expected code pattern:
  - sprite class in `entities/[name]_boss_sprite.py`
  - import/init/reset wiring in `pingfighter.py`
  - stage render branch in `pingfighter.py`
  - attack and dash trigger wiring in gameplay logic
  - optional turn/facing-transition selection in sprite update logic
- When walk, attack, dash, and optional turn sheets exist for the same boss, treat them as one animation set with one body-size reference
- Dash or attack effects may extend outward, but the body silhouette should stay stable across sheets
- Judge cross-sheet consistency by **visible body read** (head height, face size, torso silhouette in-game), not only raw canvas / frame size -- action sheets that are technically the same size but read visibly smaller due to outward effects, flame halos, or trails have failed the scale check
- Effects, trails, and motion lines must not cause the character's body or face to read smaller than the walk baseline at gameplay scale
- If attack or dash integration makes the perceived body / face class drift below the walk baseline, prefer a small runtime upscale on the action sheets over accepting a shrunk body read
- A turn sheet is an optional support sheet for brief facing changes only; it is not the default replacement for the main walking cycle
- Unless the design explicitly adopts multi-angle walking, normal movement should continue using the main walk sheet and the turn sheet should appear only during short left/right facing transitions
- For front-biased / front-facing walk bosses, the default turn design is NOT a body-angle rotation chart. Turn should stay visually tied to the frontal walk and express the direction change through a short characterful accent: chin lift, head tilt, shoulder hitch, arm pose swap, one-knee lift, small hop / pivot, ribbon / skirt rebound, or another signature habit that fits the boss
- Turn should read like a brief transition gesture that connects left-travel walk back into right-travel walk (and vice versa), not like the boss is spinning to show side-profile angles to the camera
- If a turn sheet is accepted for runtime playback under an explicit policy despite small cosmetic divergence, document it as a **runtime-only auxiliary non-anchor** sheet. The walking sheet remains the sole identity anchor for future regeneration unless explicitly reclassified later
- For front-biased or front-facing walk sheets, "front-biased" means the boss still reads as facing the player during stable movement. It does NOT mean a hidden 3/4 walk that consistently reads as looking left or right in-game
- A front-biased walk fails QA if hair mass, ribbon placement, hat tilt, eye placement, cheek visibility, shoulder exposure, torso angle, or other asymmetry makes stable movement read as "the boss is looking to one side" instead of "the boss is facing forward"
- If a regenerated walk sheet reads more side-facing than the last accepted walk sheet, reject it even if animation energy improved. Liveliness is not allowed to trade away frontal combat readability
- Recommended runtime priority when a turn sheet exists: `dash > attack > turn-transition > walk > idle`
- Runtime may play only a short transition slice of the turn sheet if that keeps the direction-change accent readable. The turn sheet exists to bridge walk-to-walk with characterful motion, not to force a full visible spin
- If a turn frame looks face-clipped, forehead-cut, or "cropped" in gameplay, compare the raw cell, post-inset crop, trimmed frame, and gameplay-size render before changing runtime scale. If the same clipped-looking read already exists before runtime fitting, it is an asset-side failure, not a runtime crop bug
- Do NOT keep stacking stronger turn-only downscale just to hide a clipped-looking peak transition pose. If the key turn frames still read chopped after a conservative fit, reject the turn art and prefer disabling visible turn playback until the art is regenerated
- If the turn sheet still reads as a different character, breaks the frontal walk connection, or feels like unrelated acting pasted on top of the walk, prefer disabling turn playback entirely and keep normal lateral travel on the walk sheet until art is fixed
- Do NOT paper over an asset-side frontal-read failure with runtime facing remaps, blind left/right flipping, or by silently redefining which travel direction uses which frame set. If the accepted walk no longer reads as a forward-facing walk, roll back to the previous accepted walk sheet and regenerate the art
- For bosses whose design goal is "walk stays frontal, direction changes get a small hop / pivot accent," a hop-only runtime transition without visible turn-frame playback is an acceptable fallback when the turn sheet is mismatched
- Victory sheets must read as an actual win / celebration sequence at gameplay scale. If a replacement victory sheet preserves identity but still reads like a walk loop, turn extension, or flat idle posing, treat that as an asset-side failure and regenerate instead of shipping it as-is
- For projectile-casting bosses, the actual projectile launch event must trigger the matching cast / attack animation. Do NOT restrict attack-animation triggers to ball-hit timing alone when the boss also has explicit projectile-launch events -- cast timing and attack timing must be wired separately
- For contact-based strike sheets (chops, punches, hammer hits, paddle-hit attacks), the default runtime trigger model should be anticipatory / pre-contact rather than pure ball-hit-only. If the sheet has visible prep before impact, start it slightly before predicted contact so the prep frames are seen and the impact frame lands at or near the actual hit; keep a ball-hit fallback when prediction can miss
- The good default is a SHORT, conservative pre-contact lead window, not an early cinematic wind-up. If anticipatory triggering makes the swing visibly fire before the ball arrives, narrow the lead window or start from a later frame; do not keep widening anticipation just to show more prep
- Petite human / chibi bosses should use the current Stage 3 Menhera in-game body class (after her latest +10% upscale) as the preferred runtime-size baseline reference unless the design explicitly calls for a different class (e.g. large-frame bosses like Tauren, tall vertical-silhouette bosses like Honglyeon). This is a baseline reference, not a universal hard rule.
- Runtime integration for a new petite human / chibi boss should not silently rescale it to a size that drifts noticeably away from that baseline without explicit design intent
- Small in-game readability baked into the source sheet should be preserved during integration; do not layer downscaling, blurring, or extra transforms that erase the readability achieved at the asset stage

## Sprite Class Reference Pattern
`entities/tauren_boss_sprite.py` is the reference implementation for boss sprite classes. Match its structure when authoring `entities/[name]_boss_sprite.py` so new bosses plug into the existing loader and render conventions.
- Use a `FRAME_INSET` constant (value `14` is the known-good recommendation) to exclude grid lines, cell borders, and label bleed from each source cell.
- After inset, call `_trim_to_visible_bounds()` to compute a tight bounding box and strip transparent margin.
- Apply `_scale_to_target()` to resize to the target in-game size while preserving aspect ratio.
- Store each motion in its own frame buffer: `_frames_right` for walk, `_attack_frames_right` for attack, `_dash_frames_right` for dash, `_turn_frames_right` for the optional turn sheet. Do NOT reuse one buffer across motions.
- Expose `trigger_attack()` that plays the attack sheet once and returns to idle/walk state. Mirror this pattern for dash and turn triggers when those sheets are present.
- The scale factor MUST be derived from the walking sheet and reused across attack / dash / turn. The "no per-sheet rescale" rule in the following section is the rationale.
- In-class JPEG cleanup is a runtime safety net only; it does not replace the offline PNG nukki pipeline owned by the `sprite-generation` skill.

## Runtime Performance Rules
- Treat large 2K sprite sheets as source assets, not hot-path data
- Prefer offline-prepared PNG assets over JPEG fallback whenever possible
- Runtime JPEG cleanup is a safety net only; do not rely on it as the normal path
- Expensive preprocessing such as trim, halo cleanup, outline generation, and downscaling should happen once at load time at most
- Never do heavy sprite-sheet preprocessing inside per-frame update or draw code
- Avoid rebuilding large sprite objects repeatedly across rounds or state transitions unless strictly necessary
- If sprite initialization is expensive, prefer lazy-load or one-time caching over repeated reconstruction
- Avoid repeated creation of large temporary `Surface` objects on hot paths
- Avoid per-frame `pygame.transform.scale()` and `pygame.transform.rotate()` unless the source, target size, or angle actually changed
- Cache common scaled or rotated results when the same size or angle is reused
- Particle/effect cost is multiplicative: particle count x lifetime x layer count x translucent radius. Small-looking increases across multiple axes can add several ms/frame
- Do not assume `pygame.gfxdraw` makes particle-heavy effects "free" -- layered smoke, halos, and large translucent blobs should reuse cached / pooled surfaces when possible instead of redrawing the same shape stack every frame
- New sprite classes must not independently trim-and-rescale walk, attack, dash, and turn sheets in ways that change perceived body size
- Use the walking sheet as the scale reference for attack, dash, and turn when cross-sheet body size must remain consistent
- Do not let a turn sheet hijack normal walking unless multi-angle walking is the explicit approved design goal
- If a generated sheet is too large or noisy for runtime comfort, export a runtime-ready version instead of pushing the cleanup cost into Python at startup
- When a boss package adds multiple large motion sheets (walk + attack + dash + turn), review the aggregate load cost as well as per-frame cost; stage-entry hitch can regress even when animation playback is cheap
- Before blaming a new sprite for stage slowdown, also inspect stage-specific background and event systems; Stage 5 and Stage 6 already have animated backgrounds and continuous event updates

## Stage Integration Checklist
- Confirm the real stage-to-code-stage mapping first
- Verify asset filenames and `resource_path()` loading
- Add import/init/reset wiring safely
- Verify render branch size, offsets, and facing logic
- Verify attack trigger timing aligns with the gameplay event. For contact-based strike sheets with visible prep, prefer an anticipatory / pre-contact trigger so prep frames are visible and the impact frame lands at or near ball-hit instead of a beat late
- For projectile-casting bosses, also verify the projectile-launch event triggers the matching cast / attack animation (not just ball-hit); cast timing and attack timing are checked as separate integration paths
- If an anticipatory attack trigger is used, verify the ball-hit fallback does not double-fire, repeated approaches reset cleanly, and the chosen lead window still preserves the intended front-to-impact read
- If an anticipatory attack trigger is used, verify the lead window is conservative enough that the visible downswing / chop does not complete before contact. "Prep becomes visible" is good; "attack whiffs early in empty air" is a fail
- Verify dash trigger timing at actual dash start timing
- Verify walk, attack, dash, and optional turn body size consistency by **perceived body read at gameplay scale**, not just raw frame size -- action sheets should not feel visibly smaller than the walk baseline in-game
- Verify the accepted walk still reads as facing the player during stable left and right travel. If stable movement reads as consistently looking left or right, reject the walk sheet asset-side instead of compensating in runtime logic
- Verify the direct walk `f1..f8` strip has real slot separation before runtime promotion. If the accepted frames still look like the same pose repeated with only tiny paw / foot offsets, treat that as an asset-side walk failure even if a stitched preview or live loop vaguely reads as movement
- Do not promote a walk candidate just because `F1↔F5` mirror discipline landed or because the loop is technically animating. Intermediate slots must still read as distinct rise / shift / rebound / return beats at sheet-review scale
- Verify effects, trails, and motion lines do not visually compress the character's body / face class below the walk baseline
- Verify turn frames appear only on actual facing changes and do not replace stable walking by accident
- For front-biased bosses, verify turn playback preserves the same frontal combat read as walk and comes across as a brief characterful transition gesture rather than a visible profile-spin or multi-angle showcase
- Verify walk-to-turn-to-walk recovery is brief and readable when turn support is enabled
- If a replacement turn sheet uses a different grid layout than the previous asset (for example `8x1` -> `4x2`), update the loader grid constants and explicit frame-order mapping before swapping files. Do NOT drop a new sheet onto an old slicer and assume row-major intent matches automatically
- If a turn frame looks face-clipped or forehead-cut, inspect the raw cell -> inset crop -> trimmed frame -> gameplay-size render path before applying more runtime scaling. Do not assume a runtime crop bug just because the in-game frame looks chopped
- Verify the runtime-selected key turn frames preserve the same face / forehead read as walk at gameplay size and do not look visually chopped even when the frame technically fits inside the canvas
- If a turn sheet or turn subset looks materially different from walk in body read, palette, outline weight, hair silhouette, or face scale, disable turn playback rather than shipping visibly mismatched facing transitions
- If the previous accepted walk sheet was more front-readable than the new candidate, restore the older walk sheet until a better regeneration passes QA. Do not permanently promote a weaker frontal-read walk just because it is newer
- If the turn sheet is authored with a short usable transition slice instead of the full source sequence, document the accepted usable frames and verify the runtime selection matches that slice exactly
- If a turn sheet is accepted as runtime-only non-anchor, verify that the handoff and repo notes explicitly preserve the walking sheet as the sole regeneration anchor before enabling any runtime migration work
- If a victory sheet exists or was replaced, verify the played sequence reads like a real celebration at gameplay scale (rise / peak / hold or equivalent) rather than like calm walk / turn leftovers
- If stage-specific event/background/effect code was touched, verify that effect path itself (smoke / fire / background / laser / etc.) rather than assuming the sprite class is the only possible regression source
- If particle count, lifetime, layer count, or translucent blob size increased, run one targeted effect benchmark or live FPS sanity check in addition to the normal sprite-load smoke test
- Run syntax checks and at least one headless sprite-load smoke test
- Perform one real in-game visual check before calling the task done

## Testing Guidelines
- Use `pytest` and `unittest` as already present in the repo
- Add `tests/test_<feature>.py` for new logic when feasible
- For graphics-dependent checks, prefer headless runs with `SDL_VIDEODRIVER=dummy`
- For regenerated icons or other asset replacements that have a runtime fallback, do one live sanity check that the written PNG is what actually appears in-game; a stale cache or early procedural-return is a known regression pattern
- For new or changed character perk / skill icons, do at least one live check
  in every relevant UI family: perk-choice card, smallest perk grid /
  academy-style offer panel, and orb HUD / tooltip path when applicable.
  Verify no alias route falls back to the wrong branch and the main motif does
  not read materially smaller than neighboring icons.
- For new or changed character active skills, verify the skill-specific
  gold-reward policy is explicit: either add an intentional reward sized
  consistently with comparable skills or document that the skill is
  intentionally no-gold. If the skill grants gold, confirm the payout is
  wired to the real hit / absorb / consume event and does not double-pay
  alongside generic rally gold or alternate fallback paths.
- For new or changed downtown / interior / NPC modal flows, do one live check that text actually renders with the shipped repo font path, not just a silent fallback-free code path
- For nested confirmation -> menu flows, do one live check that the opened modal does not capture the previous dialog as a dimmed background ghost
- For menu flows opened by both mouse and keyboard, test confirm / cancel / ESC in both input paths so stale open flags cannot reopen the menu or double-trigger an action
- For settings / options changes, do one live check from every supported entry path (for example `start_menu.py` main-menu settings, pause/options, `option.py`, and any dedicated settings UI that is still reachable). Verify the value persists, reopens with the saved state, and changes the real runtime behavior rather than only the local widget state
- For visit-scoped NPC offers (academy-style), verify same-visit reroll / repurchase / reswap is blocked after success and that re-entry resets only at the intended boundary
- If a helper module spends or grants gold / AP / other visit currency, verify the final value persists back to the manager / shared player state after the modal closes
- For new boss-sprite integrations, do at least:
  - syntax compile check
  - headless sprite class load
  - one visual gameplay sanity check
  - for regenerated walk sheets, one direct `f1..f8` side-by-side strip review before runtime sign-off
  - for front-biased walks, one check that left travel and right travel both still read as forward-facing rather than as persistent side-looking poses
  - if a turn sheet exists, one check that stable movement still uses walk and only facing changes show turn frames
  - if turn QA is disputed, one raw cell / inset / trimmed / gameplay-size comparison before blaming runtime crop or adding more turn-only downscale
  - if turn loader layout changed, one local playback pass with visible turn playback temporarily enabled before restoring the intended shipping default
  - one quick check for stage-entry hitching or obvious FPS regression
  - if stage-specific effects changed, one targeted headless update/draw loop or micro-benchmark for the touched effect path

## Windows Compatibility
- Use `os.path.join` and `resource_path()`
- Do not assume case-sensitive paths
- PyInstaller on Windows uses `--add-data "src;dest"`
- Watch for MP3 decoder issues; `PINGF_BGM_EXT=ogg` may be needed
- Local Windows smoke test:
  - `py -3 -m venv .venv`
  - `.venv\\Scripts\\activate`
  - `pip install -r requirements.txt`
  - `python pingfighter.py`

## Commit & Pull Request Guidelines
- Commit format: `feat|fix|docs|style|refactor|test|chore: short summary`
- PRs should include:
  - summary
  - change list
  - screenshots for visual changes
  - related issue or context when available
