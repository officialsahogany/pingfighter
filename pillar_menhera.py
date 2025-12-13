# -*- coding: utf-8 -*-
"""
Stage 3: 멘헤라 플러시 프레임 - 플레이 화면 주위 액자 (고퀄리티 버전)
- 핑크색 그런지 스타일 액자 테두리
- 체인, 리본, 반창고, 약통, 면도날
- 고퀄리티 곰인형들 (검은 곰, 분홍 곰, 갈색 곰)
- 쿠로미/마이멜로디/헬로키티 스타일 캐릭터들
- 하트, 반짝이 효과
"""

import pygame
import math
import random


class MenheraPlushFrame:
    """멘헤라 플러시 프레임 - 게임 화면 주위 액자 (고퀄리티)"""

    COLORS = {
        # 액자 프레임 색상 (더러운 핑크)
        'frame_pink_dark': (140, 80, 100),
        'frame_pink_mid': (180, 120, 140),
        'frame_pink_light': (210, 160, 175),
        'frame_pink_dirty': (120, 70, 85),
        'frame_edge_dark': (80, 50, 60),
        'frame_rust': (100, 60, 50),
        'frame_stain': (90, 55, 65),

        # 체인
        'chain_dark': (50, 50, 55),
        'chain_mid': (90, 90, 100),
        'chain_light': (140, 140, 155),
        'chain_highlight': (180, 180, 195),

        # 리본
        'ribbon_pink': (255, 150, 180),
        'ribbon_light': (255, 200, 220),
        'ribbon_dark': (200, 100, 130),
        'ribbon_hot_pink': (255, 105, 180),

        # 반창고
        'bandage_base': (240, 215, 185),
        'bandage_pad': (255, 235, 215),
        'bandage_blood': (160, 50, 60),
        'bandage_pink': (255, 200, 210),

        # 약통
        'pill_bottle_orange': (220, 140, 80),
        'pill_bottle_dark': (180, 100, 50),
        'pill_bottle_pink': (255, 180, 200),
        'pill_label': (245, 240, 235),

        # 알약
        'pill_white': (245, 245, 250),
        'pill_pink': (255, 180, 200),
        'pill_blue': (180, 200, 240),
        'pill_yellow': (255, 240, 180),

        # 면도날
        'razor_metal': (200, 205, 215),
        'razor_dark': (140, 145, 155),
        'razor_edge': (230, 235, 245),

        # 곰인형
        'bear_black': (30, 25, 30),
        'bear_dark': (50, 45, 52),
        'bear_brown': (90, 60, 50),
        'bear_light_brown': (140, 100, 80),
        'bear_pink': (255, 180, 200),
        'bear_light_pink': (255, 220, 230),
        'bear_eye': (200, 60, 80),
        'bear_ribbon': (255, 120, 150),

        # 쿠로미 (검은 토끼)
        'kuromi_black': (30, 25, 35),
        'kuromi_dark': (50, 45, 55),
        'kuromi_pink': (255, 150, 180),
        'kuromi_skull': (255, 255, 255),
        'kuromi_eye': (255, 100, 150),

        # 마이멜로디 (분홍 토끼)
        'melody_pink': (255, 180, 200),
        'melody_light': (255, 220, 230),
        'melody_dark': (230, 140, 170),
        'melody_hood': (255, 150, 180),
        'melody_eye': (50, 40, 60),

        # 헬로키티
        'kitty_white': (255, 250, 250),
        'kitty_light': (255, 255, 255),
        'kitty_ribbon': (255, 80, 100),
        'kitty_nose': (255, 200, 100),
        'kitty_eye': (30, 25, 35),

        # 네온사인
        'neon_pink': (255, 100, 180),
        'neon_pink_glow': (255, 150, 200),
        'neon_cyan': (100, 220, 255),
        'neon_cyan_glow': (150, 235, 255),
        'neon_purple': (200, 120, 255),
        'neon_purple_glow': (220, 160, 255),

        # 그래피티
        'graffiti_purple': (120, 80, 140),
        'graffiti_dark': (80, 50, 90),
        'graffiti_pink': (255, 100, 150),

        # 하트
        'heart_pink': (255, 120, 160),
        'heart_red': (255, 80, 100),
        'heart_peach': (255, 200, 180),
        'heart_broken': (180, 80, 100),

        # 배경
        'bg_dark': (20, 15, 25),
        'bg_purple': (30, 20, 35),
    }

    def __init__(self, screen_width, screen_height, game_width, game_height):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 액자 설정
        self.frame_thickness = 50  # 약간 더 두꺼운 액자
        self.frame_outer_margin = 8

        self.time = 0.0
        self.excitement = 0.0

        # 요소들
        self.chains = []
        self.bandages = []
        self.razors = []
        self.pill_bottles = []
        self.pills = []
        self.ribbons = []
        self.bears = []
        self.characters = []  # 쿠로미/마이멜로디/헬로키티
        self.hearts = []
        self.sparkles = []  # 반짝이 효과
        self.floating_hearts = []  # 필러 영역 떠다니는 버블 하트

        self._generate_elements()
        self._create_static_cache()
        self._generate_floating_hearts()  # 떠다니는 하트 초기화

    def _generate_elements(self):
        """모든 요소 생성"""
        self._generate_chains()
        self._generate_bandages()
        self._generate_razors()
        self._generate_pill_bottles()
        self._generate_pills()
        self._generate_ribbons()
        self._generate_bears()
        self._generate_characters()
        self._generate_hearts()
        self._generate_sparkles()

    def _generate_chains(self):
        """체인 생성 - 액자 주변에 매달린 체인들"""
        self.chains = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 상단 좌측에서 내려오는 체인
        self.chains.append({
            'start_x': gx - ft // 2,
            'start_y': gy - ft,
            'end_x': gx + 40,
            'end_y': gy + 100,
            'link_size': 12,
            'sway_offset': random.uniform(0, 6.28),
        })

        # 상단 우측에서 내려오는 체인
        self.chains.append({
            'start_x': gx + gw + ft // 2,
            'start_y': gy - ft,
            'end_x': gx + gw - 40,
            'end_y': gy + 120,
            'link_size': 12,
            'sway_offset': random.uniform(0, 6.28),
        })

        # 우측 상단 코너 체인
        self.chains.append({
            'start_x': gx + gw + ft,
            'start_y': gy - 20,
            'end_x': gx + gw + ft - 15,
            'end_y': gy + 140,
            'link_size': 10,
            'sway_offset': random.uniform(0, 6.28),
        })

        # 하단 체인 (느슨하게 늘어진)
        self.chains.append({
            'start_x': gx - ft // 2,
            'start_y': gy + gh + ft // 2,
            'end_x': gx + gw // 3,
            'end_y': gy + gh + ft + 25,
            'link_size': 10,
            'sway_offset': random.uniform(0, 6.28),
            'loose': True,
        })

        self.chains.append({
            'start_x': gx + gw * 2 // 3,
            'start_y': gy + gh + ft + 25,
            'end_x': gx + gw + ft // 2,
            'end_y': gy + gh + ft // 2,
            'link_size': 10,
            'sway_offset': random.uniform(0, 6.28),
            'loose': True,
        })

    def _generate_bandages(self):
        """반창고 생성 - 액자 프레임 위에 붙은 반창고"""
        self.bandages = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 상단 좌측 코너 근처
        self.bandages.append({
            'x': gx - ft + 15,
            'y': gy - ft // 2 - 25,
            'width': 55,
            'height': 20,
            'rotation': -0.25,
            'color': 'beige',
        })

        # 상단 우측
        self.bandages.append({
            'x': gx + gw // 2 + 80,
            'y': gy - ft // 2 - 10,
            'width': 50,
            'height': 18,
            'rotation': 0.2,
            'color': 'pink',
        })

        # 하단 반창고들
        self.bandages.append({
            'x': gx + gw // 4,
            'y': gy + gh + ft // 2 - 5,
            'width': 48,
            'height': 17,
            'rotation': 0.15,
            'color': 'beige',
        })

        self.bandages.append({
            'x': gx + gw * 3 // 4,
            'y': gy + gh + ft // 2 + 12,
            'width': 45,
            'height': 16,
            'rotation': -0.18,
            'color': 'pink',
        })

        # 우측 프레임 반창고
        self.bandages.append({
            'x': gx + gw + ft // 2 - 12,
            'y': gy + gh // 3,
            'width': 46,
            'height': 16,
            'rotation': 1.3,
            'color': 'beige',
        })

        # 좌측 프레임 반창고
        self.bandages.append({
            'x': gx - ft // 2 - 5,
            'y': gy + gh * 2 // 3,
            'width': 42,
            'height': 15,
            'rotation': -1.1,
            'color': 'pink',
        })

    def _generate_razors(self):
        """면도날 생성 - 프레임에 붙은 면도날"""
        self.razors = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 상단 우측
        self.razors.append({
            'x': gx + gw // 2 + 30,
            'y': gy - ft // 2 + 8,
            'width': 38,
            'height': 24,
            'rotation': 0.15,
        })

        # 우측 프레임
        self.razors.append({
            'x': gx + gw + ft // 2 - 8,
            'y': gy + gh * 2 // 3 + 20,
            'width': 35,
            'height': 22,
            'rotation': -0.35,
        })

        # 하단
        self.razors.append({
            'x': gx + gw // 2 - 100,
            'y': gy + gh + ft // 2 + 5,
            'width': 32,
            'height': 20,
            'rotation': 0.45,
        })

        # 좌측 프레임
        self.razors.append({
            'x': gx - ft // 2 + 5,
            'y': gy + gh // 2 - 30,
            'width': 30,
            'height': 18,
            'rotation': 0.7,
        })

    def _generate_pill_bottles(self):
        """약통 생성"""
        self.pill_bottles = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 우측 상단 약통 (핑크)
        self.pill_bottles.append({
            'x': gx + gw + ft // 2 + 10,
            'y': gy - ft // 2 - 10,
            'width': 28,
            'height': 55,
            'tilt': 0.2,
            'color': 'pink',
            'pills_spilling': True,
        })

        # 좌측 프레임 약통 (주황)
        self.pill_bottles.append({
            'x': gx - ft - 25,
            'y': gy + gh // 4,
            'width': 26,
            'height': 48,
            'tilt': -0.15,
            'color': 'orange',
            'pills_spilling': True,
        })

    def _generate_pills(self):
        """알약 생성 - 흩어진 알약들"""
        self.pills = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 우측 약통 근처 알약들
        for i in range(6):
            self.pills.append({
                'x': gx + gw + ft // 2 + 20 + random.randint(-20, 20),
                'y': gy + random.randint(50, 150),
                'size': random.randint(5, 8),
                'color': random.choice(['white', 'pink', 'blue', 'yellow']),
                'type': random.choice(['round', 'capsule']),
                'rotation': random.uniform(0, 6.28),
            })

        # 좌측 약통 근처 알약들
        for i in range(5):
            self.pills.append({
                'x': gx - ft - 15 + random.randint(-15, 25),
                'y': gy + gh // 4 + random.randint(60, 120),
                'size': random.randint(4, 7),
                'color': random.choice(['white', 'pink']),
                'type': random.choice(['round', 'capsule']),
                'rotation': random.uniform(0, 6.28),
            })

        # 하단 프레임 알약들
        for i in range(5):
            self.pills.append({
                'x': gx + random.randint(80, gw - 80),
                'y': gy + gh + ft // 2 + random.randint(-8, 18),
                'size': random.randint(4, 6),
                'color': random.choice(['white', 'pink', 'yellow']),
                'type': 'capsule',
                'rotation': random.uniform(0, 6.28),
            })

    def _generate_ribbons(self):
        """리본 생성"""
        self.ribbons = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 상단 우측 코너 큰 리본
        self.ribbons.append({
            'x': gx + gw + ft // 2 + 5,
            'y': gy - ft // 2 - 15,
            'size': 45,
            'style': 'bow',
            'rotation': 0.25,
            'color': 'hot_pink',
        })

        # 좌측 하단 리본
        self.ribbons.append({
            'x': gx - ft // 2 - 10,
            'y': gy + gh + ft // 2 + 10,
            'size': 40,
            'style': 'bow',
            'rotation': -0.15,
            'color': 'pink',
        })

        # 상단 작은 리본들
        self.ribbons.append({
            'x': gx + gw // 4,
            'y': gy - ft // 2 - 5,
            'size': 25,
            'style': 'small',
            'rotation': 0.1,
            'color': 'pink',
        })

        # 우측 프레임 리본
        self.ribbons.append({
            'x': gx + gw + ft // 2 + 8,
            'y': gy + gh * 3 // 4,
            'size': 28,
            'style': 'small',
            'rotation': -0.2,
            'color': 'hot_pink',
        })

    def _generate_bears(self):
        """곰인형 생성 - 고퀄리티 버전"""
        self.bears = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 좌측 상단 큰 분홍 곰 (쿠로미 대신)
        self.bears.append({
            'x': gx - ft - 55,
            'y': gy + 10,
            'size': 90,
            'head_tilt': 0.08,
            'has_ribbon': True,
            'ribbon_color': 'hot_pink',
            'eye_type': 'button',
            'color': 'pink',
            'has_blush': True,
            'has_bow': True,
        })

        # 우측 상단 검은 곰 (헬로키티 대신)
        self.bears.append({
            'x': gx + gw + ft - 25,
            'y': gy + 20,
            'size': 85,
            'head_tilt': -0.1,
            'has_ribbon': True,
            'ribbon_color': 'red',
            'eye_type': 'x',
            'color': 'black',
            'has_blush': True,
            'has_bow': True,
        })

        # 좌측 하단 큰 검은 곰
        self.bears.append({
            'x': gx - ft - 50,
            'y': gy + gh - 50,
            'size': 85,
            'head_tilt': 0.1,
            'has_ribbon': True,
            'ribbon_color': 'pink',
            'eye_type': 'button',
            'color': 'black',
            'has_blush': True,
        })

        # 우측 하단 분홍 곰
        self.bears.append({
            'x': gx + gw + ft - 10,
            'y': gy + gh - 40,
            'size': 75,
            'head_tilt': -0.12,
            'has_ribbon': True,
            'ribbon_color': 'red',
            'eye_type': 'x',
            'color': 'pink',
            'has_blush': True,
        })

        # 하단 중앙 작은 갈색 곰
        self.bears.append({
            'x': gx + gw // 2 + 50,
            'y': gy + gh + ft - 10,
            'size': 60,
            'head_tilt': 0.05,
            'has_ribbon': False,
            'eye_type': 'button',
            'color': 'brown',
            'has_blush': True,
        })

        # 좌측 중간 작은 분홍 곰
        self.bears.append({
            'x': gx - ft - 35,
            'y': gy + gh // 2 + 30,
            'size': 55,
            'head_tilt': -0.05,
            'has_ribbon': True,
            'ribbon_color': 'hot_pink',
            'eye_type': 'button',
            'color': 'pink',
            'has_blush': True,
        })

    def _generate_characters(self):
        """캐릭터 생성 - 하단에만 배치 (상단은 곰인형)"""
        self.characters = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 하단 좌측 작은 쿠로미
        self.characters.append({
            'x': gx + 30,
            'y': gy + gh + ft - 5,
            'size': 58,
            'type': 'kuromi',
            'pose': 'sitting',
            'head_tilt': -0.08,
        })

        # 하단 우측 작은 마이멜로디
        self.characters.append({
            'x': gx + gw - 90,
            'y': gy + gh + ft + 5,
            'size': 55,
            'type': 'melody',
            'pose': 'standing',
            'head_tilt': 0.08,
        })

        # 하단 중앙 헬로키티
        self.characters.append({
            'x': gx + gw // 2 - 50,
            'y': gy + gh + ft + 8,
            'size': 55,
            'type': 'kitty',
            'pose': 'sitting',
            'head_tilt': 0,
        })

    def _generate_hearts(self):
        """하트 생성"""
        self.hearts = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 프레임 주변 하트들
        positions = [
            (gx + gw // 2 - 30, gy - ft // 2 - 8, 14, 'pink'),
            (gx + gw + ft // 2 + 12, gy + gh // 2 - 40, 12, 'red'),
            (gx - ft // 2 - 15, gy + gh // 3 + 20, 10, 'pink'),
            (gx + gw // 4 - 20, gy + gh + ft // 2 + 10, 11, 'peach'),
            (gx + gw - 60, gy + gh + ft - 5, 13, 'pink'),
            (gx + gw // 2 + 100, gy - ft - 5, 10, 'red'),
            (gx - ft - 10, gy + gh // 2, 9, 'peach'),
        ]

        for px, py, size, color in positions:
            self.hearts.append({
                'x': px,
                'y': py,
                'size': size,
                'color': color,
                'broken': random.random() < 0.25,
                'float_offset': random.uniform(0, 6.28),
            })

    def _generate_sparkles(self):
        """반짝이 효과 생성"""
        self.sparkles = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 프레임 주변에 반짝이 배치
        for _ in range(25):
            side = random.choice(['top', 'bottom', 'left', 'right'])
            if side == 'top':
                x = gx + random.randint(-ft, gw + ft)
                y = gy - ft + random.randint(-20, ft)
            elif side == 'bottom':
                x = gx + random.randint(-ft, gw + ft)
                y = gy + gh + random.randint(0, ft + 20)
            elif side == 'left':
                x = gx - ft + random.randint(-20, ft)
                y = gy + random.randint(-ft, gh + ft)
            else:
                x = gx + gw + random.randint(0, ft + 20)
                y = gy + random.randint(-ft, gh + ft)

            self.sparkles.append({
                'x': x,
                'y': y,
                'size': random.randint(3, 8),
                'phase': random.uniform(0, 6.28),
                'speed': random.uniform(2, 5),
            })

    def _generate_floating_hearts(self):
        """필러 영역에 떠다니는 버블 하트 생성"""
        self.floating_hearts = []

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 하트 컬러들 (핑크, 보라, 퍼플 계열)
        heart_colors = [
            (255, 150, 200),   # 밝은 핑크
            (255, 120, 180),   # 핑크
            (230, 130, 200),   # 핑크 퍼플
            (200, 120, 220),   # 라벤더
            (180, 100, 200),   # 보라
            (220, 140, 230),   # 연보라
            (255, 180, 210),   # 연핑크
            (190, 110, 190),   # 퍼플
        ]

        # 좌측 필러 영역에 하트 생성
        left_area_width = gx - ft - 10
        if left_area_width > 30:
            num_left = random.randint(5, 8)
            for _ in range(num_left):
                self._spawn_floating_heart('left', heart_colors)

        # 우측 필러 영역에 하트 생성
        right_start = gx + gw + ft + 10
        right_area_width = self.screen_width - right_start
        if right_area_width > 30:
            num_right = random.randint(5, 8)
            for _ in range(num_right):
                self._spawn_floating_heart('right', heart_colors)

    def _spawn_floating_heart(self, side, colors):
        """떠다니는 하트 하나 생성"""
        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        if side == 'left':
            x = random.randint(20, gx - ft - 20)
        else:
            x = random.randint(gx + gw + ft + 20, self.screen_width - 20)

        y = random.randint(50, self.screen_height - 50)
        size = random.randint(10, 28)
        color = random.choice(colors)

        self.floating_hearts.append({
            'x': x,
            'y': y,
            'start_x': x,
            'start_y': y,
            'size': size,
            'color': color,
            'alpha': random.randint(40, 90),  # 은은한 투명도
            'side': side,
            # 부드러운 떠다니기 파라미터
            'float_phase': random.uniform(0, math.pi * 2),
            'float_speed_x': random.uniform(0.3, 0.8),
            'float_speed_y': random.uniform(0.5, 1.0),
            'float_range_x': random.uniform(8, 20),
            'float_range_y': random.uniform(10, 25),
            # 버블 터지기 효과
            'life': random.uniform(3.0, 8.0),  # 수명 (초)
            'max_life': 0,  # 초기화 시 설정
            'state': 'floating',  # floating, popping, respawning
            'pop_progress': 0,  # 터지기 진행도
            'respawn_delay': 0,  # 재생성 대기 시간
        })
        self.floating_hearts[-1]['max_life'] = self.floating_hearts[-1]['life']

    def _create_static_cache(self):
        """정적 캐시 생성"""
        self._static_cache = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)

        # 배경 (필러 영역) - 심플한 단색
        self._draw_pillar_background(self._static_cache)

        # 액자 프레임 (그런지 스타일 유지)
        self._draw_frame(self._static_cache)

        # 필러 장식들
        for bandage in self.bandages:
            self._draw_bandage(self._static_cache, bandage)

        for razor in self.razors:
            self._draw_razor(self._static_cache, razor)

        for bottle in self.pill_bottles:
            self._draw_pill_bottle(self._static_cache, bottle)

        for pill in self.pills:
            self._draw_pill(self._static_cache, pill)

        for ribbon in self.ribbons:
            self._draw_ribbon(self._static_cache, ribbon)

        # 곰인형
        for bear in self.bears:
            self._draw_bear(self._static_cache, bear)

        # 하단 캐릭터들
        for character in self.characters:
            self._draw_character(self._static_cache, character)

    def _draw_pillar_background(self, surface):
        """필러 영역 배경 - 멘헤라 핑크 스타일"""
        # 전체 배경
        bg_color = (18, 12, 22)  # 어두운 보라빛 검정
        surface.fill(bg_color)

        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 좌측 필러 - 부드러운 핑크 그라데이션
        left_width = gx - ft
        if left_width > 0:
            for i in range(left_width):
                # 왼쪽에서 오른쪽으로 어두워지는 그라데이션
                t = i / left_width
                r = int(45 + 25 * (1 - t))  # 70 -> 45
                g = int(25 + 15 * (1 - t))  # 40 -> 25
                b = int(50 + 30 * (1 - t))  # 80 -> 50
                pygame.draw.line(surface, (r, g, b), (i, 0), (i, self.screen_height))

        # 우측 필러 - 부드러운 핑크 그라데이션
        right_start = gx + gw + ft
        right_width = self.screen_width - right_start
        if right_width > 0:
            for i in range(right_width):
                # 왼쪽에서 오른쪽으로 어두워지는 그라데이션
                t = i / right_width
                r = int(45 + 25 * t)  # 45 -> 70
                g = int(25 + 15 * t)  # 25 -> 40
                b = int(50 + 30 * t)  # 50 -> 80
                pygame.draw.line(surface, (r, g, b),
                               (right_start + i, 0), (right_start + i, self.screen_height))

        # 게임 영역은 투명하게 남김
        pygame.draw.rect(surface, (0, 0, 0, 0),
                        (self.game_x, self.game_y, self.game_width, self.game_height))

    def _draw_frame(self, surface):
        """그런지 스타일 액자 프레임"""
        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        # 외부 프레임 (어두운 테두리)
        outer_rect = pygame.Rect(gx - ft - 6, gy - ft - 6,
                                gw + ft * 2 + 12, gh + ft * 2 + 12)
        pygame.draw.rect(surface, self.COLORS['frame_edge_dark'], outer_rect, border_radius=10)

        # 메인 프레임 영역
        frame_surf = pygame.Surface((gw + ft * 2, gh + ft * 2), pygame.SRCALPHA)

        # 기본 핑크 색상
        pygame.draw.rect(frame_surf, self.COLORS['frame_pink_mid'],
                        (0, 0, gw + ft * 2, gh + ft * 2), border_radius=8)

        # 내부 구멍 (게임 영역)
        pygame.draw.rect(frame_surf, (0, 0, 0, 0),
                        (ft, ft, gw, gh))

        # 그런지 텍스처 - 얼룩
        for _ in range(80):
            sx = random.randint(0, gw + ft * 2)
            sy = random.randint(0, gh + ft * 2)
            # 내부 게임 영역 제외
            if ft < sx < ft + gw and ft < sy < ft + gh:
                continue
            size = random.randint(5, 30)
            alpha = random.randint(15, 55)
            color = random.choice([self.COLORS['frame_stain'], self.COLORS['frame_rust'],
                                  self.COLORS['frame_pink_dirty'], self.COLORS['frame_pink_dark']])
            stain_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(stain_surf, (*color, alpha), (size, size), size)
            frame_surf.blit(stain_surf, (sx - size, sy - size))

        # 긁힌 자국
        for _ in range(40):
            x1 = random.randint(0, gw + ft * 2)
            y1 = random.randint(0, gh + ft * 2)
            if ft < x1 < ft + gw and ft < y1 < ft + gh:
                continue
            length = random.randint(10, 50)
            angle = random.uniform(-0.8, 0.8)
            x2 = x1 + int(length * math.cos(angle))
            y2 = y1 + int(length * math.sin(angle))
            pygame.draw.line(frame_surf, (*self.COLORS['frame_pink_dirty'], 35),
                           (x1, y1), (x2, y2), random.randint(1, 3))

        # 하이라이트 (위쪽 가장자리)
        for i in range(4):
            pygame.draw.line(frame_surf, (*self.COLORS['frame_pink_light'], 90 - i * 20),
                           (6 + i, 6 + i), (gw + ft * 2 - 6 - i, 6 + i), 1)

        # 그림자 (아래쪽)
        for i in range(4):
            pygame.draw.line(frame_surf, (*self.COLORS['frame_edge_dark'], 70 - i * 15),
                           (6 + i, gh + ft * 2 - 6 - i),
                           (gw + ft * 2 - 6 - i, gh + ft * 2 - 6 - i), 1)

        # 내부 테두리 (게임 영역 주변)
        inner_rect = pygame.Rect(ft - 4, ft - 4, gw + 8, gh + 8)
        pygame.draw.rect(frame_surf, self.COLORS['frame_edge_dark'], inner_rect, 5, border_radius=3)

        surface.blit(frame_surf, (gx - ft, gy - ft))

        # 코너 장식 (X 표시 + 하트)
        corners = [
            (gx - ft // 2, gy - ft // 2),
            (gx + gw + ft // 2, gy - ft // 2),
            (gx - ft // 2, gy + gh + ft // 2),
            (gx + gw + ft // 2, gy + gh + ft // 2),
        ]
        for i, (cx, cy) in enumerate(corners):
            size = 12
            pygame.draw.line(surface, self.COLORS['ribbon_hot_pink'],
                           (cx - size, cy - size), (cx + size, cy + size), 3)
            pygame.draw.line(surface, self.COLORS['ribbon_hot_pink'],
                           (cx + size, cy - size), (cx - size, cy + size), 3)

    def _draw_bandage(self, surface, bandage):
        """반창고"""
        x, y = bandage['x'], bandage['y']
        w, h = bandage['width'], bandage['height']
        rotation = bandage['rotation']

        band_surf = pygame.Surface((w + 24, h + 24), pygame.SRCALPHA)

        # 기본 모양
        if bandage['color'] == 'pink':
            base_color = self.COLORS['bandage_pink']
            pad_color = (255, 240, 245)
        else:
            base_color = self.COLORS['bandage_base']
            pad_color = self.COLORS['bandage_pad']

        pygame.draw.rect(band_surf, base_color, (12, 12, w, h), border_radius=5)

        # 중앙 패드
        pad_w = w // 3
        pad_x = 12 + (w - pad_w) // 2
        pygame.draw.rect(band_surf, pad_color, (pad_x, 12, pad_w, h))

        # 구멍 패턴
        for i in range(4):
            for j in range(2):
                hole_x = pad_x + 4 + i * (pad_w // 4)
                hole_y = 14 + j * (h // 2 - 2)
                pygame.draw.circle(band_surf, (*base_color, 180), (hole_x, hole_y), 2)

        # 테두리
        pygame.draw.rect(band_surf, (200, 180, 160), (12, 12, w, h), 1, border_radius=5)

        rotated = pygame.transform.rotate(band_surf, math.degrees(-rotation))
        rect = rotated.get_rect(center=(x + w // 2, y + h // 2))
        surface.blit(rotated, rect)

    def _draw_razor(self, surface, razor):
        """면도날"""
        x, y = razor['x'], razor['y']
        w, h = razor['width'], razor['height']
        rotation = razor['rotation']

        razor_surf = pygame.Surface((w + 14, h + 14), pygame.SRCALPHA)

        # 본체
        pygame.draw.rect(razor_surf, self.COLORS['razor_metal'], (7, 7, w, h), border_radius=3)

        # 구멍
        hole_y = 7 + h // 2
        for hx in [7 + w // 4, 7 + 3 * w // 4]:
            pygame.draw.ellipse(razor_surf, self.COLORS['razor_dark'],
                              (hx - 5, hole_y - 4, 10, 8))

        # 하이라이트
        pygame.draw.line(razor_surf, self.COLORS['razor_edge'], (8, 8), (6 + w, 8), 2)

        # 날카로운 가장자리
        pygame.draw.line(razor_surf, (100, 105, 115), (7, 7 + h), (7 + w, 7 + h), 2)

        rotated = pygame.transform.rotate(razor_surf, math.degrees(-rotation))
        rect = rotated.get_rect(center=(x + w // 2, y + h // 2))
        surface.blit(rotated, rect)

    def _draw_pill_bottle(self, surface, bottle):
        """약통"""
        x, y = bottle['x'], bottle['y']
        w, h = bottle['width'], bottle['height']
        tilt = bottle.get('tilt', 0)

        bottle_surf = pygame.Surface((w + 20, h + 25), pygame.SRCALPHA)
        cx = w // 2 + 10

        # 본체 색상
        if bottle.get('color') == 'pink':
            body_color = self.COLORS['pill_bottle_pink']
            dark_color = (230, 150, 170)
        else:
            body_color = self.COLORS['pill_bottle_orange']
            dark_color = self.COLORS['pill_bottle_dark']

        # 본체
        pygame.draw.rect(bottle_surf, body_color,
                        (10, 15, w, h), border_radius=6)
        pygame.draw.rect(bottle_surf, dark_color,
                        (10, 15, w, h), 2, border_radius=6)

        # 라벨
        label_y = 15 + h // 3
        pygame.draw.rect(bottle_surf, self.COLORS['pill_label'],
                        (13, label_y, w - 6, h // 3))

        # 라벨 텍스트 (Rx)
        pygame.draw.line(bottle_surf, (100, 100, 110),
                        (15, label_y + 5), (20, label_y + h // 4), 2)

        # 뚜껑
        cap_color = (240, 240, 245) if bottle.get('color') != 'pink' else (255, 220, 230)
        pygame.draw.rect(bottle_surf, cap_color,
                        (8, 3, w + 4, 14), border_radius=4)
        pygame.draw.rect(bottle_surf, (200, 200, 210),
                        (8, 3, w + 4, 14), 1, border_radius=4)

        if tilt != 0:
            bottle_surf = pygame.transform.rotate(bottle_surf, math.degrees(-tilt))

        rect = bottle_surf.get_rect(center=(x + w // 2, y + h // 2))
        surface.blit(bottle_surf, rect)

    def _draw_pill(self, surface, pill):
        """알약"""
        x, y = int(pill['x']), int(pill['y'])
        size = pill['size']

        color_map = {
            'white': self.COLORS['pill_white'],
            'pink': self.COLORS['pill_pink'],
            'blue': self.COLORS['pill_blue'],
            'yellow': self.COLORS['pill_yellow'],
        }
        color = color_map.get(pill['color'], self.COLORS['pill_white'])

        if pill['type'] == 'round':
            pygame.draw.circle(surface, color, (x, y), size)
            # 하이라이트
            pygame.draw.circle(surface, (255, 255, 255),
                             (x - size // 3, y - size // 3), max(1, size // 3))
        else:  # capsule
            cap_surf = pygame.Surface((size * 4, size * 3), pygame.SRCALPHA)
            # 두 색상
            pygame.draw.ellipse(cap_surf, self.COLORS['pill_pink'],
                              (0, size // 2, size * 2, size * 2))
            pygame.draw.ellipse(cap_surf, self.COLORS['pill_white'],
                              (size * 2 - 3, size // 2, size * 2, size * 2))
            # 하이라이트
            pygame.draw.arc(cap_surf, (255, 255, 255, 150),
                          (2, size // 2 + 2, size * 2 - 4, size), 0.5, 2.5, 2)

            rotated = pygame.transform.rotate(cap_surf, math.degrees(pill['rotation']))
            rect = rotated.get_rect(center=(x, y))
            surface.blit(rotated, rect)

    def _draw_ribbon(self, surface, ribbon):
        """리본"""
        x, y = ribbon['x'], ribbon['y']
        size = ribbon['size']
        style = ribbon['style']
        color_type = ribbon.get('color', 'pink')

        if color_type == 'hot_pink':
            main_color = self.COLORS['ribbon_hot_pink']
            light_color = (255, 180, 210)
            dark_color = (220, 80, 140)
        else:
            main_color = self.COLORS['ribbon_pink']
            light_color = self.COLORS['ribbon_light']
            dark_color = self.COLORS['ribbon_dark']

        ribbon_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
        cx, cy = size * 1.5, size * 1.5

        if style == 'bow':
            # 나비 리본
            # 왼쪽 날개
            pygame.draw.ellipse(ribbon_surf, main_color,
                              (cx - size * 1.4, cy - size * 0.55, size * 1.2, size * 1.1))
            pygame.draw.ellipse(ribbon_surf, dark_color,
                              (cx - size * 1.4, cy - size * 0.55, size * 1.2, size * 1.1), 2)
            # 날개 하이라이트
            pygame.draw.ellipse(ribbon_surf, (*light_color, 100),
                              (cx - size * 1.2, cy - size * 0.4, size * 0.5, size * 0.4))

            # 오른쪽 날개
            pygame.draw.ellipse(ribbon_surf, main_color,
                              (cx + size * 0.2, cy - size * 0.55, size * 1.2, size * 1.1))
            pygame.draw.ellipse(ribbon_surf, dark_color,
                              (cx + size * 0.2, cy - size * 0.55, size * 1.2, size * 1.1), 2)
            # 날개 하이라이트
            pygame.draw.ellipse(ribbon_surf, (*light_color, 100),
                              (cx + size * 0.4, cy - size * 0.4, size * 0.5, size * 0.4))

            # 중앙 매듭
            pygame.draw.circle(ribbon_surf, light_color, (int(cx), int(cy)), int(size * 0.28))
            pygame.draw.circle(ribbon_surf, dark_color, (int(cx), int(cy)), int(size * 0.28), 2)

            # 꼬리
            tail_pts1 = [(cx - size * 0.18, cy + size * 0.22),
                        (cx - size * 0.55, cy + size * 1.1),
                        (cx - size * 0.35, cy + size * 0.85),
                        (cx, cy + size * 0.35)]
            tail_pts2 = [(cx + size * 0.18, cy + size * 0.22),
                        (cx + size * 0.55, cy + size * 1.1),
                        (cx + size * 0.35, cy + size * 0.85),
                        (cx, cy + size * 0.35)]
            pygame.draw.polygon(ribbon_surf, main_color, tail_pts1)
            pygame.draw.polygon(ribbon_surf, main_color, tail_pts2)
            pygame.draw.polygon(ribbon_surf, dark_color, tail_pts1, 2)
            pygame.draw.polygon(ribbon_surf, dark_color, tail_pts2, 2)

        else:  # small
            # 작은 리본
            pygame.draw.circle(ribbon_surf, main_color,
                             (int(cx - size * 0.45), int(cy)), int(size * 0.35))
            pygame.draw.circle(ribbon_surf, main_color,
                             (int(cx + size * 0.45), int(cy)), int(size * 0.35))
            pygame.draw.circle(ribbon_surf, light_color,
                             (int(cx), int(cy)), int(size * 0.22))
            pygame.draw.circle(ribbon_surf, dark_color,
                             (int(cx), int(cy)), int(size * 0.22), 2)

        rotated = pygame.transform.rotate(ribbon_surf, math.degrees(-ribbon['rotation']))
        rect = rotated.get_rect(center=(x, y))
        surface.blit(rotated, rect)

    def _draw_heart(self, surface, heart, time=0):
        """하트"""
        x, y = heart['x'], heart['y']
        size = heart['size']

        # 부유 효과
        float_y = math.sin(time * 2 + heart.get('float_offset', 0)) * 3
        y = y + float_y

        color_map = {
            'pink': self.COLORS['heart_pink'],
            'red': self.COLORS['heart_red'],
            'peach': self.COLORS['heart_peach'],
        }
        color = color_map.get(heart['color'], self.COLORS['heart_pink'])

        if heart['broken']:
            # 깨진 하트 - 왼쪽 반
            points_left = []
            for i in range(16):
                t = i / 16 * math.pi
                hx = size * 0.55 * (16 * math.sin(t) ** 3) / 16
                hy = -size * 0.55 * (13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)) / 16
                if hx <= 2:
                    points_left.append((x + hx - 3, y + hy))
            if len(points_left) >= 3:
                pygame.draw.polygon(surface, self.COLORS['heart_broken'], points_left)

            # 오른쪽 반
            points_right = []
            for i in range(16, 32):
                t = i / 32 * 2 * math.pi
                hx = size * 0.55 * (16 * math.sin(t) ** 3) / 16
                hy = -size * 0.55 * (13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)) / 16
                if hx >= -2:
                    points_right.append((x + hx + 3, y + hy))
            if len(points_right) >= 3:
                pygame.draw.polygon(surface, color, points_right)
        else:
            # 일반 하트
            points = []
            for i in range(32):
                t = i / 32 * 2 * math.pi
                hx = size * 0.55 * (16 * math.sin(t) ** 3) / 16
                hy = -size * 0.55 * (13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)) / 16
                points.append((x + hx, y + hy))
            if len(points) >= 3:
                pygame.draw.polygon(surface, color, points)
                # 하이라이트
                pygame.draw.circle(surface, (255, 255, 255, 150),
                                 (int(x - size * 0.2), int(y - size * 0.15)), max(2, size // 4))

    def _draw_bear(self, surface, bear):
        """곰인형 - 고퀄리티 버전 (빈틈 없이 완성도 높게)"""
        x, y = bear['x'], bear['y']
        size = bear['size']
        color_type = bear.get('color', 'black')

        # 더 넉넉한 서피스
        margin = 40
        bear_surf = pygame.Surface((size * 2 + margin * 2, size * 2 + margin * 2), pygame.SRCALPHA)
        cx, cy = size + margin, size + margin

        # 색상 선택 - 더 풍부한 색상
        if color_type == 'pink':
            body_color = (255, 180, 200)
            body_dark = (235, 150, 175)
            inner_color = (255, 220, 235)
            highlight_color = (255, 240, 248)
            shadow_color = (200, 120, 145)
            outline_color = (180, 100, 130)
        elif color_type == 'brown':
            body_color = (140, 100, 75)
            body_dark = (110, 75, 55)
            inner_color = (180, 145, 120)
            highlight_color = (200, 170, 145)
            shadow_color = (80, 55, 40)
            outline_color = (60, 40, 30)
        else:  # black
            body_color = (45, 40, 50)
            body_dark = (30, 25, 35)
            inner_color = (75, 70, 85)
            highlight_color = (95, 90, 105)
            shadow_color = (20, 15, 25)
            outline_color = (15, 10, 20)

        # === 1. 귀 (먼저 그려서 머리 뒤에 위치) ===
        head_size = int(size * 0.7)
        head_y = cy - int(size * 0.35)
        ear_size = int(head_size * 0.35)
        ear_inner = int(ear_size * 0.55)

        for ear_x_offset in [-1, 1]:
            ear_x = cx + ear_x_offset * int(head_size * 0.38)
            ear_y = head_y - int(head_size * 0.35)
            # 귀 그림자
            pygame.draw.circle(bear_surf, shadow_color, (ear_x + 2, ear_y + 2), ear_size)
            # 귀 본체
            pygame.draw.circle(bear_surf, body_color, (ear_x, ear_y), ear_size)
            # 귀 테두리
            pygame.draw.circle(bear_surf, outline_color, (ear_x, ear_y), ear_size, 2)
            # 귀 안쪽
            pygame.draw.circle(bear_surf, inner_color, (ear_x, ear_y), ear_inner)

        # === 2. 몸통 크기 정의 (먼저 정의해서 팔/다리 위치 계산에 사용) ===
        body_w = int(size * 1.0)  # 몸통 더 크게
        body_h = int(size * 1.05)  # 몸통 더 길게
        body_top = cy - int(body_h * 0.18)

        # === 3. 팔 (몸통 뒤에 위치하도록 먼저 그림) ===
        arm_size = int(size * 0.30)

        for arm_x_offset in [-1, 1]:
            # 팔이 몸통에 더 많이 겹치도록 위치 조정
            arm_x = cx + arm_x_offset * int(body_w * 0.42)
            arm_y = body_top + int(body_h * 0.38)
            # 팔 그림자
            pygame.draw.circle(bear_surf, shadow_color, (arm_x + 2, arm_y + 2), arm_size)
            # 팔 본체
            pygame.draw.circle(bear_surf, body_color, (arm_x, arm_y), arm_size)
            # 팔 테두리
            pygame.draw.circle(bear_surf, outline_color, (arm_x, arm_y), arm_size, 2)
            # 팔 패드
            pad_x = arm_x + arm_x_offset * int(arm_size * 0.25)
            pygame.draw.circle(bear_surf, inner_color, (pad_x, arm_y + 2), int(arm_size * 0.5))

        # === 4. 다리 ===
        leg_w = int(body_w * 0.40)
        leg_h = int(size * 0.35)
        # 다리가 몸통에 더 많이 겹치도록 위치 조정
        leg_y = body_top + body_h - int(leg_h * 0.75)

        for leg_x_offset in [-1, 1]:
            leg_x = cx + leg_x_offset * int(body_w * 0.24) - leg_w // 2
            # 다리 그림자
            pygame.draw.ellipse(bear_surf, shadow_color, (leg_x + 2, leg_y + 2, leg_w, leg_h))
            # 다리 본체
            pygame.draw.ellipse(bear_surf, body_color, (leg_x, leg_y, leg_w, leg_h))
            # 다리 테두리
            pygame.draw.ellipse(bear_surf, outline_color, (leg_x, leg_y, leg_w, leg_h), 2)
            # 다리 패드
            pad_margin = 5
            pygame.draw.ellipse(bear_surf, inner_color,
                              (leg_x + pad_margin, leg_y + pad_margin,
                               leg_w - pad_margin * 2, leg_h - pad_margin * 2))

        # === 5. 몸통 (팔/다리 위에 덮어씌움 - 빈틈 없도록 크게) ===
        body_rect = (cx - body_w // 2, body_top, body_w, body_h)
        # 몸통 그림자
        pygame.draw.ellipse(bear_surf, shadow_color,
                          (body_rect[0] + 3, body_rect[1] + 3, body_rect[2], body_rect[3]))
        # 몸통 본체 - 2번 그려서 완전히 채움
        pygame.draw.ellipse(bear_surf, body_color, body_rect)
        pygame.draw.ellipse(bear_surf, body_color,
                          (body_rect[0] + 1, body_rect[1] + 1, body_rect[2] - 2, body_rect[3] - 2))
        # 몸통 테두리
        pygame.draw.ellipse(bear_surf, outline_color, body_rect, 2)

        # 몸통 하이라이트 (상단)
        hl_w = int(body_w * 0.55)
        hl_h = int(body_h * 0.32)
        pygame.draw.ellipse(bear_surf, (*highlight_color, 90),
                          (cx - hl_w // 2, body_top + 10, hl_w, hl_h))

        # 배 부분
        belly_w = int(body_w * 0.55)
        belly_h = int(body_h * 0.45)
        belly_y = body_top + int(body_h * 0.38)
        pygame.draw.ellipse(bear_surf, inner_color,
                          (cx - belly_w // 2, belly_y, belly_w, belly_h))

        # === 6. 머리 (몸통과 겹치도록 위치 조정) ===
        # 머리를 몸통 위에 살짝 겹치게
        head_radius = head_size // 2 + 5
        # 머리 그림자
        pygame.draw.circle(bear_surf, shadow_color, (cx + 3, head_y + 3), head_radius)
        # 머리 본체 - 2번 그려서 완전히 채움
        pygame.draw.circle(bear_surf, body_color, (cx, head_y), head_radius)
        pygame.draw.circle(bear_surf, body_color, (cx, head_y), head_radius - 1)
        # 머리 테두리
        pygame.draw.circle(bear_surf, outline_color, (cx, head_y), head_radius, 2)
        # 머리 하이라이트
        pygame.draw.circle(bear_surf, (*highlight_color, 80),
                         (cx - head_size // 5, head_y - head_size // 5), head_size // 4)

        # === 7. 주둥이 ===
        muzzle_w = int(head_size * 0.6)
        muzzle_h = int(head_size * 0.45)
        muzzle_y = head_y + int(head_size * 0.08)
        pygame.draw.ellipse(bear_surf, inner_color,
                          (cx - muzzle_w // 2, muzzle_y, muzzle_w, muzzle_h))

        # === 8. 눈 ===
        eye_y = head_y - 2
        eye_spacing = int(head_size * 0.24)
        eye_size = max(6, int(size * 0.09))

        if bear['eye_type'] == 'x':
            # X 눈
            for eye_x in [cx - eye_spacing, cx + eye_spacing]:
                es = eye_size
                pygame.draw.line(bear_surf, (180, 60, 90),
                               (eye_x - es, eye_y - es), (eye_x + es, eye_y + es), 4)
                pygame.draw.line(bear_surf, (180, 60, 90),
                               (eye_x + es, eye_y - es), (eye_x - es, eye_y + es), 4)
        else:  # button
            for eye_x in [cx - eye_spacing, cx + eye_spacing]:
                # 눈 그림자
                pygame.draw.circle(bear_surf, (0, 0, 0), (eye_x + 1, eye_y + 1), eye_size + 1)
                # 눈 본체
                pygame.draw.circle(bear_surf, (25, 20, 30), (eye_x, eye_y), eye_size)
                # 큰 하이라이트
                pygame.draw.circle(bear_surf, (255, 255, 255),
                                 (eye_x - eye_size // 3, eye_y - eye_size // 3), max(2, eye_size // 2))
                # 작은 하이라이트
                pygame.draw.circle(bear_surf, (255, 255, 255),
                                 (eye_x + eye_size // 4, eye_y + eye_size // 4), max(1, eye_size // 4))

        # === 9. 볼터치 ===
        if bear.get('has_blush', False):
            blush_y = head_y + int(head_size * 0.18)
            blush_w = int(size * 0.22)
            blush_h = int(size * 0.12)
            blush_surf = pygame.Surface((blush_w, blush_h), pygame.SRCALPHA)
            pygame.draw.ellipse(blush_surf, (255, 140, 170, 100), (0, 0, blush_w, blush_h))
            bear_surf.blit(blush_surf, (cx - eye_spacing - blush_w + 2, blush_y))
            bear_surf.blit(blush_surf, (cx + eye_spacing - 2, blush_y))

        # === 10. 코 ===
        nose_y = head_y + int(head_size * 0.22)
        nose_w = int(size * 0.16)
        nose_h = int(size * 0.12)
        pygame.draw.ellipse(bear_surf, (55, 40, 50),
                          (cx - nose_w // 2, nose_y, nose_w, nose_h))
        # 코 하이라이트
        pygame.draw.ellipse(bear_surf, (90, 75, 85),
                          (cx - nose_w // 4, nose_y + 2, nose_w // 2, nose_h // 2))

        # === 11. 입 ===
        mouth_y = nose_y + nose_h + 2
        mouth_w = int(size * 0.08)
        pygame.draw.arc(bear_surf, (55, 40, 50),
                       (cx - mouth_w - 1, mouth_y - 3, mouth_w, mouth_w), 3.5, 5.9, 2)
        pygame.draw.arc(bear_surf, (55, 40, 50),
                       (cx + 1, mouth_y - 3, mouth_w, mouth_w), 3.5, 5.9, 2)

        # === 12. 머리 위 나비리본 ===
        if bear.get('has_bow', False):
            bow_y = head_y - head_size // 2 - 5
            if bear.get('ribbon_color') == 'hot_pink':
                ribbon_color = (255, 105, 180)
            else:
                ribbon_color = (255, 80, 100)
            dark_ribbon = tuple(max(0, c - 50) for c in ribbon_color)
            light_ribbon = tuple(min(255, c + 30) for c in ribbon_color)

            bow_w = int(size * 0.28)
            bow_h = int(size * 0.22)

            # 왼쪽 날개
            pygame.draw.ellipse(bear_surf, ribbon_color,
                              (cx - bow_w - 4, bow_y - bow_h // 2, bow_w, bow_h))
            pygame.draw.ellipse(bear_surf, dark_ribbon,
                              (cx - bow_w - 4, bow_y - bow_h // 2, bow_w, bow_h), 2)
            pygame.draw.ellipse(bear_surf, (*light_ribbon, 100),
                              (cx - bow_w, bow_y - bow_h // 3, bow_w // 2, bow_h // 2))

            # 오른쪽 날개
            pygame.draw.ellipse(bear_surf, ribbon_color,
                              (cx + 4, bow_y - bow_h // 2, bow_w, bow_h))
            pygame.draw.ellipse(bear_surf, dark_ribbon,
                              (cx + 4, bow_y - bow_h // 2, bow_w, bow_h), 2)
            pygame.draw.ellipse(bear_surf, (*light_ribbon, 100),
                              (cx + 8, bow_y - bow_h // 3, bow_w // 2, bow_h // 2))

            # 중앙 매듭
            knot_size = int(size * 0.1)
            pygame.draw.circle(bear_surf, ribbon_color, (cx, bow_y), knot_size)
            pygame.draw.circle(bear_surf, dark_ribbon, (cx, bow_y), knot_size, 2)

        # === 13. 목 리본 ===
        elif bear.get('has_ribbon', False):
            ribbon_y = head_y + head_size // 2 + 8
            if bear.get('ribbon_color') == 'red':
                ribbon_color = (255, 80, 100)
            elif bear.get('ribbon_color') == 'hot_pink':
                ribbon_color = (255, 105, 180)
            else:
                ribbon_color = (255, 120, 150)
            dark_ribbon = tuple(max(0, c - 50) for c in ribbon_color)

            # 리본 중앙
            pygame.draw.circle(bear_surf, ribbon_color, (cx, ribbon_y), 10)
            pygame.draw.circle(bear_surf, dark_ribbon, (cx, ribbon_y), 10, 2)

            # 리본 날개
            pygame.draw.polygon(bear_surf, ribbon_color,
                              [(cx - 22, ribbon_y - 7), (cx - 8, ribbon_y), (cx - 22, ribbon_y + 7)])
            pygame.draw.polygon(bear_surf, dark_ribbon,
                              [(cx - 22, ribbon_y - 7), (cx - 8, ribbon_y), (cx - 22, ribbon_y + 7)], 2)
            pygame.draw.polygon(bear_surf, ribbon_color,
                              [(cx + 22, ribbon_y - 7), (cx + 8, ribbon_y), (cx + 22, ribbon_y + 7)])
            pygame.draw.polygon(bear_surf, dark_ribbon,
                              [(cx + 22, ribbon_y - 7), (cx + 8, ribbon_y), (cx + 22, ribbon_y + 7)], 2)

        # 회전
        if bear.get('head_tilt', 0) != 0:
            bear_surf = pygame.transform.rotate(bear_surf, math.degrees(-bear['head_tilt']))

        rect = bear_surf.get_rect(center=(x + size, y + size))
        surface.blit(bear_surf, rect)

    def _draw_character(self, surface, character):
        """쿠로미/마이멜로디/헬로키티 캐릭터 그리기"""
        char_type = character['type']
        if char_type == 'kuromi':
            self._draw_kuromi(surface, character)
        elif char_type == 'melody':
            self._draw_melody(surface, character)
        elif char_type == 'kitty':
            self._draw_kitty(surface, character)

    def _draw_kuromi(self, surface, character):
        """쿠로미 (검은 후드 토끼) 그리기"""
        x, y = character['x'], character['y']
        size = character['size']
        pose = character['pose']
        tilt = character.get('head_tilt', 0)

        char_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
        cx, cy = size, size

        # 색상
        black = self.COLORS['kuromi_black']
        dark = self.COLORS['kuromi_dark']
        pink = self.COLORS['kuromi_pink']
        skull_white = self.COLORS['kuromi_skull']

        if pose == 'standing':
            # 몸통 (검은 원피스)
            body_w = int(size * 0.55)
            body_h = int(size * 0.65)
            pygame.draw.ellipse(char_surf, black,
                              (cx - body_w // 2, cy + size * 0.1, body_w, body_h))
            # 레이스 장식
            for i in range(5):
                lace_x = cx - body_w // 2 + 5 + i * (body_w // 5)
                pygame.draw.arc(char_surf, pink,
                              (lace_x, cy + size * 0.6, 10, 8), 0, math.pi, 2)

        else:  # sitting
            # 앉은 몸통
            body_w = int(size * 0.6)
            body_h = int(size * 0.45)
            pygame.draw.ellipse(char_surf, black,
                              (cx - body_w // 2, cy + size * 0.15, body_w, body_h))

        # 머리 (검은 후드)
        head_size = int(size * 0.55)
        head_y = cy - size * 0.15
        pygame.draw.circle(char_surf, black, (cx, int(head_y)), head_size // 2)

        # 귀 (검은 토끼 귀)
        ear_w = int(size * 0.18)
        ear_h = int(size * 0.5)
        # 왼쪽 귀
        pygame.draw.ellipse(char_surf, black,
                          (cx - head_size // 3 - ear_w // 2, head_y - head_size // 2 - ear_h + 10,
                           ear_w, ear_h))
        pygame.draw.ellipse(char_surf, pink,
                          (cx - head_size // 3 - ear_w // 2 + 3, head_y - head_size // 2 - ear_h + 15,
                           ear_w - 6, ear_h - 15))
        # 오른쪽 귀
        pygame.draw.ellipse(char_surf, black,
                          (cx + head_size // 3 - ear_w // 2, head_y - head_size // 2 - ear_h + 10,
                           ear_w, ear_h))
        pygame.draw.ellipse(char_surf, pink,
                          (cx + head_size // 3 - ear_w // 2 + 3, head_y - head_size // 2 - ear_h + 15,
                           ear_w - 6, ear_h - 15))

        # 해골 마크 (이마)
        skull_y = head_y - head_size // 6
        skull_size = int(size * 0.12)
        pygame.draw.circle(char_surf, skull_white, (cx, int(skull_y)), skull_size)
        # 해골 눈
        pygame.draw.circle(char_surf, black, (cx - 3, int(skull_y) - 1), 2)
        pygame.draw.circle(char_surf, black, (cx + 3, int(skull_y) - 1), 2)
        # 해골 크로스본
        pygame.draw.line(char_surf, skull_white,
                        (cx - skull_size - 3, skull_y + skull_size),
                        (cx + skull_size + 3, skull_y - skull_size - 5), 3)
        pygame.draw.line(char_surf, skull_white,
                        (cx + skull_size + 3, skull_y + skull_size),
                        (cx - skull_size - 3, skull_y - skull_size - 5), 3)

        # 얼굴 (하얀색)
        face_size = int(head_size * 0.65)
        face_y = head_y + head_size // 8
        pygame.draw.ellipse(char_surf, skull_white,
                          (cx - face_size // 2, int(face_y) - face_size // 3, face_size, int(face_size * 0.8)))

        # 눈 (날카로운 눈)
        eye_y = face_y + face_size // 8
        eye_spacing = face_size // 4
        for eye_x in [cx - eye_spacing, cx + eye_spacing]:
            # 눈 윤곽
            pygame.draw.ellipse(char_surf, black,
                              (eye_x - 6, int(eye_y) - 5, 12, 10))
            # 눈동자
            pygame.draw.ellipse(char_surf, self.COLORS['kuromi_eye'],
                              (eye_x - 4, int(eye_y) - 3, 8, 7))
            # 하이라이트
            pygame.draw.circle(char_surf, skull_white, (eye_x - 1, int(eye_y) - 1), 2)

        # 코
        pygame.draw.ellipse(char_surf, pink,
                          (cx - 3, int(face_y) + face_size // 3, 6, 4))

        # 리본 장식 (머리 옆)
        pygame.draw.circle(char_surf, pink, (cx - head_size // 2 + 5, int(head_y) - 5), 8)
        pygame.draw.polygon(char_surf, pink,
                          [(cx - head_size // 2 - 8, head_y - 10),
                           (cx - head_size // 2 + 2, head_y - 5),
                           (cx - head_size // 2 - 8, head_y)])

        # 회전
        if tilt != 0:
            char_surf = pygame.transform.rotate(char_surf, math.degrees(-tilt))

        rect = char_surf.get_rect(center=(x + size, y + size))
        surface.blit(char_surf, rect)

    def _draw_melody(self, surface, character):
        """마이멜로디 (분홍 토끼) 그리기"""
        x, y = character['x'], character['y']
        size = character['size']
        pose = character['pose']
        tilt = character.get('head_tilt', 0)

        char_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
        cx, cy = size, size

        # 색상
        pink = self.COLORS['melody_pink']
        light_pink = self.COLORS['melody_light']
        dark_pink = self.COLORS['melody_dark']
        white = (255, 255, 255)
        eye_color = self.COLORS['melody_eye']

        if pose == 'standing':
            # 몸통 (분홍 원피스)
            body_w = int(size * 0.5)
            body_h = int(size * 0.6)
            pygame.draw.ellipse(char_surf, pink,
                              (cx - body_w // 2, cy + size * 0.1, body_w, body_h))
            # 리본 장식
            pygame.draw.circle(char_surf, (255, 255, 100), (cx, cy + size * 0.15), 6)
        else:  # sitting
            body_w = int(size * 0.55)
            body_h = int(size * 0.4)
            pygame.draw.ellipse(char_surf, pink,
                              (cx - body_w // 2, cy + size * 0.18, body_w, body_h))

        # 머리 (흰색 + 분홍 후드)
        head_size = int(size * 0.55)
        head_y = cy - size * 0.12

        # 분홍 후드 (뒤쪽)
        pygame.draw.circle(char_surf, pink, (cx, int(head_y)), head_size // 2 + 3)

        # 흰 얼굴
        pygame.draw.circle(char_surf, white, (cx, int(head_y) + 5), head_size // 2 - 5)

        # 귀 (분홍 + 흰색)
        ear_w = int(size * 0.16)
        ear_h = int(size * 0.48)
        # 왼쪽 귀
        pygame.draw.ellipse(char_surf, pink,
                          (cx - head_size // 3 - ear_w // 2, head_y - head_size // 2 - ear_h + 12,
                           ear_w, ear_h))
        pygame.draw.ellipse(char_surf, light_pink,
                          (cx - head_size // 3 - ear_w // 2 + 3, head_y - head_size // 2 - ear_h + 18,
                           ear_w - 6, ear_h - 18))
        # 오른쪽 귀
        pygame.draw.ellipse(char_surf, pink,
                          (cx + head_size // 3 - ear_w // 2, head_y - head_size // 2 - ear_h + 12,
                           ear_w, ear_h))
        pygame.draw.ellipse(char_surf, light_pink,
                          (cx + head_size // 3 - ear_w // 2 + 3, head_y - head_size // 2 - ear_h + 18,
                           ear_w - 6, ear_h - 18))

        # 후드 꽃 장식
        flower_x = cx - head_size // 3 - 5
        flower_y = head_y - head_size // 4
        pygame.draw.circle(char_surf, (255, 255, 100), (flower_x, int(flower_y)), 7)
        for angle in range(0, 360, 72):
            petal_x = flower_x + int(10 * math.cos(math.radians(angle)))
            petal_y = flower_y + int(10 * math.sin(math.radians(angle)))
            pygame.draw.circle(char_surf, pink, (petal_x, int(petal_y)), 5)

        # 눈 (큰 둥근 눈)
        eye_y = head_y + head_size // 6
        eye_spacing = head_size // 5
        for eye_x in [cx - eye_spacing, cx + eye_spacing]:
            # 눈 윤곽
            pygame.draw.ellipse(char_surf, eye_color,
                              (eye_x - 5, int(eye_y) - 6, 10, 12))
            # 하이라이트
            pygame.draw.circle(char_surf, white, (eye_x - 1, int(eye_y) - 2), 3)
            pygame.draw.circle(char_surf, white, (eye_x + 2, int(eye_y) + 2), 2)

        # 코
        pygame.draw.ellipse(char_surf, (255, 200, 180),
                          (cx - 3, int(head_y) + head_size // 4, 6, 4))

        # 회전
        if tilt != 0:
            char_surf = pygame.transform.rotate(char_surf, math.degrees(-tilt))

        rect = char_surf.get_rect(center=(x + size, y + size))
        surface.blit(char_surf, rect)

    def _draw_kitty(self, surface, character):
        """헬로키티 그리기"""
        x, y = character['x'], character['y']
        size = character['size']
        pose = character['pose']
        tilt = character.get('head_tilt', 0)

        char_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
        cx, cy = size, size

        # 색상
        white = self.COLORS['kitty_white']
        ribbon_red = self.COLORS['kitty_ribbon']
        nose_yellow = self.COLORS['kitty_nose']
        eye_black = self.COLORS['kitty_eye']

        if pose == 'standing':
            # 몸통 (파란 옷)
            body_w = int(size * 0.48)
            body_h = int(size * 0.55)
            pygame.draw.ellipse(char_surf, (100, 150, 220),
                              (cx - body_w // 2, cy + size * 0.12, body_w, body_h))
            # 옷 칼라
            pygame.draw.ellipse(char_surf, white,
                              (cx - body_w // 3, cy + size * 0.1, body_w * 2 // 3, 15))
        else:  # sitting
            body_w = int(size * 0.52)
            body_h = int(size * 0.38)
            pygame.draw.ellipse(char_surf, (255, 150, 180),
                              (cx - body_w // 2, cy + size * 0.18, body_w, body_h))

        # 머리 (특징적인 타원형)
        head_w = int(size * 0.65)
        head_h = int(size * 0.55)
        head_y = cy - size * 0.1
        pygame.draw.ellipse(char_surf, white,
                          (cx - head_w // 2, int(head_y) - head_h // 2, head_w, head_h))

        # 귀 (삼각형)
        ear_size = int(size * 0.18)
        # 왼쪽 귀
        pygame.draw.polygon(char_surf, white,
                          [(cx - head_w // 3, head_y - head_h // 3),
                           (cx - head_w // 3 - ear_size, head_y - head_h // 2 - ear_size),
                           (cx - head_w // 3 + ear_size // 2, head_y - head_h // 2)])
        # 오른쪽 귀
        pygame.draw.polygon(char_surf, white,
                          [(cx + head_w // 3, head_y - head_h // 3),
                           (cx + head_w // 3 + ear_size, head_y - head_h // 2 - ear_size),
                           (cx + head_w // 3 - ear_size // 2, head_y - head_h // 2)])

        # 리본 (왼쪽 귀 옆)
        ribbon_x = cx - head_w // 3 - 5
        ribbon_y = head_y - head_h // 3 - 5
        # 리본 날개
        pygame.draw.ellipse(char_surf, ribbon_red,
                          (ribbon_x - 15, ribbon_y - 8, 18, 16))
        pygame.draw.ellipse(char_surf, ribbon_red,
                          (ribbon_x + 2, ribbon_y - 8, 18, 16))
        # 리본 중앙
        pygame.draw.circle(char_surf, ribbon_red, (ribbon_x, int(ribbon_y)), 6)

        # 눈 (타원형 검은 눈)
        eye_y = head_y + 3
        eye_spacing = head_w // 5
        for eye_x in [cx - eye_spacing, cx + eye_spacing]:
            pygame.draw.ellipse(char_surf, eye_black,
                              (eye_x - 4, int(eye_y) - 5, 8, 10))

        # 코 (노란 타원)
        pygame.draw.ellipse(char_surf, nose_yellow,
                          (cx - 4, int(head_y) + head_h // 6, 8, 6))

        # 수염 (6개)
        whisker_y = head_y + head_h // 5
        whisker_len = 18
        # 왼쪽 수염
        pygame.draw.line(char_surf, eye_black,
                        (cx - head_w // 4, whisker_y - 4),
                        (cx - head_w // 4 - whisker_len, whisker_y - 8), 2)
        pygame.draw.line(char_surf, eye_black,
                        (cx - head_w // 4, whisker_y),
                        (cx - head_w // 4 - whisker_len, whisker_y), 2)
        pygame.draw.line(char_surf, eye_black,
                        (cx - head_w // 4, whisker_y + 4),
                        (cx - head_w // 4 - whisker_len, whisker_y + 8), 2)
        # 오른쪽 수염
        pygame.draw.line(char_surf, eye_black,
                        (cx + head_w // 4, whisker_y - 4),
                        (cx + head_w // 4 + whisker_len, whisker_y - 8), 2)
        pygame.draw.line(char_surf, eye_black,
                        (cx + head_w // 4, whisker_y),
                        (cx + head_w // 4 + whisker_len, whisker_y), 2)
        pygame.draw.line(char_surf, eye_black,
                        (cx + head_w // 4, whisker_y + 4),
                        (cx + head_w // 4 + whisker_len, whisker_y + 8), 2)

        # 회전
        if tilt != 0:
            char_surf = pygame.transform.rotate(char_surf, math.degrees(-tilt))

        rect = char_surf.get_rect(center=(x + size, y + size))
        surface.blit(char_surf, rect)

    def _draw_graffiti(self, surface):
        """그래피티 (삭제됨 - 빈 함수로 유지)"""
        pass

    def _draw_chain(self, surface, chain, time):
        """체인 그리기 (애니메이션)"""
        start_x, start_y = chain['start_x'], chain['start_y']
        end_x, end_y = chain['end_x'], chain['end_y']
        link_size = chain['link_size']
        sway = chain['sway_offset']

        # 체인 길이 계산
        dx = end_x - start_x
        dy = end_y - start_y
        length = math.sqrt(dx * dx + dy * dy)
        num_links = int(length / (link_size + 4))

        if num_links < 2:
            return

        # 느슨한 체인인지
        loose = chain.get('loose', False)

        for i in range(num_links):
            t = i / (num_links - 1) if num_links > 1 else 0

            # 기본 위치
            lx = start_x + dx * t
            ly = start_y + dy * t

            # 흔들림 효과
            swing_amount = math.sin(time * 2.5 + sway + i * 0.35) * 4
            lx += swing_amount

            # 느슨한 체인은 처짐 효과
            if loose:
                sag = math.sin(t * math.pi) * 18
                ly += sag

            # 링크 그리기
            if i % 2 == 0:
                # 세로 링크
                pygame.draw.ellipse(surface, self.COLORS['chain_mid'],
                                  (lx - link_size // 4, ly - link_size // 2,
                                   link_size // 2, link_size))
                pygame.draw.ellipse(surface, self.COLORS['chain_dark'],
                                  (lx - link_size // 4 + 2, ly - link_size // 2 + 2,
                                   link_size // 2 - 4, link_size - 4))
            else:
                # 가로 링크
                pygame.draw.ellipse(surface, self.COLORS['chain_mid'],
                                  (lx - link_size // 2, ly - link_size // 4,
                                   link_size, link_size // 2))
                pygame.draw.ellipse(surface, self.COLORS['chain_dark'],
                                  (lx - link_size // 2 + 2, ly - link_size // 4 + 2,
                                   link_size - 4, link_size // 2 - 4))

            # 하이라이트
            pygame.draw.arc(surface, self.COLORS['chain_highlight'],
                          (lx - link_size // 4, ly - link_size // 4,
                           link_size // 2, link_size // 2),
                          0.3, 1.8, 2)

    def _draw_neon_sign(self, surface, text, x, y, color, size, time, flicker=False):
        """네온사인 그리기"""
        brightness = 1.0
        if flicker:
            flicker_val = math.sin(time * 10)
            if flicker_val < -0.8:
                brightness = 0.2
            elif flicker_val < -0.5:
                brightness = 0.5
            else:
                brightness = 0.75 + 0.25 * (flicker_val + 1) / 2

        # 색상 선택
        if color == 'pink':
            base_color = self.COLORS['neon_pink']
            glow_color = self.COLORS['neon_pink_glow']
        elif color == 'cyan':
            base_color = self.COLORS['neon_cyan']
            glow_color = self.COLORS['neon_cyan_glow']
        else:
            base_color = self.COLORS['neon_purple']
            glow_color = self.COLORS['neon_purple_glow']

        base_color = tuple(int(c * brightness) for c in base_color)
        glow_color = tuple(int(c * brightness) for c in glow_color)

        # 네온 박스 배경
        box_padding = 10
        try:
            font = pygame.font.SysFont('Yu Gothic', size)
        except:
            try:
                font = pygame.font.SysFont('MS Gothic', size)
            except:
                font = pygame.font.SysFont('Arial', size)

        text_surf = font.render(text, True, glow_color)
        tw, th = text_surf.get_size()

        # 박스 그리기
        box_rect = pygame.Rect(x - box_padding, y - box_padding,
                              tw + box_padding * 2, th + box_padding * 2)

        # 어두운 배경
        pygame.draw.rect(surface, (15, 12, 20), box_rect, border_radius=4)

        # 외부 글로우
        for i in range(4):
            glow_alpha = int(50 * brightness * (1 - i / 4))
            glow_surf = pygame.Surface((box_rect.width + i * 8, box_rect.height + i * 8), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*base_color, glow_alpha),
                           (0, 0, glow_surf.get_width(), glow_surf.get_height()),
                           3, border_radius=5)
            surface.blit(glow_surf, (box_rect.x - i * 4, box_rect.y - i * 4))

        # 내부 테두리
        pygame.draw.rect(surface, base_color, box_rect, 3, border_radius=4)

        # 텍스트 글로우 효과
        for offset in [(2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, -1), (1, -1), (-1, 1)]:
            glow_text = font.render(text, True, (*base_color[:3], 80))
            surface.blit(glow_text, (x + offset[0], y + offset[1]))

        # 메인 텍스트
        surface.blit(text_surf, (x, y))

    def _draw_sparkle(self, surface, sparkle, time):
        """반짝이 효과 그리기"""
        x, y = sparkle['x'], sparkle['y']
        base_size = sparkle['size']
        phase = sparkle['phase']
        speed = sparkle['speed']

        # 깜빡임 효과
        alpha = int(128 + 127 * math.sin(time * speed + phase))
        size = int(base_size * (0.5 + 0.5 * math.sin(time * speed + phase)))

        if size < 2:
            return

        # 십자 형태 반짝이
        sparkle_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        cx, cy = size * 2, size * 2

        # 세로선
        pygame.draw.line(sparkle_surf, (255, 255, 255, alpha),
                        (cx, cy - size), (cx, cy + size), 2)
        # 가로선
        pygame.draw.line(sparkle_surf, (255, 255, 255, alpha),
                        (cx - size, cy), (cx + size, cy), 2)
        # 대각선
        pygame.draw.line(sparkle_surf, (255, 255, 255, alpha // 2),
                        (cx - size // 2, cy - size // 2),
                        (cx + size // 2, cy + size // 2), 1)
        pygame.draw.line(sparkle_surf, (255, 255, 255, alpha // 2),
                        (cx + size // 2, cy - size // 2),
                        (cx - size // 2, cy + size // 2), 1)

        surface.blit(sparkle_surf, (x - size * 2, y - size * 2))

    def update(self, dt):
        """업데이트"""
        self.time += dt
        if self.excitement > 0:
            self.excitement = max(0, self.excitement - dt * 0.5)

        # 떠다니는 하트 업데이트
        self._update_floating_hearts(dt)

    def _update_floating_hearts(self, dt):
        """떠다니는 하트 업데이트"""
        # 하트 컬러들 (재생성용)
        heart_colors = [
            (255, 150, 200), (255, 120, 180), (230, 130, 200),
            (200, 120, 220), (180, 100, 200), (220, 140, 230),
            (255, 180, 210), (190, 110, 190),
        ]

        for heart in self.floating_hearts:
            if heart['state'] == 'floating':
                # 부드럽게 떠다니기
                heart['float_phase'] += dt * 0.5
                heart['x'] = heart['start_x'] + math.sin(heart['float_phase'] * heart['float_speed_x']) * heart['float_range_x']
                heart['y'] = heart['start_y'] + math.sin(heart['float_phase'] * heart['float_speed_y'] + 0.5) * heart['float_range_y']

                # 수명 감소
                heart['life'] -= dt
                if heart['life'] <= 0:
                    heart['state'] = 'popping'
                    heart['pop_progress'] = 0

            elif heart['state'] == 'popping':
                # 물방울이 터지는 효과
                heart['pop_progress'] += dt * 3.0  # 터지는 속도
                if heart['pop_progress'] >= 1.0:
                    heart['state'] = 'respawning'
                    heart['respawn_delay'] = random.uniform(0.3, 1.0)

            elif heart['state'] == 'respawning':
                # 재생성 대기
                heart['respawn_delay'] -= dt
                if heart['respawn_delay'] <= 0:
                    # 새 위치에서 재생성
                    self._respawn_floating_heart(heart, heart_colors)

    def _respawn_floating_heart(self, heart, colors):
        """떠다니는 하트 재생성"""
        ft = self.frame_thickness
        gx, gy = self.game_x, self.game_y
        gw, gh = self.game_width, self.game_height

        side = heart['side']
        if side == 'left':
            x = random.randint(20, max(25, gx - ft - 20))
        else:
            x = random.randint(gx + gw + ft + 20, max(gx + gw + ft + 25, self.screen_width - 20))

        y = random.randint(50, self.screen_height - 50)

        heart['x'] = x
        heart['y'] = y
        heart['start_x'] = x
        heart['start_y'] = y
        heart['size'] = random.randint(10, 28)
        heart['color'] = random.choice(colors)
        heart['alpha'] = random.randint(40, 90)
        heart['float_phase'] = random.uniform(0, math.pi * 2)
        heart['float_speed_x'] = random.uniform(0.3, 0.8)
        heart['float_speed_y'] = random.uniform(0.5, 1.0)
        heart['float_range_x'] = random.uniform(8, 20)
        heart['float_range_y'] = random.uniform(10, 25)
        heart['life'] = random.uniform(3.0, 8.0)
        heart['max_life'] = heart['life']
        heart['state'] = 'floating'
        heart['pop_progress'] = 0

    def _draw_floating_heart(self, surface, heart):
        """떠다니는 버블 하트 그리기"""
        if heart['state'] == 'respawning':
            return  # 재생성 중에는 안 보임

        x, y = heart['x'], heart['y']
        size = heart['size']
        color = heart['color']
        alpha = heart['alpha']

        if heart['state'] == 'popping':
            # 터지는 효과 - 크기가 커지면서 투명해짐
            progress = heart['pop_progress']
            # 확장 후 사라지는 효과
            size = size * (1 + progress * 1.5)
            alpha = int(alpha * (1 - progress))
            if alpha <= 0:
                return

        # 하트 서피스 생성
        heart_size = int(size * 2.5)
        heart_surf = pygame.Surface((heart_size, heart_size), pygame.SRCALPHA)
        cx, cy = heart_size // 2, heart_size // 2

        # 하트 그리기 (파라메트릭 공식)
        points = []
        for i in range(32):
            t = i / 32 * 2 * math.pi
            hx = size * 0.5 * (16 * math.sin(t) ** 3) / 16
            hy = -size * 0.5 * (13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)) / 16
            points.append((cx + hx, cy + hy))

        if len(points) >= 3:
            # 메인 하트 (투명하게)
            r, g, b = color
            pygame.draw.polygon(heart_surf, (r, g, b, alpha), points)

            # 터지는 중일 때 파티클 효과
            if heart['state'] == 'popping':
                progress = heart['pop_progress']
                # 파티클들이 퍼져나가는 효과
                num_particles = 6
                for i in range(num_particles):
                    angle = (i / num_particles) * math.pi * 2
                    dist = size * 0.5 + progress * size * 1.5
                    px = cx + math.cos(angle) * dist
                    py = cy + math.sin(angle) * dist
                    particle_size = max(1, int(size * 0.15 * (1 - progress)))
                    particle_alpha = int(alpha * (1 - progress * 0.8))
                    if particle_alpha > 0 and particle_size > 0:
                        pygame.draw.circle(heart_surf, (r, g, b, particle_alpha),
                                         (int(px), int(py)), particle_size)
            else:
                # 은은한 광택 효과
                glow_alpha = int(alpha * 0.3)
                pygame.draw.circle(heart_surf, (255, 255, 255, glow_alpha),
                                 (int(cx - size * 0.15), int(cy - size * 0.15)),
                                 max(2, int(size * 0.2)))

        surface.blit(heart_surf, (int(x - heart_size // 2), int(y - heart_size // 2)))

    def draw(self, screen):
        """그리기"""
        # 정적 캐시 (배경, 액자, 장식, 곰인형, 캐릭터)
        screen.blit(self._static_cache, (0, 0))

        # 동적 요소 - 떠다니는 버블 하트 (필러 영역)
        for heart in self.floating_hearts:
            self._draw_floating_heart(screen, heart)

        # 동적 요소 - 체인
        for chain in self.chains:
            self._draw_chain(screen, chain, self.time)

        # 동적 요소 - 하트 (부유 효과)
        for heart in self.hearts:
            self._draw_heart(screen, heart, self.time)

        # 동적 요소 - 반짝이
        for sparkle in self.sparkles:
            self._draw_sparkle(screen, sparkle, self.time)

    def trigger_excitement(self, level=1.0):
        """흥분 효과"""
        self.excitement = min(2.0, self.excitement + level)

    def resize(self, screen_width, screen_height, game_width, game_height):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        self._generate_elements()
        self._create_static_cache()
        self._generate_floating_hearts()  # 떠다니는 하트도 재생성


# 전역 인스턴스
_menhera_bg_instance = None


def init_menhera_background(screen_width, screen_height, game_width, game_height):
    global _menhera_bg_instance
    _menhera_bg_instance = MenheraPlushFrame(screen_width, screen_height, game_width, game_height)
    return _menhera_bg_instance


def get_menhera_background():
    return _menhera_bg_instance
