"""N6b 팔레트 hard gate 검증기 — 스매셔 착석 라이더(N).

계약: docs/lingpet_mount_rider_seated_smasher_brief.md §3-1.

관측 해상도 정본(2026-08-14):
  후보    = premultiplied-alpha Lanczos 로 **운영 draw size(기본 160)** 에 축소
  레퍼런스 = 승인 idle 시트 프레임 0 의 **native 160** 셀, 구름 제외 y < 96

판정: 재질별 후보 **중앙 Lab** 이 계약 중심과 dE2000 <= 2.5, 그리고 점유율이
      레퍼런스 점유율의 30% 이상.

사용법:
  py tools/verify_smasher_seated_rider_palette.py <candidate.png> [--draw 160]
  py tools/verify_smasher_seated_rider_palette.py --self-test    # 레퍼런스 자기검정

레퍼런스를 후보로 넣으면 전 재질 dE ~= 0 으로 통과해야 한다(자기검정).
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REF_SHEET = Path("godot/assets/sprites/smasher/hanmiryang_rear_cloud_idle_autosprite_v1_4x2_160_clean.png")
REF_CELL = 160
REF_CLOUD_CUT_Y = 96          # 레퍼런스에만 적용
DE_MAX = 2.5
OCCUPANCY_FRACTION = 0.30

# 계약 §3-1 확정값 (재질, 중심 Lab, 레퍼런스 점유율 %)
MATERIALS = [
    ("indigo_hair_dress", (22.0, 7.4, -15.8), 55.86),
    ("cream_sleeve", (87.9, 2.2, 4.3), 5.40),
    ("red_accent", (32.0, 20.8, 13.3), 9.22),
    ("wood_shield", (24.3, 14.4, 10.5), 8.28),
    ("bronze_beopgu", (47.9, 8.2, 15.6), 11.98),
]


def srgb_to_lab(rgb):
    c = rgb.astype(np.float64) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T
    white = np.array([0.95047, 1.0, 1.08883])
    t = xyz / white
    d = 6.0 / 29.0
    f = np.where(t > d ** 3, np.cbrt(t), t / (3 * d * d) + 4.0 / 29.0)
    return np.stack([116 * f[..., 1] - 16,
                     500 * (f[..., 0] - f[..., 1]),
                     200 * (f[..., 1] - f[..., 2])], axis=-1)


def ciede2000(lab1, lab2):
    L1, a1, b1 = lab1
    L2, a2, b2 = lab2
    C1 = np.hypot(a1, b1)
    C2 = np.hypot(a2, b2)
    Cb = (C1 + C2) / 2.0
    G = 0.5 * (1 - np.sqrt(Cb ** 7 / (Cb ** 7 + 25.0 ** 7))) if Cb > 0 else 0.5
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360.0 if (a1p or b1) else 0.0
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360.0 if (a2p or b2) else 0.0
    dLp = L2 - L1
    dCp = C2p - C1p
    if C1p * C2p == 0:
        dhp = 0.0
    elif abs(h2p - h1p) <= 180:
        dhp = h2p - h1p
    elif h2p - h1p > 180:
        dhp = h2p - h1p - 360
    else:
        dhp = h2p - h1p + 360
    dHp = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dhp) / 2.0)
    Lbp = (L1 + L2) / 2.0
    Cbp = (C1p + C2p) / 2.0
    if C1p * C2p == 0:
        hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbp = (h1p + h2p) / 2.0
    elif h1p + h2p < 360:
        hbp = (h1p + h2p + 360) / 2.0
    else:
        hbp = (h1p + h2p - 360) / 2.0
    T = (1 - 0.17 * np.cos(np.radians(hbp - 30))
         + 0.24 * np.cos(np.radians(2 * hbp))
         + 0.32 * np.cos(np.radians(3 * hbp + 6))
         - 0.20 * np.cos(np.radians(4 * hbp - 63)))
    dth = 30 * np.exp(-(((hbp - 275) / 25.0) ** 2))
    Rc = 2 * np.sqrt(Cbp ** 7 / (Cbp ** 7 + 25.0 ** 7)) if Cbp > 0 else 0.0
    Sl = 1 + (0.015 * (Lbp - 50) ** 2) / np.sqrt(20 + (Lbp - 50) ** 2)
    Sc = 1 + 0.045 * Cbp
    Sh = 1 + 0.015 * Cbp * T
    Rt = -np.sin(np.radians(2 * dth)) * Rc
    return float(np.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2
                         + Rt * (dCp / Sc) * (dHp / Sh)))


def masks_for(rgb):
    r = rgb[..., 0].astype(np.int16)
    g = rgb[..., 1].astype(np.int16)
    b = rgb[..., 2].astype(np.int16)
    mx = rgb.max(axis=2).astype(np.int16)
    mn = rgb.min(axis=2).astype(np.int16)
    chroma = mx - mn
    L = srgb_to_lab(rgb)[..., 0]
    red = (r > g + 40) & (r > b + 25) & (r >= 90)
    cream = (mx >= 190) & (chroma <= 45)
    indigo = (b > r + 8) & (b >= 40) & ~cream
    brown = (r > b + 20) & (chroma >= 25) & ~red
    return {
        "indigo_hair_dress": indigo,
        "cream_sleeve": cream,
        "red_accent": red,
        "wood_shield": brown & (L < 36),
        "bronze_beopgu": brown & (L >= 36),
    }


def premultiplied_lanczos(img, size):
    a = np.array(img.convert("RGBA")).astype(np.float64)
    al = a[..., 3:4] / 255.0
    pm = np.concatenate([a[..., :3] * al, a[..., 3:4]], axis=2)
    s = np.array(Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8))
                 .resize((size, size), Image.LANCZOS)).astype(np.float64)
    als = s[..., 3:4] / 255.0
    rgb = np.where(als > 1e-6, s[..., :3] / np.maximum(als, 1e-6), 0.0)
    return np.concatenate([np.clip(rgb, 0, 255), s[..., 3:4]], axis=2).astype(np.uint8)


def measure(arr, cloud_cut=None):
    rgb, al = arr[..., :3], arr[..., 3]
    op = al > 200
    if cloud_cut is not None:
        op = op & (np.arange(arr.shape[0])[:, None] < cloud_cut)
    denom = int(op.sum())
    lab = srgb_to_lab(rgb)
    out = {}
    for name, m in masks_for(rgb).items():
        sel = m & op
        n = int(sel.sum())
        if n == 0:
            out[name] = (None, 0.0, 0)
            continue
        px = lab[sel]
        out[name] = (tuple(np.median(px, axis=0)), 100.0 * n / denom, n)
    return out, denom


def report(res, denom, label):
    print("%s  (분모 candidate_opaque = %d px)" % (label, denom))
    print("  %-19s %-26s %8s %8s %s" % ("재질", "중앙 Lab", "dE2000", "점유율%", "판정"))
    ok = True
    for name, center, ref_occ in MATERIALS:
        med, occ, n = res[name]
        floor = ref_occ * OCCUPANCY_FRACTION
        if med is None:
            print("  %-19s %-26s %8s %8s FAIL(픽셀 0)" % (name, "-", "-", "0.00"))
            ok = False
            continue
        de = ciede2000(med, center)
        pass_de = de <= DE_MAX
        pass_occ = occ >= floor
        if not (pass_de and pass_occ):
            ok = False
        print("  %-19s (%5.1f,%5.1f,%6.1f) %8.2f %8.2f %s%s"
              % (name, med[0], med[1], med[2], de, occ,
                 "PASS" if pass_de else "FAIL(dE)",
                 "" if pass_occ else " FAIL(점유율<%.2f)" % floor))
    print("  => %s" % ("PASS" if ok else "FAIL"))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("candidate", nargs="?")
    ap.add_argument("--draw", type=int, default=160)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()

    ref_path = Path(args.repo) / REF_SHEET
    ref_cell = np.array(Image.open(ref_path).convert("RGBA"))[:REF_CELL, :REF_CELL]
    ref_res, ref_denom = measure(ref_cell, cloud_cut=REF_CLOUD_CUT_Y)

    if args.self_test:
        print("[자기검정] 레퍼런스 native 160 (구름 제외 y<%d)" % REF_CLOUD_CUT_Y)
        return 0 if report(ref_res, ref_denom, "레퍼런스") else 1

    if not args.candidate:
        print("candidate 경로가 필요합니다 (또는 --self-test)")
        return 2
    cand = premultiplied_lanczos(Image.open(args.candidate), args.draw)
    cand_res, cand_denom = measure(cand, cloud_cut=None)
    print("[N6b] 후보 = %s → premultiplied Lanczos %dpx / 레퍼런스 = native %d"
          % (args.candidate, args.draw, REF_CELL))
    return 0 if report(cand_res, cand_denom, "후보") else 1


if __name__ == "__main__":
    sys.exit(main())
