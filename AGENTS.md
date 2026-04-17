# Repository Guidelines

PingFighter is a Python/Pygame boss-pong arcade game. This file is the shared implementation guide for Codex and other agent-style coding tools.

`AGENTS.md` covers code integration, runtime behavior, performance, testing, and repo-specific implementation rules.
`CLAUDE.md` covers Claude/Gemini asset-generation workflow, prompt wording, sprite-sheet composition, and offline background-removal steps.

When the two overlap:
- `AGENTS.md` is the source of truth for implementation and runtime rules.
- `CLAUDE.md` is the source of truth for image-generation and asset-prep rules.

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
- A turn sheet is an optional support sheet for brief facing changes only; it is not the default replacement for the main walking cycle
- Unless the design explicitly adopts multi-angle walking, normal movement should continue using the main walk sheet and the turn sheet should appear only during short left/right facing transitions
- Recommended runtime priority when a turn sheet exists: `dash > attack > turn-transition > walk > idle`
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
- New sprite classes must not independently trim-and-rescale walk, attack, dash, and turn sheets in ways that change perceived body size
- Use the walking sheet as the scale reference for attack, dash, and turn when cross-sheet body size must remain consistent
- Do not let a turn sheet hijack normal walking unless multi-angle walking is the explicit approved design goal
- If a generated sheet is too large or noisy for runtime comfort, export a runtime-ready version instead of pushing the cleanup cost into Python at startup
- Before blaming a new sprite for stage slowdown, also inspect stage-specific background and event systems; Stage 5 and Stage 6 already have animated backgrounds and continuous event updates

## Stage Integration Checklist
- Confirm the real stage-to-code-stage mapping first
- Verify asset filenames and `resource_path()` loading
- Add import/init/reset wiring safely
- Verify render branch size, offsets, and facing logic
- Verify attack trigger timing at actual ball-hit timing
- Verify dash trigger timing at actual dash start timing
- Verify walk, attack, dash, and optional turn body size consistency
- Verify turn frames appear only on actual facing changes and do not replace stable walking by accident
- Verify walk-to-turn-to-walk recovery is brief and readable when turn support is enabled
- Run syntax checks and at least one headless sprite-load smoke test
- Perform one real in-game visual check before calling the task done

## Testing Guidelines
- Use `pytest` and `unittest` as already present in the repo
- Add `tests/test_<feature>.py` for new logic when feasible
- For graphics-dependent checks, prefer headless runs with `SDL_VIDEODRIVER=dummy`
- For new boss-sprite integrations, do at least:
  - syntax compile check
  - headless sprite class load
  - one visual gameplay sanity check
  - if a turn sheet exists, one check that stable movement still uses walk and only facing changes show turn frames
  - one quick check for stage-entry hitching or obvious FPS regression

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
