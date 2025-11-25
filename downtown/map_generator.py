# downtown/map_generator.py
# 번화가 맵 랜덤 생성 시스템

import pygame
import random
import math
from .constants import (
    MAP_WIDTH, MAP_HEIGHT, TILE_SIZE,
    TileType, BuildingType, BUILDING_INFO,
    Colors, PlanetTheme, PLANET_THEMES
)

class DowntownMap:
    """
    번화가 맵 생성 및 관리 (세로형 - 아래에서 위로 이동)
    - 랜덤 지형 생성
    - 건물 배치
    - 세로형 도로 생성
    - 충돌 처리
    """

    def __init__(self, stage_number=1, seed=None):
        self.stage_number = stage_number
        self.seed = seed if seed else random.randint(0, 999999)
        random.seed(self.seed)

        # 맵 데이터 (세로형: 15x18 타일)
        self.width = MAP_WIDTH    # 15 타일 (가로)
        self.height = MAP_HEIGHT  # 18 타일 (세로)
        self.tiles = [[TileType.EMPTY for _ in range(self.width)] for _ in range(self.height)]

        # 건물 데이터
        self.buildings = []  # [(type, x, y, width, height), ...]
        self.building_rects = []  # pygame.Rect 리스트

        # 특수 위치 (세로형: 아래에서 시작 → 위로 출구)
        self.spawn_point = (self.width // 2, self.height - 2)  # 아래쪽 중앙
        self.exit_point = (self.width // 2, 1)                  # 위쪽 중앙

        # 테마
        self.theme = self._select_theme()
        self.theme_data = PLANET_THEMES.get(self.theme, PLANET_THEMES[PlanetTheme.CYBER_CITY])

        # 장식물
        self.decorations = []

        # 맵 생성
        self._generate_map()

    def _select_theme(self):
        """스테이지에 따른 테마 선택"""
        themes = list(PLANET_THEMES.keys())
        # 스테이지마다 다른 테마
        return themes[self.stage_number % len(themes)]

    def _generate_map(self):
        """맵 생성 메인 로직"""
        # 1. 기본 바닥 채우기
        self._fill_ground()

        # 2. 메인 도로 생성
        self._generate_roads()

        # 3. 건물 배치
        self._place_buildings()

        # 4. 스폰/출구 설정
        self._set_spawn_exit()

        # 5. 장식물 배치
        self._place_decorations()

        # 6. 건물 렉트 생성
        self._create_building_rects()

    def _fill_ground(self):
        """기본 바닥 채우기"""
        for y in range(self.height):
            for x in range(self.width):
                # 가장자리는 빈 공간
                if x == 0 or x == self.width - 1 or y == 0 or y == self.height - 1:
                    self.tiles[y][x] = TileType.EMPTY
                else:
                    self.tiles[y][x] = TileType.GROUND

    def _generate_roads(self):
        """세로형 도로 생성 (아래→위 메인 도로)"""
        pattern = random.choice(['vertical_main', 'y_shape', 'ladder', 'zigzag'])

        if pattern == 'vertical_main':
            self._generate_vertical_main_road()
        elif pattern == 'y_shape':
            self._generate_y_road()
        elif pattern == 'ladder':
            self._generate_ladder_road()
        else:
            self._generate_zigzag_road()

    def _generate_vertical_main_road(self):
        """세로 메인 도로 (중앙)"""
        mid_x = self.width // 2

        # 세로 메인 도로 (아래→위)
        for y in range(2, self.height - 1):
            self.tiles[y][mid_x] = TileType.ROAD
            self.tiles[y][mid_x - 1] = TileType.ROAD

        # 양쪽 가로 연결 도로
        for x in range(2, self.width - 2):
            self.tiles[4][x] = TileType.ROAD          # 위쪽 가로
            self.tiles[self.height // 2][x] = TileType.ROAD  # 중간 가로
            self.tiles[self.height - 4][x] = TileType.ROAD   # 아래쪽 가로

    def _generate_y_road(self):
        """Y자 도로 (아래에서 위로 갈라짐)"""
        mid_x = self.width // 2

        # 아래쪽 세로 도로 (하나)
        for y in range(self.height - 2, self.height // 2, -1):
            self.tiles[y][mid_x] = TileType.ROAD

        # 중간에서 위쪽으로 갈라짐
        for y in range(self.height // 2, 1, -1):
            # 왼쪽 길
            left_x = mid_x - (self.height // 2 - y) // 2 - 1
            if 2 <= left_x < self.width - 2:
                self.tiles[y][left_x] = TileType.ROAD
            # 오른쪽 길
            right_x = mid_x + (self.height // 2 - y) // 2 + 1
            if 2 <= right_x < self.width - 2:
                self.tiles[y][right_x] = TileType.ROAD
            # 중앙 연결
            self.tiles[y][mid_x] = TileType.ROAD

    def _generate_ladder_road(self):
        """사다리 도로 (세로 2개 + 가로 연결)"""
        left_x = 3
        right_x = self.width - 4

        # 양쪽 세로 도로
        for y in range(2, self.height - 1):
            self.tiles[y][left_x] = TileType.ROAD
            self.tiles[y][right_x] = TileType.ROAD

        # 가로 연결 (사다리 가로대)
        for y in [3, 6, 9, 12, 15]:
            if y < self.height - 2:
                for x in range(left_x, right_x + 1):
                    self.tiles[y][x] = TileType.ROAD

    def _generate_zigzag_road(self):
        """지그재그 도로"""
        mid_x = self.width // 2

        # 아래에서 위로 지그재그
        current_x = mid_x
        direction = 1  # 1: 오른쪽, -1: 왼쪽

        for y in range(self.height - 2, 1, -1):
            self.tiles[y][current_x] = TileType.ROAD

            # 일정 간격으로 방향 전환
            if y % 4 == 0:
                # 가로 연결
                target_x = current_x + direction * 3
                target_x = max(3, min(self.width - 4, target_x))
                for x in range(min(current_x, target_x), max(current_x, target_x) + 1):
                    self.tiles[y][x] = TileType.ROAD
                current_x = target_x
                direction *= -1  # 방향 전환

    def _place_buildings(self):
        """건물 배치"""
        self.buildings.clear()

        # 필수 건물 (항상 등장)
        required_buildings = [BuildingType.SHOP]

        # 스테이지에 따른 추가 필수 건물
        if self.stage_number >= 2:
            required_buildings.append(BuildingType.BLACKSMITH)
        if self.stage_number >= 3:
            required_buildings.append(BuildingType.ELDER)

        # 선택적 건물 (확률에 따라)
        optional_buildings = []
        for btype, info in BUILDING_INFO.items():
            if btype not in required_buildings:
                if random.random() < info["rarity"]:
                    optional_buildings.append(btype)

        # 최대 건물 수 제한 (세로형 화면과 건물 간격을 고려하여 축소)
        max_buildings = min(3 + self.stage_number // 3, 5)
        all_buildings = required_buildings + optional_buildings[:max_buildings - len(required_buildings)]
        random.shuffle(all_buildings)

        # 건물 배치 시도
        for btype in all_buildings:
            self._try_place_building(btype)

    def _try_place_building(self, building_type, max_attempts=50):
        """건물 배치 시도"""
        info = BUILDING_INFO[building_type]
        bw, bh = info["size"]

        for _ in range(max_attempts):
            # 랜덤 위치 (도로에서 약간 떨어진 곳)
            x = random.randint(2, self.width - bw - 2)
            y = random.randint(2, self.height - bh - 2)

            # 배치 가능 여부 확인
            if self._can_place_building(x, y, bw, bh):
                self._place_single_building(building_type, x, y, bw, bh)
                return True

        return False

    def _can_place_building(self, x, y, width, height):
        """건물 배치 가능 여부"""
        # 범위 체크
        if x < 1 or y < 1 or x + width >= self.width - 1 or y + height >= self.height - 1:
            return False

        # 타일 체크 (바닥이어야 함)
        for dy in range(height):
            for dx in range(width):
                tile = self.tiles[y + dy][x + dx]
                if tile != TileType.GROUND:
                    return False

        # 기존 건물과 겹침 체크 (캐릭터가 지나갈 수 있도록 충분한 간격 확보)
        # 캐릭터 크기 191px을 고려하여 6타일(240px) 간격 확보
        building_spacing = TILE_SIZE * 6  # 240px 간격
        new_rect = pygame.Rect(x * TILE_SIZE, y * TILE_SIZE,
                              width * TILE_SIZE, height * TILE_SIZE)
        for _, bx, by, bw, bh in self.buildings:
            existing_rect = pygame.Rect(bx * TILE_SIZE, by * TILE_SIZE,
                                        bw * TILE_SIZE, bh * TILE_SIZE)
            if new_rect.colliderect(existing_rect.inflate(building_spacing, building_spacing)):
                return False

        # 도로 인접 체크 (건물은 도로에 인접해야 함)
        adjacent_to_road = False
        for dy in range(-1, height + 1):
            for dx in range(-1, width + 1):
                check_x = x + dx
                check_y = y + dy
                if 0 <= check_x < self.width and 0 <= check_y < self.height:
                    if self.tiles[check_y][check_x] == TileType.ROAD:
                        adjacent_to_road = True
                        break
            if adjacent_to_road:
                break

        return adjacent_to_road

    def _place_single_building(self, building_type, x, y, width, height):
        """단일 건물 배치"""
        # 타일 업데이트
        for dy in range(height):
            for dx in range(width):
                self.tiles[y + dy][x + dx] = TileType.BUILDING

        # 건물 리스트에 추가
        self.buildings.append((building_type, x, y, width, height))

    def _set_spawn_exit(self):
        """스폰/출구 위치 설정 (세로형: 아래→위)"""
        mid_x = self.width // 2

        # 스폰 위치 (아래쪽 중앙 - 도로 위)
        for x in range(mid_x - 2, mid_x + 3):
            if 0 <= x < self.width:
                y = self.height - 3
                if self.tiles[y][x] == TileType.ROAD:
                    self.spawn_point = (x, y)
                    self.tiles[y][x] = TileType.SPAWN
                    break
        else:
            # 도로가 없으면 중앙에 강제 설정
            self.spawn_point = (mid_x, self.height - 3)
            self.tiles[self.height - 3][mid_x] = TileType.SPAWN

        # 출구 위치 (위쪽 중앙)
        for x in range(mid_x - 2, mid_x + 3):
            if 0 <= x < self.width:
                y = 2
                if self.tiles[y][x] == TileType.ROAD:
                    self.exit_point = (x, y)
                    self.tiles[y][x] = TileType.EXIT
                    break
        else:
            # 도로가 없으면 중앙에 강제 설정
            self.exit_point = (mid_x, 2)
            self.tiles[2][mid_x] = TileType.EXIT

    def _place_decorations(self):
        """장식물 배치"""
        self.decorations.clear()

        decoration_types = ['lamp', 'tree', 'bench', 'sign', 'barrel', 'crate']

        for y in range(self.height):
            for x in range(self.width):
                if self.tiles[y][x] == TileType.GROUND:
                    # 낮은 확률로 장식물 배치
                    if random.random() < 0.05:
                        dec_type = random.choice(decoration_types)
                        self.decorations.append((dec_type, x, y))
                        self.tiles[y][x] = TileType.DECORATION

    def _create_building_rects(self):
        """건물 충돌 렉트 생성"""
        self.building_rects.clear()
        for btype, x, y, w, h in self.buildings:
            rect = pygame.Rect(x * TILE_SIZE, y * TILE_SIZE,
                              w * TILE_SIZE, h * TILE_SIZE)
            self.building_rects.append((btype, rect))

    def get_tile(self, x, y):
        """타일 좌표로 타일 타입 가져오기"""
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.tiles[y][x]
        return TileType.EMPTY

    def get_tile_at_pixel(self, px, py):
        """픽셀 좌표로 타일 타입 가져오기"""
        tx = int(px // TILE_SIZE)
        ty = int(py // TILE_SIZE)
        return self.get_tile(tx, ty)

    def is_walkable(self, px, py):
        """해당 픽셀 위치가 이동 가능한지"""
        tile = self.get_tile_at_pixel(px, py)
        return tile in [TileType.GROUND, TileType.ROAD, TileType.SPAWN, TileType.EXIT, TileType.BRIDGE]

    def get_building_at(self, px, py):
        """해당 픽셀 위치의 건물 가져오기"""
        for btype, rect in self.building_rects:
            if rect.collidepoint(px, py):
                return btype, rect
        return None, None

    def get_spawn_pixel_pos(self):
        """스폰 위치 (픽셀)"""
        return (self.spawn_point[0] * TILE_SIZE + TILE_SIZE // 2,
                self.spawn_point[1] * TILE_SIZE + TILE_SIZE // 2)

    def get_exit_pixel_pos(self):
        """출구 위치 (픽셀)"""
        return (self.exit_point[0] * TILE_SIZE + TILE_SIZE // 2,
                self.exit_point[1] * TILE_SIZE + TILE_SIZE // 2)

    def get_buildings_list(self):
        """건물 리스트 반환 (UI용)"""
        result = []
        for btype, x, y, w, h in self.buildings:
            info = BUILDING_INFO[btype]
            center_x = (x + w / 2) * TILE_SIZE
            center_y = (y + h / 2) * TILE_SIZE
            result.append({
                'type': btype,
                'name': info['name'],
                'icon': info['icon'],
                'color': info['color'],
                'ap_cost': info['ap_cost'],
                'x': center_x,
                'y': center_y,
                'rect': pygame.Rect(x * TILE_SIZE, y * TILE_SIZE, w * TILE_SIZE, h * TILE_SIZE)
            })
        return result
