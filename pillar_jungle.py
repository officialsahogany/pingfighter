# -*- coding: utf-8 -*-
"""
Stage 2: 고퀄리티 정글 숲 액자 필러 배경 (최적화 버전)
- 사실적인 이끼 낀 돌 테두리
- 두꺼운 덩굴과 열대 식물
- 깊은 정글 숲 배경 (구불구불한 나무, 덩굴)
- 신비로운 빛 효과
- 정적 요소 캐싱으로 성능 최적화
"""

import pygame
import math
import random


class MossyStoneFrame:
    """고퀄리티 정글 숲 액자 스타일 필러 배경 (최적화)"""

    COLORS = {
        # 돌 색상
        'stone_darkest': (45, 42, 38),
        'stone_dark': (65, 60, 52),
        'stone_mid': (90, 82, 70),
        'stone_light': (115, 105, 88),
        'stone_highlight': (145, 135, 115),
        'stone_crack': (35, 32, 28),

        # 이끼 색상
        'moss_darkest': (30, 55, 20),
        'moss_dark': (45, 75, 30),
        'moss_mid': (65, 100, 40),
        'moss_light': (85, 125, 50),
        'moss_bright': (105, 150, 60),
        'moss_highlight': (130, 175, 75),

        # 덩굴 색상
        'vine_darkest': (30, 45, 20),
        'vine_dark': (45, 60, 30),
        'vine_mid': (60, 80, 40),
        'vine_light': (80, 105, 55),
        'vine_tendril': (55, 70, 35),

        # 열대 잎 색상
        'tropical_darkest': (20, 50, 25),
        'tropical_dark': (35, 75, 40),
        'tropical_mid': (50, 100, 55),
        'tropical_light': (70, 130, 70),
        'tropical_highlight': (95, 155, 85),
        'tropical_vein': (40, 65, 35),

        # 양치식물
        'fern_dark': (40, 85, 40),
        'fern_mid': (55, 110, 50),
        'fern_light': (75, 140, 65),

        # 꽃
        'flower_white': (255, 250, 245),
        'flower_cream': (255, 245, 220),
        'flower_yellow': (255, 235, 150),
        'flower_pink': (245, 200, 210),
        'flower_orange': (255, 180, 120),
        'flower_center': (255, 210, 100),

        # 정글 나무 줄기 색상 (어둡고 신비로운)
        'trunk_darkest': (25, 20, 15),
        'trunk_dark': (40, 32, 22),
        'trunk_mid': (55, 45, 32),
        'trunk_light': (75, 60, 42),
        'trunk_highlight': (95, 75, 55),
        'trunk_moss': (45, 60, 35),

        # 정글 배경 색상 (어두운 숲)
        'jungle_darkest': (8, 12, 8),
        'jungle_dark': (15, 25, 15),
        'jungle_mid': (25, 40, 25),
        'jungle_light': (35, 55, 32),
        'jungle_glow': (120, 140, 60),  # 신비로운 황금빛
        'jungle_mist': (60, 80, 50),

        # 정글 잎 (어두운 녹색)
        'jungle_leaf_dark': (20, 45, 20),
        'jungle_leaf_mid': (35, 65, 30),
        'jungle_leaf_light': (50, 85, 40),

        # 큰 활엽수 잎 (밝은 녹색, 참고 이미지처럼)
        'broad_leaf_darkest': (25, 55, 20),
        'broad_leaf_dark': (40, 80, 35),
        'broad_leaf_mid': (55, 110, 45),
        'broad_leaf_light': (75, 140, 60),
        'broad_leaf_highlight': (100, 170, 80),
        'broad_leaf_vein': (35, 65, 30),

        # 나무 감싸는 덩굴 (두꺼운)
        'wrap_vine_dark': (35, 50, 25),
        'wrap_vine_mid': (50, 70, 35),
        'wrap_vine_light': (65, 90, 45),

        # 배경 (정글 숲)
        'bg_darkest': (10, 15, 10),
        'bg_mid': (25, 35, 22),

        # 효과
        'glow_green': (120, 200, 100),
        'glow_gold': (180, 160, 80),
        'shadow': (10, 15, 10),
    }

    # 사전 계산된 sin/cos 테이블 (최적화)
    _sin_table = None
    _cos_table = None

    @classmethod
    def _init_trig_tables(cls):
        """삼각함수 테이블 초기화 (한 번만)"""
        if cls._sin_table is None:
            cls._sin_table = [math.sin(i * 0.01) for i in range(629)]  # 0 ~ 2π
            cls._cos_table = [math.cos(i * 0.01) for i in range(629)]

    def __init__(self, screen_width, screen_height, game_width, game_height):
        MossyStoneFrame._init_trig_tables()

        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        self.time = 0.0
        self.excitement = 0.0
        self._frame_counter = 0

        # 요소 데이터
        self.stones = []
        self.moss_layers = []
        self.thick_vines = []
        self.thin_vines = []
        self.palm_leaves = []
        self.monstera_leaves = []
        self.ferns = []
        self.small_plants = []
        self.flowers = []
        self.hanging_vines = []
        self.jungle_trees = []  # 정글 나무
        self.background_vines = []  # 배경 덩굴
        self.undergrowth_ferns = []  # 밑바닥 양치식물
        self.wrapping_vines = []  # 나무 감싸는 덩굴
        self.broad_leaves = []  # 큰 활엽수 잎사귀

        # 파티클 (수 줄임)
        self.falling_leaves = []
        self.fireflies = []

        # 생성
        self._generate_all_elements()
        self._init_particles()

        # 캐시 서피스들
        self._static_cache = None  # 배경, 돌, 이끼, 작은 식물
        self._foliage_cache = None  # 야자수, 몬스테라, 양치식물, 덩굴, 꽃 (정적)
        self._create_all_caches()

        # 애니메이션용 재사용 서피스
        self._glow_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
        self._leaf_surf = pygame.Surface((50, 30), pygame.SRCALPHA)

    def _fast_sin(self, x):
        """빠른 sin 근사"""
        idx = int((x % 6.283) * 100) % 629
        return self._sin_table[idx]

    def _fast_cos(self, x):
        """빠른 cos 근사"""
        idx = int((x % 6.283) * 100) % 629
        return self._cos_table[idx]

    def _generate_all_elements(self):
        """모든 요소 생성"""
        self._generate_jungle_trees()  # 정글 나무 먼저 (배경)
        self._generate_background_vines()  # 배경 덩굴
        self._generate_wrapping_vines()  # 나무 감싸는 덩굴
        self._generate_broad_leaves()  # 큰 활엽수 잎사귀
        self._generate_undergrowth_ferns()  # 밑바닥 양치식물
        self._generate_layered_stones()
        self._generate_rich_moss()
        self._generate_thick_vines()
        self._generate_thin_vines()
        self._generate_palm_leaves()
        self._generate_monstera_leaves()
        self._generate_detailed_ferns()
        self._generate_small_plants()
        self._generate_flowers()
        self._generate_hanging_vines()

    def _generate_jungle_trees(self):
        """깊은 정글 숲 나무 생성 (필러 빈 공간 배경)"""
        self.jungle_trees = []

        # 좌측 필러 영역
        left_width = self.game_x
        # 우측 필러 영역
        right_start = self.game_x + self.game_width

        if left_width < 60:  # 필러 영역이 너무 좁으면 생략
            return

        # 좌측 정글 나무들 (미니멀하게 3개, 자연스러운 곡선)
        left_trees = [
            # (x, 기준높이, 줄기높이, 줄기두께, 기울기, 곡률, 레이어)
            (left_width * 0.2, 1.05, 0.95, 40, 15, 0.9, 'back'),    # 곡률 증가
            (left_width * 0.6, 1.0, 0.9, 35, -12, 0.75, 'mid'),     # 곡률 증가
            (left_width * 0.1, 1.08, 0.7, 25, 20, 1.0, 'front'),    # 곡률 증가
        ]

        for x, base_y_ratio, height_ratio, thickness, lean, curve, layer in left_trees:
            base_y = self.screen_height * base_y_ratio
            trunk_height = self.screen_height * height_ratio
            self.jungle_trees.append(self._create_jungle_tree(
                x + random.randint(-8, 8),
                base_y,
                trunk_height + random.randint(-30, 30),
                thickness + random.randint(-3, 3),
                lean + random.randint(-8, 8),
                curve,
                layer
            ))

        # 우측 정글 나무들 (미니멀하게 3개, 자연스러운 곡선)
        right_trees = [
            (right_start + (self.screen_width - right_start) * 0.4, 1.0, 0.95, 42, -15, 0.85, 'back'),   # 곡률 증가
            (right_start + (self.screen_width - right_start) * 0.8, 1.04, 0.85, 35, 12, 0.8, 'mid'),     # 곡률 증가
            (right_start + (self.screen_width - right_start) * 0.9, 1.08, 0.68, 25, -18, 0.95, 'front'), # 곡률 증가
        ]

        for x, base_y_ratio, height_ratio, thickness, lean, curve, layer in right_trees:
            base_y = self.screen_height * base_y_ratio
            trunk_height = self.screen_height * height_ratio
            self.jungle_trees.append(self._create_jungle_tree(
                x + random.randint(-8, 8),
                base_y,
                trunk_height + random.randint(-30, 30),
                thickness + random.randint(-3, 3),
                lean + random.randint(-8, 8),
                curve,
                layer
            ))

    def _create_jungle_tree(self, x, base_y, height, thickness, lean, curve_factor, layer):
        """정글 나무 데이터 생성 (구불구불한 줄기)"""
        # 줄기 곡선 포인트 생성 (더 많은 세그먼트로 부드럽게)
        num_segments = 16
        trunk_points = []
        branches = []

        for i in range(num_segments + 1):
            t = i / num_segments
            # 자연스러운 S자 곡선 (여러 사인파 합성)
            # 큰 굽음 + 작은 흔들림으로 실제 나무처럼
            main_curve = math.sin(t * 2.5) * 35 * curve_factor  # 큰 S자 굽음
            secondary_curve = math.sin(t * 5.0 + 1.5) * 12 * curve_factor  # 작은 흔들림
            curve_x = x + lean * t + main_curve + secondary_curve
            curve_y = base_y - height * t
            # 두께 (뿌리 부분이 넓고, 위로 갈수록 가늘어짐)
            root_bulge = 1.3 if t < 0.15 else 1.0
            seg_thickness = thickness * (1 - t * 0.5) * root_bulge
            trunk_points.append((curve_x, curve_y, seg_thickness))

            # 가지 (중간 높이에서)
            if t > 0.4 and t < 0.85 and random.random() < 0.25:
                branch_side = 1 if random.random() < 0.5 else -1
                branches.append({
                    'start_x': curve_x,
                    'start_y': curve_y,
                    'angle': 30 + random.randint(0, 40) if branch_side > 0 else 150 - random.randint(0, 40),
                    'length': random.randint(30, 60),
                    'thickness': max(3, seg_thickness * 0.4),
                })

        # 줄기 표면 텍스처 (이끼, 나무 껍질)
        bark_details = []
        for i in range(num_segments):
            if random.random() < 0.6:
                t = i / num_segments
                px, py, _ = trunk_points[i]
                bark_details.append({
                    'x': px + random.randint(-8, 8),
                    'y': py + random.randint(-5, 5),
                    'type': random.choice(['moss', 'bark', 'lichen']),
                    'size': random.randint(4, 10),
                })

        # 뿌리 (아래쪽에서 뻗어나감)
        roots = []
        num_roots = random.randint(2, 4)
        for i in range(num_roots):
            angle = -60 + (120 / (num_roots - 1)) * i if num_roots > 1 else 0
            roots.append({
                'angle': angle + random.randint(-15, 15),
                'length': random.randint(20, 45),
                'thickness': thickness * 0.4,
            })

        return {
            'x': x,
            'base_y': base_y,
            'height': height,
            'thickness': thickness,
            'lean': lean,
            'curve_factor': curve_factor,
            'layer': layer,
            'trunk_points': trunk_points,
            'branches': branches,
            'bark_details': bark_details,
            'roots': roots,
        }

    def _generate_background_vines(self):
        """배경 덩굴 생성 (미니멀하게)"""
        self.background_vines = []

        left_width = self.game_x
        right_start = self.game_x + self.game_width

        if left_width < 50:
            return

        # 좌측 덩굴 (2개만)
        for _ in range(2):
            self.background_vines.append({
                'x': random.randint(10, left_width - 10),
                'y': random.randint(-30, 30),
                'length': random.randint(120, 250),
                'thickness': random.randint(2, 4),
                'sway_offset': random.uniform(0, 6.283),
                'curve': random.uniform(0.4, 1.0),
            })

        # 우측 덩굴 (2개만)
        for _ in range(2):
            self.background_vines.append({
                'x': random.randint(right_start + 10, self.screen_width - 10),
                'y': random.randint(-30, 30),
                'length': random.randint(120, 250),
                'thickness': random.randint(2, 4),
                'sway_offset': random.uniform(0, 6.283),
                'curve': random.uniform(0.4, 1.0),
            })

    def _generate_undergrowth_ferns(self):
        """밑바닥 양치식물 생성 (미니멀하게)"""
        self.undergrowth_ferns = []

        left_width = self.game_x
        right_start = self.game_x + self.game_width

        if left_width < 50:
            return

        # 좌측 밑바닥 (2개만)
        for i in range(2):
            self.undergrowth_ferns.append({
                'x': random.randint(5, left_width - 5),
                'y': self.screen_height - random.randint(25, 60),
                'size': random.randint(30, 50),
                'angle': random.randint(-20, 20),
                'num_fronds': random.randint(3, 5),
                'shade': random.uniform(0.8, 1.0),
            })

        # 우측 밑바닥 (2개만)
        for i in range(2):
            self.undergrowth_ferns.append({
                'x': random.randint(right_start + 5, self.screen_width - 5),
                'y': self.screen_height - random.randint(25, 60),
                'size': random.randint(30, 50),
                'angle': random.randint(-20, 20),
                'num_fronds': random.randint(3, 5),
                'shade': random.uniform(0.8, 1.0),
            })

    def _generate_wrapping_vines(self):
        """나무를 감싸는 덩굴 생성 (부드러운 곡선)"""
        self.wrapping_vines = []

        # 일부 나무에만 덩굴 추가 (밀도 줄이기)
        for tree in self.jungle_trees[::2]:  # 2개당 1개만
            trunk_points = tree['trunk_points']
            if len(trunk_points) < 5:
                continue

            # 나무당 1개의 감싸는 덩굴
            # 덩굴 시작점 (나무 줄기의 아래쪽)
            start_idx = random.randint(1, 3)

            # 부드러운 베지어 곡선으로 나무 감싸기
            vine_points = []
            num_points = 30  # 더 많은 포인트로 부드럽게
            wrap_count = random.uniform(1.5, 2.5)  # 감싸는 횟수
            thickness = random.randint(4, 7)

            for i in range(num_points):
                t = i / (num_points - 1)
                # 부드러운 사인 곡선으로 나선형
                wrap_angle = t * wrap_count * 6.283
                # 감싸는 반경 (위로 갈수록 줄어듦)
                wrap_radius = 20 * (1 - t * 0.3)

                # 나무 줄기를 따라 올라가면서
                idx = min(start_idx + int(t * (len(trunk_points) - start_idx - 2)), len(trunk_points) - 1)
                trunk_x, trunk_y, trunk_t = trunk_points[idx]

                # 부드러운 곡선 (사인파로 좌우 흔들림)
                vx = trunk_x + math.sin(wrap_angle) * wrap_radius
                vy = trunk_y
                vine_points.append((vx, vy))

            self.wrapping_vines.append({
                'points': vine_points,
                'thickness': thickness,
                'layer': tree['layer'],
                'has_leaves': random.random() < 0.5,
            })

    def _generate_broad_leaves(self):
        """간소화된 활엽수 잎사귀 생성 (미니멀하게)"""
        self.broad_leaves = []

        left_width = self.game_x
        right_start = self.game_x + self.game_width

        if left_width < 50:
            return

        # 좌측 - 미니멀하게 2개만
        left_positions = [
            # (x, y, angle, size, layer) - 최소한의 배치
            (left_width * 0.2, self.screen_height * 0.15, -20, 'medium', 'back'),
            (left_width * 0.15, self.screen_height * 0.75, -25, 'medium', 'front'),
        ]

        for x, y, angle, size_type, layer in left_positions:
            self.broad_leaves.append(self._create_broad_leaf(x, y, angle, size_type, layer))

        # 우측 - 미니멀하게 2개만
        right_positions = [
            (right_start + (self.screen_width - right_start) * 0.8, self.screen_height * 0.18, -15, 'medium', 'back'),
            (right_start + (self.screen_width - right_start) * 0.85, self.screen_height * 0.72, -20, 'medium', 'front'),
        ]

        for x, y, angle, size_type, layer in right_positions:
            self.broad_leaves.append(self._create_broad_leaf(x, y, angle, size_type, layer))

    def _create_broad_leaf(self, x, y, angle, size_type, layer):
        """단일 활엽수 잎 데이터 생성"""
        size_map = {
            'small': random.randint(50, 70),
            'medium': random.randint(80, 110),
            'large': random.randint(120, 160),  # 크기 증가
        }
        size = size_map.get(size_type, 80)

        return {
            'x': x + random.randint(-10, 10),
            'y': y + random.randint(-10, 10),
            'angle': angle + random.randint(-10, 10),
            'size': size,
            'type': random.choice(['heart', 'oval', 'pointed']),
            'layer': layer,
            'shade': random.uniform(0.8, 1.1),
            'droop': random.uniform(0.1, 0.3),
        }

    def _generate_layered_stones(self):
        """돌 생성 (수 최적화)"""
        self.stones = []

        frame_thickness = 55
        margin = 15

        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2
        inner_h = self.game_height + margin * 2

        positions = []

        # 상단 (간격 넓힘)
        x = inner_x - frame_thickness
        while x < inner_x + inner_w + frame_thickness:
            size = random.randint(40, 65)
            positions.append({'x': x, 'y': inner_y - frame_thickness // 2 + random.randint(-12, 12),
                            'size': size, 'layer': 'back'})
            x += size * 0.6

        # 하단
        x = inner_x - frame_thickness
        while x < inner_x + inner_w + frame_thickness:
            size = random.randint(40, 65)
            positions.append({'x': x, 'y': inner_y + inner_h + frame_thickness // 2 + random.randint(-12, 12),
                            'size': size, 'layer': 'back'})
            x += size * 0.6

        # 좌측
        y = inner_y
        while y < inner_y + inner_h:
            size = random.randint(35, 55)
            positions.append({'x': inner_x - frame_thickness // 2 + random.randint(-10, 10),
                            'y': y, 'size': size, 'layer': 'back'})
            y += size * 0.6

        # 우측
        y = inner_y
        while y < inner_y + inner_h:
            size = random.randint(35, 55)
            positions.append({'x': inner_x + inner_w + frame_thickness // 2 + random.randint(-10, 10),
                            'y': y, 'size': size, 'layer': 'back'})
            y += size * 0.6

        for pos in positions:
            self.stones.append(self._create_stone(pos['x'], pos['y'], pos['size'], pos['layer']))

        # 전경 돌 (수 줄임)
        for _ in range(len(positions) // 4):
            base = random.choice(positions)
            self.stones.append(self._create_stone(
                base['x'] + random.randint(-15, 15),
                base['y'] + random.randint(-12, 12),
                random.randint(18, 28), 'front'))

    def _create_stone(self, x, y, size, layer):
        """간단한 돌 생성"""
        num_points = random.randint(6, 9)
        points = []
        for i in range(num_points):
            angle = i * (6.283 / num_points)
            radius = size * (0.45 + random.uniform(0.1, 0.4))
            points.append((radius * math.cos(angle), radius * math.sin(angle) * random.uniform(0.75, 1.0)))

        return {
            'x': x, 'y': y, 'size': size, 'points': points,
            'rotation': random.uniform(-15, 15),
            'shade': random.uniform(0.9, 1.1),
            'layer': layer
        }

    def _generate_rich_moss(self):
        """이끼 생성 (수 최적화)"""
        self.moss_layers = []

        for stone in self.stones:
            if random.random() < 0.75:
                num = random.randint(1, 3)
                for _ in range(num):
                    self.moss_layers.append({
                        'x': stone['x'] + random.randint(-20, 20),
                        'y': stone['y'] + random.randint(-15, 12),
                        'width': random.randint(18, 40),
                        'height': random.randint(12, 28),
                        'type': random.choice(['fluffy', 'carpet', 'thick']),
                        'shade': random.uniform(0.85, 1.15),
                    })

    def _generate_thick_vines(self):
        """두꺼운 덩굴 생성"""
        self.thick_vines = []

        margin = 15
        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2
        inner_h = self.game_height + margin * 2

        corners = [
            (inner_x - 35, inner_y - 35, 45),
            (inner_x + inner_w + 35, inner_y - 35, 135),
            (inner_x - 35, inner_y + inner_h + 35, -45),
            (inner_x + inner_w + 35, inner_y + inner_h + 35, -135),
        ]

        for cx, cy, angle in corners:
            segments = []
            current_angle = angle
            length = random.randint(70, 120)
            seg_count = length // 20

            for i in range(seg_count):
                current_angle += random.uniform(-20, 20)
                segments.append({'length': 20, 'angle': current_angle})

            self.thick_vines.append({
                'x': cx, 'y': cy, 'segments': segments,
                'thickness': random.randint(8, 12)
            })

    def _generate_thin_vines(self):
        """얇은 덩굴 생성 (수 줄임)"""
        self.thin_vines = []

        margin = 15
        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2
        inner_h = self.game_height + margin * 2

        # 상단 (수 줄임)
        for i in range(4):
            self.thin_vines.append({
                'x': inner_x + inner_w * (i + 0.5) / 5 + random.randint(-10, 10),
                'y': inner_y - 30,
                'length': random.randint(45, 85),
                'direction': 'down',
                'sway_offset': random.uniform(0, 6.283),
                'thickness': random.randint(2, 3),
            })

        # 측면 (수 줄임)
        for i in range(3):
            y_pos = inner_y + inner_h * (i + 0.5) / 4
            self.thin_vines.append({
                'x': inner_x - 30, 'y': y_pos + random.randint(-15, 15),
                'length': random.randint(35, 65), 'direction': 'right',
                'sway_offset': random.uniform(0, 6.283), 'thickness': 2
            })
            self.thin_vines.append({
                'x': inner_x + inner_w + 30, 'y': y_pos + random.randint(-15, 15),
                'length': random.randint(35, 65), 'direction': 'left',
                'sway_offset': random.uniform(0, 6.283), 'thickness': 2
            })

    def _generate_palm_leaves(self):
        """야자수 잎 생성 (수 줄임)"""
        self.palm_leaves = []

        margin = 15
        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2
        inner_h = self.game_height + margin * 2

        positions = [
            (inner_x - 45, inner_y - 25, 25, 'large'),
            (inner_x + inner_w + 45, inner_y - 25, 155, 'large'),
            (inner_x - 45, inner_y + inner_h + 25, -25, 'large'),
            (inner_x + inner_w + 45, inner_y + inner_h + 25, -155, 'large'),
            (inner_x - 40, inner_y + inner_h * 0.5, 10, 'medium'),
            (inner_x + inner_w + 40, inner_y + inner_h * 0.5, 170, 'medium'),
        ]

        for px, py, base_angle, size_type in positions:
            num = 2 if size_type == 'large' else 1
            for i in range(num):
                angle_off = (i - num // 2) * 22
                self.palm_leaves.append({
                    'x': px + random.randint(-8, 8),
                    'y': py + random.randint(-8, 8),
                    'angle': base_angle + angle_off,
                    'length': random.randint(60, 95) if size_type == 'large' else random.randint(45, 70),
                    'num_fronds': random.randint(10, 14),
                    'sway_offset': random.uniform(0, 6.283),
                    'droop': random.uniform(0.1, 0.25),
                })

    def _generate_monstera_leaves(self):
        """몬스테라 잎 생성 (수 줄임)"""
        self.monstera_leaves = []

        margin = 15
        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2
        inner_h = self.game_height + margin * 2

        positions = [
            (inner_x - 30, inner_y + inner_h * 0.35, 15),
            (inner_x + inner_w + 30, inner_y + inner_h * 0.4, 165),
            (inner_x + inner_w * 0.4, inner_y + inner_h + 30, -90),
            (inner_x + inner_w * 0.7, inner_y + inner_h + 30, -90),
        ]

        for px, py, angle in positions:
            self.monstera_leaves.append({
                'x': px, 'y': py, 'angle': angle + random.randint(-8, 8),
                'size': random.randint(32, 48),
                'sway_offset': random.uniform(0, 6.283),
            })

    def _generate_detailed_ferns(self):
        """양치식물 생성 (수 줄임)"""
        self.ferns = []

        margin = 15
        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2
        inner_h = self.game_height + margin * 2

        corners = [
            (inner_x - 35, inner_y - 25, -40),
            (inner_x + inner_w + 35, inner_y - 25, 220),
            (inner_x - 35, inner_y + inner_h + 25, 40),
            (inner_x + inner_w + 35, inner_y + inner_h + 25, 140),
        ]

        for cx, cy, base_angle in corners:
            for i in range(3):
                self.ferns.append({
                    'x': cx + random.randint(-6, 6),
                    'y': cy + random.randint(-6, 6),
                    'angle': base_angle + (i - 1) * 20,
                    'length': random.randint(40, 60),
                    'num_pairs': random.randint(8, 12),
                    'sway_offset': random.uniform(0, 6.283),
                })

    def _generate_small_plants(self):
        """작은 식물 생성 (수 줄임)"""
        self.small_plants = []

        for stone in self.stones[::3]:
            if random.random() < 0.5:
                self.small_plants.append({
                    'x': stone['x'] + random.randint(-12, 12),
                    'y': stone['y'] - stone['size'] // 3,
                    'type': random.choice(['grass', 'sprout']),
                    'size': random.randint(10, 18),
                    'count': random.randint(3, 5),
                })

    def _generate_flowers(self):
        """꽃 생성 (수 줄임)"""
        self.flowers = []

        margin = 15
        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2
        inner_h = self.game_height + margin * 2

        positions = [
            (inner_x - 25, inner_y + inner_h * 0.3),
            (inner_x - 25, inner_y + inner_h * 0.7),
            (inner_x + inner_w + 25, inner_y + inner_h * 0.35),
            (inner_x + inner_w + 25, inner_y + inner_h * 0.65),
            (inner_x + inner_w * 0.3, inner_y + inner_h + 22),
            (inner_x + inner_w * 0.7, inner_y + inner_h + 22),
        ]

        for px, py in positions:
            self.flowers.append({
                'x': px + random.randint(-8, 8),
                'y': py + random.randint(-8, 8),
                'size': random.randint(6, 10),
                'petals': random.randint(4, 6),
                'color': random.choice(['white', 'cream', 'yellow', 'pink']),
                'phase': random.uniform(0, 6.283),
            })

    def _generate_hanging_vines(self):
        """매달린 덩굴 (수 줄임)"""
        self.hanging_vines = []

        margin = 15
        inner_x = self.game_x - margin
        inner_y = self.game_y - margin
        inner_w = self.game_width + margin * 2

        for i in range(3):
            self.hanging_vines.append({
                'x': inner_x + inner_w * (i + 0.5) / 4 + random.randint(-12, 12),
                'y': inner_y - 25,
                'length': random.randint(35, 70),
                'sway_offset': random.uniform(0, 6.283),
            })

    def _init_particles(self):
        """파티클 초기화 (수 줄임)"""
        self.falling_leaves = []
        self.fireflies = []

        for _ in range(3):
            self._spawn_falling_leaf()

        for _ in range(6):
            self.fireflies.append({
                'x': random.randint(0, self.screen_width),
                'y': random.randint(0, self.screen_height),
                'phase': random.uniform(0, 6.283),
                'speed': random.uniform(0.3, 0.5),
                'size': random.randint(2, 3),
            })

    def _spawn_falling_leaf(self):
        """떨어지는 잎 생성"""
        if len(self.falling_leaves) >= 5 or self.game_x < 30:
            return

        x = random.randint(10, self.game_x - 10) if random.random() < 0.5 else \
            random.randint(self.screen_width - self.game_x + 10, self.screen_width - 10)

        self.falling_leaves.append({
            'x': x, 'y': random.randint(-30, -10),
            'size': random.randint(8, 14),
            'rotation': random.uniform(0, 360),
            'rot_speed': random.uniform(-2, 2),
            'fall_speed': random.uniform(0.35, 0.6),
            'sway_offset': random.uniform(0, 6.283),
        })

    def _create_all_caches(self):
        """모든 캐시 생성"""
        self._create_static_cache()
        self._create_foliage_cache()

    def _create_static_cache(self):
        """정적 캐시 (배경, 정글 나무, 돌, 이끼, 작은 식물)"""
        self._static_cache = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)

        # 배경 (깊은 정글 숲)
        self._draw_jungle_background(self._static_cache)

        # 배경 덩굴
        for vine in self.background_vines:
            self._draw_background_vine(self._static_cache, vine)

        # 큰 활엽수 잎 (back 레이어)
        for leaf in self.broad_leaves:
            if leaf['layer'] == 'back':
                self._draw_broad_leaf(self._static_cache, leaf)

        # 정글 나무 (레이어별로 그리기)
        for layer in ['back', 'mid', 'front']:
            for tree in self.jungle_trees:
                if tree['layer'] == layer:
                    self._draw_jungle_tree(self._static_cache, tree)

            # 나무 감싸는 덩굴 (같은 레이어)
            for vine in self.wrapping_vines:
                if vine['layer'] == layer:
                    self._draw_wrapping_vine(self._static_cache, vine)

            # 큰 활엽수 잎 (mid, front 레이어)
            if layer != 'back':
                for leaf in self.broad_leaves:
                    if leaf['layer'] == layer:
                        self._draw_broad_leaf(self._static_cache, leaf)

        # 밑바닥 양치식물
        for fern in self.undergrowth_ferns:
            self._draw_undergrowth_fern(self._static_cache, fern)

        # 돌
        for stone in self.stones:
            if stone['layer'] == 'back':
                self._draw_stone(self._static_cache, stone)

        # 이끼
        for moss in self.moss_layers:
            self._draw_moss(self._static_cache, moss)

        # 전경 돌
        for stone in self.stones:
            if stone['layer'] == 'front':
                self._draw_stone(self._static_cache, stone)

        # 작은 식물
        for plant in self.small_plants:
            self._draw_small_plant(self._static_cache, plant)

    def _create_foliage_cache(self):
        """식물 캐시 (덩굴, 양치, 야자수, 몬스테라, 꽃)"""
        self._foliage_cache = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)

        # 두꺼운 덩굴
        for vine in self.thick_vines:
            self._draw_thick_vine(self._foliage_cache, vine)

        # 양치식물
        for fern in self.ferns:
            self._draw_fern_static(self._foliage_cache, fern)

        # 야자수 잎
        for leaf in self.palm_leaves:
            self._draw_palm_leaf_static(self._foliage_cache, leaf)

        # 몬스테라 잎
        for leaf in self.monstera_leaves:
            self._draw_monstera_static(self._foliage_cache, leaf)

        # 꽃
        for flower in self.flowers:
            self._draw_flower_static(self._foliage_cache, flower)

        # 얇은 덩굴
        for vine in self.thin_vines:
            self._draw_thin_vine_static(self._foliage_cache, vine)

        # 매달린 덩굴
        for vine in self.hanging_vines:
            self._draw_hanging_vine_static(self._foliage_cache, vine)

    def _draw_jungle_background(self, surface):
        """깊은 정글 숲 배경 그리기"""
        left_width = self.game_x
        right_start = self.game_x + self.game_width

        # 어두운 정글 그라데이션 (필러 영역만)
        for y in range(0, self.screen_height, 2):
            progress = y / self.screen_height
            # 위쪽은 약간 밝고 (나무 캐노피), 중간은 더 어둡고, 아래쪽은 약간 밝은 빛
            if progress < 0.3:
                # 상단 (나무 사이로 들어오는 빛)
                t = progress / 0.3
                r = int(self.COLORS['jungle_dark'][0] + (self.COLORS['jungle_mid'][0] - self.COLORS['jungle_dark'][0]) * t)
                g = int(self.COLORS['jungle_dark'][1] + (self.COLORS['jungle_mid'][1] - self.COLORS['jungle_dark'][1]) * t)
                b = int(self.COLORS['jungle_dark'][2] + (self.COLORS['jungle_mid'][2] - self.COLORS['jungle_dark'][2]) * t)
            elif progress < 0.7:
                # 중간 (어두운 정글 내부)
                r, g, b = self.COLORS['jungle_darkest']
            else:
                # 하단 (바닥쪽 - 약간 밝은 이끼빛)
                t = (progress - 0.7) / 0.3
                r = int(self.COLORS['jungle_darkest'][0] + (self.COLORS['jungle_dark'][0] - self.COLORS['jungle_darkest'][0]) * t)
                g = int(self.COLORS['jungle_darkest'][1] + (self.COLORS['jungle_dark'][1] - self.COLORS['jungle_darkest'][1]) * t)
                b = int(self.COLORS['jungle_darkest'][2] + (self.COLORS['jungle_dark'][2] - self.COLORS['jungle_darkest'][2]) * t)

            # 좌측 필러
            if left_width > 0:
                pygame.draw.rect(surface, (r, g, b), (0, y, left_width, 2))
            # 우측 필러
            if right_start < self.screen_width:
                pygame.draw.rect(surface, (r, g, b), (right_start, y, self.screen_width - right_start, 2))

        # 신비로운 빛 (중앙 뒤쪽에서 들어오는 황금빛)
        glow_center_y = int(self.screen_height * 0.4)
        glow_radius = int(self.screen_height * 0.35)

        # 좌측 빛
        if left_width > 0:
            for i in range(5):
                alpha = 15 - i * 3
                radius = glow_radius - i * 20
                if radius > 0:
                    glow_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                    pygame.draw.ellipse(glow_surf, (*self.COLORS['jungle_glow'], alpha),
                                       (0, 0, radius * 2, radius * 2))
                    surface.blit(glow_surf, (left_width - radius, glow_center_y - radius))

        # 우측 빛
        if right_start < self.screen_width:
            for i in range(5):
                alpha = 15 - i * 3
                radius = glow_radius - i * 20
                if radius > 0:
                    glow_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                    pygame.draw.ellipse(glow_surf, (*self.COLORS['jungle_glow'], alpha),
                                       (0, 0, radius * 2, radius * 2))
                    surface.blit(glow_surf, (right_start - radius, glow_center_y - radius))

        # 안개 효과 (하단)
        mist_start = int(self.screen_height * 0.7)
        for y in range(mist_start, self.screen_height, 4):
            progress = (y - mist_start) / (self.screen_height - mist_start)
            alpha = int(20 * (1 - progress))
            if left_width > 0:
                pygame.draw.rect(surface, (*self.COLORS['jungle_mist'], alpha), (0, y, left_width, 4))
            if right_start < self.screen_width:
                pygame.draw.rect(surface, (*self.COLORS['jungle_mist'], alpha),
                               (right_start, y, self.screen_width - right_start, 4))

        # 게임 영역 배경 (어두운 색)
        pygame.draw.rect(surface, self.COLORS['bg_darkest'],
                        (self.game_x, self.game_y, self.game_width, self.game_height))

    def _draw_background_vine(self, surface, vine):
        """배경 덩굴 그리기"""
        x, y = vine['x'], vine['y']
        length = vine['length']
        thickness = vine['thickness']
        curve = vine['curve']

        points = []
        for i in range(15):
            t = i / 14
            vx = x + math.sin(t * 4 * curve) * 20 * curve
            vy = y + length * t
            points.append((int(vx), int(vy)))

        if len(points) >= 2:
            # 어두운 덩굴
            pygame.draw.lines(surface, self.COLORS['jungle_dark'], False, points, thickness + 1)
            pygame.draw.lines(surface, self.COLORS['jungle_leaf_dark'], False, points, thickness)

            # 작은 잎들
            for i in range(2, len(points) - 1, 3):
                px, py = points[i]
                side = 1 if i % 2 == 0 else -1
                pygame.draw.ellipse(surface, self.COLORS['jungle_leaf_mid'],
                                  (px + side * 6 - 4, py - 3, 8, 6))

    def _draw_jungle_tree(self, surface, tree):
        """정글 나무 그리기 (구불구불한 큰 나무)"""
        trunk_points = tree['trunk_points']
        branches = tree['branches']
        bark_details = tree['bark_details']
        roots = tree['roots']
        layer = tree['layer']

        # 레이어에 따른 색상 조정
        if layer == 'back':
            shade = 0.6
        elif layer == 'mid':
            shade = 0.8
        else:
            shade = 1.0

        # 뿌리 그리기
        if len(trunk_points) > 0:
            base_x, base_y, base_t = trunk_points[0]
            for root in roots:
                rad = math.radians(root['angle'])
                end_x = base_x + math.cos(rad) * root['length']
                end_y = base_y + math.sin(rad) * root['length'] * 0.5

                root_color = tuple(int(c * shade * 0.8) for c in self.COLORS['trunk_darkest'])
                pygame.draw.line(surface, root_color, (int(base_x), int(base_y)),
                               (int(end_x), int(end_y)), int(root['thickness']))

        # 줄기 그리기
        if len(trunk_points) >= 2:
            # 그림자
            for i in range(len(trunk_points) - 1):
                x1, y1, t1 = trunk_points[i]
                x2, y2, t2 = trunk_points[i + 1]
                pygame.draw.line(surface, (0, 0, 0, 25),
                               (int(x1 + 4), int(y1 + 4)), (int(x2 + 4), int(y2 + 4)), int(t1) + 3)

            # 줄기 본체 (어두운 쪽)
            for i in range(len(trunk_points) - 1):
                x1, y1, t1 = trunk_points[i]
                x2, y2, t2 = trunk_points[i + 1]
                color = tuple(int(c * shade) for c in self.COLORS['trunk_darkest'])
                pygame.draw.line(surface, color, (int(x1), int(y1)), (int(x2), int(y2)), int(t1) + 2)

            # 줄기 본체 (중간)
            for i in range(len(trunk_points) - 1):
                x1, y1, t1 = trunk_points[i]
                x2, y2, t2 = trunk_points[i + 1]
                color = tuple(int(c * shade) for c in self.COLORS['trunk_dark'])
                pygame.draw.line(surface, color, (int(x1 - 1), int(y1)), (int(x2 - 1), int(y2)), int(t1))

            # 하이라이트 (한쪽 면)
            for i in range(len(trunk_points) - 1):
                x1, y1, t1 = trunk_points[i]
                x2, y2, t2 = trunk_points[i + 1]
                color = tuple(int(c * shade) for c in self.COLORS['trunk_mid'])
                pygame.draw.line(surface, (*color, 150), (int(x1 - 3), int(y1)), (int(x2 - 3), int(y2)),
                               max(2, int(t1) // 3))

        # 가지 그리기
        for branch in branches:
            bx, by = branch['start_x'], branch['start_y']
            rad = math.radians(branch['angle'])
            end_x = bx + math.cos(rad) * branch['length']
            end_y = by + math.sin(rad) * branch['length']

            branch_color = tuple(int(c * shade * 0.9) for c in self.COLORS['trunk_dark'])
            pygame.draw.line(surface, branch_color, (int(bx), int(by)),
                           (int(end_x), int(end_y)), int(branch['thickness']))

        # 나무 껍질 텍스처
        for detail in bark_details:
            dx, dy = detail['x'], detail['y']
            size = detail['size']

            if detail['type'] == 'moss':
                moss_color = tuple(int(c * shade) for c in self.COLORS['trunk_moss'])
                pygame.draw.circle(surface, moss_color, (int(dx), int(dy)), size)
            elif detail['type'] == 'bark':
                bark_color = tuple(int(c * shade * 0.7) for c in self.COLORS['trunk_darkest'])
                pygame.draw.line(surface, bark_color, (int(dx), int(dy - size)),
                               (int(dx), int(dy + size)), 2)
            else:  # lichen
                lichen_color = tuple(int(c * shade) for c in self.COLORS['jungle_mist'])
                pygame.draw.circle(surface, (*lichen_color, 100), (int(dx), int(dy)), size // 2)

    def _draw_undergrowth_fern(self, surface, fern):
        """밑바닥 양치식물 그리기"""
        x, y = fern['x'], fern['y']
        size = fern['size']
        angle = fern['angle']
        num_fronds = fern['num_fronds']
        shade = fern['shade']

        rad = math.radians(angle - 90)

        # 여러 잎 줄기
        for f in range(num_fronds):
            frond_angle = rad + (f - num_fronds // 2) * 0.25
            frond_len = size * (0.7 + random.random() * 0.3)

            # 줄기
            end_x = x + math.cos(frond_angle) * frond_len
            end_y = y + math.sin(frond_angle) * frond_len

            color = tuple(int(c * shade) for c in self.COLORS['jungle_leaf_dark'])
            pygame.draw.line(surface, color, (int(x), int(y)), (int(end_x), int(end_y)), 2)

            # 작은 잎들
            for i in range(4):
                t = (i + 1) / 5
                stem_x = x + (end_x - x) * t
                stem_y = y + (end_y - y) * t
                leaf_len = size * 0.25 * (1 - t * 0.5)

                for side in [-1, 1]:
                    leaf_angle = frond_angle + (1.2 * side)
                    lx = stem_x + math.cos(leaf_angle) * leaf_len
                    ly = stem_y + math.sin(leaf_angle) * leaf_len
                    leaf_color = tuple(int(c * shade) for c in self.COLORS['jungle_leaf_mid'])
                    pygame.draw.line(surface, leaf_color, (int(stem_x), int(stem_y)), (int(lx), int(ly)), 1)

    def _draw_wrapping_vine(self, surface, vine):
        """나무를 감싸는 덩굴 그리기"""
        points = vine['points']
        thickness = vine['thickness']
        layer = vine['layer']
        has_leaves = vine['has_leaves']

        if len(points) < 2:
            return

        # 레이어에 따른 색상 조정
        if layer == 'back':
            shade = 0.65
        elif layer == 'mid':
            shade = 0.85
        else:
            shade = 1.0

        # 정수 좌표로 변환
        int_points = [(int(p[0]), int(p[1])) for p in points]

        # 덩굴 그리기 (굵은 선)
        dark_color = tuple(int(c * shade) for c in self.COLORS['wrap_vine_dark'])
        mid_color = tuple(int(c * shade) for c in self.COLORS['wrap_vine_mid'])
        light_color = tuple(int(c * shade) for c in self.COLORS['wrap_vine_light'])

        # 그림자
        pygame.draw.lines(surface, (0, 0, 0, 30), False,
                         [(p[0] + 2, p[1] + 2) for p in int_points], thickness + 2)

        # 본체
        pygame.draw.lines(surface, dark_color, False, int_points, thickness + 1)
        pygame.draw.lines(surface, mid_color, False, int_points, thickness)

        # 하이라이트
        if thickness >= 4:
            pygame.draw.lines(surface, (*light_color, 120), False,
                            [(p[0] - 1, p[1]) for p in int_points], max(1, thickness // 3))

        # 덩굴 잎 (옵션)
        if has_leaves:
            for i in range(3, len(int_points) - 1, 4):
                px, py = int_points[i]
                side = 1 if i % 2 == 0 else -1

                # 작은 하트 모양 잎
                leaf_size = random.randint(6, 12)
                leaf_color = tuple(int(c * shade) for c in self.COLORS['broad_leaf_mid'])
                pygame.draw.ellipse(surface, leaf_color,
                                  (px + side * 8 - leaf_size // 2, py - leaf_size // 2,
                                   leaf_size, int(leaf_size * 1.2)))

    def _draw_broad_leaf(self, surface, leaf):
        """큰 활엽수 잎사귀 그리기 (고품질 디테일)"""
        x, y = int(leaf['x']), int(leaf['y'])
        angle = leaf['angle']
        size = leaf['size']
        leaf_type = leaf['type']
        layer = leaf['layer']
        shade = leaf['shade']
        droop = leaf['droop']

        # 레이어에 따른 밝기 조정
        if layer == 'back':
            layer_shade = 0.55
        elif layer == 'mid':
            layer_shade = 0.75
        else:
            layer_shade = 1.0

        final_shade = shade * layer_shade

        # 잎 서피스 생성
        surf_size = int(size * 3.5)
        leaf_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2

        # 색상 준비
        darkest = tuple(int(c * final_shade * 0.7) for c in self.COLORS['broad_leaf_darkest'])
        dark = tuple(int(c * final_shade) for c in self.COLORS['broad_leaf_dark'])
        mid = tuple(int(c * final_shade) for c in self.COLORS['broad_leaf_mid'])
        light = tuple(int(c * final_shade) for c in self.COLORS['broad_leaf_light'])
        highlight = tuple(int(c * final_shade) for c in self.COLORS['broad_leaf_highlight'])
        vein = tuple(int(c * final_shade * 0.8) for c in self.COLORS['broad_leaf_vein'])

        # 실제 잎 모양 생성 (부드러운 곡선)
        num_points = 40
        points = []

        for i in range(num_points):
            t = i / num_points * 6.283

            if leaf_type == 'heart':
                # 하트형 (몬스테라 스타일) - 더 자연스러운 곡선
                r = size * (1 - 0.15 * abs(math.sin(t * 1.5)))
                # 아래쪽이 뾰족하게
                if t > 2.8 and t < 3.5:
                    r *= 0.7
                px = center + r * math.sin(t) * 0.85
                py = center - r * math.cos(t) * 1.15 + size * droop * 0.3

            elif leaf_type == 'oval':
                # 타원형 - 더 길쭉하게
                rx = size * 0.45
                ry = size * 0.75
                px = center + rx * math.cos(t)
                py = center + ry * math.sin(t) * 1.1

            else:  # pointed
                # 뾰족한 잎 - 위쪽이 뾰족
                r = size * 0.6 * (1 + 0.3 * math.cos(t))
                if t < 0.5 or t > 5.8:
                    r *= (1 - abs(t - 0.2 if t < 0.5 else t - 6.08) * 0.8)
                px = center + r * math.sin(t) * 0.7
                py = center - r * math.cos(t) * 1.2

            points.append((px, py))

        if len(points) < 3:
            return

        # 그림자 (더 부드럽게)
        shadow_pts = [(p[0] + 4, p[1] + 4) for p in points]
        pygame.draw.polygon(leaf_surf, (0, 0, 0, 20), shadow_pts)

        # 외곽선 (어두운 테두리)
        pygame.draw.polygon(leaf_surf, darkest, points)

        # 본체 (살짝 안쪽)
        inner1 = [(center + (p[0] - center) * 0.95, center + (p[1] - center) * 0.95) for p in points]
        pygame.draw.polygon(leaf_surf, dark, inner1)

        # 중간 톤
        inner2 = [(center + (p[0] - center) * 0.85, center + (p[1] - center) * 0.85) for p in points]
        pygame.draw.polygon(leaf_surf, mid, inner2)

        # 밝은 부분 (위쪽)
        inner3 = [(center + (p[0] - center) * 0.65, center + (p[1] - center) * 0.6 - size * 0.05) for p in points]
        pygame.draw.polygon(leaf_surf, (*light, 180), inner3)

        # 하이라이트 (반사광)
        inner4 = [(center + (p[0] - center) * 0.35, center + (p[1] - center) * 0.3 - size * 0.1) for p in points]
        pygame.draw.polygon(leaf_surf, (*highlight, 60), inner4)

        # 잎맥 그리기 (더 상세하게)
        # 중앙 잎맥
        pygame.draw.line(leaf_surf, vein,
                        (center, int(center - size * 0.5)), (center, int(center + size * 0.85)), 3)
        pygame.draw.line(leaf_surf, (*mid, 150),
                        (center - 1, int(center - size * 0.5)), (center - 1, int(center + size * 0.85)), 1)

        # 측면 잎맥 (곡선으로)
        for i in range(5):
            t = (i + 1) / 6
            vy = int(center - size * 0.3 + size * t * 1.0)
            vein_len = int(size * 0.45 * (1 - t * 0.4))

            if vein_len > 5:
                # 왼쪽 잎맥 (곡선)
                for j in range(8):
                    jt = j / 7
                    vx1 = center - vein_len * jt
                    vy1 = vy + vein_len * 0.25 * jt * jt
                    vx2 = center - vein_len * (jt + 0.15)
                    vy2 = vy + vein_len * 0.25 * (jt + 0.15) ** 2
                    if j < 7:
                        pygame.draw.line(leaf_surf, vein, (int(vx1), int(vy1)), (int(vx2), int(vy2)), 1)

                # 오른쪽 잎맥 (곡선)
                for j in range(8):
                    jt = j / 7
                    vx1 = center + vein_len * jt
                    vy1 = vy + vein_len * 0.25 * jt * jt
                    vx2 = center + vein_len * (jt + 0.15)
                    vy2 = vy + vein_len * 0.25 * (jt + 0.15) ** 2
                    if j < 7:
                        pygame.draw.line(leaf_surf, vein, (int(vx1), int(vy1)), (int(vx2), int(vy2)), 1)

        # 회전 및 배치
        rotated = pygame.transform.rotate(leaf_surf, -angle)
        rect = rotated.get_rect(center=(x, y))
        surface.blit(rotated, rect)

    def _draw_stone(self, surface, stone):
        """돌 그리기"""
        x, y = int(stone['x']), int(stone['y'])
        size = stone['size']
        shade = stone['shade']
        points = stone['points']

        surf_size = size * 3
        stone_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2

        # 그림자
        shadow_pts = [(p[0] + center + 3, p[1] + center + 3) for p in points]
        pygame.draw.polygon(stone_surf, (0, 0, 0, 40), shadow_pts)

        # 본체
        base_pts = [(p[0] + center, p[1] + center) for p in points]
        pygame.draw.polygon(stone_surf, tuple(int(c * shade * 0.65) for c in self.COLORS['stone_darkest']), base_pts)

        mid_pts = [(p[0] * 0.88 + center, p[1] * 0.88 + center) for p in points]
        pygame.draw.polygon(stone_surf, tuple(int(c * shade * 0.85) for c in self.COLORS['stone_dark']), mid_pts)

        # 하이라이트
        pygame.draw.ellipse(stone_surf, (*self.COLORS['stone_light'], 100),
                           (center - size//4, center - size//4, size//2, size//3))

        rotated = pygame.transform.rotate(stone_surf, stone['rotation'])
        rect = rotated.get_rect(center=(x, y))
        surface.blit(rotated, rect)

    def _draw_moss(self, surface, moss):
        """이끼 그리기"""
        x, y = int(moss['x']), int(moss['y'])
        w, h = moss['width'], moss['height']
        shade = moss['shade']

        if moss['type'] == 'fluffy':
            for _ in range(8):
                ox = x + random.randint(-w//2, w//2)
                oy = y + random.randint(-h//2, h//2)
                r = random.randint(3, 7)
                color = tuple(int(c * shade) for c in random.choice([
                    self.COLORS['moss_dark'], self.COLORS['moss_mid'], self.COLORS['moss_light']]))
                pygame.draw.circle(surface, color, (ox, oy), r)

        elif moss['type'] == 'carpet':
            color = tuple(int(c * shade) for c in self.COLORS['moss_mid'])
            pygame.draw.ellipse(surface, color, (x - w//2, y - h//2, w, h))

        else:  # thick
            dark = tuple(int(c * shade * 0.85) for c in self.COLORS['moss_darkest'])
            mid = tuple(int(c * shade) for c in self.COLORS['moss_mid'])
            pygame.draw.ellipse(surface, dark, (x - w//2, y - h//2, w, h))
            pygame.draw.ellipse(surface, mid, (x - w//2 + 2, y - h//2 + 2, w - 4, h - 4))

    def _draw_small_plant(self, surface, plant):
        """작은 식물 그리기"""
        x, y = plant['x'], plant['y']

        if plant['type'] == 'grass':
            for i in range(plant['count']):
                angle = -90 + (i - plant['count']//2) * 14
                rad = math.radians(angle)
                length = plant['size']
                pygame.draw.line(surface, self.COLORS['tropical_mid'],
                               (x, y), (int(x + math.cos(rad) * length), int(y + math.sin(rad) * length)), 2)
        else:  # sprout
            pygame.draw.line(surface, self.COLORS['vine_mid'], (x, y), (x, y - plant['size']), 2)
            pygame.draw.ellipse(surface, self.COLORS['tropical_light'], (x - 5, y - plant['size'] - 3, 5, 8))
            pygame.draw.ellipse(surface, self.COLORS['tropical_light'], (x, y - plant['size'] - 3, 5, 8))

    def _draw_thick_vine(self, surface, vine):
        """두꺼운 덩굴 그리기"""
        x, y = vine['x'], vine['y']
        thickness = vine['thickness']

        points = [(x, y)]
        cx, cy = x, y
        for seg in vine['segments']:
            rad = math.radians(seg['angle'])
            cx += math.cos(rad) * seg['length']
            cy += math.sin(rad) * seg['length']
            points.append((cx, cy))

        if len(points) >= 2:
            pygame.draw.lines(surface, self.COLORS['vine_darkest'], False, points, thickness + 2)
            pygame.draw.lines(surface, self.COLORS['vine_dark'], False, points, thickness)

    def _draw_fern_static(self, surface, fern):
        """양치식물 정적 그리기"""
        x, y = fern['x'], fern['y']
        angle = fern['angle']
        length = fern['length']
        num_pairs = fern['num_pairs']

        rad = math.radians(angle)
        end_x = x + math.cos(rad) * length
        end_y = y + math.sin(rad) * length

        # 줄기
        pygame.draw.line(surface, self.COLORS['fern_dark'], (int(x), int(y)), (int(end_x), int(end_y)), 3)

        # 잎
        for i in range(num_pairs):
            t = (i + 1) / (num_pairs + 1)
            stem_x = x + (end_x - x) * t
            stem_y = y + (end_y - y) * t
            frond_len = int(length * 0.3 * (1 - t * 0.5))

            if frond_len < 5:
                continue

            for side in [-1, 1]:
                frond_angle = rad + (1.2 * side)
                fx = stem_x + math.cos(frond_angle) * frond_len
                fy = stem_y + math.sin(frond_angle) * frond_len
                pygame.draw.line(surface, self.COLORS['fern_light'],
                               (int(stem_x), int(stem_y)), (int(fx), int(fy)), 2)

    def _draw_palm_leaf_static(self, surface, leaf):
        """야자수 잎 정적 그리기"""
        x, y = leaf['x'], leaf['y']
        angle = leaf['angle']
        length = leaf['length']
        num_fronds = leaf['num_fronds']
        droop = leaf['droop']

        rad = math.radians(angle)

        # 줄기
        spine_pts = []
        for i in range(10):
            t = i / 9
            droop_off = droop * t * t * length * 0.4
            px = x + math.cos(rad) * length * t
            py = y + math.sin(rad) * length * t + droop_off
            spine_pts.append((int(px), int(py)))

        if len(spine_pts) >= 2:
            pygame.draw.lines(surface, self.COLORS['tropical_vein'], False, spine_pts, 3)

        # 잎
        for i in range(num_fronds):
            t = (i + 1.5) / (num_fronds + 2)
            idx = min(int(t * len(spine_pts)), len(spine_pts) - 1)
            stem_x, stem_y = spine_pts[idx]

            len_factor = 1 - abs(t - 0.5) * 1.4
            frond_len = int(length * 0.4 * max(0.35, len_factor))
            if frond_len < 8:
                continue

            if idx < len(spine_pts) - 1:
                dx = spine_pts[idx + 1][0] - spine_pts[idx][0]
                dy = spine_pts[idx + 1][1] - spine_pts[idx][1]
                spine_angle = math.atan2(dy, dx)
            else:
                spine_angle = rad

            for side in [-1, 1]:
                frond_angle = spine_angle + (1.4 * side)
                fx = stem_x + math.cos(frond_angle) * frond_len
                fy = stem_y + math.sin(frond_angle) * frond_len

                # 간단한 선으로 대체
                pygame.draw.line(surface, self.COLORS['tropical_mid'],
                               (stem_x, stem_y), (int(fx), int(fy)), 3)
                pygame.draw.line(surface, self.COLORS['tropical_light'],
                               (stem_x, stem_y), (int((stem_x + fx) / 2), int((stem_y + fy) / 2)), 2)

    def _draw_monstera_static(self, surface, leaf):
        """몬스테라 잎 정적 그리기"""
        x, y = int(leaf['x']), int(leaf['y'])
        angle = leaf['angle']
        size = leaf['size']

        surf_size = size * 3
        leaf_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2

        # 하트 모양
        points = []
        for i in range(20):
            t = i / 20 * 6.283
            r = size * (1 - 0.25 * abs(math.sin(t)))
            if t > 3.14:
                r *= 0.88
            px = center + r * math.sin(t) * 0.85
            py = center - r * math.cos(t) * 1.05
            points.append((px, py))

        pygame.draw.polygon(leaf_surf, self.COLORS['tropical_dark'], points)

        inner_pts = [(center + (p[0] - center) * 0.82, center + (p[1] - center) * 0.82) for p in points]
        pygame.draw.polygon(leaf_surf, self.COLORS['tropical_mid'], inner_pts)

        # 잎맥
        pygame.draw.line(leaf_surf, self.COLORS['tropical_vein'],
                        (center, center - size * 0.25), (center, center + size * 0.8), 2)

        rotated = pygame.transform.rotate(leaf_surf, -angle)
        rect = rotated.get_rect(center=(x, y))
        surface.blit(rotated, rect)

    def _draw_flower_static(self, surface, flower):
        """꽃 정적 그리기"""
        x, y = int(flower['x']), int(flower['y'])
        size = flower['size']
        petals = flower['petals']

        color_map = {
            'white': self.COLORS['flower_white'],
            'cream': self.COLORS['flower_cream'],
            'yellow': self.COLORS['flower_yellow'],
            'pink': self.COLORS['flower_pink'],
        }
        color = color_map.get(flower['color'], self.COLORS['flower_white'])

        for i in range(petals):
            angle = i * (360 / petals)
            rad = math.radians(angle)
            px = x + int(math.cos(rad) * size)
            py = y + int(math.sin(rad) * size)
            pygame.draw.circle(surface, color, (px, py), size // 2)

        pygame.draw.circle(surface, self.COLORS['flower_center'], (x, y), size // 3)

    def _draw_thin_vine_static(self, surface, vine):
        """얇은 덩굴 정적 그리기"""
        x, y = vine['x'], vine['y']
        length = vine['length']
        direction = vine['direction']
        thickness = vine['thickness']

        dx = {'down': 0, 'up': 0, 'right': 1, 'left': -1}[direction]
        dy = {'down': 1, 'up': -1, 'right': 0, 'left': 0}[direction]

        points = []
        for i in range(12):
            t = i / 11
            curl = math.sin(t * 6) * 12 * t
            px = x + dx * length * t + (dy * curl if direction in ['down', 'up'] else curl)
            py = y + dy * length * t + (dx * curl if direction in ['left', 'right'] else curl)
            points.append((int(px), int(py)))

        if len(points) >= 2:
            pygame.draw.lines(surface, self.COLORS['vine_dark'], False, points, thickness + 1)
            pygame.draw.lines(surface, self.COLORS['vine_mid'], False, points, thickness)

    def _draw_hanging_vine_static(self, surface, vine):
        """매달린 덩굴 정적 그리기"""
        x, y = vine['x'], vine['y']
        length = vine['length']

        points = []
        for i in range(8):
            t = i / 7
            points.append((int(x), int(y + length * t)))

        if len(points) >= 2:
            pygame.draw.lines(surface, self.COLORS['vine_dark'], False, points, 2)

        # 잎 몇 개
        for i in range(2):
            t = (i + 1) / 3
            ly = y + length * t
            side = 1 if i % 2 == 0 else -1
            pygame.draw.ellipse(surface, self.COLORS['tropical_mid'],
                              (int(x + side * 8 - 6), int(ly - 4), 12, 8))

    def update(self, dt):
        """업데이트"""
        self.time += dt
        self._frame_counter += 1

        if self.excitement > 0:
            self.excitement = max(0, self.excitement - dt * 0.5)

        # 떨어지는 잎 (매 프레임)
        for leaf in self.falling_leaves[:]:
            leaf['y'] += leaf['fall_speed']
            leaf['sway_offset'] += 1.5 * dt
            leaf['rotation'] += leaf['rot_speed']
            if leaf['y'] > self.screen_height + 25:
                self.falling_leaves.remove(leaf)

        # 반딧불이 (매 프레임)
        for fly in self.fireflies:
            fly['phase'] += fly['speed'] * dt
            fly['x'] += self._fast_sin(fly['phase']) * 0.35
            fly['y'] += self._fast_cos(fly['phase'] * 0.7) * 0.2

            if fly['x'] < -25:
                fly['x'] = self.screen_width + 25
            elif fly['x'] > self.screen_width + 25:
                fly['x'] = -25
            if fly['y'] < -25:
                fly['y'] = self.screen_height + 25
            elif fly['y'] > self.screen_height + 25:
                fly['y'] = -25

        # 새 잎 (낮은 확률)
        if random.random() < 0.0015 * (1 + self.excitement):
            self._spawn_falling_leaf()

    def trigger_excitement(self, level=1.5):
        """흥분 트리거"""
        self.excitement = min(2.0, level)
        for _ in range(2):
            self._spawn_falling_leaf()

    def draw(self, screen):
        """렌더링 (최적화)"""
        # 정적 캐시 (배경, 돌, 이끼, 작은 식물)
        if self._static_cache:
            screen.blit(self._static_cache, (0, 0))

        # 식물 캐시 (덩굴, 양치, 야자수, 몬스테라, 꽃)
        if self._foliage_cache:
            screen.blit(self._foliage_cache, (0, 0))

        # 동적 요소만 그리기
        self._draw_falling_leaves(screen)
        self._draw_fireflies(screen)
        self._draw_inner_border(screen)

    def _draw_falling_leaves(self, screen):
        """떨어지는 잎 (최적화)"""
        for leaf in self.falling_leaves:
            sway_x = self._fast_sin(leaf['sway_offset']) * 20
            x = int(leaf['x'] + sway_x)
            y = int(leaf['y'])

            self._leaf_surf.fill((0, 0, 0, 0))
            pygame.draw.ellipse(self._leaf_surf, self.COLORS['tropical_mid'],
                              (0, 0, leaf['size'] * 2, leaf['size']))

            rotated = pygame.transform.rotate(self._leaf_surf, leaf['rotation'])
            rect = rotated.get_rect(center=(x, y))
            screen.blit(rotated, rect)

    def _draw_fireflies(self, screen):
        """반딧불이 (최적화)"""
        for fly in self.fireflies:
            glow = (self._fast_sin(self.time * 2.5 + fly['phase']) + 1) * 0.5

            if glow > 0.25:
                alpha = int(70 * glow)
                size = fly['size'] + int(glow * 3)

                self._glow_surf.fill((0, 0, 0, 0))
                pygame.draw.circle(self._glow_surf, (*self.COLORS['glow_green'], int(alpha * 0.5)),
                                 (15, 15), size * 2)
                pygame.draw.circle(self._glow_surf, (220, 255, 200, alpha),
                                 (15, 15), size)

                screen.blit(self._glow_surf, (int(fly['x'] - 15), int(fly['y'] - 15)))

    def _draw_inner_border(self, screen):
        """게임 영역 테두리"""
        margin = 4
        rect = pygame.Rect(self.game_x - margin, self.game_y - margin,
                          self.game_width + margin * 2, self.game_height + margin * 2)

        for i in range(3):
            pygame.draw.rect(screen, (*self.COLORS['shadow'], 60 - i * 18),
                           rect.inflate(i * 2, i * 2), 2)

    def resize(self, screen_width, screen_height, game_width, game_height):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        self._generate_all_elements()
        self._init_particles()
        self._create_all_caches()

        # 재사용 서피스 재생성
        self._glow_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
        self._leaf_surf = pygame.Surface((50, 30), pygame.SRCALPHA)


# ============================================================================
# 원숭이-바나나 이벤트 시스템 (스테이지 2)
# ============================================================================

# 사운드 재생 콜백 (pingfighter.py에서 설정)
_throwing_banana_sound = None
_step_banana_sound = None

def set_throwing_banana_sound(sound):
    """바나나 던지기 사운드 설정 (pingfighter.py에서 호출)"""
    global _throwing_banana_sound
    _throwing_banana_sound = sound

def set_step_banana_sound(sound):
    """바나나 밟기 사운드 설정 (pingfighter.py에서 호출)"""
    global _step_banana_sound
    _step_banana_sound = sound

def play_throwing_banana_sound():
    """바나나 던지기 사운드 재생"""
    if _throwing_banana_sound:
        try:
            _throwing_banana_sound.play()
        except Exception as e:
            print(f"[MonkeyEvent] 사운드 재생 오류: {e}")

def play_step_banana_sound():
    """바나나 밟기 사운드 재생"""
    if _step_banana_sound:
        try:
            _step_banana_sound.play()
        except Exception as e:
            print(f"[MonkeyEvent] 사운드 재생 오류: {e}")


class JungleMonkey:
    """정글 나무에서 바나나를 던지는 원숭이"""

    # 원숭이 색상
    COLORS = {
        'body_dark': (101, 67, 33),      # 어두운 갈색
        'body_mid': (139, 90, 43),       # 중간 갈색
        'body_light': (160, 110, 60),    # 밝은 갈색
        'face': (210, 170, 135),         # 얼굴 살색
        'face_dark': (180, 140, 105),    # 얼굴 어두운 부분 / 손바닥
        'eyes': (20, 20, 20),            # 눈
        'eye_white': (255, 255, 255),    # 눈 흰자
        'nose': (80, 50, 30),            # 코
        'ear_inner': (200, 150, 120),    # 귀 안쪽
        'palm': (190, 150, 115),         # 손바닥/발바닥
    }

    def __init__(self, tree_data, screen_width, screen_height, game_x, game_y, game_width, game_height):
        """
        tree_data: 정글 나무 데이터 (trunk_points 포함)
        """
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_x = game_x
        self.game_y = game_y
        self.game_width = game_width
        self.game_height = game_height

        # 나무 정보
        self.tree = tree_data
        self.trunk_points = tree_data['trunk_points']

        # 원숭이 상태
        self.state = 'climbing'  # 'climbing', 'sitting', 'throwing', 'leaving'
        self.x = 0
        self.y = 0
        self.target_point_idx = 0
        self.climb_progress = 0.0
        self.climb_speed = 2.4  # 초당 진행률 (2배 속도)

        # 앉아있을 위치 (나무 중간~상단)
        self.sit_point_idx = random.randint(len(self.trunk_points) // 3,
                                            int(len(self.trunk_points) * 0.7))

        # 던지기 관련
        self.throw_timer = 0
        self.throw_delay = random.uniform(1.5, 3.0)  # 앉은 후 던지기까지 대기
        self.has_thrown = False

        # 애니메이션
        self.anim_timer = 0
        self.size = 28  # 원숭이 크기
        self.facing_right = tree_data['x'] < screen_width / 2

        # 시작 위치 (나무 아래)
        if len(self.trunk_points) > 0:
            self.x, self.y, _ = self.trunk_points[0]

        # 바나나 (던질 때 생성)
        self.banana = None

    def update(self, dt):
        """원숭이 업데이트"""
        self.anim_timer += dt

        if self.state == 'climbing':
            # 나무 올라가기
            self.climb_progress += self.climb_speed * dt

            if self.climb_progress >= 1.0:
                # 목표 지점 도달
                self.target_point_idx += 1
                self.climb_progress = 0.0

                if self.target_point_idx >= self.sit_point_idx:
                    # 앉을 위치 도달
                    self.state = 'sitting'
                    self.throw_timer = 0

            # 현재 위치 계산
            if self.target_point_idx < len(self.trunk_points) - 1:
                p1 = self.trunk_points[self.target_point_idx]
                p2 = self.trunk_points[min(self.target_point_idx + 1, len(self.trunk_points) - 1)]
                self.x = p1[0] + (p2[0] - p1[0]) * self.climb_progress
                self.y = p1[1] + (p2[1] - p1[1]) * self.climb_progress

        elif self.state == 'sitting':
            # 앉아서 대기
            self.throw_timer += dt

            if self.throw_timer >= self.throw_delay and not self.has_thrown:
                self.state = 'throwing'
                self.throw_timer = 0

        elif self.state == 'throwing':
            # 바나나 던지기 애니메이션
            self.throw_timer += dt

            if self.throw_timer >= 0.5 and not self.has_thrown:
                # 바나나 생성 및 던지기
                self._throw_banana()
                self.has_thrown = True

            if self.throw_timer >= 1.0:
                # 던진 후 떠나기
                self.state = 'leaving'
                self.climb_progress = 0.0

        elif self.state == 'leaving':
            # 나무에서 내려가기 (빠르게)
            self.climb_progress += self.climb_speed * 1.5 * dt

            if self.climb_progress >= 1.0:
                self.target_point_idx -= 1
                self.climb_progress = 0.0

            if self.target_point_idx < len(self.trunk_points) - 1:
                p1 = self.trunk_points[max(0, self.target_point_idx)]
                p2 = self.trunk_points[max(0, self.target_point_idx - 1)]
                self.x = p1[0] + (p2[0] - p1[0]) * self.climb_progress
                self.y = p1[1] + (p2[1] - p1[1]) * self.climb_progress

        # 바나나 업데이트
        if self.banana:
            self.banana.update(dt)

        return self.state == 'leaving' and self.target_point_idx <= 0

    def _throw_banana(self):
        """바나나 던지기 - 보스 60%, 플레이어 40% 확률"""
        target_x = self.game_x + random.randint(30, self.game_width - 30)

        # 40% 확률로 플레이어, 60% 확률로 보스
        target_player = random.random() < 0.4

        if target_player:
            # 플레이어 진영 (하단) - 인게임 화면 내부 바닥에 떨어지도록
            # 인게임 화면: game_y ~ game_y + game_height
            # 플레이어는 인게임 바닥 근처에 있음
            target_y = self.game_y + self.game_height - 40  # 인게임 화면 내 플레이어가 밟을 수 있는 바닥
        else:
            # 보스 진영 (상단)
            target_y = self.game_y + 50

        self.banana = ThrownBanana(
            self.x, self.y,
            target_x, target_y,
            self.game_x, self.game_y,
            self.game_width, self.game_height,
            target_player=target_player  # 타겟 정보 전달
        )

        # 바나나 던지기 사운드 재생
        play_throwing_banana_sound()

    def get_banana(self):
        """던져진 바나나 반환 (이벤트 매니저에서 관리하기 위해)"""
        banana = self.banana
        self.banana = None
        return banana

    def is_done(self):
        """원숭이가 떠났는지"""
        return self.state == 'leaving' and self.target_point_idx <= 0

    def draw(self, screen):
        """원숭이 그리기 - 뒷모습 (플레이어 시점에서 나무를 타고 있는 모습)"""
        x, y = int(self.x), int(self.y)
        size = self.size

        # 게임 방향 (인게임 화면이 어느 쪽인지)
        game_is_right = self.x < self.game_x + self.game_width / 2
        dir_mult = 1 if game_is_right else -1

        # 클라이밍 애니메이션 프레임 (0~3)
        climb_frame = int(self.anim_timer * 4) % 4

        # 상태별 애니메이션 오프셋
        body_sway = 0
        if self.state == 'climbing' or self.state == 'leaving':
            # 올라가거나 내려갈 때 몸 흔들림
            body_sway = math.sin(self.anim_timer * 6) * 2

        # === 뒷모습 렌더링 ===

        # 꼬리 (먼저 그려서 몸 뒤에 오도록)
        self._draw_tail(screen, x, y, size, dir_mult)

        # 다리 (나무를 감싸는 포즈)
        self._draw_legs_back(screen, x, y, size, climb_frame)

        # 몸통 (등)
        self._draw_body_back(screen, x + int(body_sway), y, size)

        # 팔 (나무를 잡거나 던지는 포즈)
        if self.state == 'throwing':
            self._draw_throwing_arm(screen, x, y, size, dir_mult)
        else:
            self._draw_arms_climbing(screen, x + int(body_sway), y, size, climb_frame)

        # 머리 (상태에 따라 방향 변경)
        if self.state == 'sitting' or self.state == 'throwing':
            # 앉아있거나 던질 때는 고개를 인게임 방향으로 돌림
            self._draw_head_turned(screen, x, y, size, dir_mult)
        else:
            # 올라가거나 내려갈 때는 뒷통수만 보임
            self._draw_head_back(screen, x + int(body_sway), y, size)

    def _draw_body_back(self, screen, x, y, size):
        """등 (뒷모습) 그리기"""
        # 몸통 메인
        body_rect = pygame.Rect(x - size//2, y - size//2, size, int(size * 1.2))
        pygame.draw.ellipse(screen, self.COLORS['body_dark'], body_rect)
        pygame.draw.ellipse(screen, self.COLORS['body_mid'], body_rect.inflate(-4, -4))

        # 등 중앙 라인 (척추 느낌)
        spine_color = self.COLORS['body_dark']
        pygame.draw.line(screen, spine_color,
                        (x, y - size//3), (x, y + size//3), 2)

        # 어깨 근육 표현
        shoulder_y = y - size//3
        pygame.draw.arc(screen, self.COLORS['body_dark'],
                       (x - size//2 - 2, shoulder_y - 5, size + 4, 15),
                       0, 3.14, 3)

    def _draw_head_back(self, screen, x, y, size):
        """뒷통수 그리기"""
        head_y = y - size//2 - size//3
        head_size = int(size * 0.8)

        # 뒷통수
        head_rect = pygame.Rect(x - head_size//2, head_y - head_size//2, head_size, head_size)
        pygame.draw.ellipse(screen, self.COLORS['body_dark'], head_rect)
        pygame.draw.ellipse(screen, self.COLORS['body_mid'], head_rect.inflate(-3, -3))

        # 귀 (양쪽)
        ear_size = head_size // 3
        ear_offset = head_size // 2 - 2
        for side in [-1, 1]:
            ear_x = x + side * ear_offset
            ear_y = head_y
            pygame.draw.circle(screen, self.COLORS['body_mid'], (ear_x, ear_y), ear_size)
            pygame.draw.circle(screen, self.COLORS['ear_inner'], (ear_x, ear_y), ear_size - 3)

        # 뒷머리 털 표현
        for i in range(5):
            angle = math.radians(-30 + i * 15)
            hx = x + int(math.cos(angle) * (head_size // 3))
            hy = head_y - head_size // 3 + int(math.sin(angle) * 3)
            pygame.draw.circle(screen, self.COLORS['body_dark'], (hx, hy), 3)

    def _draw_head_turned(self, screen, x, y, size, dir_mult):
        """고개를 돌린 모습 (3/4 측면) - 인게임 방향을 바라봄"""
        head_y = y - size//2 - size//3
        head_size = int(size * 0.8)

        # 머리 본체 (3/4 측면 - 바라보는 방향으로 약간 이동)
        head_offset = dir_mult * 4
        head_rect = pygame.Rect(x - head_size//2 + head_offset, head_y - head_size//2,
                                head_size, head_size)
        pygame.draw.ellipse(screen, self.COLORS['body_dark'], head_rect)
        pygame.draw.ellipse(screen, self.COLORS['body_mid'], head_rect.inflate(-3, -3))

        # 귀 (양쪽 귀 - 뒤쪽 귀가 조금 보임)
        ear_size = head_size // 3
        # 뒤쪽 귀 (작게)
        back_ear_x = x - dir_mult * (head_size // 2 - 3) + head_offset
        pygame.draw.circle(screen, self.COLORS['body_mid'], (back_ear_x, head_y - 3), ear_size - 2)
        pygame.draw.circle(screen, self.COLORS['ear_inner'], (back_ear_x, head_y - 3), ear_size - 5)
        # 앞쪽 귀 (정상 크기)
        front_ear_x = x + dir_mult * (head_size // 2 - 2) + head_offset
        pygame.draw.circle(screen, self.COLORS['body_mid'], (front_ear_x, head_y - 3), ear_size)
        pygame.draw.circle(screen, self.COLORS['ear_inner'], (front_ear_x, head_y - 3), ear_size - 3)

        # 얼굴 (하트 모양 베이지색 - 바라보는 방향으로 치우침)
        face_offset = dir_mult * 6
        face_w = int(head_size * 0.65)
        face_h = int(head_size * 0.55)
        face_x = x + head_offset + face_offset
        face_y = head_y + 2
        pygame.draw.ellipse(screen, self.COLORS['face'],
                           (face_x - face_w//2, face_y - face_h//2, face_w, face_h))

        # 눈 (가까운 쪽 눈만 보임)
        eye_x = face_x + dir_mult * 2
        eye_y = face_y - 5
        # 눈 흰자 (약간 타원형)
        pygame.draw.ellipse(screen, self.COLORS['eye_white'],
                           (eye_x - 5, eye_y - 4, 10, 8))
        # 눈동자
        pupil_x = eye_x + dir_mult * 1
        pygame.draw.circle(screen, self.COLORS['eyes'], (pupil_x, eye_y), 3)
        # 하이라이트
        pygame.draw.circle(screen, (255, 255, 255), (pupil_x - dir_mult, eye_y - 1), 1)

        # 먼 쪽 눈 (살짝만 보임)
        far_eye_x = face_x - dir_mult * 8
        pygame.draw.ellipse(screen, self.COLORS['eye_white'],
                           (far_eye_x - 3, eye_y - 3, 6, 6))
        pygame.draw.circle(screen, self.COLORS['eyes'], (far_eye_x, eye_y), 2)

        # 코 (얼굴 중앙 아래)
        nose_x = face_x + dir_mult * 4
        nose_y = face_y + 3
        pygame.draw.ellipse(screen, self.COLORS['nose'],
                           (nose_x - 4, nose_y - 2, 8, 5))

        # 입 (작은 미소)
        mouth_x = nose_x - dir_mult * 2
        mouth_y = nose_y + 6
        pygame.draw.arc(screen, self.COLORS['nose'],
                       (mouth_x - 5, mouth_y - 3, 8, 5),
                       3.14, 0, 2)

    def _draw_arms_climbing(self, screen, x, y, size, frame):
        """클라이밍 팔 애니메이션"""
        arm_length = size // 2 + 5
        arm_width = 6

        # 프레임에 따른 팔 위치 (교차 패턴)
        # frame 0: 왼팔 위, 오른팔 아래
        # frame 1: 양팔 중간
        # frame 2: 왼팔 아래, 오른팔 위
        # frame 3: 양팔 중간

        arm_positions = [
            [(-15, -25), (15, 5)],    # frame 0
            [(-12, -10), (12, -10)],  # frame 1
            [(-15, 5), (15, -25)],    # frame 2
            [(-12, -10), (12, -10)],  # frame 3
        ]

        left_end, right_end = arm_positions[frame]

        # 왼팔
        arm_start_l = (x - size//3, y - size//4)
        arm_end_l = (x + left_end[0], y + left_end[1])
        pygame.draw.line(screen, self.COLORS['body_dark'], arm_start_l, arm_end_l, arm_width)
        # 손
        pygame.draw.circle(screen, self.COLORS['body_dark'], arm_end_l, 5)
        pygame.draw.circle(screen, self.COLORS['face_dark'], arm_end_l, 3)

        # 오른팔
        arm_start_r = (x + size//3, y - size//4)
        arm_end_r = (x + right_end[0], y + right_end[1])
        pygame.draw.line(screen, self.COLORS['body_dark'], arm_start_r, arm_end_r, arm_width)
        # 손
        pygame.draw.circle(screen, self.COLORS['body_dark'], arm_end_r, 5)
        pygame.draw.circle(screen, self.COLORS['face_dark'], arm_end_r, 3)

    def _draw_legs_back(self, screen, x, y, size, frame):
        """클라이밍 다리 애니메이션 (뒷모습)"""
        leg_length = size // 2
        leg_width = 6

        # 프레임에 따른 다리 위치 (팔과 반대로)
        leg_positions = [
            [(-10, 20), (10, 35)],   # frame 0
            [(-8, 28), (8, 28)],     # frame 1
            [(-10, 35), (10, 20)],   # frame 2
            [(-8, 28), (8, 28)],     # frame 3
        ]

        left_end, right_end = leg_positions[frame]

        # 왼다리
        leg_start_l = (x - size//4, y + size//3)
        leg_end_l = (x + left_end[0], y + left_end[1])
        pygame.draw.line(screen, self.COLORS['body_dark'], leg_start_l, leg_end_l, leg_width)
        # 발
        pygame.draw.circle(screen, self.COLORS['body_dark'], leg_end_l, 5)

        # 오른다리
        leg_start_r = (x + size//4, y + size//3)
        leg_end_r = (x + right_end[0], y + right_end[1])
        pygame.draw.line(screen, self.COLORS['body_dark'], leg_start_r, leg_end_r, leg_width)
        # 발
        pygame.draw.circle(screen, self.COLORS['body_dark'], leg_end_r, 5)

    def _draw_throwing_arm(self, screen, x, y, size, dir_mult):
        """바나나 던지기 팔 애니메이션"""
        arm_length = size // 2 + 8
        arm_width = 6

        throw_progress = min(1.0, self.throw_timer / 0.5)

        # 던지지 않는 팔 (나무 잡고 있음)
        other_arm_x = x - dir_mult * size // 3
        pygame.draw.line(screen, self.COLORS['body_dark'],
                        (other_arm_x, y - size//4),
                        (other_arm_x - dir_mult * 5, y - size//2 - 10), arm_width)
        pygame.draw.circle(screen, self.COLORS['body_dark'],
                          (other_arm_x - dir_mult * 5, y - size//2 - 10), 5)

        # 던지는 팔 애니메이션
        throw_arm_x = x + dir_mult * size // 3

        if throw_progress < 0.3:
            # 준비 동작: 팔을 뒤로 빼기
            back_progress = throw_progress / 0.3
            arm_angle = -45 - back_progress * 45  # 뒤로
            rad = math.radians(arm_angle)
            arm_end_x = throw_arm_x - dir_mult * int(math.cos(rad) * arm_length)
            arm_end_y = y - size//4 + int(math.sin(rad) * arm_length)
        elif throw_progress < 0.7:
            # 던지기 동작: 앞으로 휘두르기
            swing_progress = (throw_progress - 0.3) / 0.4
            arm_angle = -90 + swing_progress * 150  # 뒤에서 앞으로
            rad = math.radians(arm_angle)
            arm_end_x = throw_arm_x + dir_mult * int(math.cos(rad) * arm_length)
            arm_end_y = y - size//4 + int(math.sin(rad) * arm_length)
        else:
            # 팔로우 스루
            arm_angle = 60
            rad = math.radians(arm_angle)
            arm_end_x = throw_arm_x + dir_mult * int(math.cos(rad) * arm_length * 0.8)
            arm_end_y = y - size//4 + int(math.sin(rad) * arm_length * 0.8)

        # 팔 그리기
        pygame.draw.line(screen, self.COLORS['body_dark'],
                        (throw_arm_x, y - size//4),
                        (arm_end_x, arm_end_y), arm_width)
        # 손
        pygame.draw.circle(screen, self.COLORS['body_dark'], (arm_end_x, arm_end_y), 6)
        pygame.draw.circle(screen, self.COLORS['face_dark'], (arm_end_x, arm_end_y), 4)

        # 손에 바나나 (던지기 전)
        if not self.has_thrown and throw_progress < 0.5:
            self._draw_banana_in_hand(screen, arm_end_x, arm_end_y)

    def _draw_tail(self, screen, x, y, size, dir_mult):
        """꼬리 그리기 (곡선, 흔들림)"""
        tail_points = []
        tail_length = 12
        for i in range(tail_length):
            t = i / (tail_length - 1)
            # 꼬리는 등 뒤로 나와서 옆으로 휘어짐
            tx = x - dir_mult * (5 + t * size * 0.8)
            # S자 곡선 + 흔들림
            wave = math.sin(t * 2.5 + self.anim_timer * 3) * (8 + t * 5)
            ty = y + size//4 + wave + t * 15
            tail_points.append((int(tx), int(ty)))

        if len(tail_points) >= 2:
            # 꼬리 두께 점점 가늘어짐
            for i in range(len(tail_points) - 1):
                thickness = max(2, 5 - i // 3)
                pygame.draw.line(screen, self.COLORS['body_dark'],
                               tail_points[i], tail_points[i+1], thickness)

    def _draw_banana_in_hand(self, screen, x, y):
        """손에 든 바나나 그리기"""
        banana_color = (255, 225, 50)
        # 간단한 바나나 모양
        points = [
            (x - 8, y),
            (x - 4, y - 10),
            (x + 4, y - 12),
            (x + 10, y - 8),
            (x + 8, y),
            (x + 4, y + 4),
            (x - 4, y + 2),
        ]
        pygame.draw.polygon(screen, banana_color, points)
        pygame.draw.polygon(screen, (200, 180, 40), points, 2)


class ThrownBanana:
    """던져진 바나나 (필러에서 인게임으로 날아감)"""

    def __init__(self, start_x, start_y, target_x, target_y, game_x, game_y, game_width, game_height, target_player=True):
        self.x = start_x
        self.y = start_y
        self.start_x = start_x
        self.start_y = start_y
        self.target_x = target_x
        self.target_y = target_y
        self.game_x = game_x
        self.game_y = game_y
        self.game_width = game_width
        self.game_height = game_height

        # 타겟 정보 (True: 플레이어, False: 보스)
        self.target_player = target_player

        # 비행 관련
        self.state = 'flying'  # 'flying', 'landed', 'bursting', 'expired'
        self.flight_progress = 0.0
        self.flight_duration = 1.0  # 1초 동안 날아감
        self.rotation = 0
        self.rotation_speed = 360 * 3  # 초당 3바퀴

        # 착지 후
        self.land_timer = 0
        self.land_duration = 2.0  # 2초 후 사라짐

        # 바나나 크기
        self.size = 48  # 2배 크기

        # 충돌 판정용
        self.rect = pygame.Rect(0, 0, self.size, self.size // 2)

        # 미끄러짐 효과 적용 여부 (플레이어용, 보스용 분리)
        self.slip_triggered = False
        self.boss_slip_triggered = False

        # 터지는 효과용 파티클
        self.burst_particles = []
        self.burst_timer = 0
        self.burst_duration = 0.4  # 터지는 애니메이션 지속 시간

    def update(self, dt):
        """바나나 업데이트"""
        if self.state == 'flying':
            self.flight_progress += dt / self.flight_duration
            self.rotation += self.rotation_speed * dt

            if self.flight_progress >= 1.0:
                self.flight_progress = 1.0
                self.state = 'landed'
                self.x = self.target_x
                self.y = self.target_y
            else:
                # 포물선 운동
                t = self.flight_progress
                # X: 선형 보간
                self.x = self.start_x + (self.target_x - self.start_x) * t
                # Y: 포물선 (위로 올라갔다 내려옴)
                arc_height = -200  # 최대 높이
                self.y = self.start_y + (self.target_y - self.start_y) * t + arc_height * 4 * t * (1 - t)

        elif self.state == 'landed':
            self.land_timer += dt
            if self.land_timer >= self.land_duration:
                self.state = 'expired'

        elif self.state == 'bursting':
            # 터지는 애니메이션 업데이트
            self.burst_timer += dt
            # 파티클 업데이트
            for p in self.burst_particles:
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt
                p['vy'] += 300 * dt  # 중력
                p['life'] -= dt
            # 죽은 파티클 제거
            self.burst_particles = [p for p in self.burst_particles if p['life'] > 0]
            # 애니메이션 종료
            if self.burst_timer >= self.burst_duration:
                self.state = 'expired'

        # 충돌 박스 업데이트
        self.rect.center = (int(self.x), int(self.y))

        return self.state == 'expired'

    def trigger_burst(self):
        """바나나 터지기 시작"""
        if self.state == 'landed':
            self.state = 'bursting'
            self.burst_timer = 0
            self._create_burst_particles()

    def _create_burst_particles(self):
        """터지는 파티클 생성"""
        # 바나나 조각 색상들
        colors = [
            (255, 225, 50),   # 밝은 노랑
            (227, 189, 52),   # 중간 노랑
            (198, 156, 41),   # 어두운 노랑
            (255, 255, 200),  # 바나나 속 흰색
            (139, 90, 43),    # 꼭지 갈색
        ]
        # 12~16개 파티클 생성
        num_particles = random.randint(12, 16)
        for i in range(num_particles):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(80, 200)
            self.burst_particles.append({
                'x': self.x,
                'y': self.y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 100,  # 위로 튀어오름
                'size': random.randint(3, 8),
                'color': random.choice(colors),
                'life': random.uniform(0.2, 0.4),
                'rotation': random.uniform(0, 360),
                'rot_speed': random.uniform(-500, 500),
            })

    def is_landed(self):
        """바닥에 떨어졌는지"""
        return self.state == 'landed'

    def is_expired(self):
        """사라졌는지"""
        return self.state == 'expired'

    def check_player_collision(self, player_rect):
        """플레이어와 충돌 체크"""
        if self.state == 'landed' and not self.slip_triggered and player_rect is not None:
            # 플레이어 rect는 인게임 좌표 (0~game_width)
            # 바나나는 전체 화면 좌표 (game_x 기준)
            # 플레이어 좌표를 전체 화면 좌표로 변환
            player_screen_rect = pygame.Rect(
                player_rect.x + self.game_x,
                player_rect.y + self.game_y,
                player_rect.width,
                player_rect.height
            )

            # 바나나가 바닥에 있고, 플레이어가 밟으면
            banana_ground_rect = pygame.Rect(
                self.x - self.size,
                self.y - 10,
                self.size * 2,
                20
            )
            if player_screen_rect.colliderect(banana_ground_rect):
                self.slip_triggered = True
                self.trigger_burst()  # 바나나 터지기!
                play_step_banana_sound()  # 바나나 밟기 사운드 재생
                print(f"[MonkeyEvent] 🍌 바나나 밟음! 플레이어 위치: ({player_rect.centerx})")
                return True
        return False

    def check_boss_collision(self, boss_rect):
        """보스와 충돌 체크"""
        if self.state == 'landed' and not self.boss_slip_triggered and boss_rect is not None:
            # 보스 rect는 인게임 좌표 (0~game_width)
            # 바나나는 전체 화면 좌표 (game_x 기준)
            # 보스 좌표를 전체 화면 좌표로 변환
            boss_screen_rect = pygame.Rect(
                boss_rect.x + self.game_x,
                boss_rect.y + self.game_y,
                boss_rect.width,
                boss_rect.height
            )

            # 바나나가 바닥에 있고, 보스가 밟으면
            banana_ground_rect = pygame.Rect(
                self.x - self.size,
                self.y - 10,
                self.size * 2,
                20
            )
            if boss_screen_rect.colliderect(banana_ground_rect):
                self.boss_slip_triggered = True
                self.trigger_burst()  # 바나나 터지기!
                play_step_banana_sound()  # 바나나 밟기 사운드 재생
                print(f"[MonkeyEvent] 🍌 보스가 바나나 밟음! 보스 위치: ({boss_rect.centerx})")
                return True
        return False

    def is_target_player(self):
        """플레이어가 타겟인지"""
        return self.target_player

    def is_target_boss(self):
        """보스가 타겟인지"""
        return not self.target_player

    def _create_banana_surface(self):
        """현실감 있는 픽셀 아트 바나나 서피스 생성"""
        surf_size = self.size * 2
        banana_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)

        # 투명도 계산
        if self.state == 'landed':
            alpha = 255 - int((self.land_timer / self.land_duration) * 100)
            if self.land_timer > self.land_duration * 0.7:
                if int(self.land_timer * 10) % 2 == 0:
                    alpha = 100
        else:
            alpha = 255

        # 바나나 색상 팔레트 (실제 바나나 색상)
        colors = {
            'stem_dark': (101, 67, 33),       # 꼭지 어두운 갈색
            'stem_mid': (139, 90, 43),        # 꼭지 중간 갈색
            'stem_green': (154, 165, 67),     # 꼭지 녹색
            'tip_dark': (89, 60, 31),         # 끝부분 어두운 갈색
            'tip_mid': (51, 41, 28),          # 끝부분 검은 갈색
            'peel_dark': (198, 156, 41),      # 껍질 어두운 노랑
            'peel_mid': (227, 189, 52),       # 껍질 중간 노랑
            'peel_light': (247, 220, 89),     # 껍질 밝은 노랑
            'peel_highlight': (255, 239, 143),# 껍질 하이라이트
            'shadow': (178, 134, 32),         # 그림자
            'spots': (139, 105, 45),          # 바나나 반점 (익은 부분)
        }

        # 바나나 크기 스케일
        scale = self.size / 24  # 기본 24px 기준

        # 픽셀 단위로 바나나 그리기 (초승달 곡선 형태)
        cx, cy = surf_size // 2, surf_size // 2

        # 바나나 본체 - 부드러운 곡선 (왼쪽 위에서 오른쪽 아래로)
        # 메인 바디 포인트 (곡선 형태)
        body_points = []
        for i in range(20):
            t = i / 19
            # 곡선 방정식 (초승달 형태)
            x = cx - 10 * scale + t * 20 * scale
            # 위쪽 곡선
            curve_top = -8 * scale * math.sin(t * math.pi)
            # 아래쪽은 덜 굽음
            y = cy + curve_top
            body_points.append((x, y))

        # 아래쪽 곡선 (역순)
        for i in range(19, -1, -1):
            t = i / 19
            x = cx - 10 * scale + t * 20 * scale
            curve_bottom = -4 * scale * math.sin(t * math.pi) + 5 * scale
            y = cy + curve_bottom
            body_points.append((x, y))

        # 메인 바디 그리기 (그라데이션 효과)
        if len(body_points) >= 3:
            # 그림자 레이어
            pygame.draw.polygon(banana_surf, colors['shadow'], body_points)

            # 메인 색상
            inner_points = [(p[0], p[1] - 1 * scale) for p in body_points]
            pygame.draw.polygon(banana_surf, colors['peel_mid'], inner_points)

            # 밝은 부분 (상단)
            highlight_points = []
            for i in range(10):
                t = i / 9
                x = cx - 8 * scale + t * 16 * scale
                y = cy - 6 * scale * math.sin(t * math.pi) - 1 * scale
                highlight_points.append((x, y))
            for i in range(9, -1, -1):
                t = i / 9
                x = cx - 8 * scale + t * 16 * scale
                y = cy - 4 * scale * math.sin(t * math.pi) + 1 * scale
                highlight_points.append((x, y))

            if len(highlight_points) >= 3:
                pygame.draw.polygon(banana_surf, colors['peel_light'], highlight_points)

            # 최상단 하이라이트 (빛 반사)
            top_highlight = []
            for i in range(8):
                t = i / 7
                x = cx - 6 * scale + t * 12 * scale
                y = cy - 5 * scale * math.sin(t * math.pi) - 2 * scale
                top_highlight.append((x, y))
            for i in range(7, -1, -1):
                t = i / 7
                x = cx - 6 * scale + t * 12 * scale
                y = cy - 3 * scale * math.sin(t * math.pi)
                top_highlight.append((x, y))

            if len(top_highlight) >= 3:
                pygame.draw.polygon(banana_surf, colors['peel_highlight'], top_highlight)

        # 왼쪽 꼭지 (줄기)
        stem_x = cx - 11 * scale
        stem_y = cy - 2 * scale
        # 녹색 부분
        pygame.draw.ellipse(banana_surf, colors['stem_green'],
                           (stem_x - 3 * scale, stem_y - 2 * scale, 5 * scale, 4 * scale))
        # 갈색 꼭지
        pygame.draw.rect(banana_surf, colors['stem_dark'],
                        (stem_x - 4 * scale, stem_y - 4 * scale, 3 * scale, 3 * scale))
        pygame.draw.rect(banana_surf, colors['stem_mid'],
                        (stem_x - 3 * scale, stem_y - 3 * scale, 2 * scale, 2 * scale))

        # 오른쪽 끝 (검은 부분)
        tip_x = cx + 10 * scale
        tip_y = cy + 2 * scale
        pygame.draw.ellipse(banana_surf, colors['tip_dark'],
                           (tip_x - 2 * scale, tip_y - 2 * scale, 4 * scale, 3 * scale))
        pygame.draw.ellipse(banana_surf, colors['tip_mid'],
                           (tip_x, tip_y - 1 * scale, 2 * scale, 2 * scale))

        # 바나나 반점 (익은 느낌) - 랜덤 위치에 작은 점들
        random.seed(42)  # 일관된 반점 패턴
        for _ in range(3):
            spot_t = random.uniform(0.3, 0.7)
            spot_x = cx - 6 * scale + spot_t * 12 * scale
            spot_y = cy - 2 * scale * math.sin(spot_t * math.pi) + random.uniform(-2, 2) * scale
            spot_size = random.uniform(1, 2) * scale
            pygame.draw.circle(banana_surf, colors['spots'],
                             (int(spot_x), int(spot_y)), int(spot_size))
        random.seed()  # 시드 리셋 (다른 랜덤 로직에 영향 방지)

        # 투명도 적용
        if alpha < 255:
            banana_surf.set_alpha(alpha)

        return banana_surf

    def is_in_game_area(self):
        """바나나가 인게임 영역 안에 있는지"""
        return (self.x >= self.game_x and
                self.x <= self.game_x + self.game_width and
                self.y >= self.game_y and
                self.y <= self.game_y + self.game_height)

    def draw(self, screen):
        """바나나 그리기 (필러 화면용 - 전체 화면 좌표)"""
        if self.state == 'expired':
            return

        x, y = int(self.x), int(self.y)

        # 터지는 상태면 파티클만 그림
        if self.state == 'bursting':
            self._draw_burst_particles(screen, 0, 0)  # 필러 좌표계 (오프셋 없음)
            return

        banana_surf = self._create_banana_surface()

        # 회전 적용 (날아갈 때만)
        if self.state == 'flying':
            rotated = pygame.transform.rotate(banana_surf, self.rotation)
            rect = rotated.get_rect(center=(x, y))
            screen.blit(rotated, rect)
        else:
            # 바닥에 있을 때는 회전 없이
            rect = banana_surf.get_rect(center=(x, y))
            screen.blit(banana_surf, rect)

        # 그림자 (바닥에 있을 때)
        if self.state == 'landed':
            shadow_surf = pygame.Surface((self.size * 2, 10), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40),
                              (0, 0, self.size * 2, 10))
            screen.blit(shadow_surf, (x - self.size, y + 5))

    def draw_ingame(self, screen):
        """바나나 그리기 (인게임 화면용 - 인게임 좌표로 변환)"""
        if self.state == 'expired':
            return

        # 터지는 상태면 파티클만 그림 (인게임 좌표계)
        if self.state == 'bursting':
            self._draw_burst_particles(screen, -self.game_x, -self.game_y)
            return

        # 인게임 영역 밖이면 그리지 않음
        if not self.is_in_game_area():
            return

        # 전체 화면 좌표 -> 인게임 좌표 변환
        ingame_x = int(self.x - self.game_x)
        ingame_y = int(self.y - self.game_y)

        banana_surf = self._create_banana_surface()

        # 회전 적용 (날아갈 때만)
        if self.state == 'flying':
            rotated = pygame.transform.rotate(banana_surf, self.rotation)
            rect = rotated.get_rect(center=(ingame_x, ingame_y))
            screen.blit(rotated, rect)
        else:
            # 바닥에 있을 때는 회전 없이
            rect = banana_surf.get_rect(center=(ingame_x, ingame_y))
            screen.blit(banana_surf, rect)

        # 그림자 (바닥에 있을 때)
        if self.state == 'landed':
            shadow_surf = pygame.Surface((self.size * 2, 10), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40),
                              (0, 0, self.size * 2, 10))
            screen.blit(shadow_surf, (ingame_x - self.size, ingame_y + 5))

    def _draw_burst_particles(self, screen, offset_x, offset_y):
        """터지는 파티클 그리기"""
        for p in self.burst_particles:
            px = int(p['x'] + offset_x)
            py = int(p['y'] + offset_y)
            size = p['size']
            alpha = int(255 * (p['life'] / 0.4))  # 점점 투명해짐
            color = p['color']

            # 파티클 서피스 생성
            particle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)

            # 불규칙한 바나나 조각 모양 그리기
            if size > 5:
                # 큰 조각: 불규칙한 다각형
                points = []
                num_points = random.randint(4, 6)
                for i in range(num_points):
                    angle = (i / num_points) * math.pi * 2 + p['rotation'] * 0.01
                    r = size * random.uniform(0.6, 1.0)
                    points.append((
                        size + int(math.cos(angle) * r),
                        size + int(math.sin(angle) * r)
                    ))
                pygame.draw.polygon(particle_surf, (*color, alpha), points)
            else:
                # 작은 조각: 원형
                pygame.draw.circle(particle_surf, (*color, alpha), (size, size), size)

            screen.blit(particle_surf, (px - size, py - size))


class MonkeyBananaEventManager:
    """원숭이-바나나 이벤트 관리자"""

    def __init__(self, pillar_bg):
        """
        pillar_bg: MossyStoneFrame 인스턴스
        """
        self.pillar_bg = pillar_bg

        # 이벤트 타이머
        self.event_timer = 0
        self.next_event_time = random.uniform(5, 10)  # 첫 번째는 5~10초 후 등장

        # 활성 원숭이들
        self.active_monkeys = []

        # 바닥에 있는 바나나들
        self.landed_bananas = []

        # 플레이어 미끄러짐 효과
        self.player_slip_active = False
        self.player_slip_timer = 0
        self.player_slip_duration = 0.8  # 0.8초 미끄러짐
        self.player_slip_direction = 0  # -1: 왼쪽, 1: 오른쪽
        self.player_slip_speed = 15  # 미끄러짐 속도
        self.player_wall_slip = False  # 벽까지 미끄러지는 대쉬 슬립
        self.player_wall_slip_speed = 25  # 벽까지 미끄러지는 속도

        # 보스 미끄러짐 효과
        self.boss_slip_active = False
        self.boss_slip_timer = 0
        self.boss_slip_duration = 1.0  # 1.0초 미끄러짐 (통제불능)
        self.boss_slip_direction = 0  # -1: 왼쪽, 1: 오른쪽
        self.boss_slip_speed = 20  # 미끄러짐 속도 (더 강하게)

    def update(self, dt, player_rect=None, boss_rect=None, player_dash_dir=0, boss_move_dir=0, player_in_smoke=False):
        """이벤트 업데이트

        Args:
            dt: 델타 타임
            player_rect: 플레이어 위치
            boss_rect: 보스 위치
            player_dash_dir: 플레이어 대쉬 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
            boss_move_dir: 보스 이동 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
            player_in_smoke: 플레이어가 연막 안에 있는지 (연막탄/테크니컬조끼)
        """
        # 이벤트 타이머
        self.event_timer += dt

        if self.event_timer >= self.next_event_time:
            print(f"[MonkeyEvent] 타이머 완료! dt={dt:.3f}, timer={self.event_timer:.1f}s")
            self._spawn_monkey()
            self.event_timer = 0
            self.next_event_time = random.uniform(15, 30)

        # 원숭이들 업데이트
        for monkey in self.active_monkeys[:]:
            is_done = monkey.update(dt)

            # 던져진 바나나 수집
            banana = monkey.get_banana()
            if banana:
                self.landed_bananas.append(banana)

            # 완료된 원숭이 제거
            if is_done:
                self.active_monkeys.remove(monkey)

        # 바나나들 업데이트
        for banana in self.landed_bananas[:]:
            is_expired = banana.update(dt)

            # 플레이어 충돌 체크 (연막 안에 있으면 면역)
            if player_rect and banana.check_player_collision(player_rect):
                if player_in_smoke:
                    # 연막 안에 있으면 미끄러짐 면역 - 바나나만 터뜨림
                    print("[MonkeyEvent] 🌫️ 연막 보호! 바나나 미끄러짐 무효화")
                else:
                    self._trigger_player_slip(player_rect, player_dash_dir)

            # 보스 충돌 체크
            if boss_rect and banana.check_boss_collision(boss_rect):
                self._trigger_boss_slip(boss_rect, boss_move_dir)

            # 만료된 바나나 제거
            if is_expired:
                self.landed_bananas.remove(banana)

        # 플레이어 미끄러짐 효과 업데이트
        if self.player_slip_active:
            self.player_slip_timer += dt
            if self.player_slip_timer >= self.player_slip_duration:
                self.player_slip_active = False
                self.player_slip_timer = 0
                self.player_wall_slip = False  # 벽 슬립도 종료

        # 보스 미끄러짐 효과 업데이트
        if self.boss_slip_active:
            self.boss_slip_timer += dt
            if self.boss_slip_timer >= self.boss_slip_duration:
                self.boss_slip_active = False
                self.boss_slip_timer = 0

        return self.get_slip_offset() if self.player_slip_active else 0

    def _spawn_monkey(self):
        """원숭이 스폰"""
        if not self.pillar_bg or not hasattr(self.pillar_bg, 'jungle_trees'):
            print("[MonkeyEvent] pillar_bg 또는 jungle_trees 없음")
            return

        trees = self.pillar_bg.jungle_trees
        if not trees:
            print("[MonkeyEvent] 나무 없음")
            return

        # 랜덤 나무 선택
        tree = random.choice(trees)

        # 원숭이 생성
        monkey = JungleMonkey(
            tree,
            self.pillar_bg.screen_width,
            self.pillar_bg.screen_height,
            self.pillar_bg.game_x,
            self.pillar_bg.game_y,
            self.pillar_bg.game_width,
            self.pillar_bg.game_height
        )

        self.active_monkeys.append(monkey)
        print(f"[MonkeyEvent] 🐵 원숭이 스폰! 나무 위치: ({tree['x']:.0f}), 총 원숭이 수: {len(self.active_monkeys)}")

    def _trigger_player_slip(self, player_rect, dash_dir=0):
        """플레이어 미끄러짐 효과 트리거

        Args:
            player_rect: 플레이어 위치
            dash_dir: 대쉬 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        """
        self.player_slip_active = True
        self.player_slip_timer = 0

        # 대쉬 중이면 대쉬 방향으로 벽까지 미끄러짐
        if dash_dir != 0:
            self.player_wall_slip = True
            self.player_slip_direction = dash_dir
            self.player_slip_duration = 1.2  # 벽까지 미끄러지는 시간 증가
            print(f"[MonkeyEvent] 🍌💨 대쉬 중 바나나! 벽까지 미끄러짐! 방향: {'←' if dash_dir < 0 else '→'}")
        else:
            self.player_wall_slip = False
            self.player_slip_duration = 0.8  # 일반 미끄러짐
            # 미끄러지는 방향 결정 (플레이어 위치에 따라)
            center_x = self.pillar_bg.game_x + self.pillar_bg.game_width // 2
            if player_rect.centerx < center_x:
                self.player_slip_direction = -1  # 왼쪽으로 미끄러짐
            else:
                self.player_slip_direction = 1   # 오른쪽으로 미끄러짐

    def _trigger_boss_slip(self, boss_rect, boss_move_dir=0):
        """보스 미끄러짐 효과 트리거 (통제불능 상태)

        Args:
            boss_rect: 보스 위치
            boss_move_dir: 보스 이동 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        """
        self.boss_slip_active = True
        self.boss_slip_timer = 0

        # 미끄러지는 방향 결정
        if boss_move_dir != 0:
            # 보스가 이동 중이면 이동 방향으로 미끄러짐
            self.boss_slip_direction = boss_move_dir
        else:
            # 정지 상태면 위치 기반으로 방향 결정
            center_x = self.pillar_bg.game_x + self.pillar_bg.game_width // 2
            if boss_rect.centerx < center_x:
                self.boss_slip_direction = -1  # 왼쪽으로 미끄러짐
            else:
                self.boss_slip_direction = 1   # 오른쪽으로 미끄러짐

        print(f"[MonkeyEvent] 🍌🤖 보스 통제불능! 방향: {'←' if self.boss_slip_direction < 0 else '→'}")

    def get_slip_offset(self):
        """현재 플레이어 미끄러짐 오프셋 반환"""
        if not self.player_slip_active:
            return 0

        # 미끄러짐 강도 (시작할 때 강하고 점점 약해짐)
        progress = self.player_slip_timer / self.player_slip_duration
        strength = 1.0 - progress  # 1.0 -> 0.0

        # 벽까지 미끄러지는 경우 더 빠른 속도
        if self.player_wall_slip:
            return self.player_slip_direction * self.player_wall_slip_speed * strength
        else:
            return self.player_slip_direction * self.player_slip_speed * strength

    def is_wall_slipping(self):
        """플레이어가 벽까지 미끄러지는 중인지"""
        return self.player_wall_slip and self.player_slip_active

    def get_boss_slip_offset(self):
        """현재 보스 미끄러짐 오프셋 반환"""
        if not self.boss_slip_active:
            return 0

        # 미끄러짐 강도 (시작할 때 강하고 점점 약해짐)
        progress = self.boss_slip_timer / self.boss_slip_duration
        strength = 1.0 - progress  # 1.0 -> 0.0

        return self.boss_slip_direction * self.boss_slip_speed * strength

    def is_player_slipping(self):
        """플레이어가 미끄러지고 있는지"""
        return self.player_slip_active

    def is_boss_slipping(self):
        """보스가 미끄러지고 있는지"""
        return self.boss_slip_active

    def draw(self, screen):
        """이벤트 요소들 그리기 (필러 화면용)"""
        # 원숭이들 그리기
        for monkey in self.active_monkeys:
            monkey.draw(screen)

        # 바나나들 그리기
        for banana in self.landed_bananas:
            banana.draw(screen)

    def draw_ingame(self, screen):
        """인게임 영역 안의 바나나만 그리기 (인게임 화면용)"""
        for banana in self.landed_bananas:
            banana.draw_ingame(screen)

    def reset(self):
        """이벤트 리셋"""
        self.event_timer = 0
        self.next_event_time = random.uniform(15, 30)
        self.active_monkeys.clear()
        self.landed_bananas.clear()
        self.player_slip_active = False
        self.player_slip_timer = 0
        self.player_wall_slip = False
        self.boss_slip_active = False
        self.boss_slip_timer = 0


# 호환성 별칭
JungleSwampBackground = MossyStoneFrame
Stage2PillarBackground = MossyStoneFrame
TropicalLeafFrame = MossyStoneFrame

# 전역 인스턴스
_jungle_bg_instance = None
_monkey_event_manager = None


def init_jungle_background(screen_width, screen_height, game_width, game_height):
    global _jungle_bg_instance, _monkey_event_manager
    _jungle_bg_instance = MossyStoneFrame(screen_width, screen_height, game_width, game_height)
    _monkey_event_manager = MonkeyBananaEventManager(_jungle_bg_instance)
    return _jungle_bg_instance


def get_jungle_background():
    return _jungle_bg_instance


def get_monkey_event_manager():
    """원숭이-바나나 이벤트 매니저 반환"""
    global _monkey_event_manager
    return _monkey_event_manager


def reset_monkey_event():
    """원숭이 이벤트 리셋"""
    global _monkey_event_manager
    if _monkey_event_manager:
        _monkey_event_manager.reset()
