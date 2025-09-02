#!/usr/bin/env python3
"""
BossPong 실행기
원본 bosspong.py처럼 바로 게임 실행
"""

from playable_bosspong import PlayableBossPong

if __name__ == "__main__":
    game = PlayableBossPong()
    game.run()