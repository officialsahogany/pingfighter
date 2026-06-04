"""Chroma-key background remover for Gemini/imagegen HUD + sprite sources.

Use this for assets generated on a flat solid CHROMA-KEY background
(`#00ff00` green or `#ff00ff` magenta). It is the counterpart to
`remove_bg.py`, which only removes WHITISH / neutral-gray-checker
backgrounds and will leave a green/magenta chroma source FULLY OPAQUE.

Algorithm (mirrors the hard-edge nukki philosophy of remove_bg.py):
  1. Auto-detect (or force) the key color from the image border.
  2. Border-seeded flood-fill on a loose chroma-dominance mask so only the
     background that is connected to the edge is removed (interior accents
     that happen to be greenish/magenta-ish, e.g. cyan neon, stay opaque).
  3. 2-ring hard halo kill for JPEG compression fringe.
  4. Edge-only despill: pull the over-saturated key channel back toward the
     non-key channels so neon edges do not keep a colored rim.
  5. Crop to the alpha bbox with a small padding.

Cyan (`g` and `b` both high) is protected in green mode because dominance
is measured as `g - max(r, b)`, which stays low when blue is also high.

Usage
-----
    py chroma_key.py <src> <dst.png> [--key green|magenta|auto] [--pad N]

Default key is `auto`. `green` is the tested path (result-scroll v2).
"""

from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


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


def _dominance(arr: np.ndarray, key: str) -> np.ndarray:
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]
    if key == "green":
        return g - np.maximum(r, b)
    # magenta: red and blue both high, green low
    return np.minimum(r, b) - g


def _auto_key(arr: np.ndarray) -> str:
    # Sample the 4 borders; whichever dominance is larger picks the key.
    border = np.concatenate([
        arr[0, :, :3], arr[-1, :, :3], arr[:, 0, :3], arr[:, -1, :3]
    ]).astype(np.int32)
    r, g, b = border[:, 0].mean(), border[:, 1].mean(), border[:, 2].mean()
    green_dom = g - max(r, b)
    magenta_dom = min(r, b) - g
    return "green" if green_dom >= magenta_dom else "magenta"


def chroma_key(src: Path, dst: Path, key: str = "auto", pad: int = 10) -> str:
    img = Image.open(src).convert("RGBA")
    arr = np.array(img).astype(np.int16)
    h, w, _ = arr.shape

    if key == "auto":
        key = _auto_key(arr)

    dom = _dominance(arr, key)
    seed = (dom > 38)
    loose = (dom > 14)

    visited = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if seed[y, x]:
                visited[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if seed[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and loose[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))
    bg = visited
    arr[bg, 3] = 0

    # 2-ring hard halo kill for compression fringe.
    for ring in (1, 2):
        halo = _dilate(bg, ring) & ~bg & (dom > 10)
        arr[halo, 3] = 0
        bg = bg | halo

    # Edge-only despill.
    edge = _dilate(bg, 3) & ~bg & (arr[:, :, 3] > 0)
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]
    if key == "green":
        clamp = np.maximum(r, b)
        spill = edge & (g > clamp)
        arr[:, :, 1] = np.where(spill, clamp, g)
    else:  # magenta
        excess = np.minimum(r, b) - g
        spill = edge & (excess > 0)
        arr[:, :, 0] = np.where(spill, np.maximum(0, r - excess), r)
        arr[:, :, 2] = np.where(spill, np.maximum(0, b - excess), b)

    alpha = arr[:, :, 3]
    ys = np.where((alpha > 16).any(axis=1))[0]
    xs = np.where((alpha > 16).any(axis=0))[0]
    if ys.size == 0 or xs.size == 0:
        raise SystemExit("error: nothing left after keying — wrong key color?")
    y0 = max(0, ys.min() - pad)
    y1 = min(h - 1, ys.max() + pad)
    x0 = max(0, xs.min() - pad)
    x1 = min(w - 1, xs.max() + pad)
    out = arr[y0:y1 + 1, x0:x1 + 1].astype(np.uint8)
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out).save(dst, "PNG", optimize=True)
    return f"{key}: {w}x{h} -> {out.shape[1]}x{out.shape[0]} (corners alpha {out[0,0,3]},{out[0,-1,3]},{out[-1,0,3]},{out[-1,-1,3]})"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Green/magenta chroma-key remover")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--key", choices=["green", "magenta", "auto"], default="auto")
    ap.add_argument("--pad", type=int, default=10)
    args = ap.parse_args(argv[1:])
    src = Path(args.src)
    if not src.exists():
        print(f"error: source not found: {src}", file=sys.stderr)
        return 1
    print("wrote " + args.dst + " | " + chroma_key(src, Path(args.dst), args.key, args.pad))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
