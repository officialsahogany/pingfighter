"""N6b 팔레트 hard gate 검증기 — 스매셔 착석 라이더(N).

계약: docs/lingpet_mount_rider_seated_smasher_brief.md §3-1.

기준 정의(2026-08-15 개정 — 사용자 판정):
  **승인 idle 8프레임 medoid + 실측 반경**. 재질별로 8프레임 각각의 중앙 Lab 을 구하고,
  다른 7개까지의 **최대** dE2000 이 가장 작은 프레임을 medoid 로 삼는다. 그때의 최대
  거리가 **실측 반경**이다. 후보는 medoid 로부터 반경 이내여야 한다.

  ⚠️ 구 기준(프레임 0 중심 + 평탄 dE <= 2.5)은 폐기됐다. 그 기준은 idle 자기 시트의
  f2·f3(bronze 2.97 · cream 2.63)를 잘못 탈락시켰다. 반경은 관측에서 나오지, 임의의
  상수에서 나오지 않는다.

  ⚠️ 양성 대조군은 **승인 idle 8프레임뿐이다.** sd_unified_* 는 출하 자산이 아니다
  (production record `promotion_status = rejected_motion_qa_runtime_rolled_back`,
  런타임은 battle_smasher_sprite_paths.gd 에서 별도 시트를 읽는다). gemini_v2 등
  이종 생성원 시트도 마찬가지로 **진단 자료 전용**이며 기준 산출에 넣지 않는다.

관측 해상도 정본(2026-08-14):
  후보    = premultiplied-alpha Lanczos 로 **운영 draw size(기본 160)** 에 축소
  레퍼런스 = 승인 idle 시트의 **native 160** 셀, 구름 제외 y < 96

사용법:
  py tools/verify_smasher_seated_rider_palette.py <candidate.png> [--draw 160]
  py tools/verify_smasher_seated_rider_palette.py --self-test    # 8프레임 자기검정
  py tools/verify_smasher_seated_rider_palette.py --show-basis   # medoid·반경 표만 출력

자기검정은 8프레임 **전부**를 후보 자리에 넣는다. 하나라도 반경을 벗어나면 기준이
자기 자신을 기각하는 것이므로 exit 1 이다.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REF_SHEET = Path("godot/assets/sprites/smasher/hanmiryang_rear_cloud_idle_autosprite_v1_4x2_160_clean.png")
REF_CELL = 160
REF_COLS = 4
REF_FRAMES = 8
REF_CLOUD_CUT_Y = 96          # 레퍼런스에만 적용
OCCUPANCY_FRACTION = 0.30

MATERIAL_NAMES = [
    "indigo_hair_dress",
    "cream_sleeve",
    "red_accent",
    "wood_shield",
    "bronze_beopgu",
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


def reference_frames(repo):
    """승인 idle 8프레임 각각의 재질별 (중앙 Lab, 점유율). 양성 대조군은 이것뿐이다."""
    sheet = np.array(Image.open(Path(repo) / REF_SHEET).convert("RGBA"))
    frames = []
    for i in range(REF_FRAMES):
        r, c = divmod(i, REF_COLS)
        cell = sheet[r * REF_CELL:(r + 1) * REF_CELL, c * REF_CELL:(c + 1) * REF_CELL]
        frames.append(measure(cell, cloud_cut=REF_CLOUD_CUT_Y)[0])
    return frames


def basis_from(frames):
    """재질별 medoid(최대거리 최소 프레임) + 실측 반경 + 점유율 하한."""
    basis = {}
    for name in MATERIAL_NAMES:
        labs = [f[name][0] for f in frames]
        occs = [f[name][1] for f in frames]
        if any(l is None for l in labs):
            raise RuntimeError("레퍼런스 프레임에 %s 픽셀이 없다 — 기준 산출 불가" % name)
        dist = [[ciede2000(a, b) for b in labs] for a in labs]
        i = min(range(len(labs)), key=lambda k: max(dist[k]))
        basis[name] = {
            "medoid": labs[i],
            "medoid_frame": i,
            "radius": max(dist[i]),
            "occ_min": min(occs),
            "occ_max": max(occs),
            "occ_floor": min(occs) * OCCUPANCY_FRACTION,
        }
    return basis


def show_basis(basis):
    print("[N6b 기준] 승인 idle 8프레임 medoid + 실측 반경")
    print("  %-19s %-24s %6s %8s %s" % ("재질", "medoid Lab", "frame", "반경", "점유율(관측/하한)"))
    for name in MATERIAL_NAMES:
        b = basis[name]
        m = b["medoid"]
        print("  %-19s (%5.1f,%5.1f,%6.1f) %6d %8.3f   %.2f~%.2f%% / >=%.2f%%"
              % (name, m[0], m[1], m[2], b["medoid_frame"], b["radius"],
                 b["occ_min"], b["occ_max"], b["occ_floor"]))


def report(res, denom, basis, label):
    print("%s  (분모 opaque = %d px)" % (label, denom))
    print("  %-19s %-24s %8s %8s %8s %s"
          % ("재질", "중앙 Lab", "거리", "반경", "점유율%", "판정"))
    ok = True
    for name in MATERIAL_NAMES:
        b = basis[name]
        med, occ, n = res[name]
        if med is None:
            print("  %-19s %-24s %8s %8.3f %8s FAIL(픽셀 0)"
                  % (name, "-", "-", b["radius"], "0.00"))
            ok = False
            continue
        de = ciede2000(med, b["medoid"])
        pass_de = de <= b["radius"]
        pass_occ = occ >= b["occ_floor"]
        if not (pass_de and pass_occ):
            ok = False
        print("  %-19s (%5.1f,%5.1f,%6.1f) %8.3f %8.3f %8.2f %s%s"
              % (name, med[0], med[1], med[2], de, b["radius"], occ,
                 "PASS" if pass_de else "FAIL(반경 초과)",
                 "" if pass_occ else " FAIL(점유율<%.2f)" % b["occ_floor"]))
    print("  => %s" % ("PASS" if ok else "FAIL"))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("candidate", nargs="?")
    ap.add_argument("--draw", type=int, default=160)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--show-basis", action="store_true")
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()

    frames = reference_frames(args.repo)
    basis = basis_from(frames)

    if args.show_basis:
        show_basis(basis)
        return 0

    if args.self_test:
        show_basis(basis)
        print("\n[자기검정] 승인 idle 8프레임을 후보 자리에 넣는다 - 전부 반경 이내여야 한다")
        ok = True
        for i, f in enumerate(frames):
            row = []
            for name in MATERIAL_NAMES:
                b = basis[name]
                de = ciede2000(f[name][0], b["medoid"])
                bad = de > b["radius"]
                ok = ok and not bad
                row.append("%6.3f%s" % (de, "*" if bad else " "))
            print("  idle f%d  %s" % (i, " ".join(row)))
        print("  => %s%s" % ("PASS" if ok else "FAIL", "" if ok else "  (* = 반경 초과)"))
        return 0 if ok else 1

    if not args.candidate:
        print("candidate 경로가 필요합니다 (또는 --self-test / --show-basis)")
        return 2
    cand = premultiplied_lanczos(Image.open(args.candidate), args.draw)
    cand_res, cand_denom = measure(cand, cloud_cut=None)
    print("[N6b] 후보 = %s → premultiplied Lanczos %dpx / 기준 = 승인 idle 8f medoid+반경"
          % (args.candidate, args.draw))
    show_basis(basis)
    print()
    return 0 if report(cand_res, cand_denom, basis, "후보") else 1


if __name__ == "__main__":
    sys.exit(main())
