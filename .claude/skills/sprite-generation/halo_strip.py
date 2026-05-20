"""AI 아이콘 halo 잔재 제거 + 재리샘플.

remove_bg.py는 `WHITISH_SAT<=30` 인 순백 배경만 플러드 필로 털어내기 때문에,
Gemini가 아이콘 실루엣 바깥으로 그려주는 저채도 파스텔 halo (cyan aura, red
aura, yellow glow 등) 가 남는다. 이게 32px로 내려가면 아이콘 가장자리에
테두리처럼 보인다.

이 스크립트는 nukki 된 1024 PNG를 받아서:
1. 기존 투명 픽셀로부터 BFS로 확장
2. 확장 대상: `V >= 220 AND S <= 100` (밝고 채도 낮은 halo) 픽셀
3. 이 영역을 투명화

로 halo 잔재만 추가로 털어낸다. 실루엣 내부의 채도 있는 본체는 건드리지
않는다.
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


HALO_V_THRESHOLD = 220    # max(R,G,B) >= 220 → 충분히 밝은 픽셀
HALO_S_THRESHOLD = 110    # max(R,G,B) - min(R,G,B) <= 110 → 저채도 halo
ALPHA_FULL_OPAQUE = 250   # 이 이하면 semi-transparent halo 후보


def strip_halo(src_path: Path, dst_path: Path) -> None:
    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img)  # H x W x 4
    h, w, _ = arr.shape

    r = arr[..., 0].astype(np.int16)
    g = arr[..., 1].astype(np.int16)
    b = arr[..., 2].astype(np.int16)
    a = arr[..., 3]

    v = np.maximum(np.maximum(r, g), b)
    s_range = v - np.minimum(np.minimum(r, g), b)

    # halo 후보: 밝고 + 채도 낮고 + 이미 투명하거나 반투명인 픽셀 포함
    halo_candidate = (v >= HALO_V_THRESHOLD) & (s_range <= HALO_S_THRESHOLD)

    # 이미 투명한 픽셀을 시작점으로 BFS
    transparent = a == 0
    visited = transparent.copy()

    q: deque[tuple[int, int]] = deque()
    # BFS 시작: 투명 픽셀 전부를 큐에 안 넣고, 투명↔불투명 경계만 push
    for y in range(h):
        for x in range(w):
            if transparent[y, x]:
                # 인접 칸에 candidate 있으면 push
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and halo_candidate[ny, nx]:
                        visited[ny, nx] = True
                        q.append((ny, nx))

    kill = np.zeros_like(transparent)
    while q:
        y, x = q.popleft()
        kill[y, x] = True
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and halo_candidate[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))

    killed = int(kill.sum())
    arr[..., 3][kill] = 0
    Image.fromarray(arr).save(dst_path)
    print(f"{src_path.name}: stripped {killed} halo px -> {dst_path.name}")


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: py halo_strip.py <src.png> <dst.png>")
        sys.exit(1)
    strip_halo(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
