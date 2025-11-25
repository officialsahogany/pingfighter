# downtown/buildings.py
# 번화가 건물 시스템 - 고유 디자인 적용

import pygame
import math
from .constants import (
    BuildingType, BUILDING_INFO, TILE_SIZE, Colors
)
from .building_designs import get_building_designer

class Building:
    """개별 건물 클래스"""

    def __init__(self, building_type, x, y, width, height):
        self.type = building_type
        self.info = BUILDING_INFO[building_type]

        # 위치 (타일 좌표)
        self.tile_x = x
        self.tile_y = y
        self.tile_width = width
        self.tile_height = height

        # 픽셀 위치 - 고유 사이즈 적용
        self.x = x * TILE_SIZE
        self.y = y * TILE_SIZE

        # 건물별 고유 크기 사용
        if 'pixel_size' in self.info:
            self.width = self.info['pixel_size'][0]
            self.height = self.info['pixel_size'][1]
        else:
            self.width = width * TILE_SIZE
            self.height = height * TILE_SIZE

        # 렉트 (충돌용 - 타일 기반)
        self.rect = pygame.Rect(
            self.x, self.y,
            width * TILE_SIZE, height * TILE_SIZE
        )

        # 상태
        self.visited = False
        self.available = True
        self.highlight = False

        # 애니메이션
        self.animation_timer = 0
        self.glow_intensity = 0

        # 입구 위치 (건물 아래쪽 중앙)
        self.entrance_x = self.x + self.width // 2
        self.entrance_y = self.y + self.height

    def update(self, dt):
        """업데이트"""
        self.animation_timer += dt

        # 하이라이트 글로우
        if self.highlight:
            self.glow_intensity = min(self.glow_intensity + dt * 3, 1.0)
        else:
            self.glow_intensity = max(self.glow_intensity - dt * 3, 0.0)

    def draw(self, screen, camera_offset=(0, 0)):
        """건물 그리기 - 고유 디자인 시스템 사용"""
        # 하이라이트 글로우 효과 (고유 디자인 위에 추가)
        if self.glow_intensity > 0:
            draw_x = self.x - camera_offset[0]
            draw_y = self.y - camera_offset[1]
            glow_surf = pygame.Surface(
                (self.width + 30, self.height + 30), pygame.SRCALPHA
            )
            glow_alpha = int(80 * self.glow_intensity)
            pygame.draw.rect(glow_surf, (*self.info['color'], glow_alpha),
                           (0, 0, self.width + 30, self.height + 30),
                           border_radius=15)
            screen.blit(glow_surf, (draw_x - 15, draw_y - 15))

        # 방문 완료 표시
        if self.visited:
            draw_x = self.x - camera_offset[0]
            draw_y = self.y - camera_offset[1]
            self._draw_visited_mark(screen, draw_x, draw_y)

        # 비활성화 표시
        if not self.available:
            draw_x = self.x - camera_offset[0]
            draw_y = self.y - camera_offset[1]
            self._draw_unavailable_overlay(screen, draw_x, draw_y)

    def _draw_visited_mark(self, screen, x, y):
        """방문 완료 표시"""
        check_size = 24
        check_x = x + self.width - check_size - 5
        check_y = y + 5

        # 체크 배경
        pygame.draw.circle(screen, Colors.UI_SUCCESS,
                          (check_x + check_size // 2, check_y + check_size // 2),
                          check_size // 2)
        pygame.draw.circle(screen, Colors.TEXT_WHITE,
                          (check_x + check_size // 2, check_y + check_size // 2),
                          check_size // 2, 2)

        # 체크 마크
        points = [
            (check_x + 6, check_y + check_size // 2),
            (check_x + check_size // 2 - 1, check_y + check_size - 6),
            (check_x + check_size - 4, check_y + 6)
        ]
        pygame.draw.lines(screen, Colors.TEXT_WHITE, False, points, 3)

    def _draw_unavailable_overlay(self, screen, x, y):
        """비활성화 오버레이"""
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 150))
        screen.blit(overlay, (x, y))

        # X 표시
        padding = 20
        pygame.draw.line(screen, Colors.UI_DANGER,
                        (x + padding, y + padding),
                        (x + self.width - padding, y + self.height - padding), 4)
        pygame.draw.line(screen, Colors.UI_DANGER,
                        (x + self.width - padding, y + padding),
                        (x + padding, y + self.height - padding), 4)


class BuildingManager:
    """건물 관리자 - 고유 디자인 시스템 통합"""

    def __init__(self):
        self.buildings = []
        self.designer = get_building_designer()

    def load_from_map(self, downtown_map):
        """맵에서 건물 로드"""
        self.buildings.clear()

        for btype, x, y, w, h in downtown_map.buildings:
            building = Building(btype, x, y, w, h)
            self.buildings.append(building)

    def update(self, dt):
        """모든 건물 업데이트"""
        # 디자이너 업데이트 (파티클 등)
        self.designer.update(dt)

        for building in self.buildings:
            building.update(dt)

    def draw(self, screen, camera_offset=(0, 0)):
        """모든 건물 그리기 - 고유 디자인 적용"""
        # Y좌표 기준 정렬 (깊이 표현)
        sorted_buildings = sorted(self.buildings, key=lambda b: b.y)

        for building in sorted_buildings:
            # 고유 디자인으로 건물 그리기
            self.designer.draw_building(screen, building, camera_offset)

            # 추가 효과 (하이라이트, 방문 표시 등)
            building.draw(screen, camera_offset)

    def get_building_at(self, x, y):
        """해당 위치의 건물 반환"""
        for building in self.buildings:
            if building.rect.collidepoint(x, y):
                return building
        return None

    def get_nearest_building(self, x, y, max_distance=None):
        """가장 가까운 건물 반환"""
        nearest = None
        min_dist = float('inf')

        for building in self.buildings:
            # 건물 중심까지의 거리
            center_x = building.x + building.width // 2
            center_y = building.y + building.height // 2
            dist = math.sqrt((x - center_x)**2 + (y - center_y)**2)

            if dist < min_dist:
                if max_distance is None or dist <= max_distance:
                    min_dist = dist
                    nearest = building

        return nearest

    def set_highlight(self, building):
        """건물 하이라이트 설정"""
        for b in self.buildings:
            b.highlight = (b == building)

    def clear_highlight(self):
        """하이라이트 해제"""
        for b in self.buildings:
            b.highlight = False

    def mark_visited(self, building):
        """방문 완료 표시"""
        if building:
            building.visited = True

    def get_unvisited_buildings(self):
        """미방문 건물 목록"""
        return [b for b in self.buildings if not b.visited]

    def get_available_buildings(self):
        """이용 가능한 건물 목록"""
        return [b for b in self.buildings if b.available and not b.visited]
