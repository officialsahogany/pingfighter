"""
AK-47 연사 홀드 스모크 테스트

목표
- 스페이스/좌클릭을 누르고 있는 동안 끊김 없이 fire_interval 간격으로
  총알이 발사되는지 점검한다.

사용법
- SDL 가상 드라이버로 창을 띄우지 않고 실행됨:
    python tools/smoke_ak47_hold.py

판정
- 180프레임(3초 @60FPS) 동안 홀드 입력을 유지하며 발사 간격의 최대 갭이
  fire_interval+1 프레임을 넘지 않으면 통과로 본다.
"""

import os
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame

# 로컬 패키지 임포트 경로 보정
import sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from item_effects.ak47 import get_ak47_instance


def main():
    pygame.init()
    try:
        pygame.display.set_mode((1, 1))
    except Exception:
        pass

    ak47 = get_ak47_instance()
    ak47.activate(None, current_stage=1)

    # 테스트 파라미터
    total_frames = 180  # 3초간 테스트
    player_rect = pygame.Rect(100, 400, 40, 40)
    boss_rect = pygame.Rect(100, 60, 80, 20)

    # 입력 홀드 시작
    ak47.handle_space_input(True)

    fire_frames: list[int] = []
    for f in range(total_frames):
        # 연사 체크 (프레임마다)
        if ak47.should_fire():
            if ak47.fire(player_rect, boss_rect):
                fire_frames.append(f)

        # 내부 쿨다운/총알 이동 업데이트
        ak47.update(boss_rect, tick_timer=True)

    # 입력 해제
    ak47.handle_space_input(False)

    if not fire_frames:
        print("[FAIL] 연사 실패: 발사가 발생하지 않음")
        return 1

    gaps = [b - a for a, b in zip(fire_frames, fire_frames[1:])]
    max_gap = max(gaps) if gaps else 0
    allowed = ak47.fire_interval + 1  # 1프레임 유예

    print(f"fires={len(fire_frames)}, first={fire_frames[0]}, max_gap={max_gap}, allowed<={allowed}")
    if max_gap <= allowed:
        print("[OK] AK-47 홀드 연사 간격 안정화 통과")
        return 0
    else:
        print("[FAIL] 연사 간격이 들쭉날쭉함")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
