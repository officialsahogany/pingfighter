"""
Input Key Mapping Tests - 입력 키 매핑 테스트
한글/영문 키보드에서 A/D 이동 입력이 항상 동작하는지 확인
"""

import unittest

import pygame

from tests.test_framework import GameTestCase
from core.input_keys import (
    is_move_left_key,
    is_move_right_key,
    is_move_left_pressed,
    is_move_right_pressed,
)


class TestInputKeyMapping(GameTestCase):
    """입력 키 매핑 테스트"""

    def test_move_left_keys_support_korean_and_english_layouts(self):
        """왼쪽 이동 키가 한/영 모두에서 인식되는지 확인"""
        left_keys = [
            pygame.K_LEFT,
            pygame.K_a,
            0x61,
            0x6E,
        ]

        for key_code in left_keys:
            with self.subTest(key_code=key_code):
                self.assertTrue(
                    is_move_left_key(key_code),
                    msg=f"Left move key not recognized: {key_code}",
                )

    def test_move_right_keys_support_korean_and_english_layouts(self):
        """오른쪽 이동 키가 한/영 모두에서 인식되는지 확인"""
        right_keys = [
            pygame.K_RIGHT,
            pygame.K_d,
            0x64,
            0x6F,
        ]

        for key_code in right_keys:
            with self.subTest(key_code=key_code):
                self.assertTrue(
                    is_move_right_key(key_code),
                    msg=f"Right move key not recognized: {key_code}",
                )

    def test_move_left_pressed_state_helper(self):
        """get_pressed() 결과에 대해 왼쪽 이동 상태 헬퍼가 정상 동작하는지 확인"""
        size = max(pygame.K_LEFT, pygame.K_a, 0x61, 0x6E) + 10
        keys = [False] * size

        for key_code in (pygame.K_LEFT, pygame.K_a, 0x61, 0x6E):
            keys_local = keys[:]
            keys_local[key_code] = True
            with self.subTest(pressed_key=key_code):
                self.assertTrue(is_move_left_pressed(keys_local))

    def test_move_right_pressed_state_helper(self):
        """get_pressed() 결과에 대해 오른쪽 이동 상태 헬퍼가 정상 동작하는지 확인"""
        size = max(pygame.K_RIGHT, pygame.K_d, 0x64, 0x6F) + 10
        keys = [False] * size

        for key_code in (pygame.K_RIGHT, pygame.K_d, 0x64, 0x6F):
            keys_local = keys[:]
            keys_local[key_code] = True
            with self.subTest(pressed_key=key_code):
                self.assertTrue(is_move_right_pressed(keys_local))


if __name__ == "__main__":
    unittest.main()
