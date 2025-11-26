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

        # 맵 데이터 (세로형: 15x50 타일 - 긴 탐험형)
        self.width = MAP_WIDTH    # 15 타일 (가로)
        self.height = MAP_HEIGHT  # 50 타일 (세로) - 긴 탐험 맵
        self.tiles = [[TileType.EMPTY for _ in range(self.width)] for _ in range(self.height)]

        # 건물 데이터
        self.buildings = []  # [(type, x, y, width, height), ...]
        self.building_rects = []  # pygame.Rect 리스트

        # 특수 위치 (세로형: 아래에서 시작 → 위로 출구)
        self.spawn_point = (self.width // 2, self.height - 3)    # 아래쪽 중앙 (시작)
        self.exit_point = (self.width // 2, 3)                    # 위쪽 중앙 (출구)

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
        """긴 탐험형 도로 생성 (위→아래 메인 도로 + 구역별 변화)"""
        # 긴 맵에서는 구역별로 다른 패턴을 조합
        self._generate_long_exploration_road()

    def _generate_long_exploration_road(self):
        """긴 탐험형 맵을 위한 도로 생성 (구역별 변화)"""
        mid_x = self.width // 2

        # 메인 세로 도로 (위에서 아래로 - 약간 구불구불)
        current_x = mid_x
        section_length = 10  # 구역 길이

        for y in range(2, self.height - 2):
            # 2칸 너비 도로
            for dx in range(-1, 2):
                road_x = current_x + dx
                if 1 < road_x < self.width - 2:
                    self.tiles[y][road_x] = TileType.ROAD

            # 구역마다 도로 방향 약간 변경 (자연스러운 굽이)
            if y % section_length == 0 and y > 5 and y < self.height - 10:
                shift = random.choice([-1, 0, 0, 1])  # 중앙 유지 확률 높음
                new_x = current_x + shift
                if 3 < new_x < self.width - 4:
                    # 연결 도로 생성
                    for connect_x in range(min(current_x, new_x), max(current_x, new_x) + 1):
                        self.tiles[y][connect_x] = TileType.ROAD
                    current_x = new_x

        # 구역별 가로 연결 도로 (건물 접근용)
        num_sections = self.height // section_length
        for section in range(num_sections):
            y = 5 + section * section_length + random.randint(-2, 2)
            if 3 < y < self.height - 5:
                # 왼쪽 또는 오른쪽으로 가로 도로
                side = random.choice(['left', 'right', 'both'])

                if side in ['left', 'both']:
                    for x in range(2, mid_x):
                        self.tiles[y][x] = TileType.ROAD

                if side in ['right', 'both']:
                    for x in range(mid_x, self.width - 2):
                        self.tiles[y][x] = TileType.ROAD

        # 광장 구역 (중간 중간에 넓은 공간)
        plaza_positions = [self.height // 4, self.height // 2, self.height * 3 // 4]
        for plaza_y in plaza_positions:
            if 5 < plaza_y < self.height - 5:
                for dy in range(-2, 3):
                    for dx in range(-3, 4):
                        px, py = mid_x + dx, plaza_y + dy
                        if 1 < px < self.width - 2 and 1 < py < self.height - 2:
                            self.tiles[py][px] = TileType.ROAD

    def _generate_vertical_main_road(self):
        """세로 메인 도로 (중앙) - 폴백용"""
        mid_x = self.width // 2

        # 세로 메인 도로 (위→아래)
        for y in range(2, self.height - 1):
            self.tiles[y][mid_x] = TileType.ROAD
            self.tiles[y][mid_x - 1] = TileType.ROAD

        # 여러 가로 연결 도로
        for section in range(5):
            y = 5 + section * 10
            if y < self.height - 5:
                for x in range(2, self.width - 2):
                    self.tiles[y][x] = TileType.ROAD

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
        """건물 배치 - 긴 탐험형 맵에 분산 배치"""
        self.buildings.clear()

        # 1. 먼저 은행을 시작 지점 근처에 배치
        self._place_bank_near_spawn()

        # 필수 건물 (항상 등장 - 은행은 이미 배치됨)
        required_buildings = [BuildingType.MAGIC_STORE, BuildingType.BLACKSMITH]

        # 스테이지에 따른 추가 필수 건물
        if self.stage_number >= 2:
            required_buildings.append(BuildingType.ELDER)
        if self.stage_number >= 3:
            required_buildings.append(BuildingType.COLOSSEUM)

        # 선택적 건물 (확률에 따라 - 은행 제외)
        optional_buildings = []
        for btype, info in BUILDING_INFO.items():
            if btype not in required_buildings and btype != BuildingType.BANK:
                if random.random() < info["rarity"]:
                    optional_buildings.append(btype)

        # 긴 맵에서는 더 많은 건물 배치 (8~12개)
        max_buildings = min(8 + self.stage_number // 2, 12)
        all_buildings = required_buildings + optional_buildings[:max_buildings - len(required_buildings)]

        # 건물을 구역별로 분산 배치 (탐험하면서 발견하는 재미)
        num_sections = 5  # 맵을 5구역으로 나눔
        section_height = self.height // num_sections

        # 건물을 구역에 할당
        buildings_per_section = []
        for i in range(num_sections):
            buildings_per_section.append([])

        random.shuffle(all_buildings)
        for i, btype in enumerate(all_buildings):
            section_idx = i % num_sections
            buildings_per_section[section_idx].append(btype)

        # 각 구역에 건물 배치
        for section_idx, section_buildings in enumerate(buildings_per_section):
            section_start_y = section_idx * section_height + 3
            section_end_y = (section_idx + 1) * section_height - 3

            for btype in section_buildings:
                self._try_place_building_in_section(btype, section_start_y, section_end_y)

    def _try_place_building_in_section(self, building_type, min_y, max_y, max_attempts=30):
        """특정 구역 내에 건물 배치 시도"""
        info = BUILDING_INFO[building_type]
        bw, bh = info["size"]

        for _ in range(max_attempts):
            # 구역 내 랜덤 위치
            x = random.randint(2, self.width - bw - 2)
            y = random.randint(max(2, min_y), min(max_y - bh, self.height - bh - 2))

            # 배치 가능 여부 확인
            if self._can_place_building(x, y, bw, bh):
                self._place_single_building(building_type, x, y, bw, bh)
                return True

        return False

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

    def _can_place_building(self, x, y, width, height, allow_near_spawn_exit=False, is_bank=False):
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

        # 시작/도착 지점 주변 금지 영역 체크 (은행 제외)
        if not allow_near_spawn_exit:
            if self._is_near_spawn_or_exit(x, y, width, height):
                return False

        # 기존 건물과 겹침 체크
        # 모든 건물은 캐릭터가 통행할 수 있도록 충분한 간격 확보 (6타일 = 240px)
        building_spacing = TILE_SIZE * 6  # 모든 건물: 240px 간격 (캐릭터 통행 가능)

        new_rect = pygame.Rect(x * TILE_SIZE, y * TILE_SIZE,
                              width * TILE_SIZE, height * TILE_SIZE)
        for _, bx, by, bw, bh in self.buildings:
            existing_rect = pygame.Rect(bx * TILE_SIZE, by * TILE_SIZE,
                                        bw * TILE_SIZE, bh * TILE_SIZE)
            if new_rect.colliderect(existing_rect.inflate(building_spacing, building_spacing)):
                return False

        # 도로 인접 체크 (일반 건물은 도로에 인접해야 하지만 은행은 예외)
        if is_bank:
            return True  # 은행은 도로 없이도 배치 가능 (시작 지점 바로 옆)

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

    def _is_near_spawn_or_exit(self, x, y, width, height):
        """건물이 시작/도착 지점 근처인지 확인"""
        # 건물 중심점
        building_center_x = x + width / 2
        building_center_y = y + height / 2

        # 시작 지점 근처 체크 (7타일 = 280px 반경)
        spawn_distance_tiles = 7
        spawn_x, spawn_y = self.spawn_point
        if abs(building_center_x - spawn_x) < spawn_distance_tiles and \
           abs(building_center_y - spawn_y) < spawn_distance_tiles:
            return True

        # 도착 지점 근처 체크 (7타일 = 280px 반경)
        exit_distance_tiles = 7
        exit_x, exit_y = self.exit_point
        if abs(building_center_x - exit_x) < exit_distance_tiles and \
           abs(building_center_y - exit_y) < exit_distance_tiles:
            return True

        return False

    def _place_bank_near_spawn(self):
        """은행을 시작 지점 근처에 배치 (적절한 거리 유지)"""
        spawn_x, spawn_y = self.spawn_point
        bank_info = BUILDING_INFO[BuildingType.BANK]
        bw, bh = bank_info["size"]

        # 시작 지점에서 적절한 거리(5-8타일)에 은행 배치
        # 너무 가깝지 않게, 하지만 찾기 쉽게
        search_positions = [
            # 5타일 거리 (최우선 - 적절한 거리)
            (spawn_x - 5 - bw, spawn_y),      # 왼쪽 5타일
            (spawn_x + 5, spawn_y),            # 오른쪽 5타일
            (spawn_x - 5 - bw, spawn_y - 2),  # 왼쪽 위
            (spawn_x + 5, spawn_y - 2),        # 오른쪽 위
            # 6타일 거리 (차선)
            (spawn_x - 6 - bw, spawn_y),
            (spawn_x + 6, spawn_y),
            (spawn_x - 6 - bw, spawn_y - 3),
            (spawn_x + 6, spawn_y - 3),
            # 7타일 거리 (백업)
            (spawn_x - 7 - bw, spawn_y - 1),
            (spawn_x + 7, spawn_y - 1),
        ]

        for test_x, test_y in search_positions:
            # 은행 배치 체크 (금지 영역 무시, 은행 전용 간격 적용)
            if self._can_place_building(test_x, test_y, bw, bh, allow_near_spawn_exit=True, is_bank=True):
                self._place_single_building(BuildingType.BANK, test_x, test_y, bw, bh)
                return True

        # 찾지 못한 경우 일반 배치 시도 (시작 지점 구역)
        for _ in range(50):
            x = random.randint(2, self.width - bw - 2)
            y = random.randint(max(2, spawn_y - 10), min(spawn_y + 2, self.height - bh - 2))
            if self._can_place_building(x, y, bw, bh, allow_near_spawn_exit=True, is_bank=True):
                self._place_single_building(BuildingType.BANK, x, y, bw, bh)
                return True

        return False

    def _place_single_building(self, building_type, x, y, width, height):
        """단일 건물 배치"""
        # 타일 업데이트
        for dy in range(height):
            for dx in range(width):
                self.tiles[y + dy][x + dx] = TileType.BUILDING

        # 건물 리스트에 추가
        self.buildings.append((building_type, x, y, width, height))

    def _set_spawn_exit(self):
        """스폰/출구 위치 설정 (아래에서 시작 → 위로 출구)"""
        mid_x = self.width // 2

        # 스폰 위치 (아래쪽 중앙 - 도로 위에서 시작)
        for x in range(mid_x - 2, mid_x + 3):
            if 0 <= x < self.width:
                y = self.height - 4  # 아래쪽에서 시작
                if self.tiles[y][x] == TileType.ROAD:
                    self.spawn_point = (x, y)
                    self.tiles[y][x] = TileType.SPAWN
                    break
        else:
            # 도로가 없으면 중앙에 강제 설정
            self.spawn_point = (mid_x, self.height - 4)
            self.tiles[self.height - 4][mid_x] = TileType.SPAWN

        # 출구 위치 (위쪽 중앙 - 목표 지점)
        for x in range(mid_x - 2, mid_x + 3):
            if 0 <= x < self.width:
                y = 3  # 위쪽 끝
                if self.tiles[y][x] == TileType.ROAD:
                    self.exit_point = (x, y)
                    self.tiles[y][x] = TileType.EXIT
                    break
        else:
            # 도로가 없으면 중앙에 강제 설정
            self.exit_point = (mid_x, 3)
            self.tiles[3][mid_x] = TileType.EXIT

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
        """건물 충돌 렉트 생성 - 실제 픽셀 크기 기반"""
        self.building_rects.clear()
        for btype, x, y, w, h in self.buildings:
            info = BUILDING_INFO[btype]

            # 타일 기반 영역의 중심점
            tile_center_x = x * TILE_SIZE + (w * TILE_SIZE) // 2
            tile_center_y = y * TILE_SIZE + (h * TILE_SIZE) // 2

            # 실제 픽셀 크기 사용 (더 정확한 충돌)
            pixel_w, pixel_h = info.get("pixel_size", (w * TILE_SIZE, h * TILE_SIZE))

            # 픽셀 크기 기반 충돌 렉트 (중심 정렬)
            rect = pygame.Rect(
                tile_center_x - pixel_w // 2,
                tile_center_y - pixel_h // 2,
                pixel_w,
                pixel_h
            )
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
        """해당 픽셀 위치가 이동 가능한지 - 픽셀 기반 건물 충돌 체크"""
        tile = self.get_tile_at_pixel(px, py)

        # 기본 타일 체크 (BUILDING 타일도 일단 허용 - 픽셀 충돌로 판단)
        # DECORATION 타일도 이동 가능 (꽃밭, 벤치 등은 지나갈 수 있음)
        walkable_tiles = [TileType.GROUND, TileType.ROAD, TileType.SPAWN,
                         TileType.EXIT, TileType.BRIDGE, TileType.BUILDING,
                         TileType.DECORATION]

        if tile not in walkable_tiles:
            return False

        # 픽셀 기반 건물 충돌 체크 (실제 건물 그래픽 영역만)
        # 마진 없이 실제 건물 크기 그대로 사용
        for btype, rect in self.building_rects:
            if rect.collidepoint(px, py):
                return False

        return True

    def get_building_at(self, px, py):
        """해당 픽셀 위치의 건물 가져오기"""
        for btype, rect in self.building_rects:
            if rect.collidepoint(px, py):
                return btype, rect
        return None, None

    def get_spawn_pixel_pos(self):
        """스폰 위치 (픽셀) - 정확한 spawn_point에서 시작"""
        # 정확한 spawn_point 위치 반환 (타일 중앙)
        base_x = self.spawn_point[0] * TILE_SIZE + TILE_SIZE // 2
        base_y = self.spawn_point[1] * TILE_SIZE + TILE_SIZE // 2

        # 맵 생성 시 spawn_point 주변을 충분히 비워두므로
        # 항상 정확한 spawn_point 위치 반환
        return (base_x, base_y)

    def _is_spawn_safe(self, px, py, radius):
        """스폰 위치가 안전한지 체크 (건물/장애물과 충돌 없음)"""
        # 4 코너 + 중심 체크
        check_points = [
            (px, py),
            (px - radius, py - radius),
            (px + radius, py - radius),
            (px - radius, py + radius),
            (px + radius, py + radius),
        ]

        for cx, cy in check_points:
            if not self.is_walkable(cx, cy):
                return False

        # 건물 렉트와의 거리 체크
        for btype, rect in self.building_rects:
            # 플레이어 영역이 건물과 겹치는지
            player_rect = pygame.Rect(px - radius, py - radius, radius * 2, radius * 2)
            if player_rect.colliderect(rect.inflate(20, 20)):  # 약간의 여유
                return False

        return True

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
