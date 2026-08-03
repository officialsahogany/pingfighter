# -*- coding: utf-8 -*-
"""Reproduce the baekrin/mukrin transform-sheet palette restoration (colormatch v3).

WHAT / WHY
----------
The shipped transform sheet ``godot/assets/sprites/lingpet/baekrin_mokrin_transform_
6x2_12f.png`` (pre-fix state = commit ``5dfc7f9e0``, LFS) carried the AutoSprite
"custom"-family colour grade: body CIEDE2000 8.11 / gold 4.43 against the
user-authored original artwork, while its GEOMETRY and ALPHA were faithful and
accepted. Because the accepted companion idle IS faithful to the original palette,
the grade broke the idle<->transform pixel no-pop contract (S1 blocker).

Fix = ONE global per-channel affine map in CIE Lab (D65), applied to every visible
pixel of the sheet. Alpha untouched; transparent RGB untouched. A global monotonic
colour map cannot add ornaments, move geometry, or break within-sheet continuity.

SKILL BASIS (recorded per user direction, 2026-08-01)
-----------------------------------------------------
Precedent: sprite-generation skill section 2.3.3 — the established "Reinhard
colour-match" post-process step in the lingpet cut-in pipeline (deterministic,
AutoSprite-derived post-processing).
Distinction: section 8.3 forbids papering over PALETTE DRIFT with post-processing.
This is the EXPLICIT EXCEPTION to that rule: the sheet's geometry/alpha were already
accepted, and the operation restores the user-authored original palette that the
generator graded away — it does not hide an identity drift, it removes one.

DERIVATION (deterministic, no RNG — rerunning reproduces the same floats)
-------------------------------------------------------------------------
Anchors: per-frame material medians of the pre-fix sheet's baekrin frames f1..f8
(body mask S<0.18 & V>=0.55, gold mask H28-65 & S>=0.35 & V>=0.30; sampled on
alpha>=250; median RGB -> Lab), each paired with the ORIGINAL artwork's material
median (body Lab ~[89.9209, +1.1767, +5.3621], gold ~[61.6065, +10.4490, +52.6769]).
Fit: per-channel weighted least squares (gain+offset), initial weights body=2.0 /
gold=1.0, then IRLS toward minimax: 24 iterations, each multiplying the weight of
the worst gate-normalised anchor (dE00 / gate, gates body 1.5 / gold 2.5) by 1.6,
keeping the best iterate. Best normalised worst = 0.6949334103938024.

Result gates (measured on corrected pixels): baekrin f1..f8 body worst 0.90 /
gold worst 1.90 — PASS. Mukrin/transition f9..f12 are NOT numerically gated (the
charcoal endpoint has no artwork reference); the corrected neutral ink-charcoal
was approved VISUALLY by the user (2026-08-01). Never report this sheet as
"12/12 palette PASS".

USAGE
-----
    py tools/color_match_baekrin_transform_v3.py <input_prefix_sheet.png> <output.png>

The pre-fix input can be recovered from git LFS:
    git show 5dfc7f9e0:godot/assets/sprites/lingpet/baekrin_mokrin_transform_6x2_12f.png | git lfs smudge > prefix.png

The script verifies both hashes and refuses to claim success on a mismatch.
"""
import hashlib
import sys

import numpy as np
from PIL import Image

# full-precision affine (Lab, D65): lab_out = lab_in * GAIN + OFF
GAIN = np.array([0.9274270861945577, 0.9345292998717541, 1.114512541334578])
OFF = np.array([5.33928425851931, 5.077503637516015, -6.598116690372097])

SHA_INPUT_PREFIX = "2BCEEEF6124E0936F43E9DA6DADE9D2F7EEA3745F9C030001422BD5B23B858DF"
SHA_OUTPUT = "042C6532750629A62576AC8DA0D4B97DE5E2C6BFEDCE521252A0A07B6312B569"


def srgb_to_linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def rgb_to_lab(rgb):
    lin = srgb_to_linear(rgb.astype(np.float64))
    m = np.array([
        [0.4124564, 0.3575761, 0.1804375],
        [0.2126729, 0.7151522, 0.0721750],
        [0.0193339, 0.1191920, 0.9503041],
    ])
    xyz = lin @ m.T / np.array([0.95047, 1.00000, 1.08883])
    eps = 216.0 / 24389.0
    kappa = 24389.0 / 27.0
    f = np.where(xyz > eps, np.cbrt(xyz), (kappa * xyz + 16.0) / 116.0)
    L = 116.0 * f[..., 1] - 16.0
    a = 500.0 * (f[..., 0] - f[..., 1])
    b = 200.0 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], axis=-1)


def lab_to_rgb(lab):
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    fy = (L + 16.0) / 116.0
    fx = fy + a / 500.0
    fz = fy - b / 200.0
    eps = 216.0 / 24389.0
    kappa = 24389.0 / 27.0

    def finv(f):
        f3 = f ** 3
        return np.where(f3 > eps, f3, (116.0 * f - 16.0) / kappa)

    xyz = np.stack([finv(fx), finv(fy), finv(fz)], axis=-1) * np.array([0.95047, 1.00000, 1.08883])
    m = np.array([
        [3.2404542, -1.5371385, -0.4985314],
        [-0.9692660, 1.8760108, 0.0415560],
        [0.0556434, -0.2040259, 1.0572252],
    ])
    lin = np.clip(xyz @ m.T, 0.0, None)
    srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)
    return np.clip(srgb * 255.0, 0.0, 255.0)


def sha256(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest().upper()


def main(src, dst):
    # HARD seal: this tool reproduces exactly ONE approved transformation. A different
    # input is a hard failure, not a warning — an "unverified input" success path would
    # let a stale or wrong sheet masquerade as the approved output.
    in_sha = sha256(src)
    if in_sha != SHA_INPUT_PREFIX:
        print(f"FAIL: input sha {in_sha}")
        print(f"      expected  {SHA_INPUT_PREFIX} (pre-fix sheet, commit 5dfc7f9e0)")
        print("      recover it with: git show 5dfc7f9e0:godot/assets/sprites/lingpet/"
              "baekrin_mokrin_transform_6x2_12f.png | git lfs smudge")
        return 1

    img = Image.open(src)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    arr = np.array(img)
    visible = arr[..., 3] > 0
    lab = rgb_to_lab(arr[..., :3]) * GAIN + OFF
    rgb2 = lab_to_rgb(lab)
    out = arr.copy()
    out[..., :3][visible] = np.round(rgb2[visible]).astype(np.uint8)
    Image.fromarray(out).save(dst, format="PNG", optimize=False)

    if not np.array_equal(np.array(Image.open(dst).convert("RGBA"))[..., 3], arr[..., 3]):
        print("FAIL: alpha changed")
        return 1
    out_sha = sha256(dst)
    print(f"output sha {out_sha}")
    if out_sha != SHA_OUTPUT:
        print(f"FAIL: expected {SHA_OUTPUT}")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
