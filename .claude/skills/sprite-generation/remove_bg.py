"""Offline background remover (nukki) for PingFighter boss sprite sheets.

Hard-edge algorithm tuned for Gemini-MCP JPEG output:
  1. Border-seeded flood-fill of whitish pixels -> background mask.
  2. Optional checker-aware flood-fill for transparency-indicator tiles
     baked into the image as low-saturation mid-gray squares.
  3. 2-ring hard halo kill for JPEG compression fringe.
  4. One mild halo sweep for slightly-colored fringe.

Hard-kill (binary alpha) is deliberate — pixel art needs crisp outlines,
so alpha feathering is avoided. Interior highlights (horns, gold trim)
are unreachable from the border, so they stay opaque automatically.

Usage
-----
    py remove_bg.py <src.jpeg> <dst.png>

Example
-------
    py .claude/skills/sprite-generation/remove_bg.py \\
        items/mynewboss_boss_sheet.jpeg items/mynewboss_boss_sheet.png
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


WHITISH_LUM = 200
WHITISH_SAT = 30
CHECKER_LUM = 100
CHECKER_SAT = 8
CHECKER_HALO_SAT = 12
HALO_LUM = 150
HALO_SAT = 40
MILD_LUM = 180
MILD_SAT = 60


def _dilate(mask: np.ndarray, times: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(times):
        nxt = out.copy()
        nxt[1:, :] |= out[:-1, :]
        nxt[:-1, :] |= out[1:, :]
        nxt[:, 1:] |= out[:, :-1]
        nxt[:, :-1] |= out[:, 1:]
        out = nxt
    return out


def _border_seeded_flood_fill(seed_mask: np.ndarray) -> np.ndarray:
    h, w = seed_mask.shape
    visited = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()

    for x in range(w):
        for y in (0, h - 1):
            if seed_mask[y, x]:
                visited[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if seed_mask[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))

    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if (
                0 <= ny < h
                and 0 <= nx < w
                and not visited[ny, nx]
                and seed_mask[ny, nx]
            ):
                visited[ny, nx] = True
                q.append((ny, nx))
    return visited


def remove_sprite_bg(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGBA")
    arr = np.array(img)
    h, w, _ = arr.shape

    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    lum = (r + g + b) / 3.0
    sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)

    whitish = (lum >= WHITISH_LUM) & (sat <= WHITISH_SAT)
    checker_gray = (
        (lum >= CHECKER_LUM)
        & (lum < WHITISH_LUM)
        & (sat <= CHECKER_SAT)
    )

    # Some Gemini icon outputs bake transparency-indicator checker tiles into
    # the image as neutral mid-gray blocks. Only enable this extra path when
    # those tiles actually touch the border; otherwise leave normal gray
    # sprite content alone.
    border_checker = (
        checker_gray[0, :].any()
        or checker_gray[-1, :].any()
        or checker_gray[:, 0].any()
        or checker_gray[:, -1].any()
    )
    bg_seed = whitish | checker_gray if border_checker else whitish

    # Step 1: border-seeded flood-fill.
    bg_mask = _border_seeded_flood_fill(bg_seed)
    arr[bg_mask, 3] = 0

    # Step 2: 2-ring hard halo kill.
    for ring in (1, 2):
        dilated = _dilate(bg_mask, ring)
        halo = dilated & ~bg_mask & (lum >= HALO_LUM) & (sat <= HALO_SAT)
        if halo.any():
            arr[halo, 3] = 0
            bg_mask = bg_mask | halo

    # Checkerboard backgrounds can leave a final ring of neutral gray just
    # above the normal halo thresholds. Clean that ring only when a checker
    # background was detected on the border.
    if border_checker:
        checker_halo = _dilate(bg_mask, 1) & ~bg_mask & (lum >= CHECKER_LUM) & (sat <= CHECKER_HALO_SAT)
        if checker_halo.any():
            arr[checker_halo, 3] = 0
            bg_mask = bg_mask | checker_halo

    # Step 3: one mild halo sweep.
    edge2 = _dilate(bg_mask, 1) & ~bg_mask
    mild = edge2 & (lum >= MILD_LUM) & (sat <= MILD_SAT)
    if mild.any():
        arr[mild, 3] = 0

    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(dst, "PNG", optimize=True)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: py remove_bg.py <src.jpeg> <dst.png>", file=sys.stderr)
        return 2
    src = Path(argv[1])
    dst = Path(argv[2])
    if not src.exists():
        print(f"error: source not found: {src}", file=sys.stderr)
        return 1
    remove_sprite_bg(src, dst)
    print(f"wrote {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
