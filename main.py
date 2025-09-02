#!/usr/bin/env python3
"""
BossPong Main Entry Point
오리지널 bosspong.py처럼 작동하는 메인 게임
"""

import sys
import os

# 플래그에 따라 다른 버전 실행
if '--modular' in sys.argv:
    # 모듈화된 버전 (현재 bosspong.py)
    from bosspong import BossPongGame
    game = BossPongGame()
    game.run()
elif '--playable' in sys.argv or True:  # 기본값으로 playable 버전 실행
    # 플레이 가능한 버전
    from playable_bosspong import PlayableBossPong
    game = PlayableBossPong()
    game.run()
else:
    # 오리지널 버전 (legacy)
    print("원본 버전이 없습니다. --playable 플래그로 실행하세요.")
    sys.exit(1)