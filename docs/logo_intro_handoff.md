# Legacy Logo Intro Handoff — Penguin Wave Sprite Sheet

This is a frozen Python/Pygame PingFighter handoff. Keep it as provenance
for the old 24-frame penguin logo intro asset and as a parity reference only.
Current 환격전 logo / intro work belongs in the repo-local
Godot project, especially `godot/scripts/core/penguin_logo_intro.gd`,
`godot/scripts/resources/gameplay_core_module_catalog.gd`, and the relevant
`godot/assets/ui/...` logo asset folders.

Do not follow the Python/Pygame integration steps below for new work unless
the user explicitly asks for original PingFighter source changes.

Original handoff summary: asset generation / nukki / identity QA was done.
The remaining implementation notes below describe the old Python loader,
fade state machine, startup sequence wiring, caching, and PyInstaller path
handling.

Scope of this handoff:
- What the assets are and where they live
- Exact sheet geometry and frame sequence
- Per-frame alignment guarantees
- A reference Pygame slicer snippet
- Runtime plan (fps / duration / fade) the user already signed off on
- Integration hooks and performance notes
- Explicit out-of-scope items that must not be touched

## 1. Source assets

Current asset locations (all under `d:/tmp/` — move into repo before merge):

| Asset | Current path | Size | Mode |
|-------|--------------|-----:|------|
| Final sprite sheet | `d:/tmp/penguin_logo_wave_sprite_sheet.png` | 5790 × 3844 | RGBA |
| Preview strip (24 frames) | `d:/tmp/penguin_logo_wave_preview_strip.png` | 3840 × 159 | RGBA |
| Preview GIF (12fps loop) | `d:/tmp/penguin_logo_wave_preview.gif` | 512 × 509 | P |
| Transparent key poses | `d:/tmp/penguin_keys_transparent/pose_01..08.png` | 1024 × 1024 | RGBA |
| Key-pose strip | `d:/tmp/penguin_keys_transparent/00_keypose_strip.png` | 1244 × 160 | RGBA |
| Original company logo | `d:/main/bosspong/dongne.jpg` | 1024 × 946 | JPEG |

Recommended repo destinations:

- Create `intro/` at repo root (sibling to `backgrounds/`, `items/`).
- Ship: `intro/penguin_logo_wave.png` (the 5790 × 3844 sheet).
- Optional half-size cache: `intro/penguin_logo_wave_x05.png` (2895 × 1922).
- Optional: keep `dongne.jpg` at current root path or move to `intro/company_logo.jpg`.

Leave `d:/tmp/penguin_keys/` (the pre-nukki originals) out of the repo — they
are not needed at runtime and exist only as rollback references.

## 2. Sheet geometry

| Property | Value |
|----------|-------|
| Total frames | 24 |
| Columns × rows | 6 × 4 |
| Cell size | **965 × 961** |
| Sheet size | 5790 × 3844 |
| Read order | left-to-right, top-to-bottom (frame 1 = top-left, frame 24 = bottom-right) |
| Background | fully transparent (alpha channel, not color-keyed) |

Frame indexing formula (zero-based frame index `i`):

```python
col = i % 6
row = i // 6
x_px = col * 965
y_px = row * 961
```

## 3. Frame sequence (hold timing baked in)

The sheet is NOT 24 unique poses — it is 8 key poses with per-pose hold
counts. Do not attempt to de-duplicate at runtime; play frames 1..24
sequentially.

| Frames | Key pose | Hold |
|-------:|----------|-----:|
| 1–3   | 01 neutral           | 3 |
| 4–5   | 02 slight_raise      | 2 |
| 6–8   | 03 wave_left         | 3 |
| 9–12  | 04 far_left_peak     | 4 |
| 13–14 | 05 return_center     | 2 |
| 15–17 | 06 wave_right        | 3 |
| 18–21 | 07 far_right_peak    | 4 |
| 22–24 | 08 return_neutral    | 3 |

Frame 24 → frame 1 transition is a closed loop (08 return_neutral → 01
neutral is the intended seam).

## 4. Per-frame alignment guarantees

All 24 cells share the same baseline — no per-frame offset compensation is
needed. Just blit the whole cell.

- **Feet baseline Y (inside cell)**: 941 (= 961 − 20)
- **Body centerline X (inside cell)**: 482 (= 965 / 2)
- Character silhouettes were cropped to their alpha bbox and re-pasted so
  that their feet-bottom and feet-centerline hit the above anchors
  exactly. Horizontal "bounce" between frames is gone.
- Residual vertical drift on frame 9–12 (pose_04 far-left-peak) is ~5–7%
  taller silhouette from the high arm arc. This was accepted asset-side
  and does NOT need runtime correction.

## 5. Reference Pygame slicer

Minimal, engine-friendly slicing. `resource_path` usage is **mandatory**
(PyInstaller-safe, mirrors existing codebase pattern in `splash_screen.py`).

```python
import pygame
from splash_screen import resource_path  # or the local resource_path helper

LOGO_WAVE_SHEET = "intro/penguin_logo_wave.png"
LOGO_WAVE_FRAME_COUNT = 24
LOGO_WAVE_COLS = 6
LOGO_WAVE_CELL_W = 965
LOGO_WAVE_CELL_H = 961

_logo_wave_frames = None

def load_logo_wave_frames(scale_to=None):
    """Return a list of 24 pygame.Surface with per-pixel alpha.

    scale_to: optional (target_w, target_h) per frame. Pass None to keep
              the native 965x961 cell size.
    """
    global _logo_wave_frames
    if _logo_wave_frames is not None:
        return _logo_wave_frames

    sheet = pygame.image.load(resource_path(LOGO_WAVE_SHEET)).convert_alpha()
    frames = []
    for i in range(LOGO_WAVE_FRAME_COUNT):
        col = i % LOGO_WAVE_COLS
        row = i // LOGO_WAVE_COLS
        rect = pygame.Rect(
            col * LOGO_WAVE_CELL_W,
            row * LOGO_WAVE_CELL_H,
            LOGO_WAVE_CELL_W,
            LOGO_WAVE_CELL_H,
        )
        frame = sheet.subsurface(rect).copy()
        if scale_to is not None:
            frame = pygame.transform.smoothscale(frame, scale_to)
        frames.append(frame)
    _logo_wave_frames = frames
    return frames
```

Notes:
- `.convert_alpha()` is required; the sheet uses per-pixel alpha.
- Prefer `smoothscale` only at load time; never rescale per frame.
- Cache at module level (shown above) so the sheet only touches disk once.

## 6. Runtime plan (user-approved)

- Show the company logo (`dongne.jpg`) as a static background centered on
  screen.
- Composite the animated penguin on top of (or replacing) the logo's
  penguin. Since the logo already contains a penguin, either:
    - Option A (cleaner): use just the red circle + cream border of the
      logo as the backdrop and let the animated penguin be the only
      penguin. Requires a pre-rendered "empty backdrop" image, or
      programmatic red-circle draw.
    - Option B (simpler): show the logo as-is and sit the animated
      penguin over / in front of it. User accepted a slight double-penguin
      read during the wave as long as the wave is on top and readable.
  Prefer Option A if trivially doable; fall back to Option B otherwise.
- Animate:
    - Fade in (alpha 0 → 255) over ~0.3 s.
    - Play 24 frames at **12 fps** (= 2.0 s one loop) or **15 fps**
      (= 1.6 s one loop). User suggested 12–15 fps.
    - One full loop is the floor; 1.5 loops (36 frames) gives the user's
      "1.8–2.3 s intro" window.
    - Fade out (alpha 255 → 0) over ~0.3 s.
    - Hand off to existing splash / loading screen.
- Total intro duration target: **1.8–2.3 s**.

Suggested concrete choice: **12 fps × 24 frames × 1 loop = 2.0 s**, plus
0.3 s in + 0.3 s out = **2.6 s** end-to-end. If that runs long, drop to
**15 fps × 24 frames × 1 loop = 1.6 s** → 2.2 s end-to-end.

## 7. Integration hooks

Current startup path (verify before editing):

- `splash_screen.py` already provides `show_splash()`, `update_splash()`,
  `close_splash()` with a module-level singleton.
- `pingfighter.py` does NOT import `splash_screen` directly — the splash
  is driven from outside pingfighter's main loop (likely via the
  launcher / `__main__`). Find the actual caller with
  `grep -nE "show_splash|splash_screen" *.py` before wiring.

Two reasonable approaches (pick one — do not do both):

1. **Prequel screen (preferred)** — add a new `logo_intro.py` with a
   `LogoIntro` class and `play_logo_intro()` function mirroring
   `splash_screen.py`'s API. Call `play_logo_intro()` immediately before
   `show_splash()` at whichever file currently owns the startup sequence.

2. **Splash phase** — add a "logo intro" phase inside `SplashScreen.__init__`
   that runs before the progress bar appears. Simpler but couples the
   intro to the splash state machine.

Either way, the intro must be **blocking** (or driven by the same event
loop) so it completes before the main splash progress bar begins.

## 8. Performance and hitch notes

- **First-load hitch**: `pygame.image.load` on a 5790 × 3844 RGBA PNG
  plus `.convert_alpha()` is the only heavy step. Preload at the very
  start of intro (ideally during a 1-frame "black" frame or hidden behind
  the fade-in alpha-0 frame) so the load cost doesn't show as a stutter
  mid-animation.
- **Half-size variant**: if `load_logo_wave_frames(scale_to=(482, 480))`
  is too slow as a runtime resize, ship a pre-scaled
  `intro/penguin_logo_wave_x05.png` (2895 × 1922, cell 482 × 480) and
  load that instead. The user explicitly asked for "반사이즈 버전도 같이".
- **No per-frame allocation**: the slicer above uses `.subsurface(...).copy()`
  once per frame at load and caches. Do NOT re-subsurface or re-convert
  inside the animation tick — that's the CPU + pygame trap called out in
  `CLAUDE.md` (per-frame Surface / transform allocation).
- **Full-screen `fill` caveat**: blit the intro onto a dirty-region
  redraw (cell footprint ~965 × 961) if possible; a 1920 × 1080 fill per
  frame is 8 MB cleared 12× per second, which is wasteful for a 2 s
  intro. If dirty-region isn't set up for this phase, a full clear is
  acceptable (it's only 2 s).
- **Fade implementation**: use `surface.set_alpha(int(0..255))` on the
  composited logo+penguin surface, not per-pixel alpha math.

## 9. PyInstaller / `resource_path` reminder

From `CLAUDE.md` standing rules:

- Always load via `resource_path(relative)`. Never hardcode absolute
  paths (especially not `d:/tmp/...` — that will ship broken).
- Add `intro/*.png` (and the optional half-size variant) to the
  PyInstaller data spec so the files land inside the bundled app on
  Windows and macOS.

## 10. Out of scope — do not touch

- **Sprite regeneration**: the 8 key poses are signed off as final. Do
  not re-run FLUX, do not re-nukki, do not reinterpret the motion.
- **Identity / pose / controller position**: no repaint, no recolor,
  no redesign. If a frame looks wrong at runtime, debug the blit/scale
  path, not the art.
- **Boss sprite runtime rules**: this is a logo intro, NOT a boss sheet.
  `AGENTS.md`'s boss-sprite runtime rules do not apply. Identity /
  scale / per-frame perf still matter, but `AGENTS.md` is not the
  governing doc here.
- **Item runtime checklist**: not applicable — this is not an item.

## 11. Quick inventory recap

```
d:/tmp/penguin_logo_wave_sprite_sheet.png       5790 x 3844 RGBA (ship → intro/penguin_logo_wave.png)
d:/tmp/penguin_logo_wave_preview_strip.png      3840 x  159 RGBA (QA only, do not ship)
d:/tmp/penguin_logo_wave_preview.gif             512 x  509 P    (QA only, do not ship)
d:/tmp/penguin_keys_transparent/pose_01..08.png 1024 x 1024 RGBA (rollback ref, do not ship)
d:/main/bosspong/dongne.jpg                     1024 x  946 JPEG (existing logo)
```

End of handoff. Ask Claude (this session) only if the asset itself needs
changes; all runtime / integration / packaging decisions are Codex's to
make from here.
