"""백린 M-베이스(빈안장 탑다운) 수용 게이트 검증기 — G1~G8 자동 판정.

정본 = `docs/lingpet_baekrin_mount_base_asset_brief.md` §5.
G9(실 렌더 캡처)는 런타임 QA 소관이라 여기서 다루지 않는다.

사용법
------
    py tools/verify_baekrin_mount_base_asset.py <candidate_cell.png>
        [--tail-mask <tail_mask.png>]

- `candidate_cell.png` : 런타임 셀(정사각, 알파 포함). G1~G6·G8 판정 대상.
- `--tail-mask`        : 꼬리만 1(불투명)인 이진 마스크. 없으면 G7 은 SKIP 이
                         아니라 **FAIL** 이다(길이 보존은 필수 게이트).

레퍼런스 기준값은 아래 REFERENCE_* **상수**로 고정돼 있다(이미지에서 다시 재는
옵션은 없다 — 상수가 정본이라야 후보마다 기준이 흔들리지 않는다).

자기검정: **패킹한 레퍼런스 셀을 그대로 candidate 로 넣어** 돌린다.
    py tools/verify_baekrin_mount_base_asset.py <reference_cell_512.png> --tail-mask <ref_tail_mask.png>
직선 꼬리 레퍼런스는 **G3 만 FAIL**(꼬리가 안장선 아래 = 재구성 사유)이고 나머지는
전부 PASS 여야 한다. 그 외 게이트가 레퍼런스에서 떨어지면 상수/문턱이 어긋난 것이다.

레퍼런스 상수는 사용자 제공 원화 `백린_빈안장_topdown_magenta.png` 를
`chroma_key.py --key magenta --pad 4` + 마젠타 pocket 제거 → 512 셀 패킹 →
(리샘플 링잉 때문에) pocket 제거 1회 더, 순서로 만든 셀에서 실측했다(2026-08-13).
"""

from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

# ── 레퍼런스 실측 상수 (전부 **512 셀 공간**에서 측정) ──────────────────────
# 재질별 중앙 Lab(D65) + 그 재질이 자기 중앙값 대비 갖는 자연 산포(p95 dE2000).
# 산포를 함께 박는 이유: 크랙 텍스처·금속 하이라이트는 재질 내부 dE 가 원래 크다.
# 그래서 "표본 dE 중앙값 <= 2.5" 같은 문턱은 **레퍼런스 자신도 탈락**시킨다
# (자기검정에서 실측 확인). 판정은 두 축으로 나눈다:
#   ① 중심 이동  : dE2000(후보 재질 중앙 Lab, 레퍼런스 중앙 Lab) <= CENTER_MAX
#   ② 산포 변화  : |후보 p95 - 레퍼런스 p95| <= SPREAD_DELTA_MAX
REFERENCE_MATERIAL = {
    # name: (median Lab, 자기중앙 p95 dE, 마스크 점유율)
    "porcelain_white": ((90.9, 1.2, 3.5), 8.95, 0.5202),
    "gold": ((63.7, 14.4, 51.3), 23.49, 0.2511),
    "celadon_jade": ((73.2, -9.9, 20.2), 11.53, 0.0035),
    "navy_saddle": ((32.6, -1.7, -17.6), 12.11, 0.0291),
}
# 꼬리 측지 길이: 레퍼런스 셀에서 `불투명 ∧ y>=379`(= 누끼 y>=1010) 최대성분 = 208px.
REFERENCE_TAIL_GEODESIC_CELL512 = 208.0
TAIL_LENGTH_RATIO_MIN = 0.90

CELL_EXPECTED = 512
MARGIN_MIN = 4
CONTENT_WIDTH_RATIO_MAX = 0.72
MAGENTA_RESIDUE_MAX_DOM = 20
SOCKET_TOLERANCE_PX = 2.0
NAVY_MIN_AREA_RATIO = 0.015
MATERIAL_MIN_AREA_RATIO = 0.001
DE_CENTER_MAX = 2.5        # ① 재질 중심 이동 상한
DE_SPREAD_DELTA_MAX = 3.0  # ② 재질 내부 산포(p95) 변화 상한
MATERIAL_AREA_DELTA_MAX = 0.6  # 마스크 점유율이 레퍼런스 대비 ±60% 를 넘으면 재질 재배치


def srgb_to_lab(px: np.ndarray) -> np.ndarray:
    c = px.astype(np.float64) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805],
                  [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    eps, kappa = 216.0 / 24389.0, 24389.0 / 27.0
    f = np.where(xyz > eps, np.cbrt(xyz), (kappa * xyz + 16.0) / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0,
                     500.0 * (f[..., 0] - f[..., 1]),
                     200.0 * (f[..., 1] - f[..., 2])], axis=-1)


def ciede2000(lab1: np.ndarray, lab2: np.ndarray) -> np.ndarray:
    """CIEDE2000 색차. lab1 = (N,3) 표본, lab2 = (3,) 기준."""
    L1, a1, b1 = lab1[..., 0], lab1[..., 1], lab1[..., 2]
    L2, a2, b2 = lab2[0], lab2[1], lab2[2]
    C1 = np.hypot(a1, b1)
    C2 = np.hypot(a2, b2)
    Cbar = (C1 + C2) / 2.0
    G = 0.5 * (1.0 - np.sqrt(Cbar ** 7 / (Cbar ** 7 + 25.0 ** 7 + 1e-12)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360.0
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360.0
    dLp = L2 - L1
    dCp = C2p - C1p
    dhp = h2p - h1p
    dhp = np.where(dhp > 180.0, dhp - 360.0, np.where(dhp < -180.0, dhp + 360.0, dhp))
    dhp = np.where((C1p * C2p) == 0.0, 0.0, dhp)
    dHp = 2.0 * np.sqrt(C1p * C2p) * np.sin(np.radians(dhp) / 2.0)
    Lbar = (L1 + L2) / 2.0
    Cbarp = (C1p + C2p) / 2.0
    hsum = h1p + h2p
    hdiff = np.abs(h1p - h2p)
    hbar = np.where((C1p * C2p) == 0.0, hsum,
                    np.where(hdiff <= 180.0, hsum / 2.0,
                             np.where(hsum < 360.0, (hsum + 360.0) / 2.0, (hsum - 360.0) / 2.0)))
    T = (1 - 0.17 * np.cos(np.radians(hbar - 30.0))
         + 0.24 * np.cos(np.radians(2 * hbar))
         + 0.32 * np.cos(np.radians(3 * hbar + 6.0))
         - 0.20 * np.cos(np.radians(4 * hbar - 63.0)))
    dtheta = 30.0 * np.exp(-(((hbar - 275.0) / 25.0) ** 2))
    RC = 2.0 * np.sqrt(Cbarp ** 7 / (Cbarp ** 7 + 25.0 ** 7 + 1e-12))
    SL = 1.0 + (0.015 * (Lbar - 50.0) ** 2) / np.sqrt(20.0 + (Lbar - 50.0) ** 2)
    SC = 1.0 + 0.045 * Cbarp
    SH = 1.0 + 0.015 * Cbarp * T
    RT = -np.sin(np.radians(2 * dtheta)) * RC
    return np.sqrt((dLp / SL) ** 2 + (dCp / SC) ** 2 + (dHp / SH) ** 2
                   + RT * (dCp / SC) * (dHp / SH))


def largest_component(mask: np.ndarray) -> np.ndarray:
    """4-이웃 최대 연결성분(외부 의존 없이 BFS)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    best = np.zeros_like(mask, dtype=bool)
    best_size = 0
    for sy, sx in np.argwhere(mask):
        if seen[sy, sx]:
            continue
        comp = []
        dq = deque([(sy, sx)])
        seen[sy, sx] = True
        while dq:
            y, x = dq.popleft()
            comp.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    dq.append((ny, nx))
        if len(comp) > best_size:
            best_size = len(comp)
            best = np.zeros_like(mask, dtype=bool)
            ys, xs = zip(*comp)
            best[list(ys), list(xs)] = True
    return best


def geodesic_diameter(mask: np.ndarray) -> int:
    """마스크 내부 최장 측지 거리(4-이웃 BFS 2회)."""
    idx = np.argwhere(mask)
    if not len(idx):
        return 0
    h, w = mask.shape

    def bfs(src):
        dist = -np.ones((h, w), dtype=np.int32)
        dq = deque([src])
        dist[src] = 0
        far, fard = src, 0
        while dq:
            y, x = dq.popleft()
            d = dist[y, x]
            if d > fard:
                far, fard = (y, x), d
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and dist[ny, nx] < 0:
                    dist[ny, nx] = d + 1
                    dq.append((ny, nx))
        return far, fard

    a, _ = bfs(tuple(idx[0]))
    _, d = bfs(a)
    return d


def navy_pad_mask(rgb: np.ndarray, opaque: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    navy = opaque & (b > r + 25) & (b > g + 10) & (b < 200) & (r < 160)
    if not navy.any():
        return navy
    return largest_component(navy)


def material_masks(rgb: np.ndarray, opaque: np.ndarray, pad: np.ndarray) -> dict:
    f = rgb.astype(np.float64)
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    mx, mn = f.max(axis=2), f.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    val = mx
    return {
        "porcelain_white": opaque & (val >= 190) & (sat <= 0.16),
        "gold": opaque & (sat >= 0.30) & (r > g + 18) & (g > b + 25) & (val >= 110),
        "celadon_jade": opaque & (sat >= 0.14) & (sat < 0.45) & (g >= r) & (g >= b - 6) & (val >= 120) & (val <= 235),
        "navy_saddle": pad,
    }


class Gate:
    def __init__(self) -> None:
        self.failed = False

    def check(self, gid: str, label: str, ok: bool, detail: str) -> None:
        print("%-4s %-6s %s | %s" % (gid, "PASS" if ok else "FAIL", label, detail))
        if not ok:
            self.failed = True


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="백린 M-베이스 수용 게이트 G1~G8")
    ap.add_argument("candidate")
    ap.add_argument("--tail-mask", default="")
    args = ap.parse_args(argv[1:])

    im = Image.open(args.candidate).convert("RGBA")
    arr = np.array(im)
    rgb, al = arr[..., :3], arr[..., 3]
    opaque = al > 0
    h, w = al.shape
    gate = Gate()

    if not opaque.any():
        print("G0   FAIL   불투명 픽셀 0 — 검증 불가")
        return 1

    # G1 — 누끼 경계
    edge = int((al[0, :] > 0).sum() + (al[-1, :] > 0).sum() + (al[:, 0] > 0).sum() + (al[:, -1] > 0).sum())
    corners = [int(al[0, 0]), int(al[0, -1]), int(al[-1, 0]), int(al[-1, -1])]
    gate.check("G1", "누끼 경계", edge == 0 and max(corners) == 0,
               "edge alpha>0 = %d, corners = %s" % (edge, corners))

    # G2 — 마젠타 잔재
    dom = np.minimum(rgb[..., 0].astype(int), rgb[..., 2].astype(int)) - rgb[..., 1].astype(int)
    residue = int((opaque & (dom >= MAGENTA_RESIDUE_MAX_DOM)).sum())
    gate.check("G2", "마젠타 잔재", residue == 0, "min(r,b)-g >= %d 픽셀 = %d" % (MAGENTA_RESIDUE_MAX_DOM, residue))

    ys, xs = np.nonzero(opaque)
    bbox = (int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max()))
    content_w = bbox[1] - bbox[0] + 1
    content_cx = (bbox[0] + bbox[1] + 1) / 2.0
    content_bottom = float(bbox[3] + 1)

    # 소켓 검출(G3/G4 공통 정본)
    pad = navy_pad_mask(rgb, opaque)
    pad_ratio = pad.sum() / float(opaque.sum())
    if pad_ratio < NAVY_MIN_AREA_RATIO:
        gate.check("G3", "소켓 검출", False,
                   "감청 패드 최대성분 %.3f%% < %.1f%% — 자동 검출 무효(수동 승인 소켓 필요)"
                   % (100 * pad_ratio, 100 * NAVY_MIN_AREA_RATIO))
        gate.check("G4", "소켓 가로중앙", False, "소켓 미검출")
    else:
        pys, pxs = np.nonzero(pad)
        socket_x = (int(pxs.min()) + int(pxs.max()) + 1) / 2.0
        socket_y = float(int(pys.max()) + 1)
        gate.check("G3", "소켓=최하단", abs(content_bottom - socket_y) <= SOCKET_TOLERANCE_PX,
                   "socket_y %.1f vs 불투명 bbox 하단 %.1f (허용 %.1fpx)"
                   % (socket_y, content_bottom, SOCKET_TOLERANCE_PX))
        gate.check("G4", "소켓 가로중앙", abs(socket_x - content_cx) <= SOCKET_TOLERANCE_PX,
                   "socket_x %.1f vs 콘텐츠 중앙 %.1f (허용 %.1fpx)" % (socket_x, content_cx, SOCKET_TOLERANCE_PX))
        print("     socket = (%.1f, %.1f)  ← 카탈로그 companion_mount_base_saddle_x/y" % (socket_x, socket_y))

    # G5 — 셀 규격
    margin = min(bbox[0], w - 1 - bbox[1], bbox[2], h - 1 - bbox[3])
    gate.check("G5", "셀 규격", w == h == CELL_EXPECTED and margin >= MARGIN_MIN,
               "%dx%d, 최소 여백 %dpx (요구 %d정사각·여백>=%d)" % (w, h, margin, CELL_EXPECTED, MARGIN_MIN))

    # G6 — 폭 상한
    gate.check("G6", "폭 상한", content_w <= CONTENT_WIDTH_RATIO_MAX * w,
               "콘텐츠 폭 %d = 셀의 %.3f (상한 %.2f = 운영 %.0fpx)"
               % (content_w, content_w / float(w), CONTENT_WIDTH_RATIO_MAX, CONTENT_WIDTH_RATIO_MAX * 360))

    # G7 — 꼬리 길이 보존
    if not args.tail_mask:
        gate.check("G7", "꼬리 길이", False, "--tail-mask 미제공 — 길이 보존은 필수 게이트다")
    else:
        tm = np.array(Image.open(args.tail_mask).convert("L")) > 127
        if tm.shape != al.shape:
            gate.check("G7", "꼬리 길이", False, "마스크 해상도 %s != 셀 %s" % (tm.shape, al.shape))
        else:
            tail = largest_component(tm & opaque)
            length = geodesic_diameter(tail)
            need = REFERENCE_TAIL_GEODESIC_CELL512 * TAIL_LENGTH_RATIO_MIN
            gate.check("G7", "꼬리 길이", length >= need,
                       "측지 길이 %dpx (기준 %.1f × %.2f = %.1fpx)"
                       % (length, REFERENCE_TAIL_GEODESIC_CELL512, TAIL_LENGTH_RATIO_MIN, need))

    # G8 — 재질 팔레트(중심 이동 + 산포 변화 + 점유율)
    lab = srgb_to_lab(rgb)
    masks = material_masks(rgb, opaque, pad)
    for name, (ref_lab, ref_p95, ref_ratio) in REFERENCE_MATERIAL.items():
        mask = masks[name]
        ratio = mask.sum() / float(opaque.sum())
        if ratio < MATERIAL_MIN_AREA_RATIO:
            gate.check("G8", "팔레트 %s" % name, False,
                       "마스크 %.3f%% < %.1f%% — 재질 소실 또는 색역 이탈"
                       % (100 * ratio, 100 * MATERIAL_MIN_AREA_RATIO))
            continue
        px = lab[mask]
        med = np.median(px, axis=0)
        center = float(ciede2000(med.reshape(1, 3), np.array(ref_lab))[0])
        p95 = float(np.percentile(ciede2000(px, med), 95))
        area_delta = abs(ratio - ref_ratio) / max(ref_ratio, 1e-6)
        ok = (center <= DE_CENTER_MAX
              and abs(p95 - ref_p95) <= DE_SPREAD_DELTA_MAX
              and area_delta <= MATERIAL_AREA_DELTA_MAX)
        gate.check("G8", "팔레트 %s" % name, ok,
                   "중심 dE %.2f (<=%.1f) · 산포 p95 %.2f vs 기준 %.2f (Δ<=%.1f) · 점유 %.2f%% vs %.2f%% (Δ<=%.0f%%)"
                   % (center, DE_CENTER_MAX, p95, ref_p95, DE_SPREAD_DELTA_MAX,
                      100 * ratio, 100 * ref_ratio, 100 * MATERIAL_AREA_DELTA_MAX))

    print("\nRESULT:", "FAILED" if gate.failed else "ok (G1~G8) — G9 실 렌더 캡처는 별도")
    return 1 if gate.failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
