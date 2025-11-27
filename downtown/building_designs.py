# downtown/building_designs.py
# 건물별 고유 디자인 시스템

import pygame
import math
import random
from .constants import BuildingType, Colors, TILE_SIZE


def safe_surface(width, height, flags=pygame.SRCALPHA):
    """안전한 Surface 생성 - 최소 크기 1x1 보장"""
    return pygame.Surface((max(1, int(width)), max(1, int(height))), flags)


class BuildingDesigner:
    """건물별 고유 디자인 렌더러 - 고품질 버전"""

    def __init__(self):
        self.animation_timer = 0
        # 파티클 저장 (건물 기준 상대좌표로 저장)
        self.particles = {}
        # 파티클 생성 시 건물 기준점 저장 (카메라 오프셋 보정용)
        self._particle_base = {}
        # 글로우 캐시 (성능 최적화)
        self._glow_cache = {}

    # =========================================================================
    # 고품질 렌더링 헬퍼 메서드
    # =========================================================================
    def _create_soft_glow(self, size, color, intensity=1.0):
        """부드러운 글로우 효과 생성"""
        cache_key = (size, color, int(intensity * 10))
        if cache_key in self._glow_cache:
            return self._glow_cache[cache_key]

        glow_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
        for r in range(size, 0, -2):
            alpha = int((r / size) * 80 * intensity)
            pygame.draw.circle(glow_surf, (*color[:3], alpha), (size, size), r)

        self._glow_cache[cache_key] = glow_surf
        return glow_surf

    def _draw_ambient_occlusion(self, screen, rect, intensity=0.3):
        """앰비언트 오클루전 (모서리 어둡게)"""
        x, y, w, h = rect
        ao_surf = pygame.Surface((w, h), pygame.SRCALPHA)

        # 4개 코너에 부드러운 그림자
        corner_size = min(w, h) // 4
        corners = [(0, 0), (w - corner_size, 0), (0, h - corner_size), (w - corner_size, h - corner_size)]

        for cx, cy in corners:
            for i in range(corner_size):
                alpha = int(60 * intensity * (1 - i / corner_size))
                pygame.draw.circle(ao_surf, (0, 0, 0, alpha),
                                 (cx + corner_size // 2, cy + corner_size // 2),
                                 corner_size - i)

        screen.blit(ao_surf, (x, y))

    def _draw_3d_shadow(self, screen, x, y, w, h, depth=8):
        """3D 입체 그림자"""
        shadow_surf = pygame.Surface((w + depth * 2, h + depth * 2), pygame.SRCALPHA)

        # 다층 그림자
        for i in range(depth, 0, -1):
            alpha = int(80 * (i / depth))
            offset = depth - i
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, alpha),
                              (offset, h + offset, w, depth * 2 - offset))

        screen.blit(shadow_surf, (x - depth, y))

    def _draw_highlight_edge(self, screen, x, y, w, h, color, intensity=0.5):
        """하이라이트 엣지 (상단/좌측 밝게)"""
        highlight = tuple(min(255, int(c + 80 * intensity)) for c in color[:3])

        # 상단 하이라이트
        for i in range(3):
            alpha = int(150 * intensity * (1 - i / 3))
            pygame.draw.line(screen, (*highlight, alpha),
                           (x + 2, y + i + 1), (x + w - 2, y + i + 1))

        # 좌측 하이라이트
        for i in range(2):
            alpha = int(100 * intensity * (1 - i / 2))
            pygame.draw.line(screen, (*highlight, alpha),
                           (x + i + 1, y + 2), (x + i + 1, y + h - 2))

    def _draw_shadow_edge(self, screen, x, y, w, h, intensity=0.5):
        """그림자 엣지 (하단/우측 어둡게)"""
        # 하단 그림자
        for i in range(3):
            alpha = int(100 * intensity * (1 - i / 3))
            pygame.draw.line(screen, (0, 0, 0, alpha),
                           (x + 2, y + h - i - 1), (x + w - 2, y + h - i - 1))

        # 우측 그림자
        for i in range(2):
            alpha = int(80 * intensity * (1 - i / 2))
            pygame.draw.line(screen, (0, 0, 0, alpha),
                           (x + w - i - 1, y + 2), (x + w - i - 1, y + h - 2))

    def _draw_window_light(self, screen, x, y, w, h, color, flicker=True):
        """창문 빛 효과 (내부 조명)"""
        # 기본 창문
        pygame.draw.rect(screen, (40, 35, 30), (x, y, w, h))

        # 빛 효과
        if flicker:
            pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 3 + x * 0.1))
        else:
            pulse = 1.0

        light_color = tuple(int(c * pulse) for c in color)
        pygame.draw.rect(screen, light_color, (x + 2, y + 2, w - 4, h - 4))

        # 글로우
        glow_surf = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*color, int(40 * pulse)),
                        (0, 0, w + 20, h + 20), border_radius=5)
        screen.blit(glow_surf, (x - 10, y - 10))

    def _draw_brick_texture(self, surf, x, y, w, h, base_color, brick_w=28, brick_h=12):
        """고품질 벽돌 텍스처"""
        dark = tuple(max(0, c - 20) for c in base_color)
        light = tuple(min(255, c + 15) for c in base_color)
        mortar = tuple(max(0, c - 35) for c in base_color)

        for row in range(0, h, brick_h + 2):
            offset = (brick_w // 2) if (row // (brick_h + 2)) % 2 else 0
            for col in range(-offset, w, brick_w + 2):
                bx = x + col
                by = y + row

                if bx >= x and bx + brick_w <= x + w and by + brick_h <= y + h:
                    # 벽돌 그라데이션
                    brick_surf = pygame.Surface((brick_w, brick_h), pygame.SRCALPHA)
                    for i in range(brick_h):
                        grad = 1.0 - (i / brick_h) * 0.15
                        line_color = tuple(int(c * grad) for c in base_color)
                        pygame.draw.line(brick_surf, line_color, (0, i), (brick_w, i))

                    # 벽돌 하이라이트/그림자
                    pygame.draw.line(brick_surf, light, (1, 1), (brick_w - 2, 1))
                    pygame.draw.line(brick_surf, dark, (1, brick_h - 2), (brick_w - 2, brick_h - 2))

                    surf.blit(brick_surf, (bx, by))

        # 모르타르 라인
        for row in range(brick_h, h, brick_h + 2):
            pygame.draw.line(surf, mortar, (x, y + row), (x + w, y + row), 2)

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_timer += dt

        # 파티클 업데이트
        for building_id, particle_list in list(self.particles.items()):
            for p in particle_list[:]:
                p['life'] -= dt
                p['x'] += p.get('vx', 0) * dt
                p['y'] += p.get('vy', 0) * dt
                if 'vy' in p and p.get('gravity', False):
                    p['vy'] += 200 * dt
                if p['life'] <= 0:
                    particle_list.remove(p)

    def draw_building(self, screen, building, camera_offset=(0, 0)):
        """건물 타입에 따른 그리기"""
        draw_x = building.x - camera_offset[0]
        draw_y = building.y - camera_offset[1]

        # 건물 ID로 파티클 관리
        building_id = id(building)
        if building_id not in self.particles:
            self.particles[building_id] = []
            self._particle_base[building_id] = (draw_x, draw_y)

        # 카메라 이동에 따른 파티클 좌표 보정
        if building_id in self._particle_base:
            old_x, old_y = self._particle_base[building_id]
            delta_x = draw_x - old_x
            delta_y = draw_y - old_y
            if delta_x != 0 or delta_y != 0:
                # 기존 파티클 좌표를 카메라 이동량만큼 조정
                for p in self.particles[building_id]:
                    p['x'] += delta_x
                    p['y'] += delta_y

        # 현재 기준점 업데이트
        self._particle_base[building_id] = (draw_x, draw_y)

        # 건물 타입별 그리기
        if building.type == BuildingType.CASINO:
            self._draw_casino(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.COLOSSEUM:
            self._draw_colosseum(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.BLACKSMITH:
            self._draw_blacksmith(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.MAGIC_STORE:
            self._draw_magic_store(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.PET_SHOP:
            self._draw_pet_shop(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.ELDER:
            self._draw_elder_hut(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.MINIGAME:
            self._draw_arcade(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.TAVERN:
            self._draw_tavern(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.BANK:
            self._draw_bank(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.MYSTERY:
            self._draw_mystery(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.GACHA:
            self._draw_gacha(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.ACADEMY:
            self._draw_academy(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.ITEM_SHOP:
            self._draw_item_shop(screen, building, draw_x, draw_y, building_id)
        else:
            self._draw_default(screen, building, draw_x, draw_y)

    # =========================================================================
    # 🎰 카지노 - 고품질 사이버펑크 네온 스타일
    # =========================================================================
    def _draw_casino(self, screen, building, x, y, building_id):
        """카지노 - 네온 사이버펑크 스타일 럭셔리 카지노"""
        w, h = building.width, building.height

        # 색상 정의 - 네온 핑크 & 사이안 사이버펑크
        NEON_PINK = (255, 0, 128)
        NEON_PINK_LIGHT = (255, 100, 180)
        NEON_CYAN = (0, 255, 255)
        NEON_CYAN_DARK = (0, 180, 200)
        NEON_PURPLE = (180, 0, 255)
        NEON_PURPLE_DARK = (100, 0, 150)
        WHITE_GLOW = (255, 240, 255)
        DARK_PURPLE = (30, 10, 40)

        # 1. 럭셔리 3D 그림자 (여러 층)
        for i in range(15, 0, -3):
            shadow_alpha = 30 + i * 3
            shadow_surf = pygame.Surface((w + 10, 20), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, shadow_alpha),
                              (0, 0, w + 10, 15 - i // 3))
            screen.blit(shadow_surf, (x - 5, y + h + i - 10))

        # 2. 네온 앰비언트 글로우 (핑크/사이안 교대)
        glow_pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 1.5))
        for i in range(3):
            glow_size = 25 - i * 8
            glow_alpha = int(50 * glow_pulse) - i * 10
            if glow_alpha > 0:
                glow_surf = pygame.Surface((w + glow_size * 2, h + glow_size * 2), pygame.SRCALPHA)
                glow_color = NEON_PINK if i % 2 == 0 else NEON_CYAN
                pygame.draw.rect(glow_surf, (*glow_color, glow_alpha),
                                (0, 0, w + glow_size * 2, h + glow_size * 2), border_radius=12)
                screen.blit(glow_surf, (x - glow_size, y - glow_size))

        # 3. 건물 기단 (어두운 네온 스타일)
        base_h = 15
        base_surf = pygame.Surface((w + 10, base_h), pygame.SRCALPHA)
        for i in range(base_h):
            grad = 0.4 + 0.3 * (1 - i / base_h)
            color = tuple(int(c * grad) for c in (60, 40, 80))
            pygame.draw.line(base_surf, color, (0, i), (w + 10, i))
        screen.blit(base_surf, (x - 5, y + h - 5))
        pygame.draw.rect(screen, NEON_CYAN_DARK, (x - 5, y + h - 5, w + 10, base_h), 2)

        # 4. 메인 건물 본체 - 네온 퍼플 그라데이션
        main_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        for i in range(h):
            # 세로 그라데이션 (어두운 → 밝은 → 어두운)
            grad = 0.4 + 0.4 * math.sin(math.pi * i / h)
            r = int(NEON_PURPLE_DARK[0] * grad + 30)
            g = int(NEON_PURPLE_DARK[1] * grad + 10)
            b = int(NEON_PURPLE_DARK[2] * grad + 40)
            pygame.draw.line(main_surf, (r, g, b), (0, i), (w, i))
        screen.blit(main_surf, (x, y))

        # 5. 네온 대각선 스트라이프 패턴
        pattern_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        stripe_offset = int(self.animation_timer * 30) % 20
        for i in range(-h, w + h, 10):
            stripe_alpha = 40 + int(20 * math.sin(self.animation_timer * 2 + i * 0.1))
            stripe_color = NEON_PINK if (i // 10) % 2 == 0 else NEON_CYAN
            pygame.draw.line(pattern_surf, (*stripe_color, stripe_alpha),
                           (i + stripe_offset, 0), (i - h + stripe_offset, h), 3)
        screen.blit(pattern_surf, (x, y))

        # 6. 네온 세로 기둥 (양쪽)
        pillar_w = 12
        for px in [x - 2, x + w - pillar_w + 2]:
            # 기둥 그라데이션
            for i in range(h + 10):
                grad = 0.5 + 0.5 * abs(math.sin(math.pi * i / 30))
                color = tuple(int(c * grad) for c in NEON_CYAN_DARK)
                pygame.draw.line(screen, color, (px, y - 5 + i), (px + pillar_w, y - 5 + i))
            # 기둥 하이라이트
            pygame.draw.line(screen, NEON_CYAN, (px + 2, y), (px + 2, y + h), 2)
            # 기둥 그림자
            pygame.draw.line(screen, NEON_PURPLE_DARK, (px + pillar_w - 2, y), (px + pillar_w - 2, y + h), 2)
            # 기둥 장식 밴드
            for band_y in [y + 15, y + h - 25]:
                pygame.draw.rect(screen, NEON_PINK, (px - 2, band_y, pillar_w + 4, 8))
                pygame.draw.rect(screen, NEON_CYAN, (px - 2, band_y, pillar_w + 4, 8), 1)

        # 7. 상단 캐노피 (네온 지붕)
        canopy_h = 25
        canopy_y = y - canopy_h

        # 캐노피 본체
        canopy_surf = pygame.Surface((w + 20, canopy_h + 5), pygame.SRCALPHA)
        for i in range(canopy_h):
            grad = 0.4 + 0.4 * (i / canopy_h)
            color = tuple(int(c * grad) for c in NEON_PURPLE_DARK)
            pygame.draw.line(canopy_surf, color, (0, i), (w + 20, i))
        screen.blit(canopy_surf, (x - 10, canopy_y))

        # 캐노피 네온 테두리
        pygame.draw.rect(screen, NEON_PINK, (x - 10, canopy_y, w + 20, canopy_h), 3)
        pygame.draw.line(screen, NEON_CYAN, (x - 8, canopy_y + 2), (x + w + 8, canopy_y + 2), 2)

        # 캐노피 네온 장식 (물결 모양)
        for i in range(0, w + 20, 12):
            wave_y = canopy_y + canopy_h - 3 + int(3 * math.sin(i * 0.3))
            bulb_color = NEON_PINK if (i // 12) % 2 == 0 else NEON_CYAN
            pygame.draw.circle(screen, bulb_color, (x - 10 + i, wave_y), 4)
            pygame.draw.circle(screen, WHITE_GLOW, (x - 10 + i, wave_y), 2)

        # 8. "CASINO" 네온 사인 (사이버펑크 버전)
        sign_w = min(w - 10, 100)
        sign_h = 28
        sign_x = x + (w - sign_w) // 2
        sign_y = canopy_y - sign_h - 8

        # 사인 글로우 (다층 - 핑크/사이안)
        for i in range(5):
            glow_alpha = int(60 * glow_pulse) - i * 10
            if glow_alpha > 0:
                glow_surf = pygame.Surface((sign_w + 30 + i * 8, sign_h + 20 + i * 4), pygame.SRCALPHA)
                glow_color = NEON_PINK if i % 2 == 0 else NEON_CYAN
                pygame.draw.rect(glow_surf, (*glow_color, glow_alpha),
                                (0, 0, sign_w + 30 + i * 8, sign_h + 20 + i * 4), border_radius=8)
                screen.blit(glow_surf, (sign_x - 15 - i * 4, sign_y - 10 - i * 2))

        # 사인 배경 (검정 + 네온 테두리)
        pygame.draw.rect(screen, (15, 5, 25), (sign_x, sign_y, sign_w, sign_h), border_radius=5)
        pygame.draw.rect(screen, NEON_PINK, (sign_x, sign_y, sign_w, sign_h), 3, border_radius=5)
        pygame.draw.rect(screen, NEON_CYAN, (sign_x + 2, sign_y + 2, sign_w - 4, sign_h - 4), 1, border_radius=4)

        # "CASINO" 텍스트 (글자별 깜빡임 - 핑크/사이안)
        text = "CASINO"
        font = pygame.font.Font(None, 22)
        char_spacing = (sign_w - 16) // len(text)
        for i, char in enumerate(text):
            char_pulse = 0.5 + 0.5 * abs(math.sin(self.animation_timer * 5 + i * 0.8))
            # 글자 색상 (핑크/사이안 교대)
            base_color = NEON_PINK if i % 2 == 0 else NEON_CYAN
            glow_color = tuple(int(c * char_pulse) for c in base_color)
            char_surf = font.render(char, True, glow_color)
            char_x = sign_x + 8 + i * char_spacing
            screen.blit(char_surf, (char_x, sign_y + 7))

        # 9. 장식 조명 (네온 전구 체인)
        bulb_y = canopy_y + canopy_h + 3
        bulb_colors = [NEON_PINK, NEON_CYAN, NEON_PINK, NEON_CYAN]
        for i in range(0, w, 15):
            bulb_on = (int(self.animation_timer * 8 + i * 0.2) % 4) < 3
            if bulb_on:
                color = bulb_colors[(i // 15) % len(bulb_colors)]
                # 전구 글로우
                glow_surf = pygame.Surface((12, 12), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*color, 120), (6, 6), 6)
                screen.blit(glow_surf, (x + i - 1, bulb_y - 3))
                # 전구 본체
                pygame.draw.circle(screen, color, (x + i + 5, bulb_y + 2), 3)
            else:
                pygame.draw.circle(screen, (40, 30, 50), (x + i + 5, bulb_y + 2), 3)

        # 10. 중앙 슬롯머신 디스플레이
        slot_w, slot_h = 50, 35
        slot_x = x + (w - slot_w) // 2
        slot_y = y + 25

        # 슬롯 프레임
        pygame.draw.rect(screen, NEON_PURPLE_DARK, (slot_x - 4, slot_y - 4, slot_w + 8, slot_h + 8), border_radius=6)
        pygame.draw.rect(screen, (10, 5, 20), (slot_x, slot_y, slot_w, slot_h), border_radius=4)
        pygame.draw.rect(screen, NEON_CYAN, (slot_x, slot_y, slot_w, slot_h), 2, border_radius=4)

        # 슬롯 릴 (3개)
        self._draw_luxury_slot_reels(screen, slot_x + 5, slot_y + 5, slot_w - 10, slot_h - 10)

        # 11. 카드 문양 장식
        card_symbols = ['♠', '♥', '♦', '♣']
        card_y = y + h // 2 + 10
        for i, sym in enumerate(card_symbols):
            sym_x = x + 15 + i * ((w - 30) // 4)
            pulse = 0.6 + 0.4 * abs(math.sin(self.animation_timer * 3 + i * 0.5))

            # 심볼 배경 (네온 글로우)
            bg_surf = pygame.Surface((20, 24), pygame.SRCALPHA)
            bg_color = NEON_PINK if i % 2 == 0 else NEON_CYAN
            pygame.draw.ellipse(bg_surf, (*bg_color, int(100 * pulse)), (0, 0, 20, 24))
            screen.blit(bg_surf, (sym_x - 2, card_y - 2))

            # 심볼 (네온 핑크/사이안)
            sym_color = NEON_PINK if sym in ['♥', '♦'] else NEON_CYAN
            font = pygame.font.Font(None, 20)
            sym_surf = font.render(sym, True, sym_color)
            screen.blit(sym_surf, (sym_x + 2, card_y + 2))

        # 12. 입구 (네온 VIP 스타일)
        door_w, door_h = 36, 45
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h - 5

        # 문 배경 (어두운 내부)
        door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
        for i in range(door_h):
            alpha = 230 - int(80 * (i / door_h))
            pygame.draw.line(door_surf, (10, 5, 20, alpha), (0, i), (door_w, i))
        screen.blit(door_surf, (door_x, door_y))

        # 문 네온 아치 프레임
        arch_rect = pygame.Rect(door_x - 5, door_y - 10, door_w + 10, 15)
        pygame.draw.arc(screen, NEON_PINK, arch_rect, 0, math.pi, 4)
        pygame.draw.arc(screen, NEON_CYAN, (arch_rect.x + 2, arch_rect.y + 2, arch_rect.w - 4, arch_rect.h - 4), 0, math.pi, 2)

        # 문 프레임
        pygame.draw.rect(screen, NEON_PINK, (door_x - 3, door_y, door_w + 6, door_h), 3)
        pygame.draw.rect(screen, NEON_CYAN, (door_x, door_y + 2, door_w, door_h - 4), 1)

        # 문 손잡이
        handle_y = door_y + door_h // 2
        pygame.draw.circle(screen, NEON_CYAN, (door_x + door_w - 8, handle_y), 4)
        pygame.draw.circle(screen, NEON_PURPLE_DARK, (door_x + door_w - 8, handle_y), 4, 1)

        # 네온 카펫 힌트
        carpet_surf = pygame.Surface((door_w + 10, 8), pygame.SRCALPHA)
        pygame.draw.rect(carpet_surf, (*NEON_PURPLE, 180), (0, 0, door_w + 10, 8))
        screen.blit(carpet_surf, (door_x - 5, door_y + door_h - 3))

        # 13. 파티클 - 네온 스파클
        if random.random() < 0.25:
            self.particles[building_id].append({
                'x': x + random.randint(5, w - 5),
                'y': y + random.randint(5, h - 20),
                'life': 1.0,
                'type': 'sparkle',
                'color': random.choice([NEON_PINK, NEON_CYAN, NEON_PURPLE, WHITE_GLOW])
            })

        # 14. 코너 네온 장식
        corner_size = 12
        corners = [(x, y), (x + w - corner_size, y), (x, y + h - corner_size), (x + w - corner_size, y + h - corner_size)]
        for i, (cx, cy) in enumerate(corners):
            corner_color = NEON_PINK if i % 2 == 0 else NEON_CYAN
            pygame.draw.polygon(screen, corner_color, [
                (cx + corner_size // 2, cy),
                (cx + corner_size, cy + corner_size // 2),
                (cx + corner_size // 2, cy + corner_size),
                (cx, cy + corner_size // 2)
            ])
            pygame.draw.polygon(screen, WHITE_GLOW, [
                (cx + corner_size // 2, cy + 2),
                (cx + corner_size - 2, cy + corner_size // 2),
                (cx + corner_size // 2, cy + corner_size - 2),
                (cx + 2, cy + corner_size // 2)
            ], 1)

        self._draw_particles(screen, building_id, (x, y))

    def _draw_luxury_slot_reels(self, screen, x, y, w, h):
        """네온 스타일 슬롯 릴 그리기"""
        symbols = ['7', '♦', '★', '♠', '$']
        reel_w = w // 3

        for i in range(3):
            reel_x = x + i * reel_w
            # 릴 배경
            pygame.draw.rect(screen, (15, 10, 25), (reel_x, y, reel_w - 2, h))
            pygame.draw.rect(screen, (100, 0, 150), (reel_x, y, reel_w - 2, h), 1)

            # 스크롤링 심볼
            offset = int(self.animation_timer * 8 + i * 20) % (len(symbols) * 12)
            sym_idx = (offset // 12) % len(symbols)
            sym = symbols[sym_idx]

            # 심볼 색상 (네온)
            if sym == '7':
                color = (255, 0, 128)  # 네온 핑크
            elif sym == '$':
                color = (0, 255, 255)  # 네온 사이안
            elif sym == '★':
                color = (255, 255, 0)  # 네온 옐로우
            else:
                color = (180, 0, 255)  # 네온 퍼플

            font = pygame.font.Font(None, 18)
            sym_surf = font.render(sym, True, color)
            sym_rect = sym_surf.get_rect(center=(reel_x + reel_w // 2 - 1, y + h // 2))
            screen.blit(sym_surf, sym_rect)

    def _draw_slot_icons_hq(self, screen, cx, cy):
        """고품질 슬롯 아이콘"""
        icons = ['7', '♦', '♠', '♣', '★']
        offset = int(self.animation_timer * 2) % len(icons)

        for i, icon in enumerate(icons[:4]):
            angle = self.animation_timer * 2.5 + i * (math.pi / 2)
            ix = cx + math.cos(angle) * 28
            iy = cy + math.sin(angle) * 18

            # 아이콘 글로우
            glow_surf = pygame.Surface((24, 24), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*Colors.UI_ACCENT, 80), (12, 12), 12)
            screen.blit(glow_surf, (int(ix) - 12, int(iy) - 12))

            # 아이콘 텍스트
            font = pygame.font.Font(None, 22)
            text = font.render(icons[(i + offset) % len(icons)], True, Colors.UI_ACCENT)
            screen.blit(text, (int(ix) - 6, int(iy) - 8))

    def _draw_slot_icons(self, screen, cx, cy):
        """슬롯 아이콘 그리기"""
        icons = ['7', '♦', '♠', '♣']
        offset = int(self.animation_timer * 2) % len(icons)

        for i, icon in enumerate(icons):
            angle = self.animation_timer * 2 + i * (math.pi / 2)
            ix = cx + math.cos(angle) * 25
            iy = cy + math.sin(angle) * 15

            font = pygame.font.Font(None, 24)
            text = font.render(icons[(i + offset) % len(icons)], True, Colors.UI_ACCENT)
            screen.blit(text, (ix - 6, iy - 8))

    # =========================================================================
    # ⚔️ 콜로세움 - 고품질 고대 로마 신전 스타일
    # =========================================================================
    def _draw_colosseum(self, screen, building, x, y, building_id):
        """콜로세움 - 고품질 웅장한 고대 신전"""
        w, h = building.width, building.height

        # 1. 고급 3D 그림자
        self._draw_3d_shadow(screen, x, y, w, h, depth=10)

        # 2. 배경 글로우 (웅장한 분위기)
        glow_pulse = 0.5 + 0.3 * abs(math.sin(self.animation_timer * 1.5))
        ambient_glow = pygame.Surface((w + 30, h + 30), pygame.SRCALPHA)
        pygame.draw.rect(ambient_glow, (255, 200, 100, int(25 * glow_pulse)),
                        (0, 0, w + 30, h + 30), border_radius=10)
        screen.blit(ambient_glow, (x - 15, y - 15))

        # 3. 기단 (계단) - 고품질 그라데이션
        for i in range(4):
            step_y = y + h - 20 + i * 6
            step_w = max(1, w - i * 16)
            step_x = x + i * 8

            if step_w <= 0:
                continue  # 건물이 너무 작으면 계단 스킵

            # 계단 그라데이션
            step_surf = safe_surface(step_w, 8)
            for sy in range(8):
                grad = 1.0 - sy * 0.05
                color = tuple(int(c * grad) for c in (190, 170, 150))
                pygame.draw.line(step_surf, color, (0, sy), (step_w, sy))
            screen.blit(step_surf, (step_x, step_y))

            # 계단 하이라이트/그림자
            pygame.draw.line(screen, (220, 200, 180), (step_x, step_y), (step_x + step_w, step_y))
            pygame.draw.line(screen, (140, 120, 100), (step_x, step_y + 7), (step_x + step_w, step_y + 7))

        # 4. 메인 건물 (대리석 텍스처)
        main_h = max(1, h - 40)
        main_surf = safe_surface(w, main_h)
        for my in range(main_h):
            grad = 0.85 + 0.15 * (1 - my / max(1, main_h))
            base = (210, 195, 175)
            color = tuple(int(c * grad) for c in base)
            pygame.draw.line(main_surf, color, (0, my), (w, my))
        screen.blit(main_surf, (x, y + 25))

        # 대리석 결 텍스처
        vein_range = max(1, h - 80)
        for i in range(10):
            vein_x = x + random.Random(i * 123).randint(5, max(6, w - 5))
            vein_h = random.Random(i * 456).randint(20, 60)
            vein_y = y + 30 + random.Random(i * 789).randint(0, vein_range)
            vein_color = (180, 165, 145, 40)
            pygame.draw.line(screen, vein_color, (vein_x, vein_y), (vein_x + 3, vein_y + vein_h), 1)

        # 5. 아치형 구조 (정교한 디테일)
        arch_count = max(3, w // 45)
        arch_width = max(10, (w - 16) // arch_count)

        for i in range(arch_count):
            arch_x = x + 8 + i * arch_width

            # 아치 배경 (그라데이션)
            arch_bg_h = max(1, h - 55)
            arch_bg_w = max(1, arch_width - 4)
            arch_bg = safe_surface(arch_bg_w, arch_bg_h)
            for ay in range(arch_bg_h):
                grad = 0.9 + 0.1 * (ay / max(1, arch_bg_h))
                color = tuple(int(c * grad) for c in (200, 185, 165))
                pygame.draw.line(arch_bg, color, (0, ay), (arch_bg_w, ay))
            screen.blit(arch_bg, (arch_x, y + 32))

            # 아치 프레임 (3D 효과)
            pygame.draw.rect(screen, (175, 155, 135), (arch_x, y + 32, arch_width - 4, h - 55), 2)
            pygame.draw.line(screen, (230, 215, 195), (arch_x + 1, y + 33), (arch_x + arch_width - 5, y + 33))

            # 아치 상단 (반원) - 다층 효과
            for offset in range(3):
                arc_color = (160 - offset * 20, 140 - offset * 15, 120 - offset * 10)
                pygame.draw.arc(screen, arc_color,
                              (arch_x - offset, y + 25 - offset, arch_width - 4 + offset * 2, 30 + offset * 2),
                              0, math.pi, 3 - offset)

            # 아치 내부 (어둡게 - 그라데이션)
            inner_x = arch_x + 4
            inner_w = max(1, arch_width - 12)
            inner_h = max(1, h - 70)
            inner_surf = safe_surface(inner_w, inner_h)
            for iy in range(inner_h):
                depth = 1.0 - (iy / inner_h) * 0.3
                color = tuple(int(c * depth) for c in (50, 40, 35))
                pygame.draw.line(inner_surf, (*color, 220), (0, iy), (inner_w, iy))
            screen.blit(inner_surf, (inner_x, y + 48))

            # 키스톤 (아치 정상의 돌)
            keystone_x = arch_x + (arch_width - 4) // 2 - 6
            pygame.draw.polygon(screen, (220, 205, 185),
                              [(keystone_x, y + 28), (keystone_x + 12, y + 28),
                               (keystone_x + 10, y + 38), (keystone_x + 2, y + 38)])

        # 6. 기둥들 (코린트 양식)
        pillar_positions = [x + 3, x + w - 18]
        for px in pillar_positions:
            # 기둥 베이스
            pygame.draw.rect(screen, (200, 185, 165), (px - 4, y + h - 25, 23, 10))
            pygame.draw.rect(screen, (220, 205, 185), (px - 2, y + h - 28, 19, 5))

            # 기둥 본체 (그라데이션 + 세로 홈)
            pillar_h = max(1, h - 50)
            pillar_surf = safe_surface(15, pillar_h)
            for py_offset in range(pillar_h):
                grad = 0.9 + 0.1 * abs(math.sin(py_offset * 0.05))
                color = tuple(int(c * grad) for c in (225, 210, 190))
                pygame.draw.line(pillar_surf, color, (0, py_offset), (15, py_offset))

            # 세로 홈 (플루팅)
            for flute in range(4):
                flute_x = 2 + flute * 3
                pygame.draw.line(pillar_surf, (200, 185, 165), (flute_x, 0), (flute_x, pillar_h))
            screen.blit(pillar_surf, (px, y + 22))

            # 기둥 캐피털 (상단 장식)
            cap_y = y + 15
            # 아칸서스 잎 표현 (단순화)
            for leaf in range(3):
                leaf_x = px - 2 + leaf * 7
                pygame.draw.ellipse(screen, (215, 200, 180), (leaf_x, cap_y, 8, 12))
            pygame.draw.rect(screen, (210, 195, 175), (px - 5, cap_y + 8, 25, 8))
            pygame.draw.line(screen, (240, 225, 205), (px - 4, cap_y + 9), (px + 19, cap_y + 9))

        # 7. 삼각형 지붕 (페디먼트) - 고품질
        roof_points = [
            (x - 8, y + 18),
            (x + w // 2, y - 30),
            (x + w + 8, y + 18)
        ]

        # 지붕 그라데이션
        roof_surf = pygame.Surface((w + 20, 50), pygame.SRCALPHA)
        for ry in range(50):
            grad = 1.0 - ry * 0.008
            color = tuple(int(c * grad) for c in (195, 175, 155))
            pygame.draw.line(roof_surf, color, (0, ry), (w + 20, ry))
        # 마스크 적용 (삼각형)
        mask_surf = pygame.Surface((w + 20, 50), pygame.SRCALPHA)
        shifted_points = [(p[0] - x + 10, p[1] - y + 30) for p in roof_points]
        pygame.draw.polygon(mask_surf, (255, 255, 255), shifted_points)
        roof_surf.blit(mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)

        pygame.draw.polygon(screen, (195, 175, 155), roof_points)
        pygame.draw.polygon(screen, (160, 140, 120), roof_points, 3)

        # 지붕 테두리 하이라이트
        pygame.draw.line(screen, (230, 215, 195), roof_points[0], roof_points[1], 2)

        # 8. 지붕 내부 장식 (방패 + 독수리)
        shield_x = x + w // 2
        shield_y = y - 5

        # 방패 글로우
        shield_glow = self._create_soft_glow(25, Colors.UI_ACCENT, 0.5)
        screen.blit(shield_glow, (shield_x - 25, shield_y - 25))

        # 방패 다층 효과
        pygame.draw.circle(screen, (180, 160, 140), (shield_x, shield_y), 18)
        pygame.draw.circle(screen, (160, 140, 120), (shield_x, shield_y), 15)
        pygame.draw.circle(screen, Colors.UI_ACCENT, (shield_x, shield_y), 12)

        # 검 장식 (고품질)
        pygame.draw.rect(screen, (80, 70, 60), (shield_x - 2, shield_y - 10, 4, 20), border_radius=1)
        pygame.draw.rect(screen, (100, 90, 70), (shield_x - 7, shield_y - 4, 14, 4), border_radius=1)
        pygame.draw.polygon(screen, (120, 110, 90), [(shield_x - 5, shield_y + 7), (shield_x + 5, shield_y + 7), (shield_x, shield_y + 12)])

        # 9. 깃발 (펄럭이는 애니메이션)
        flag_x = x + w - 28
        flag_y = y - 25

        # 깃대 (금속 느낌)
        pygame.draw.line(screen, (100, 85, 65), (flag_x, flag_y), (flag_x, flag_y + 45), 4)
        pygame.draw.line(screen, (130, 115, 95), (flag_x - 1, flag_y), (flag_x - 1, flag_y + 45), 1)

        # 깃발 (펄럭임) - 고품질
        wave1 = math.sin(self.animation_timer * 3.5) * 6
        wave2 = math.sin(self.animation_timer * 3.5 + 0.5) * 4
        flag_points = [
            (flag_x + 2, flag_y),
            (flag_x + 28 + wave1, flag_y + 5),
            (flag_x + 30 + wave2, flag_y + 12),
            (flag_x + 25 + wave1 * 0.7, flag_y + 18),
            (flag_x + 2, flag_y + 22)
        ]

        # 깃발 그라데이션
        pygame.draw.polygon(screen, (190, 45, 45), flag_points)
        # 깃발 무늬
        pygame.draw.line(screen, (220, 180, 50), (flag_x + 5, flag_y + 5), (flag_x + 20 + wave1 * 0.5, flag_y + 11), 2)
        # 깃발 하이라이트
        pygame.draw.line(screen, (220, 80, 80), (flag_x + 3, flag_y + 1), (flag_x + 25 + wave1, flag_y + 6), 1)

        # 10. 횃불 효과 (고품질)
        torch_positions = [(x + 22, y + 32), (x + w - 32, y + 32)]
        for tx, ty in torch_positions:
            self._draw_torch_hq(screen, tx, ty, building_id)

        # 11. 앰비언트 오클루전
        self._draw_ambient_occlusion(screen, (x, y + 20, w, h - 20), 0.25)

        # 파티클 렌더링
        self._draw_particles(screen, building_id, (x, y))

    def _draw_torch_hq(self, screen, x, y, building_id):
        """고품질 횃불 그리기"""
        # 횃불대 (금속)
        pygame.draw.rect(screen, (60, 50, 40), (x - 4, y, 8, 28))
        pygame.draw.line(screen, (80, 70, 55), (x - 3, y), (x - 3, y + 28))

        # 횃불 받침
        pygame.draw.rect(screen, (90, 75, 55), (x - 6, y - 3, 12, 6), border_radius=2)

        # 불꽃 글로우
        flame_pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 8))
        glow_surf = pygame.Surface((40, 50), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (255, 150, 50, int(80 * flame_pulse)), (5, 10, 30, 35))
        pygame.draw.ellipse(glow_surf, (255, 200, 100, int(50 * flame_pulse)), (10, 15, 20, 25))
        screen.blit(glow_surf, (x - 20, y - 45))

        # 불꽃 본체 (다층)
        flame_height = 18 + math.sin(self.animation_timer * 12) * 4
        flame_colors = [
            (255, 220, 100),  # 밝은 중심
            (255, 180, 50),   # 중간
            (255, 120, 30),   # 외곽
            (200, 80, 20)     # 가장 외곽
        ]

        for i, color in enumerate(reversed(flame_colors)):
            offset = math.sin(self.animation_timer * 10 + i * 0.5) * (3 + i)
            size_factor = 1.0 - i * 0.2
            points = [
                (x + offset * 0.5, y - 5 - flame_height * size_factor),
                (x - 8 * size_factor + i, y - 3),
                (x + 8 * size_factor - i, y - 3)
            ]
            pygame.draw.polygon(screen, color, points)

        # 불꽃 파티클
        if random.random() < 0.35:
            self.particles[building_id].append({
                'x': x + random.randint(-6, 6),
                'y': y - flame_height - 5,
                'vx': random.uniform(-25, 25),
                'vy': random.uniform(-60, -35),
                'life': 0.6,
                'type': 'ember',
                'color': (255, random.randint(120, 220), random.randint(30, 80))
            })

    def _draw_torch(self, screen, x, y, building_id):
        """횃불 그리기"""
        # 횃불대
        pygame.draw.rect(screen, (80, 60, 40), (x - 3, y, 6, 25))

        # 불꽃
        flame_height = 15 + math.sin(self.animation_timer * 10) * 5
        flame_colors = [(255, 200, 50), (255, 150, 30), (255, 100, 20)]

        for i, color in enumerate(flame_colors):
            offset = math.sin(self.animation_timer * 8 + i) * 3
            points = [
                (x + offset, y - flame_height + i * 5),
                (x - 6 + i * 2, y),
                (x + 6 - i * 2, y)
            ]
            pygame.draw.polygon(screen, color, points)

        # 불꽃 파티클
        if random.random() < 0.3:
            self.particles[building_id].append({
                'x': x + random.randint(-5, 5),
                'y': y - flame_height,
                'vx': random.uniform(-20, 20),
                'vy': random.uniform(-50, -30),
                'life': 0.5,
                'type': 'ember',
                'color': (255, random.randint(100, 200), 50)
            })

    # =========================================================================
    # 🔨 대장장이 - 고품질 화산/용광로 스타일
    # =========================================================================
    def _draw_blacksmith(self, screen, building, x, y, building_id):
        """대장장이 - 고품질 불타는 용광로"""
        w, h = building.width, building.height

        # 1. 고급 3D 그림자
        self._draw_3d_shadow(screen, x, y, w, h, depth=10)

        # 2. 배경 글로우 (불꽃 분위기)
        fire_pulse = 0.6 + 0.4 * abs(math.sin(self.animation_timer * 4))
        ambient_glow = pygame.Surface((w + 40, h + 40), pygame.SRCALPHA)
        pygame.draw.ellipse(ambient_glow, (255, 100, 30, int(35 * fire_pulse)),
                           (0, 10, w + 40, h + 20))
        screen.blit(ambient_glow, (x - 20, y - 20))

        # 연기 파티클 (고품질)
        if random.random() < 0.25:
            self.particles[building_id].append({
                'x': x + w - 18 + random.randint(-8, 8),
                'y': y - 25,
                'vx': random.uniform(-15, 15),
                'vy': random.uniform(-50, -25),
                'life': 2.5,
                'type': 'smoke',
                'size': random.randint(10, 18)
            })

        # 3. 메인 건물 (검은 돌/철 - 그라데이션)
        main_surf = pygame.Surface((w, h - 18), pygame.SRCALPHA)
        for my in range(h - 18):
            # 아래로 갈수록 약간 붉은 빛
            fire_tint = max(0, (my / (h - 18)) * 0.15)
            grad = 0.9 + 0.1 * (1 - my / (h - 18))
            r = int((55 + fire_tint * 50) * grad)
            g = int(48 * grad)
            b = int(45 * grad)
            pygame.draw.line(main_surf, (r, g, b), (0, my), (w, my))
        screen.blit(main_surf, (x, y + 18))

        # 고품질 벽돌 텍스처
        self._draw_brick_texture(screen, x + 2, y + 22, w - 4, h - 45, (65, 55, 50), 24, 10)

        # 4. 지붕 (기울어진 나무/철판)
        roof_color = (45, 40, 38)
        roof_points = [
            (x - 8, y + 18),
            (x + w + 8, y + 18),
            (x + w - 5, y - 5),
            (x + 5, y - 5)
        ]
        pygame.draw.polygon(screen, roof_color, roof_points)
        pygame.draw.polygon(screen, (35, 30, 28), roof_points, 2)
        # 지붕 하이라이트
        pygame.draw.line(screen, (65, 58, 55), (x + 6, y - 4), (x + w - 6, y - 4), 2)

        # 5. 굴뚝 (고품질)
        chimney_x = x + w - 32
        chimney_w = 28

        # 굴뚝 본체 (그라데이션)
        chimney_surf = pygame.Surface((chimney_w, 55), pygame.SRCALPHA)
        for cy in range(55):
            grad = 0.85 + 0.15 * (cy / 55)
            color = tuple(int(c * grad) for c in (50, 42, 40))
            pygame.draw.line(chimney_surf, color, (0, cy), (chimney_w, cy))
        screen.blit(chimney_surf, (chimney_x, y - 35))

        # 굴뚝 벽돌 라인
        for i in range(0, 55, 8):
            pygame.draw.line(screen, (40, 35, 32), (chimney_x, y - 35 + i), (chimney_x + chimney_w, y - 35 + i))

        # 굴뚝 상단 테두리
        pygame.draw.rect(screen, (65, 55, 50), (chimney_x - 4, y - 40, chimney_w + 8, 8), border_radius=2)
        pygame.draw.line(screen, (80, 70, 62), (chimney_x - 3, y - 39), (chimney_x + chimney_w + 3, y - 39))

        # 굴뚝 불빛 글로우
        glow_pulse = 0.5 + 0.5 * abs(math.sin(self.animation_timer * 6))
        glow_surf = pygame.Surface((50, 50), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (255, 120, 40, int(100 * glow_pulse)), (5, 10, 40, 35))
        pygame.draw.ellipse(glow_surf, (255, 180, 80, int(60 * glow_pulse)), (12, 18, 26, 22))
        screen.blit(glow_surf, (chimney_x - 11, y - 60))

        # 6. 용광로 (고품질)
        furnace_w = min(55, w - 25)
        furnace_x = x + (w - furnace_w) // 2
        furnace_y = y + h - 65

        # 용광로 외곽 (금속 프레임)
        frame_surf = pygame.Surface((furnace_w + 14, 52), pygame.SRCALPHA)
        for fy in range(52):
            grad = 0.7 + 0.3 * (1 - fy / 52)
            color = tuple(int(c * grad) for c in (90, 78, 65))
            pygame.draw.line(frame_surf, color, (0, fy), (furnace_w + 14, fy))
        screen.blit(frame_surf, (furnace_x - 7, furnace_y - 7))
        pygame.draw.rect(screen, (70, 58, 48), (furnace_x - 7, furnace_y - 7, furnace_w + 14, 52), 3)

        # 용광로 내부 (불타는 효과)
        inner_pulse = abs(math.sin(self.animation_timer * 10))
        inner_surf = pygame.Surface((furnace_w, 38), pygame.SRCALPHA)
        for iy in range(38):
            heat = 1.0 - (iy / 38) * 0.4
            r = int(255 * heat)
            g = int((120 + 80 * inner_pulse) * heat)
            b = int((30 + 40 * inner_pulse) * heat * 0.5)
            pygame.draw.line(inner_surf, (r, g, b), (0, iy), (furnace_w, iy))
        screen.blit(inner_surf, (furnace_x, furnace_y))

        # 불꽃 효과 (다층)
        for i in range(4):
            flame_x = furnace_x + 8 + i * (furnace_w - 16) // 3
            flame_offset = math.sin(self.animation_timer * 12 + i * 1.2) * 5
            flame_h = 22 + math.sin(self.animation_timer * 15 + i) * 8

            # 외곽 불꽃
            points_outer = [
                (flame_x + flame_offset * 0.3, furnace_y - flame_h * 0.6),
                (flame_x - 10, furnace_y + 5),
                (flame_x + 10, furnace_y + 5)
            ]
            pygame.draw.polygon(screen, (255, 100, 20), points_outer)

            # 중간 불꽃
            points_mid = [
                (flame_x + flame_offset * 0.5, furnace_y - flame_h * 0.8),
                (flame_x - 7, furnace_y + 2),
                (flame_x + 7, furnace_y + 2)
            ]
            pygame.draw.polygon(screen, (255, 180, 50), points_mid)

            # 중심 불꽃
            points_inner = [
                (flame_x + flame_offset * 0.7, furnace_y - flame_h),
                (flame_x - 4, furnace_y - 2),
                (flame_x + 4, furnace_y - 2)
            ]
            pygame.draw.polygon(screen, (255, 240, 150), points_inner)

        # 7. 모루 (고품질)
        anvil_x = x + 12
        anvil_y = y + h - 28

        # 모루 본체 (그라데이션 금속)
        anvil_surf = pygame.Surface((35, 18), pygame.SRCALPHA)
        for ay in range(18):
            grad = 1.0 - ay * 0.02
            color = tuple(int(c * grad) for c in (75, 75, 85))
            pygame.draw.line(anvil_surf, color, (0, ay), (35, ay))
        screen.blit(anvil_surf, (anvil_x, anvil_y))

        # 모루 뿔
        pygame.draw.polygon(screen, (70, 70, 80),
                          [(anvil_x + 35, anvil_y + 5), (anvil_x + 45, anvil_y + 8), (anvil_x + 35, anvil_y + 12)])

        # 모루 받침대
        pygame.draw.rect(screen, (55, 50, 45), (anvil_x + 8, anvil_y + 18, 20, 12))
        pygame.draw.line(screen, (70, 65, 58), (anvil_x + 9, anvil_y + 19), (anvil_x + 27, anvil_y + 19))

        # 모루 하이라이트
        pygame.draw.line(screen, (100, 100, 115), (anvil_x + 2, anvil_y + 1), (anvil_x + 33, anvil_y + 1))

        # 8. 망치 (애니메이션)
        hammer_cycle = abs(math.sin(self.animation_timer * 7))
        hammer_y_offset = hammer_cycle * 18
        hammer_x = anvil_x + 38
        hammer_y = anvil_y - 22 - hammer_y_offset

        # 망치 자루 (그라데이션 나무)
        handle_surf = pygame.Surface((5, 28), pygame.SRCALPHA)
        for hy in range(28):
            grad = 0.85 + 0.15 * abs(math.sin(hy * 0.2))
            color = tuple(int(c * grad) for c in (110, 85, 55))
            pygame.draw.line(handle_surf, color, (0, hy), (5, hy))
        screen.blit(handle_surf, (hammer_x + 8, hammer_y + 2))

        # 망치 머리 (금속)
        head_surf = pygame.Surface((24, 14), pygame.SRCALPHA)
        for hy in range(14):
            grad = 1.0 - hy * 0.03
            color = tuple(int(c * grad) for c in (95, 95, 110))
            pygame.draw.line(head_surf, color, (0, hy), (24, hy))
        screen.blit(head_surf, (hammer_x, hammer_y - 5))
        pygame.draw.line(screen, (120, 120, 135), (hammer_x + 1, hammer_y - 4), (hammer_x + 22, hammer_y - 4))

        # 9. 스파크 효과 (망치질 시)
        if hammer_cycle < 0.15 and random.random() < 0.7:
            for _ in range(5):
                self.particles[building_id].append({
                    'x': anvil_x + 22,
                    'y': anvil_y - 2,
                    'vx': random.uniform(-120, 120),
                    'vy': random.uniform(-100, -40),
                    'life': 0.4,
                    'type': 'spark',
                    'color': (255, random.randint(200, 255), random.randint(50, 150)),
                    'gravity': True
                })

        # 10. 간판 (고품질)
        sign_w = 85
        sign_h = 22
        sign_x = x + (w - sign_w) // 2
        sign_y = y + 2

        # 간판 배경 (금속)
        sign_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        for sy in range(sign_h):
            grad = 0.7 + 0.3 * (1 - sy / sign_h)
            color = tuple(int(c * grad) for c in (45, 40, 38))
            pygame.draw.line(sign_surf, color, (0, sy), (sign_w, sy))
        screen.blit(sign_surf, (sign_x, sign_y))

        # 간판 테두리 (불꽃색)
        border_pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 3))
        pygame.draw.rect(screen, (int(200 * border_pulse), int(100 * border_pulse), 30),
                        (sign_x, sign_y, sign_w, sign_h), 2, border_radius=3)

        # 간판 텍스트
        font = pygame.font.Font(None, 18)
        text = font.render("FORGE", True, Colors.NEON_ORANGE)
        screen.blit(text, (sign_x + sign_w // 2 - text.get_width() // 2, sign_y + 4))

        # 11. 앰비언트 오클루전
        self._draw_ambient_occlusion(screen, (x, y + 15, w, h - 15), 0.3)

        self._draw_particles(screen, building_id, (x, y))

    # =========================================================================
    # 🛒 아이템 상점 - 고품질 마법 에너지 스타일
    # =========================================================================
    def _draw_magic_store(self, screen, building, x, y, building_id):
        """마법 성소 - 달의 힘이 깃든 신비한 sanctuary"""
        w, h = building.width, building.height

        # 1. 고급 3D 그림자
        self._draw_3d_shadow(screen, x, y, w, h, depth=10)

        # 2. 배경 마법 글로우 (다층)
        pulse = 0.5 + 0.5 * abs(math.sin(self.animation_timer * 2))
        for i in range(3):
            glow_surf = pygame.Surface((w + 50 + i * 15, h + 50 + i * 15), pygame.SRCALPHA)
            alpha = int((40 - i * 10) * pulse)
            color = (100 + i * 30, 120 + i * 20, 255)
            pygame.draw.ellipse(glow_surf, (*color, alpha), (0, 0, w + 50 + i * 15, h + 50 + i * 15))
            screen.blit(glow_surf, (x - 25 - i * 7, y - 25 - i * 7))

        # 3. 메인 건물 (마법 보라색 그라데이션)
        main_surf = pygame.Surface((w, h - 12), pygame.SRCALPHA)
        for my in range(h - 12):
            # 위아래 그라데이션 + 마법 빛
            grad = 0.85 + 0.15 * (my / (h - 12))
            magic_tint = abs(math.sin(self.animation_timer * 1.5 + my * 0.02)) * 0.1
            r = int((45 + magic_tint * 30) * grad)
            g = int((32 + magic_tint * 20) * grad)
            b = int((70 + magic_tint * 40) * grad)
            pygame.draw.line(main_surf, (r, g, b), (0, my), (w, my))
        screen.blit(main_surf, (x, y + 12))

        # 마법 벽돌 텍스처 (보라색)
        for row in range(0, h - 30, 12):
            offset = 8 if (row // 12) % 2 else 0
            for col in range(-offset, w, 22):
                bx = x + col + 2
                by = y + 18 + row
                if x + 2 <= bx < x + w - 22:
                    # 벽돌 (미세한 그라데이션)
                    brick_surf = pygame.Surface((20, 10), pygame.SRCALPHA)
                    for bi in range(10):
                        grad = 1.0 - bi * 0.03
                        pygame.draw.line(brick_surf, (int(55 * grad), int(42 * grad), int(80 * grad)),
                                        (0, bi), (20, bi))
                    screen.blit(brick_surf, (bx, by))

        # 4. 지붕 (마법사 모자 - 고품질 그라데이션)
        roof_points = [
            (x - 12, y + 18),
            (x + w // 2, y - 40),
            (x + w + 12, y + 18)
        ]

        # 지붕 그라데이션 (보라색 → 어두운 보라)
        roof_surf = pygame.Surface((w + 30, 60), pygame.SRCALPHA)
        for ry in range(60):
            grad = 0.7 + 0.3 * (ry / 60)
            color = tuple(int(c * grad) for c in (70, 45, 115))
            pygame.draw.line(roof_surf, color, (0, ry), (w + 30, ry))

        pygame.draw.polygon(screen, (70, 45, 115), roof_points)

        # 지붕 테두리 (글로우)
        for i in range(3):
            border_pulse = 0.6 + 0.4 * abs(math.sin(self.animation_timer * 3 + i * 0.5))
            alpha = int((180 - i * 40) * border_pulse)
            pygame.draw.polygon(screen, (120, 80, 180, alpha), roof_points, 3 - i)

        # 지붕 별무늬 텍스처
        for i in range(8):
            star_px = x + 10 + i * (w // 8)
            star_py = y + 5 - abs(star_px - x - w // 2) * 0.3
            star_size = 3 + random.Random(i * 789).randint(0, 2)
            star_alpha = int(100 + 100 * abs(math.sin(self.animation_timer * 4 + i)))
            self._draw_magic_star_small(screen, star_px, int(star_py), star_size, (200, 180, 255, star_alpha))

        # 5. 지붕 꼭대기 달 장식 (대형 - 초승달)
        moon_x = x + w // 2
        moon_y = y - 32

        # 달 글로우 (은은한 청백색)
        moon_glow = self._create_soft_glow(28, (180, 200, 255), pulse)
        screen.blit(moon_glow, (moon_x - 28, moon_y - 28))

        self._draw_crescent_moon(screen, moon_x, moon_y, 16, pulse)

        # 6. 마법 룬 문양 (회전 + 글로우)
        rune_y = y + h // 2 - 5
        for i in range(3):
            rune_x = x + 18 + i * (w - 36) // 2
            angle = self.animation_timer * 2 + i * (math.pi * 2 / 3)
            rune_pulse = 0.6 + 0.4 * abs(math.sin(angle))

            # 룬 글로우
            rune_glow = pygame.Surface((30, 30), pygame.SRCALPHA)
            pygame.draw.circle(rune_glow, (150, 100, 255, int(60 * rune_pulse)), (15, 15), 15)
            screen.blit(rune_glow, (rune_x - 15, rune_y - 15))

            rune_color = (int(150 + 50 * math.sin(angle)), 100, 255)
            self._draw_rune_hq(screen, rune_x, rune_y, rune_color, angle)

        # 7. 진열창 (고품질)
        window_w = w - 28
        window_h = 38
        window_x = x + 14
        window_y = y + 32

        # 진열창 배경 (깊은 보라)
        window_surf = pygame.Surface((window_w, window_h), pygame.SRCALPHA)
        for wy in range(window_h):
            grad = 0.6 + 0.4 * (wy / window_h)
            pygame.draw.line(window_surf, (int(25 * grad), int(20 * grad), int(50 * grad), 240),
                            (0, wy), (window_w, wy))
        screen.blit(window_surf, (window_x, window_y))

        # 진열창 프레임 (네온)
        for i in range(3):
            frame_pulse = 0.5 + 0.5 * abs(math.sin(self.animation_timer * 4 + i * 0.3))
            alpha = int((200 - i * 50) * frame_pulse)
            pygame.draw.rect(screen, (120, 160, 255, alpha),
                            (window_x - i, window_y - i, window_w + i * 2, window_h + i * 2), 2, border_radius=5)

        # 8. 진열된 아이템들 (고품질 회전 + 반짝임)
        item_colors = [(200, 100, 255), (100, 200, 255), (255, 200, 100), (100, 255, 150)]
        item_count = min(4, (window_w - 10) // 22)
        for i in range(item_count):
            ix = window_x + 12 + i * 22
            iy = window_y + window_h // 2

            # 아이템 부유 + 회전
            bounce = math.sin(self.animation_timer * 3 + i * 0.8) * 5
            rotation = self.animation_timer * 2 + i * 0.5

            # 아이템 글로우
            item_glow = pygame.Surface((20, 20), pygame.SRCALPHA)
            glow_alpha = int(80 + 40 * abs(math.sin(self.animation_timer * 4 + i)))
            pygame.draw.circle(item_glow, (*item_colors[i], glow_alpha), (10, 10), 10)
            screen.blit(item_glow, (ix - 10, int(iy + bounce) - 10))

            # 아이템 본체 (보석 형태)
            self._draw_gem_item(screen, ix, int(iy + bounce), 8, item_colors[i], rotation)

        # 9. 문 (아치형 - 고품질)
        door_w, door_h = 32, 48
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        # 문 본체 (그라데이션)
        door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
        for dy in range(door_h):
            grad = 0.7 + 0.3 * (dy / door_h)
            pygame.draw.line(door_surf, (int(55 * grad), int(35 * grad), int(80 * grad)),
                            (0, dy), (door_w, dy))
        screen.blit(door_surf, (door_x, door_y))

        # 문 아치 (다층 네온)
        for i in range(4):
            arc_pulse = 0.5 + 0.5 * abs(math.sin(self.animation_timer * 3 + i * 0.4))
            alpha = int((200 - i * 40) * arc_pulse)
            pygame.draw.arc(screen, (120, 160, 255, alpha),
                           (door_x - 6 - i * 2, door_y - 12 - i, door_w + 12 + i * 4, 28 + i * 2),
                           0, math.pi, 3 - i)

        # 문 룬 장식
        self._draw_rune_hq(screen, door_x + door_w // 2, door_y + 15, (150, 120, 200), self.animation_timer * 1.5)

        # 10. 간판 (떠다니는 마법 효과)
        sign_y_offset = math.sin(self.animation_timer * 2) * 4
        sign_w, sign_h = 90, 28
        sign_x = x + (w - sign_w) // 2
        sign_y = y - 8 + sign_y_offset

        # 간판 글로우
        sign_glow = pygame.Surface((sign_w + 20, sign_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(sign_glow, (150, 100, 255, int(60 * pulse)),
                        (0, 0, sign_w + 20, sign_h + 20), border_radius=10)
        screen.blit(sign_glow, (sign_x - 10, sign_y - 10))

        # 간판 본체
        sign_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        for sy in range(sign_h):
            grad = 0.6 + 0.4 * (1 - sy / sign_h)
            pygame.draw.line(sign_surf, (int(50 * grad), int(38 * grad), int(75 * grad), 245),
                            (0, sy), (sign_w, sy))
        screen.blit(sign_surf, (sign_x, sign_y))

        # 간판 테두리 (네온)
        for i in range(2):
            border_alpha = int((200 - i * 60) * pulse)
            pygame.draw.rect(screen, (170, 120, 255, border_alpha),
                            (sign_x - i, sign_y - i, sign_w + i * 2, sign_h + i * 2), 2, border_radius=6)

        # 간판 텍스트 (깜빡임 - 마법 성소)
        font = pygame.font.Font(None, 16)
        text = "SANCTUARY"
        for i, char in enumerate(text):
            char_pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 5 + i * 0.3))
            # 은은한 청백색 글로우
            char_color = (int(180 * char_pulse), int(200 * char_pulse), int(255 * char_pulse))
            char_surf = font.render(char, True, char_color)
            screen.blit(char_surf, (sign_x + 6 + i * 9, sign_y + 8))

        # 11. 마법 파티클 (다양한 효과)
        if random.random() < 0.2:
            self.particles[building_id].append({
                'x': x + random.randint(5, w - 5),
                'y': y + h,
                'vx': random.uniform(-25, 25),
                'vy': random.uniform(-70, -35),
                'life': 1.8,
                'type': 'magic',
                'color': random.choice([(120, 160, 255), (200, 120, 255), (160, 255, 220), (255, 200, 150)])
            })

        # 12. 앰비언트 오클루전
        self._draw_ambient_occlusion(screen, (x, y + 10, w, h - 10), 0.25)

        self._draw_particles(screen, building_id, (x, y))

    def _draw_magic_star_small(self, screen, x, y, size, color):
        """작은 마법 별"""
        points = []
        for i in range(8):
            angle = math.pi / 4 + i * math.pi / 4
            r = size if i % 2 == 0 else size * 0.4
            px = x + r * math.cos(angle)
            py = y - r * math.sin(angle)
            points.append((px, py))
        if len(points) >= 3:
            pygame.draw.polygon(screen, color[:3], points)

    def _draw_magic_star_hq(self, screen, x, y, size, color):
        """고품질 마법 별"""
        # 외곽 별
        points_outer = []
        for i in range(10):
            angle = -math.pi / 2 + i * math.pi / 5
            r = size if i % 2 == 0 else size * 0.4
            r += math.sin(self.animation_timer * 6) * 2
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points_outer.append((px, py))
        pygame.draw.polygon(screen, color, points_outer)

        # 내부 밝은 별
        points_inner = []
        inner_size = size * 0.6
        for i in range(10):
            angle = -math.pi / 2 + i * math.pi / 5
            r = inner_size if i % 2 == 0 else inner_size * 0.4
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points_inner.append((px, py))
        bright_color = tuple(min(255, c + 80) for c in color[:3])
        pygame.draw.polygon(screen, bright_color, points_inner)

    def _draw_rune_hq(self, screen, x, y, color, rotation=0):
        """고품질 룬 문양"""
        size = 14

        # 외곽 원 (회전하는 점선 효과)
        for i in range(12):
            angle = rotation + i * math.pi / 6
            px = x + size * math.cos(angle)
            py = y + size * math.sin(angle)
            alpha = int(150 + 100 * abs(math.sin(angle + self.animation_timer * 3)))
            pygame.draw.circle(screen, (*color, alpha), (int(px), int(py)), 2)

        # 내부 문양
        pygame.draw.circle(screen, color, (x, y), size - 4, 2)

        # 십자 문양 (회전)
        cross_len = size - 5
        for i in range(4):
            angle = rotation + i * math.pi / 2
            ex = x + cross_len * math.cos(angle)
            ey = y + cross_len * math.sin(angle)
            pygame.draw.line(screen, color, (x, y), (int(ex), int(ey)), 2)

    def _draw_gem_item(self, screen, x, y, size, color, rotation=0):
        """보석 아이템 그리기"""
        # 다이아몬드 형태
        points = [
            (x, y - size),      # 상단
            (x + size, y),      # 우측
            (x, y + size * 0.7),  # 하단
            (x - size, y)       # 좌측
        ]

        # 회전 적용
        cos_r = math.cos(rotation * 0.3)
        sin_r = math.sin(rotation * 0.3)
        rotated_points = []
        for px, py in points:
            dx, dy = px - x, py - y
            rx = x + dx * cos_r - dy * sin_r
            ry = y + dx * sin_r + dy * cos_r
            rotated_points.append((rx, ry))

        # 보석 본체
        pygame.draw.polygon(screen, color, rotated_points)

        # 하이라이트
        bright = tuple(min(255, c + 100) for c in color)
        if len(rotated_points) >= 2:
            pygame.draw.line(screen, bright, rotated_points[0], rotated_points[1], 1)

    def _draw_crescent_moon(self, screen, x, y, size, pulse):
        """초승달 그리기 (애니메이션 포함)"""
        # 전체 원 (달)
        moon_color = (220, 230, 255)
        pygame.draw.circle(screen, moon_color, (int(x), int(y)), size)

        # 그림자 원 (오른쪽에서 가리기) - 초승달 효과
        shadow_offset = int(size * 0.5)  # 초승달 두께 조절
        shadow_x = int(x + shadow_offset)
        shadow_y = int(y)
        shadow_color = (10, 10, 20)  # 어두운 배경색
        pygame.draw.circle(screen, shadow_color, (shadow_x, shadow_y), size)

        # 달 표면 디테일 (크레이터 3개)
        crater_alpha = int(80 * pulse)
        crater_color = (180, 190, 220, crater_alpha)

        # 작은 크레이터들
        if size > 10:
            pygame.draw.circle(screen, crater_color, (int(x - size * 0.3), int(y - size * 0.2)), max(2, size // 8))
            pygame.draw.circle(screen, crater_color, (int(x - size * 0.1), int(y + size * 0.3)), max(1, size // 10))
            pygame.draw.circle(screen, crater_color, (int(x - size * 0.5), int(y + size * 0.1)), max(2, size // 9))

        # 달빛 반짝임 (가장자리)
        sparkle_alpha = int(150 + 105 * pulse)
        sparkle_color = (255, 255, 255, sparkle_alpha)
        if size > 8:
            # 왼쪽 가장자리 반짝임
            pygame.draw.circle(screen, sparkle_color, (int(x - size * 0.7), int(y)), max(2, size // 6))

    def _draw_magic_star(self, screen, x, y, size, color):
        """마법 별 그리기"""
        points = []
        for i in range(10):
            angle = math.pi / 2 + i * math.pi / 5
            r = size if i % 2 == 0 else size * 0.4
            r += math.sin(self.animation_timer * 5) * 2
            px = x + r * math.cos(angle)
            py = y - r * math.sin(angle)
            points.append((px, py))
        pygame.draw.polygon(screen, color, points)

    def _draw_rune(self, screen, x, y, color):
        """룬 문양 그리기"""
        size = 12
        pygame.draw.circle(screen, color, (x, y), size, 2)
        # 내부 문양
        pygame.draw.line(screen, color, (x - 5, y - 5), (x + 5, y + 5), 2)
        pygame.draw.line(screen, color, (x + 5, y - 5), (x - 5, y + 5), 2)

    # =========================================================================
    # 🐾 펫 상점 - 고품질 자연/숲 스타일
    # =========================================================================
    def _draw_pet_shop(self, screen, building, x, y, building_id):
        """펫 상점 - 고품질 자연친화적 디자인"""
        w, h = building.width, building.height

        # 1. 고급 3D 그림자
        self._draw_3d_shadow(screen, x, y, w, h, depth=10)

        # 2. 배경 자연 글로우
        nature_pulse = 0.5 + 0.3 * abs(math.sin(self.animation_timer * 1.5))
        ambient_glow = pygame.Surface((w + 40, h + 40), pygame.SRCALPHA)
        pygame.draw.ellipse(ambient_glow, (100, 180, 80, int(30 * nature_pulse)),
                           (0, 0, w + 40, h + 40))
        screen.blit(ambient_glow, (x - 20, y - 20))

        # 3. 풀/덩굴 배경 (고품질)
        for i in range(8):
            vine_seed = random.Random(i * 12345)
            vine_x = x + vine_seed.randint(5, w - 5)
            vine_h = vine_seed.randint(25, 50)
            vine_curve = vine_seed.randint(-15, 15)

            # 덩굴 줄기 (그라데이션)
            for j in range(vine_h):
                grad = 0.7 + 0.3 * (j / vine_h)
                color = (int(60 * grad), int(130 * grad), int(60 * grad))
                offset = math.sin(j * 0.2) * 3 + vine_curve * (j / vine_h)
                pygame.draw.circle(screen, color, (int(vine_x + offset), y + h - j), 2)

            # 잎사귀
            for j in range(3):
                leaf_y = y + h - vine_seed.randint(10, vine_h - 5)
                leaf_x = vine_x + math.sin((leaf_y - y) * 0.2) * 3
                leaf_color = (80 + vine_seed.randint(-20, 20), 160 + vine_seed.randint(-30, 30), 70)
                pygame.draw.ellipse(screen, leaf_color, (int(leaf_x) - 4, leaf_y, 8, 5))

        # 4. 메인 건물 (나무 - 고품질 그라데이션)
        main_surf = pygame.Surface((w, h - 18), pygame.SRCALPHA)
        for my in range(h - 18):
            grad = 0.85 + 0.15 * (my / (h - 18))
            r = int(110 * grad)
            g = int(72 * grad)
            b = int(38 * grad)
            pygame.draw.line(main_surf, (r, g, b), (0, my), (w, my))
        screen.blit(main_surf, (x, y + 18))

        # 고품질 나무결 텍스처
        for i in range(0, w - 3, 6):
            for j in range(0, h - 25, 3):
                grain_seed = random.Random(i * 1000 + j)
                if grain_seed.random() < 0.3:
                    grain_color = (75 + grain_seed.randint(-10, 10),
                                  48 + grain_seed.randint(-10, 10),
                                  22 + grain_seed.randint(-5, 5))
                    pygame.draw.line(screen, grain_color,
                                    (x + i, y + 22 + j), (x + i, y + 22 + j + grain_seed.randint(2, 8)))

        # 5. 초가지붕 (고품질 - 다층 + 짚 텍스처)
        for layer in range(4):
            roof_y = y + 12 - layer * 6
            roof_w = w + 25 - layer * 8
            roof_x = x - 12 + layer * 4

            # 지붕 그라데이션
            roof_surf = pygame.Surface((roof_w, 28), pygame.SRCALPHA)
            for ry in range(28):
                grad = 0.85 + 0.15 * (1 - ry / 28)
                color = tuple(int(c * grad) for c in (195 - layer * 15, 175 - layer * 15, 115 - layer * 10))
                pygame.draw.line(roof_surf, color, (0, ry), (roof_w, ry))

            pygame.draw.ellipse(screen, (190 - layer * 15, 170 - layer * 15, 110 - layer * 10),
                              (roof_x, roof_y, roof_w, 28))

            # 짚 텍스처
            for i in range(0, roof_w, 4):
                if random.Random(layer * 1000 + i).random() < 0.6:
                    straw_color = (170 + random.Random(layer * 1000 + i).randint(-20, 20),
                                  150 + random.Random(layer * 1000 + i).randint(-20, 20),
                                  90 + random.Random(layer * 1000 + i).randint(-15, 15))
                    pygame.draw.line(screen, straw_color,
                                    (roof_x + i, roof_y + 8), (roof_x + i + 2, roof_y + 20), 1)

        # 6. 지붕 위 새 (고품질)
        bird_x = x + w - 28
        bird_y = y - 8 + math.sin(self.animation_timer * 4) * 4
        wing_flap = abs(math.sin(self.animation_timer * 8)) * 3

        # 새 그림자
        pygame.draw.ellipse(screen, (0, 0, 0, 40), (bird_x - 2, y + 6, 20, 6))

        # 새 본체 (그라데이션)
        bird_surf = pygame.Surface((18, 14), pygame.SRCALPHA)
        for by in range(14):
            grad = 1.0 - by * 0.03
            pygame.draw.line(bird_surf, (int(210 * grad), int(160 * grad), int(110 * grad)),
                            (0, by), (18, by))
        pygame.draw.ellipse(bird_surf, (210, 160, 110), (0, 2, 18, 12))
        screen.blit(bird_surf, (bird_x, int(bird_y)))

        # 새 머리
        pygame.draw.circle(screen, (215, 165, 115), (bird_x + 16, int(bird_y) + 4), 6)

        # 새 눈
        pygame.draw.circle(screen, (30, 30, 30), (bird_x + 18, int(bird_y) + 3), 2)
        pygame.draw.circle(screen, (255, 255, 255), (bird_x + 18, int(bird_y) + 2), 1)

        # 부리 (그라데이션)
        beak_points = [(bird_x + 21, int(bird_y) + 5), (bird_x + 28, int(bird_y) + 6), (bird_x + 21, int(bird_y) + 7)]
        pygame.draw.polygon(screen, (255, 200, 80), beak_points)
        pygame.draw.line(screen, (255, 220, 120), beak_points[0], beak_points[1], 1)

        # 날개 (펄럭임)
        wing_y = int(bird_y) + 5 - wing_flap
        pygame.draw.ellipse(screen, (180, 130, 80), (bird_x + 2, wing_y, 10, 6))

        # 7. 새장 창문 (고품질)
        cage_x = x + 12
        cage_y = y + 38
        cage_w, cage_h = 40, 45

        # 새장 배경 (어두운 내부)
        cage_bg = pygame.Surface((cage_w, cage_h), pygame.SRCALPHA)
        for cy in range(cage_h):
            grad = 0.5 + 0.3 * (cy / cage_h)
            pygame.draw.line(cage_bg, (int(50 * grad), int(35 * grad), int(18 * grad), 230),
                            (0, cy), (cage_w, cy))
        screen.blit(cage_bg, (cage_x, cage_y))

        # 새장 프레임 (나무)
        pygame.draw.rect(screen, (100, 65, 35), (cage_x - 3, cage_y - 3, cage_w + 6, cage_h + 6), 4, border_radius=5)
        pygame.draw.line(screen, (120, 80, 45), (cage_x - 2, cage_y - 2), (cage_x + cage_w + 1, cage_y - 2), 2)

        # 새장 바 (금속 - 그라데이션)
        for i in range(6):
            bar_x = cage_x + 5 + i * 6
            for by in range(cage_h - 8):
                grad = 0.7 + 0.3 * abs(math.sin(by * 0.1))
                bar_color = (int(160 * grad), int(130 * grad), int(90 * grad))
                pygame.draw.line(screen, bar_color, (bar_x, cage_y + 4 + by), (bar_x, cage_y + 5 + by))

        # 8. 창문 안 귀여운 펫 (고품질)
        pet_y = cage_y + 22 + math.sin(self.animation_timer * 5) * 6
        pet_x = cage_x + cage_w // 2

        # 펫 그림자
        pygame.draw.ellipse(screen, (0, 0, 0, 60), (pet_x - 10, int(pet_y) + 8, 20, 6))

        # 펫 본체 (그라데이션 - 귀여운 햄스터)
        pet_surf = pygame.Surface((22, 18), pygame.SRCALPHA)
        for py_off in range(18):
            grad = 1.0 - py_off * 0.02
            pygame.draw.line(pet_surf, (int(255 * grad), int(210 * grad), int(165 * grad)),
                            (0, py_off), (22, py_off))
        pygame.draw.ellipse(pet_surf, (255, 210, 165), (0, 0, 22, 18))
        screen.blit(pet_surf, (pet_x - 11, int(pet_y) - 5))

        # 펫 귀
        pygame.draw.ellipse(screen, (255, 190, 145), (pet_x - 10, int(pet_y) - 10, 8, 8))
        pygame.draw.ellipse(screen, (255, 190, 145), (pet_x + 2, int(pet_y) - 10, 8, 8))
        pygame.draw.ellipse(screen, (255, 160, 140), (pet_x - 8, int(pet_y) - 8, 4, 4))
        pygame.draw.ellipse(screen, (255, 160, 140), (pet_x + 4, int(pet_y) - 8, 4, 4))

        # 펫 눈 (반짝이는)
        eye_sparkle = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 6))
        pygame.draw.circle(screen, (40, 40, 40), (pet_x - 4, int(pet_y) - 1), 4)
        pygame.draw.circle(screen, (40, 40, 40), (pet_x + 4, int(pet_y) - 1), 4)
        pygame.draw.circle(screen, (int(255 * eye_sparkle), int(255 * eye_sparkle), int(255 * eye_sparkle)),
                          (pet_x - 5, int(pet_y) - 2), 2)
        pygame.draw.circle(screen, (int(255 * eye_sparkle), int(255 * eye_sparkle), int(255 * eye_sparkle)),
                          (pet_x + 3, int(pet_y) - 2), 2)

        # 펫 코/볼
        pygame.draw.ellipse(screen, (255, 150, 150), (pet_x - 12, int(pet_y) + 2, 6, 4))
        pygame.draw.ellipse(screen, (255, 150, 150), (pet_x + 6, int(pet_y) + 2, 6, 4))
        pygame.draw.circle(screen, (255, 180, 180), (pet_x, int(pet_y) + 3), 3)

        # 9. 문 (둥근 아치 - 고품질)
        door_w, door_h = 34, 50
        door_x = x + w - door_w - 12
        door_y = y + h - door_h

        # 문 본체 (나무 그라데이션)
        door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
        for dy in range(door_h):
            grad = 0.8 + 0.2 * (dy / door_h)
            pygame.draw.line(door_surf, (int(85 * grad), int(55 * grad), int(30 * grad)),
                            (0, dy), (door_w, dy))
        screen.blit(door_surf, (door_x, door_y))

        # 문 나무결
        for i in range(0, door_w, 5):
            pygame.draw.line(screen, (70, 45, 22), (door_x + i, door_y + 2), (door_x + i, door_y + door_h - 2))

        # 문 아치 (고품질)
        for i in range(4):
            arc_color = (110 - i * 10, 75 - i * 8, 45 - i * 5)
            pygame.draw.arc(screen, arc_color,
                           (door_x - 6 - i, door_y - 12 - i, door_w + 12 + i * 2, 28 + i * 2),
                           0, math.pi, 4 - i)

        # 문 손잡이
        pygame.draw.circle(screen, (180, 150, 100), (door_x + door_w - 8, door_y + door_h // 2), 4)
        pygame.draw.circle(screen, (200, 170, 120), (door_x + door_w - 9, door_y + door_h // 2 - 1), 2)

        # 10. 발자국 장식 (고품질)
        for i in range(3):
            paw_x = x + 18 + i * 28
            paw_y = y + h + 6
            self._draw_paw_print_hq(screen, paw_x, paw_y, (110, 90, 65))

        # 11. 간판 (고품질)
        sign_w, sign_h = 78, 26
        sign_x = x + (w - sign_w) // 2
        sign_y = y + 3 + math.sin(self.animation_timer * 1.5) * 2

        # 간판 배경 (나무)
        sign_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        for sy in range(sign_h):
            grad = 0.7 + 0.3 * (1 - sy / sign_h)
            pygame.draw.line(sign_surf, (int(95 * grad), int(60 * grad), int(35 * grad), 240),
                            (0, sy), (sign_w, sy))
        screen.blit(sign_surf, (sign_x, sign_y))

        # 간판 테두리
        pygame.draw.rect(screen, (120, 80, 50), (sign_x, sign_y, sign_w, sign_h), 2, border_radius=4)
        pygame.draw.line(screen, (140, 100, 65), (sign_x + 2, sign_y + 2), (sign_x + sign_w - 2, sign_y + 2))

        # 간판 텍스트
        font = pygame.font.Font(None, 17)
        text = font.render("PETS", True, Colors.TEXT_WHITE)
        screen.blit(text, (sign_x + sign_w // 2 - text.get_width() // 2, sign_y + 7))

        # 12. 나뭇잎 파티클 (다양한 색상)
        if random.random() < 0.15:
            self.particles[building_id].append({
                'x': x + random.randint(0, w),
                'y': y - 10,
                'vx': random.uniform(-35, 35),
                'vy': random.uniform(25, 50),
                'life': 2.5,
                'type': 'leaf',
                'rotation': random.uniform(0, 360),
                'color': random.choice([(110, 190, 90), (90, 165, 70), (130, 180, 60), (85, 140, 55)])
            })

        # 13. 앰비언트 오클루전
        self._draw_ambient_occlusion(screen, (x, y + 15, w, h - 15), 0.25)

        self._draw_particles(screen, building_id, (x, y))

    def _draw_paw_print_hq(self, screen, x, y, color):
        """고품질 발자국 그리기"""
        # 메인 패드 (그라데이션)
        pad_surf = pygame.Surface((16, 14), pygame.SRCALPHA)
        for py in range(14):
            grad = 1.0 - py * 0.03
            pygame.draw.line(pad_surf, (*tuple(int(c * grad) for c in color), 200),
                            (0, py), (16, py))
        pygame.draw.ellipse(pad_surf, (*color, 200), (0, 0, 16, 14))
        screen.blit(pad_surf, (x - 2, y))

        # 발가락 패드
        toe_positions = [(x - 3, y - 7), (x + 4, y - 9), (x + 11, y - 7), (x + 16, y - 4)]
        for tx, ty in toe_positions:
            pygame.draw.circle(screen, (*color, 200), (tx, ty), 4)
            pygame.draw.circle(screen, tuple(min(255, c + 30) for c in color), (tx - 1, ty - 1), 2)

    def _draw_paw_print(self, screen, x, y, color):
        """발자국 그리기"""
        pygame.draw.ellipse(screen, color, (x, y, 12, 10))
        pygame.draw.circle(screen, color, (x - 2, y - 5), 4)
        pygame.draw.circle(screen, color, (x + 5, y - 7), 4)
        pygame.draw.circle(screen, color, (x + 12, y - 5), 4)

    # =========================================================================
    # 👴 현자의 오두막 - 이집트/고대 마법 스타일 (고품질)
    # =========================================================================
    def _draw_elder_hut(self, screen, building, x, y, building_id):
        """현자의 오두막 - 피라미드/고대 이집트 (고품질)"""
        w, h = building.width, building.height

        # 3D 그림자
        self._draw_3d_shadow(screen, x, y, w, h, depth=10)

        # 신비로운 다중 글로우
        glow_pulse = abs(math.sin(self.animation_timer * 1.5))
        # 외부 글로우 (금빛)
        glow_surf = pygame.Surface((w + 80, h + 80), pygame.SRCALPHA)
        for i in range(3):
            alpha = int((30 - i * 8) * glow_pulse)
            size_offset = i * 15
            pygame.draw.ellipse(glow_surf, (255, 215, 0, alpha),
                               (size_offset, size_offset, w + 80 - size_offset * 2, h + 80 - size_offset * 2))
        screen.blit(glow_surf, (x - 40, y - 40))

        # 피라미드 형태 (그라데이션)
        pyramid_points = [
            (x + w // 2, y - 20),  # 꼭대기
            (x - 10, y + h),       # 왼쪽 하단
            (x + w + 10, y + h)    # 오른쪽 하단
        ]

        # 피라미드 본체 - 그라데이션 효과
        pyramid_surf = pygame.Surface((w + 30, h + 30), pygame.SRCALPHA)
        for i in range(h + 20):
            grad = 1.0 - i * 0.003
            color = (int(220 * grad), int(200 * grad), int(150 * grad))
            # 각 높이에서의 폭 계산
            progress = i / (h + 20)
            half_width = int((w // 2 + 10) * progress)
            cx = w // 2 + 15
            pygame.draw.line(pyramid_surf, color,
                            (cx - half_width, i), (cx + half_width, i))
        screen.blit(pyramid_surf, (x - 15, y - 20))

        # 피라미드 오른쪽 음영면 (더 어둡게)
        shadow_points = [
            (x + w // 2, y - 20),
            (x + w // 2 + 5, y + h // 3),
            (x + w + 10, y + h),
            (x + w // 2, y + h)
        ]
        shadow_surf = pygame.Surface((w + 30, h + 30), pygame.SRCALPHA)
        pygame.draw.polygon(shadow_surf, (140, 120, 80, 150),
                           [(p[0] - x + 15, p[1] - y + 20) for p in shadow_points])
        screen.blit(shadow_surf, (x - 15, y - 20))

        # 고품질 석재 텍스처
        for row in range(8):
            row_y = y + 5 + row * ((h + 15) // 8)
            progress = row / 8
            half_width = int((w // 2 + 8) * (0.1 + progress * 0.9))
            cx = x + w // 2

            # 각 행의 벽돌
            brick_count = 3 + row
            brick_width = (half_width * 2) // brick_count
            for b in range(brick_count):
                bx = cx - half_width + b * brick_width
                # 벽돌 라인
                pygame.draw.line(screen, (170, 150, 110), (bx, row_y), (bx, row_y + 8), 1)
            # 수평선
            pygame.draw.line(screen, (150, 130, 90), (cx - half_width, row_y), (cx + half_width, row_y), 1)

        # 호루스의 눈 (Eye of Horus) - 고품질
        eye_x = x + w // 2
        eye_y = y + 35

        # 눈 외부 글로우
        for i in range(4):
            glow_size = 30 - i * 5
            alpha = int((80 - i * 15) * glow_pulse)
            eye_glow = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(eye_glow, (255, 200, 50, alpha), (glow_size, glow_size), glow_size)
            screen.blit(eye_glow, (eye_x - glow_size, eye_y - glow_size))

        # 눈 외곽선 (이집트 스타일)
        self._draw_eye_of_horus(screen, eye_x, eye_y, glow_pulse)

        # 입구 (고품질)
        door_w = 28
        door_h = 45
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        # 입구 깊이감
        door_points = [
            (door_x + 4, door_y),
            (door_x + door_w - 4, door_y),
            (door_x + door_w, door_y + door_h),
            (door_x, door_y + door_h)
        ]

        # 입구 어둠 그라데이션
        for i in range(door_h):
            grad = 0.3 + (i / door_h) * 0.2
            color = (int(20 * grad), int(15 * grad), int(10 * grad))
            progress = i / door_h
            top_inset = int(4 * (1 - progress))
            pygame.draw.line(screen, color,
                            (door_x + top_inset, door_y + i),
                            (door_x + door_w - top_inset, door_y + i))

        # 입구 금 테두리
        pygame.draw.polygon(screen, (255, 215, 0), door_points, 3)
        # 입구 내부 광선
        for i in range(3):
            line_alpha = int(100 * glow_pulse)
            pygame.draw.line(screen, (255, 200, 50),
                            (door_x + door_w // 2, door_y + 10),
                            (door_x + 5 + i * 9, door_y + door_h - 5), 1)

        # 이집트 기둥 (고품질)
        for pi, px in enumerate([x + 3, x + w - 18]):
            # 기둥 그라데이션
            pillar_surf = pygame.Surface((15, h - 25), pygame.SRCALPHA)
            for py in range(h - 25):
                grad = 0.8 + 0.2 * math.sin(py * 0.1)
                color = (int(200 * grad), int(180 * grad), int(140 * grad))
                pygame.draw.line(pillar_surf, color, (0, py), (15, py))
            screen.blit(pillar_surf, (px, y + 25))

            # 기둥 음영
            pygame.draw.rect(screen, (140, 120, 90), (px, y + 25, 3, h - 25))

            # 기둥 상단 (로터스 캐피탈)
            cap_points = [
                (px - 2, y + 25),
                (px + 17, y + 25),
                (px + 15, y + 15),
                (px, y + 15)
            ]
            pygame.draw.polygon(screen, (220, 200, 160), cap_points)
            pygame.draw.polygon(screen, (255, 215, 0), cap_points, 2)

            # 상형문자 장식 (더 디테일하게)
            hieroglyph_colors = [(180, 150, 100), (150, 130, 90), (200, 170, 120)]
            for i in range(4):
                hy = y + 40 + i * 18
                # 상형문자 배경
                pygame.draw.rect(screen, hieroglyph_colors[i % 3], (px + 3, hy, 9, 12))
                # 상형문자 디테일
                if i % 3 == 0:  # 새
                    pygame.draw.ellipse(screen, (120, 100, 70), (px + 4, hy + 2, 7, 5))
                    pygame.draw.line(screen, (120, 100, 70), (px + 10, hy + 4), (px + 12, hy + 6), 1)
                elif i % 3 == 1:  # 눈
                    pygame.draw.ellipse(screen, (120, 100, 70), (px + 5, hy + 3, 5, 3))
                    pygame.draw.circle(screen, (120, 100, 70), (px + 7, hy + 4), 1)
                else:  # 앙크
                    pygame.draw.circle(screen, (120, 100, 70), (px + 7, hy + 3), 2, 1)
                    pygame.draw.line(screen, (120, 100, 70), (px + 7, hy + 5), (px + 7, hy + 10), 1)
                    pygame.draw.line(screen, (120, 100, 70), (px + 4, hy + 7), (px + 10, hy + 7), 1)

        # 피라미드 꼭대기 장식 (금 캡스톤)
        capstone_points = [
            (x + w // 2, y - 25),
            (x + w // 2 - 12, y - 5),
            (x + w // 2 + 12, y - 5)
        ]
        pygame.draw.polygon(screen, (255, 220, 100), capstone_points)
        pygame.draw.polygon(screen, (255, 255, 200), capstone_points, 2)
        # 캡스톤 빛
        pygame.draw.circle(screen, (255, 255, 200), (x + w // 2, y - 15), 5)

        # 떠다니는 고대 기호 (직접 그리기 - 4개)
        for i in range(4):
            char_x = x + 12 + i * 20
            char_y = y - 18 + math.sin(self.animation_timer * 2 + i) * 8
            char_alpha = int(180 + 75 * math.sin(self.animation_timer * 3 + i * 0.5))

            # 기호 글로우
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (255, 215, 0, int(char_alpha * 0.3)), (10, 10), 10)
            screen.blit(glow_surf, (char_x - 5, char_y - 5))

            # 이집트 기호 직접 그리기 (4개)
            symbol_surf = pygame.Surface((14, 14), pygame.SRCALPHA)
            gold = (255, 215, 0, char_alpha)
            gold_bright = (255, 240, 150, char_alpha)

            if i == 0:  # 앙크 (생명의 열쇠)
                # 상단 고리
                pygame.draw.circle(symbol_surf, gold, (7, 3), 3, 1)
                # 세로 막대
                pygame.draw.line(symbol_surf, gold, (7, 6), (7, 12), 2)
                # 가로 막대
                pygame.draw.line(symbol_surf, gold, (3, 8), (11, 8), 2)
            elif i == 1:  # 태양 원반 (라의 눈)
                # 외곽 원
                pygame.draw.circle(symbol_surf, gold, (7, 7), 5, 1)
                # 중앙 점
                pygame.draw.circle(symbol_surf, gold_bright, (7, 7), 2)
            elif i == 2:  # 피라미드
                # 삼각형
                pygame.draw.polygon(symbol_surf, gold, [(7, 1), (1, 12), (13, 12)], 2)
                # 내부 선
                pygame.draw.line(symbol_surf, gold, (7, 5), (7, 12), 1)
            else:  # 별 (4각별)
                # 수직선
                pygame.draw.line(symbol_surf, gold, (7, 1), (7, 13), 2)
                # 수평선
                pygame.draw.line(symbol_surf, gold, (1, 7), (13, 7), 2)
                # 대각선
                pygame.draw.line(symbol_surf, gold, (3, 3), (11, 11), 1)
                pygame.draw.line(symbol_surf, gold, (11, 3), (3, 11), 1)

            screen.blit(symbol_surf, (int(char_x), int(char_y)))

        # 금빛 마법 파티클
        if random.random() < 0.15:
            angle = random.uniform(0, math.pi * 2)
            self.particles[building_id].append({
                'x': x + w // 2 + random.randint(-35, 35),
                'y': y + random.randint(0, h),
                'vx': math.cos(angle) * random.uniform(5, 15),
                'vy': random.uniform(-50, -25),
                'life': 2.0,
                'type': 'ancient_magic',
                'color': random.choice([(255, 215, 0), (255, 200, 100), (255, 230, 150)])
            })

        # 앰비언트 오클루전
        self._draw_ambient_occlusion(screen, pygame.Rect(x - 10, y - 20, w + 20, h + 20), intensity=0.2)

        self._draw_particles(screen, building_id, (x, y))

    def _draw_eye_of_horus(self, screen, x, y, pulse):
        """호루스의 눈 고품질 렌더링"""
        # 눈 흰자 (그라데이션)
        eye_surf = pygame.Surface((40, 24), pygame.SRCALPHA)
        for i in range(24):
            grad = 0.9 + 0.1 * (1 - abs(i - 12) / 12)
            color = (int(255 * grad), int(250 * grad), int(220 * grad))
            pygame.draw.line(eye_surf, (*color, 230), (0, i), (40, i))
        # 눈 모양 마스크
        mask = pygame.Surface((40, 24), pygame.SRCALPHA)
        pygame.draw.ellipse(mask, (255, 255, 255, 255), (0, 0, 40, 24))
        eye_surf.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        screen.blit(eye_surf, (x - 20, y - 12))

        # 홍채 (청록색 그라데이션)
        iris_surf = pygame.Surface((20, 14), pygame.SRCALPHA)
        for i in range(7):
            radius = 7 - i
            grad = 0.5 + i * 0.07
            color = (int(30 * grad), int(120 * grad), int(180 * grad))
            pygame.draw.circle(iris_surf, (*color, 200), (10, 7), radius)
        screen.blit(iris_surf, (x - 10, y - 7))

        # 동공
        pygame.draw.circle(screen, (10, 10, 20), (x, y), 4)
        # 동공 하이라이트
        pygame.draw.circle(screen, (255, 255, 255), (x - 1, y - 1), 1)

        # 눈 아래 장식 (호루스의 눈 특유의 선)
        # 메인 라인
        pygame.draw.line(screen, (50, 130, 180), (x, y + 10), (x - 12, y + 22), 3)
        pygame.draw.line(screen, (50, 130, 180), (x - 12, y + 22), (x - 8, y + 28), 2)
        # 나선 장식
        pygame.draw.arc(screen, (50, 130, 180), (x - 20, y + 15, 15, 15), 0, math.pi, 2)
        # 눈꼬리 장식
        pygame.draw.line(screen, (50, 130, 180), (x + 15, y), (x + 25, y - 5), 2)

        # 눈 외곽선
        pygame.draw.ellipse(screen, (80, 60, 40), (x - 20, y - 12, 40, 24), 2)

    # =========================================================================
    # 🎮 아케이드 - 레트로 사이버 스타일 (고품질)
    # =========================================================================
    def _draw_arcade(self, screen, building, x, y, building_id):
        """아케이드 - 레트로 게임 스타일 (고품질)"""
        w, h = building.width, building.height

        # 3D 그림자
        self._draw_3d_shadow(screen, x, y + 10, w, h - 10, depth=8)

        # 다중 네온 글로우 배경
        glow_surf = pygame.Surface((w + 60, h + 40), pygame.SRCALPHA)
        glow_pulse = abs(math.sin(self.animation_timer * 2))
        for i, color in enumerate([Colors.NEON_PINK, Colors.NEON_CYAN, Colors.NEON_PURPLE]):
            alpha = int((25 + i * 5) * glow_pulse)
            offset = i * 10
            pygame.draw.ellipse(glow_surf, (*color, alpha),
                               (offset, offset, w + 60 - offset * 2, h + 40 - offset * 2))
        screen.blit(glow_surf, (x - 30, y - 15))

        # 메인 건물 (그라데이션)
        building_surf = pygame.Surface((w, h - 10), pygame.SRCALPHA)
        for i in range(h - 10):
            grad = 0.3 + 0.2 * (i / (h - 10))
            color = (int(35 * grad), int(35 * grad), int(60 * grad))
            pygame.draw.line(building_surf, color, (0, i), (w, i))
        screen.blit(building_surf, (x, y + 10))

        # 다중 네온 테두리
        neon_colors = [Colors.NEON_PINK, Colors.NEON_CYAN, Colors.NEON_GREEN, Colors.NEON_PURPLE]
        for i in range(4):
            offset = i * 2
            color_idx = (i + int(self.animation_timer * 3)) % len(neon_colors)
            alpha = int(200 + 55 * math.sin(self.animation_timer * 5 + i))
            neon_surf = pygame.Surface((w + offset * 2 + 4, h - 10 + offset * 2 + 4), pygame.SRCALPHA)
            pygame.draw.rect(neon_surf, (*neon_colors[color_idx], alpha),
                           (0, 0, w + offset * 2 + 4, h - 10 + offset * 2 + 4),
                           2, border_radius=5 + offset)
            screen.blit(neon_surf, (x - offset - 2, y + 10 - offset - 2))

        # 대형 스크린 (상단) - 고품질
        screen_x = x + 8
        screen_y = y + 18
        screen_w = w - 16
        screen_h = 55

        # 스크린 프레임 (그라데이션)
        frame_surf = pygame.Surface((screen_w + 8, screen_h + 8), pygame.SRCALPHA)
        for i in range(4):
            pygame.draw.rect(frame_surf, (60 - i * 10, 60 - i * 10, 80 - i * 10),
                           (i, i, screen_w + 8 - i * 2, screen_h + 8 - i * 2), 1, border_radius=3)
        screen.blit(frame_surf, (screen_x - 4, screen_y - 4))

        # 스크린 배경
        pygame.draw.rect(screen, (5, 5, 15), (screen_x, screen_y, screen_w, screen_h), border_radius=2)

        # 고품질 레트로 게임 화면
        self._draw_retro_screen_hq(screen, screen_x, screen_y, screen_w, screen_h)

        # 아케이드 기계들 (고품질)
        machine_w = 28
        machine_h = 50
        machine_colors = [(100, 50, 100), (50, 100, 100), (100, 100, 50), (100, 60, 60)]

        for i in range(min(3, (w - 20) // 32)):
            mx = x + 12 + i * 32
            my = y + h - machine_h - 8

            # 기계 그림자
            pygame.draw.rect(screen, (20, 20, 30), (mx + 3, my + 3, machine_w, machine_h), border_radius=4)

            # 기계 본체 (그라데이션)
            machine_surf = pygame.Surface((machine_w, machine_h), pygame.SRCALPHA)
            base_color = machine_colors[i % len(machine_colors)]
            for j in range(machine_h):
                grad = 0.8 + 0.2 * (j / machine_h)
                color = tuple(int(c * grad) for c in base_color)
                pygame.draw.line(machine_surf, color, (0, j), (machine_w, j))
            screen.blit(machine_surf, (mx, my))

            # 기계 화면 (CRT 효과)
            pygame.draw.rect(screen, (0, 0, 0), (mx + 3, my + 4, machine_w - 6, 22), border_radius=2)
            # 스캔라인
            for sl in range(0, 22, 2):
                pygame.draw.line(screen, (0, 15, 0), (mx + 3, my + 4 + sl), (mx + machine_w - 3, my + 4 + sl), 1)

            # 게임 그래픽 (더 디테일하게)
            game_type = i % 3
            if game_type == 0:  # 스페이스 인베이더
                self._draw_mini_invader(screen, mx + 10, my + 10)
            elif game_type == 1:  # 팩맨
                self._draw_mini_pacman(screen, mx + 8, my + 12)
            else:  # 테트리스
                self._draw_mini_tetris(screen, mx + 5, my + 8)

            # 컨트롤 패널
            pygame.draw.rect(screen, (40, 40, 50), (mx + 2, my + 28, machine_w - 4, 18), border_radius=2)
            # 조이스틱
            pygame.draw.circle(screen, (30, 30, 35), (mx + 10, my + 37), 5)
            pygame.draw.circle(screen, (60, 60, 70), (mx + 10, my + 37), 4)
            # 버튼들
            btn_colors = [Colors.NEON_PINK, Colors.NEON_CYAN, Colors.NEON_GREEN]
            for bi in range(2):
                btn_pulse = abs(math.sin(self.animation_timer * 4 + i + bi))
                pygame.draw.circle(screen, tuple(int(c * (0.6 + 0.4 * btn_pulse)) for c in btn_colors[bi]),
                                  (mx + 20 + bi * 6, my + 37), 3)

        # ARCADE 네온 간판 (고품질)
        sign_y = y - 8
        text = "ARCADE"
        font = pygame.font.Font(None, 24)  # 폰트 크기 축소

        # 간판 배경
        sign_bg = pygame.Surface((w - 10, 22), pygame.SRCALPHA)
        pygame.draw.rect(sign_bg, (20, 20, 30, 200), (0, 0, w - 10, 22), border_radius=5)
        screen.blit(sign_bg, (x + 5, sign_y - 3))

        # 각 글자 개별 네온 효과 (간격 조정)
        char_spacing = (w - 24) // len(text)  # 건물 폭에 맞게 간격 계산
        start_x = x + 12
        for i, char in enumerate(text):
            char_x = start_x + i * char_spacing
            color_idx = (i + int(self.animation_timer * 6)) % len(neon_colors)
            char_color = neon_colors[color_idx]

            # 글자 글로우
            glow_surf = pygame.Surface((18, 22), pygame.SRCALPHA)
            glow_text = font.render(char, True, (*char_color, 100))
            glow_surf.blit(glow_text, (2, 2))
            screen.blit(glow_surf, (char_x - 2, sign_y - 2))

            # 메인 글자
            char_surf = font.render(char, True, char_color)
            screen.blit(char_surf, (char_x, sign_y))

        # 지붕 장식 (깜빡이는 조명)
        for i in range(5):
            light_x = x + 10 + i * (w - 20) // 4
            light_y = y + 5
            blink = abs(math.sin(self.animation_timer * 8 + i * 0.7))
            light_color = neon_colors[i % len(neon_colors)]
            # 글로우
            glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*light_color, int(80 * blink)), (8, 8), 8)
            screen.blit(glow_surf, (light_x - 8, light_y - 8))
            # 전구
            pygame.draw.circle(screen, tuple(int(c * (0.5 + 0.5 * blink)) for c in light_color),
                              (light_x, light_y), 4)

        # 픽셀 파티클 (더 다양하게)
        if random.random() < 0.25:
            self.particles[building_id].append({
                'x': x + random.randint(5, w - 5),
                'y': y + random.randint(10, h - 10),
                'vx': random.uniform(-20, 20),
                'vy': random.uniform(-30, -10),
                'life': 0.5,
                'type': 'pixel',
                'color': random.choice(neon_colors)
            })

        # 앰비언트 오클루전
        self._draw_ambient_occlusion(screen, pygame.Rect(x, y + 10, w, h - 10), intensity=0.25)

        self._draw_particles(screen, building_id, (x, y))

    def _draw_mini_invader(self, screen, x, y):
        """미니 스페이스 인베이더"""
        inv_color = Colors.NEON_GREEN
        # 인베이더 픽셀
        pixels = [(0, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)]
        for px, py in pixels:
            pygame.draw.rect(screen, inv_color, (x + px * 3, y + py * 3, 2, 2))
        # 플레이어
        pygame.draw.rect(screen, Colors.NEON_CYAN, (x, y + 12, 8, 3))
        pygame.draw.rect(screen, Colors.NEON_CYAN, (x + 3, y + 10, 2, 2))

    def _draw_mini_pacman(self, screen, x, y):
        """미니 팩맨"""
        # 팩맨
        mouth = abs(math.sin(self.animation_timer * 10)) * 0.3
        pygame.draw.circle(screen, Colors.NEON_YELLOW, (x + 5, y + 5), 5)
        pygame.draw.polygon(screen, (0, 0, 0), [
            (x + 5, y + 5),
            (x + 12, y + 2),
            (x + 12, y + 8)
        ])
        # 점
        for i in range(3):
            pygame.draw.circle(screen, Colors.TEXT_WHITE, (x + 15 + i * 4, y + 5), 1)

    def _draw_mini_tetris(self, screen, x, y):
        """미니 테트리스"""
        colors = [Colors.NEON_CYAN, Colors.NEON_PINK, Colors.NEON_GREEN, Colors.NEON_ORANGE]
        # 떨어지는 블록
        pygame.draw.rect(screen, colors[0], (x + 8, y + 2, 6, 3))
        pygame.draw.rect(screen, colors[0], (x + 8, y + 5, 3, 3))
        # 쌓인 블록들
        blocks = [(0, 12), (3, 12), (6, 12), (9, 12), (12, 12),
                  (3, 9), (6, 9), (9, 9), (6, 6)]
        for i, (bx, by) in enumerate(blocks):
            pygame.draw.rect(screen, colors[i % len(colors)], (x + bx, y + by, 3, 3))

    def _draw_retro_screen_hq(self, screen, x, y, w, h):
        """고품질 레트로 게임 화면"""
        # CRT 스캔라인 효과
        for i in range(0, h, 2):
            alpha = 30 + int(20 * math.sin(i * 0.5))
            pygame.draw.line(screen, (0, alpha, 0), (x, y + i), (x + w, y + i), 1)

        # CRT 곡면 효과 (가장자리 어둡게)
        vignette = pygame.Surface((w, h), pygame.SRCALPHA)
        for i in range(min(w, h) // 4):
            alpha = int(80 * (1 - i / (min(w, h) // 4)))
            pygame.draw.rect(vignette, (0, 0, 0, alpha), (i, i, w - i * 2, h - i * 2), 1)
        screen.blit(vignette, (x, y))

        # 게임 화면: 팩맨 (더 디테일하게)
        pacman_x = x + 15 + (int(self.animation_timer * 40) % (w - 40))
        pacman_y = y + h // 2

        # 유령들
        ghost_colors = [Colors.NEON_PINK, Colors.NEON_CYAN, Colors.NEON_ORANGE]
        for i, gc in enumerate(ghost_colors):
            ghost_x = pacman_x + 25 + i * 12
            if ghost_x < x + w - 10:
                # 유령 몸체
                pygame.draw.circle(screen, gc, (int(ghost_x), pacman_y - 2), 6)
                pygame.draw.rect(screen, gc, (int(ghost_x) - 6, pacman_y - 2, 12, 6))
                # 유령 눈
                pygame.draw.circle(screen, Colors.TEXT_WHITE, (int(ghost_x) - 2, pacman_y - 3), 2)
                pygame.draw.circle(screen, Colors.TEXT_WHITE, (int(ghost_x) + 2, pacman_y - 3), 2)
                pygame.draw.circle(screen, (0, 0, 100), (int(ghost_x) - 2, pacman_y - 3), 1)
                pygame.draw.circle(screen, (0, 0, 100), (int(ghost_x) + 2, pacman_y - 3), 1)

        # 팩맨 (애니메이션)
        mouth_open = abs(math.sin(self.animation_timer * 12)) * 40
        pygame.draw.circle(screen, Colors.NEON_YELLOW, (int(pacman_x), pacman_y), 10)
        # 입 애니메이션
        if mouth_open > 5:
            pygame.draw.polygon(screen, (5, 5, 15), [
                (pacman_x, pacman_y),
                (pacman_x + 12, pacman_y - int(mouth_open / 4)),
                (pacman_x + 12, pacman_y + int(mouth_open / 4))
            ])
        # 눈
        pygame.draw.circle(screen, (5, 5, 15), (int(pacman_x) - 2, pacman_y - 4), 2)

        # 점들
        for i in range(6):
            dot_x = x + 25 + i * 12
            if dot_x > pacman_x + 12:
                # 일반 점
                pygame.draw.circle(screen, Colors.TEXT_WHITE, (dot_x, pacman_y), 2)
                if i == 3:  # 파워 펠릿
                    pulse = abs(math.sin(self.animation_timer * 6))
                    pygame.draw.circle(screen, (255, 255, int(200 * pulse)), (dot_x, pacman_y), 4)

        # HIGH SCORE 텍스트 (스크린 안에 맞춤)
        font = pygame.font.Font(None, 12)
        score_text = font.render("HI:99999", True, Colors.TEXT_WHITE)
        screen.blit(score_text, (x + 3, y + 2))

    # =========================================================================
    # 🍺 선술집 - 세련된 중세 판타지 선술집 (Ultra Premium)
    # =========================================================================
    def _draw_tavern(self, screen, building, x, y, building_id):
        """선술집 - 고급 중세 목조 선술집 (Ultra Premium Quality)"""
        w, h = building.width, building.height

        # 3D 그림자 (더 깊게)
        self._draw_3d_shadow(screen, x - 12, y + 12, w + 24, h - 10, depth=14)

        # 따뜻한 분위기 글로우 (다중 레이어 - 더 화려하게)
        for i in range(4):
            glow_surf = pygame.Surface((w + 80 - i * 18, h + 50 - i * 12), pygame.SRCALPHA)
            pulse = 0.5 + 0.5 * abs(math.sin(self.animation_timer * 1.8 + i * 0.4))
            alpha = int((50 - i * 10) * pulse)
            pygame.draw.ellipse(glow_surf, (255, 160, 60, alpha),
                               (0, 0, w + 80 - i * 18, h + 50 - i * 12))
            screen.blit(glow_surf, (x - 40 + i * 9, y - 15 + i * 6))

        # 색상 팔레트 (고급 목재 톤)
        wood_dark = (50, 28, 15)
        wood_color = (85, 50, 30)
        wood_mid = (105, 65, 40)
        wood_light = (135, 90, 55)
        wood_highlight = (165, 115, 75)

        # 벽 색상 (따뜻한 크림색)
        wall_dark = (175, 160, 135)
        wall_color = (205, 190, 165)
        wall_light = (230, 218, 195)

        # === 기초 (고품질 돌 - 코블스톤) ===
        foundation_h = 18
        foundation_surf = pygame.Surface((w + 18, foundation_h), pygame.SRCALPHA)
        for i in range(foundation_h):
            grad = 0.65 + 0.35 * (i / foundation_h)
            color = (int(95 * grad), int(85 * grad), int(75 * grad))
            pygame.draw.line(foundation_surf, color, (0, i), (w + 18, i))
        screen.blit(foundation_surf, (x - 9, y + h - 14))

        # 돌 텍스처 (불규칙한 코블스톤)
        stone_positions = [0, 18, 38, 56, 76, 95]
        for i, sx in enumerate(stone_positions):
            if sx < w + 10:
                pygame.draw.line(screen, (65, 55, 45), (x - 7 + sx, y + h - 14), (x - 7 + sx, y + h + 2), 1)
        for sy in range(2):
            pygame.draw.line(screen, (70, 60, 50), (x - 9, y + h - 14 + sy * 8), (x + w + 9, y + h - 14 + sy * 8), 1)

        # === 1층 본체 (크림색 회반죽 + 목재 프레임) ===
        floor1_h = h // 2 + 5
        floor1_surf = pygame.Surface((w + 4, floor1_h), pygame.SRCALPHA)
        for i in range(floor1_h):
            grad = 0.88 + 0.12 * (i / floor1_h)
            color = (int(wall_color[0] * grad), int(wall_color[1] * grad), int(wall_color[2] * grad))
            pygame.draw.line(floor1_surf, color, (0, i), (w + 4, i))
        screen.blit(floor1_surf, (x - 2, y + h // 2 - 5))

        # === 2층 본체 (돌출 - 튜더 스타일) ===
        floor2_overhang = 14  # 2층 돌출 정도
        floor2_h = h // 2 - 8
        floor2_surf = pygame.Surface((w + floor2_overhang * 2, floor2_h), pygame.SRCALPHA)
        for i in range(floor2_h):
            grad = 0.85 + 0.15 * (1 - i / floor2_h)
            color = (int(wall_light[0] * grad), int(wall_light[1] * grad), int(wall_light[2] * grad))
            pygame.draw.line(floor2_surf, color, (0, i), (w + floor2_overhang * 2, i))
        screen.blit(floor2_surf, (x - floor2_overhang, y + 18))

        # 2층 바닥 지지대 (목재 브라켓)
        for bx in [x - 8, x + w // 3, x + w * 2 // 3, x + w]:
            # 브라켓 삼각형
            bracket_points = [(bx, y + h // 2 - 5), (bx - 8, y + h // 2 + 8), (bx + 8, y + h // 2 + 8)]
            pygame.draw.polygon(screen, wood_color, bracket_points)
            pygame.draw.polygon(screen, wood_dark, bracket_points, 2)

        # === 목재 프레임 (하프팀버 스타일) ===
        # 메인 수직 빔 (1층)
        beam_positions_1f = [x - 2, x + w // 3, x + w * 2 // 3, x + w - 4]
        for bx in beam_positions_1f:
            beam_surf = pygame.Surface((8, floor1_h - 5), pygame.SRCALPHA)
            for i in range(8):
                grad = 0.6 + 0.4 * math.sin(i * 0.8)
                color = tuple(int(c * grad) for c in wood_mid)
                pygame.draw.line(beam_surf, color, (i, 0), (i, floor1_h - 5))
            screen.blit(beam_surf, (bx, y + h // 2 - 2))
            # 나무결 디테일
            for gy in range(0, floor1_h - 10, 12):
                pygame.draw.line(screen, wood_dark, (bx + 2, y + h // 2 + gy), (bx + 5, y + h // 2 + gy + 6), 1)

        # 메인 수직 빔 (2층)
        beam_positions_2f = [x - floor2_overhang, x + w // 2 - 4, x + w + floor2_overhang - 8]
        for bx in beam_positions_2f:
            beam_surf = pygame.Surface((8, floor2_h - 3), pygame.SRCALPHA)
            for i in range(8):
                grad = 0.6 + 0.4 * math.sin(i * 0.8)
                color = tuple(int(c * grad) for c in wood_mid)
                pygame.draw.line(beam_surf, color, (i, 0), (i, floor2_h - 3))
            screen.blit(beam_surf, (bx, y + 20))

        # 수평 빔 (층간 분리선)
        for by, bw in [(y + h // 2 - 5, w + 4), (y + 18, w + floor2_overhang * 2)]:
            bx = x - 2 if bw == w + 4 else x - floor2_overhang
            pygame.draw.rect(screen, wood_color, (bx, by, bw, 7))
            pygame.draw.line(screen, wood_highlight, (bx, by), (bx + bw, by), 1)
            pygame.draw.line(screen, wood_dark, (bx, by + 6), (bx + bw, by + 6), 1)

        # 대각선 빔 (1층 X자 패턴)
        pygame.draw.line(screen, wood_color, (x + 5, y + h // 2 + 3), (x + w // 3 - 5, y + h - 20), 5)
        pygame.draw.line(screen, wood_color, (x + w // 3 + 5, y + h - 20), (x + w // 3 - 5, y + h // 2 + 3), 5)
        pygame.draw.line(screen, wood_highlight, (x + 6, y + h // 2 + 4), (x + w // 3 - 4, y + h - 19), 1)

        # === 지붕 (고급 적갈색 기와) ===
        roof_overhang = 28
        roof_height = 45

        # 지붕 본체 그라데이션
        roof_surf = pygame.Surface((w + roof_overhang * 2, roof_height), pygame.SRCALPHA)
        for i in range(roof_height):
            progress = i / roof_height
            half_width = int((w // 2 + roof_overhang) * (1 - progress * 0.75))
            cx = w // 2 + roof_overhang
            grad = 0.65 + 0.35 * progress
            r = int(145 * grad)
            g = int(75 * grad)
            b = int(45 * grad)
            pygame.draw.line(roof_surf, (r, g, b), (cx - half_width, i), (cx + half_width, i))
        screen.blit(roof_surf, (x - roof_overhang, y - 25))

        # 기와 라인 (더 정교하게)
        for i in range(7):
            ty = y - 12 + i * 6
            progress = i / 7
            left_x = x - roof_overhang + 8 + int(progress * 18)
            right_x = x + w + roof_overhang - 8 - int(progress * 18)
            # 기와 그림자
            pygame.draw.line(screen, (70, 40, 25), (left_x, ty), (right_x, ty), 3)
            # 기와 하이라이트
            pygame.draw.line(screen, (175, 105, 70), (left_x, ty - 1), (right_x, ty - 1), 1)

        # 지붕 마루 장식
        pygame.draw.line(screen, (120, 70, 45), (x + w // 2 - 3, y - 28), (x + w // 2 + 3, y - 28), 6)
        pygame.draw.circle(screen, (150, 90, 55), (x + w // 2, y - 32), 5)

        # === 굴뚝 (고품질 벽돌) ===
        chimney_x = x + w - 22
        chimney_y = y - 28

        # 굴뚝 본체
        chimney_surf = pygame.Surface((16, 45), pygame.SRCALPHA)
        for cy in range(45):
            grad = 0.75 + 0.25 * (cy / 45)
            color = (int(125 * grad), int(85 * grad), int(70 * grad))
            pygame.draw.line(chimney_surf, color, (0, cy), (16, cy))
        screen.blit(chimney_surf, (chimney_x, chimney_y))

        # 벽돌 패턴
        for i in range(6):
            by = chimney_y + 5 + i * 7
            pygame.draw.line(screen, (85, 55, 40), (chimney_x, by), (chimney_x + 16, by), 1)
            offset = 8 if i % 2 == 0 else 0
            pygame.draw.line(screen, (85, 55, 40), (chimney_x + offset, by), (chimney_x + offset, by + 7), 1)

        # 굴뚝 상단 (캡)
        pygame.draw.rect(screen, (145, 100, 80), (chimney_x - 3, chimney_y - 4, 22, 6))
        pygame.draw.rect(screen, (165, 115, 90), (chimney_x - 2, chimney_y - 3, 20, 2))

        # 굴뚝 불빛
        glow_pulse = abs(math.sin(self.animation_timer * 4.5))
        glow_surf = pygame.Surface((20, 12), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (255, 140, 40, int(180 * glow_pulse)), (0, 0, 20, 12))
        screen.blit(glow_surf, (chimney_x - 2, chimney_y - 2))

        # 연기 파티클
        if random.random() < 0.25:
            self.particles[building_id].append({
                'x': chimney_x + 8 + random.uniform(-4, 4),
                'y': chimney_y - 5,
                'vx': random.uniform(-10, 10),
                'vy': random.uniform(-40, -25),
                'life': 3.0,
                'type': 'smoke',
                'size': random.randint(7, 14)
            })

        # === 2층 창문 (아치형 - 따뜻한 빛) ===
        window_2f_positions = [(x - 5, y + 28), (x + w - 25, y + 28)]
        for wi, (wx, wy) in enumerate(window_2f_positions):
            # 아치형 창틀
            pygame.draw.rect(screen, wood_dark, (wx - 3, wy - 3, 28, 30), border_radius=6)
            pygame.draw.rect(screen, wood_mid, (wx - 2, wy - 2, 26, 28), border_radius=5)

            # 창문 빛 (아치형)
            light_pulse = 0.6 + 0.4 * math.sin(self.animation_timer * 2.5 + wi * 1.2)
            light_surf = pygame.Surface((22, 24), pygame.SRCALPHA)
            for ly in range(24):
                grad = 0.75 + 0.25 * (ly / 24)
                r = int(255 * grad)
                g = int((175 + 50 * light_pulse) * grad)
                b = int((70 + 40 * light_pulse) * grad)
                # 아치 상단 처리
                width = 22 if ly > 5 else 22 - (5 - ly)
                offset = 0 if ly > 5 else (5 - ly) // 2
                pygame.draw.line(light_surf, (r, g, b), (offset, ly), (offset + width, ly))
            screen.blit(light_surf, (wx, wy))

            # 창살
            pygame.draw.line(screen, wood_color, (wx + 11, wy + 2), (wx + 11, wy + 22), 2)
            pygame.draw.line(screen, wood_color, (wx + 2, wy + 12), (wx + 20, wy + 12), 2)

            # 반짝임
            pygame.draw.line(screen, (255, 240, 180), (wx + 3, wy + 3), (wx + 7, wy + 7), 2)

        # === 1층 큰 창문 (술집 분위기) ===
        win1_x = x + 5
        win1_y = y + h // 2 + 8
        win1_w = w // 3 - 8
        win1_h = h // 2 - 28

        # 창틀
        pygame.draw.rect(screen, wood_dark, (win1_x - 4, win1_y - 4, win1_w + 8, win1_h + 8), border_radius=3)
        pygame.draw.rect(screen, wood_mid, (win1_x - 2, win1_y - 2, win1_w + 4, win1_h + 4), border_radius=2)

        # 창문 빛 (술집 내부 분위기)
        light_pulse = 0.5 + 0.5 * math.sin(self.animation_timer * 2)
        win_light_surf = pygame.Surface((win1_w, win1_h), pygame.SRCALPHA)
        for ly in range(win1_h):
            grad = 0.7 + 0.3 * (ly / win1_h)
            r = int(255 * grad)
            g = int((165 + 45 * light_pulse) * grad)
            b = int((60 + 35 * light_pulse) * grad)
            pygame.draw.line(win_light_surf, (r, g, b), (0, ly), (win1_w, ly))
        screen.blit(win_light_surf, (win1_x, win1_y))

        # 창살 (다이아몬드 패턴)
        for dx in range(0, win1_w, 10):
            pygame.draw.line(screen, wood_color, (win1_x + dx, win1_y), (win1_x + dx + 15, win1_y + win1_h), 1)
            pygame.draw.line(screen, wood_color, (win1_x + dx + 15, win1_y), (win1_x + dx, win1_y + win1_h), 1)

        # 창문 안 실루엣 (사람 그림자 - 활기찬 분위기)
        silhouette_surf = pygame.Surface((win1_w, win1_h), pygame.SRCALPHA)
        # 맥주잔 들고 있는 사람 실루엣
        sil_x = 8 + int(5 * math.sin(self.animation_timer * 1.5))
        pygame.draw.ellipse(silhouette_surf, (60, 40, 20, 120), (sil_x, 5, 10, 12))  # 머리
        pygame.draw.rect(silhouette_surf, (60, 40, 20, 100), (sil_x + 2, 15, 8, 15))  # 몸
        # 맥주잔
        pygame.draw.rect(silhouette_surf, (200, 180, 80, 150), (sil_x + 12, 12, 6, 10))
        screen.blit(silhouette_surf, (win1_x, win1_y))

        # === 문 (대형 아치형 - 환영하는 느낌) ===
        door_w = 36
        door_h = 58
        door_x = x + w - door_w - 12
        door_y = y + h - door_h - 10

        # 문 프레임 (아치형)
        pygame.draw.rect(screen, wood_dark, (door_x - 5, door_y - 8, door_w + 10, door_h + 12), border_radius=8)

        # 문 본체 (나무결)
        door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
        for dy in range(door_h):
            grad = 0.5 + 0.3 * math.sin(dy * 0.12) + 0.2 * (dy / door_h)
            color = (int(75 * grad), int(48 * grad), int(28 * grad))
            pygame.draw.line(door_surf, color, (0, dy), (door_w, dy))
        # 아치 상단 마스킹
        pygame.draw.rect(door_surf, (0, 0, 0, 0), (0, 0, door_w, door_h), border_radius=6)
        screen.blit(door_surf, (door_x, door_y))

        # 문 패널 (3개)
        panel_h = (door_h - 16) // 3
        for pi in range(3):
            py = door_y + 5 + pi * (panel_h + 3)
            pygame.draw.rect(screen, (55, 35, 20), (door_x + 5, py, door_w - 10, panel_h - 2), border_radius=2)
            pygame.draw.rect(screen, (95, 65, 45), (door_x + 5, py, door_w - 10, panel_h - 2), 1, border_radius=2)

        # 문 손잡이 (황동 링)
        handle_y = door_y + door_h // 2
        pygame.draw.circle(screen, (60, 45, 30), (door_x + door_w - 10, handle_y), 7)
        pygame.draw.circle(screen, (195, 160, 100), (door_x + door_w - 10, handle_y), 6)
        pygame.draw.circle(screen, (220, 190, 130), (door_x + door_w - 10, handle_y), 4, 2)
        pygame.draw.circle(screen, (255, 230, 170), (door_x + door_w - 11, handle_y - 1), 2)

        # 문 위 아치 장식
        pygame.draw.arc(screen, wood_highlight, (door_x - 2, door_y - 15, door_w + 4, 20),
                       0, math.pi, 3)

        # === 메인 간판 - 대형 맥주잔 아이콘 (건물 상단) ===
        sign_main_x = x + w // 2
        sign_main_y = y + 5

        # 간판 배경 (금속 프레임 + 나무)
        sign_w, sign_h = 50, 38

        # 간판 지지대
        pygame.draw.rect(screen, (70, 70, 80), (sign_main_x - 3, y + 18, 6, 20))
        pygame.draw.rect(screen, (100, 100, 110), (sign_main_x - 2, y + 18, 4, 20))

        # 간판 본체 (나무 + 금속 테두리)
        sign_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        # 나무 배경
        for sy in range(sign_h):
            grad = 0.65 + 0.35 * math.sin(sy * 0.15)
            color = (int(80 * grad), int(50 * grad), int(30 * grad))
            pygame.draw.line(sign_surf, color, (0, sy), (sign_w, sy))

        # 금속 테두리
        pygame.draw.rect(sign_surf, (90, 80, 60), (0, 0, sign_w, sign_h), 3, border_radius=5)
        pygame.draw.rect(sign_surf, (150, 135, 100), (2, 2, sign_w - 4, sign_h - 4), 1, border_radius=4)

        # 🍺 맥주잔 그리기 (픽셀 아트 스타일)
        beer_cx = sign_w // 2
        beer_cy = sign_h // 2

        # 맥주잔 본체 (황금색)
        mug_color = (255, 210, 80)
        mug_dark = (200, 160, 50)
        mug_light = (255, 240, 150)
        foam_color = (255, 250, 240)

        # 잔 본체
        pygame.draw.rect(sign_surf, mug_dark, (beer_cx - 8, beer_cy - 6, 16, 18), border_radius=2)
        pygame.draw.rect(sign_surf, mug_color, (beer_cx - 7, beer_cy - 5, 14, 16), border_radius=2)

        # 맥주 (황금색 액체)
        pygame.draw.rect(sign_surf, (245, 195, 60), (beer_cx - 6, beer_cy, 12, 10))

        # 거품 (상단)
        pygame.draw.ellipse(sign_surf, foam_color, (beer_cx - 7, beer_cy - 8, 14, 8))
        pygame.draw.ellipse(sign_surf, (255, 255, 255), (beer_cx - 5, beer_cy - 7, 4, 4))
        pygame.draw.ellipse(sign_surf, (255, 255, 255), (beer_cx + 1, beer_cy - 6, 3, 3))

        # 손잡이
        pygame.draw.rect(sign_surf, mug_dark, (beer_cx + 7, beer_cy - 2, 5, 12), border_radius=2)
        pygame.draw.rect(sign_surf, mug_color, (beer_cx + 8, beer_cy - 1, 3, 10), border_radius=1)

        # 하이라이트
        pygame.draw.line(sign_surf, mug_light, (beer_cx - 5, beer_cy - 3), (beer_cx - 5, beer_cy + 8), 1)

        # 물방울 효과 (맥주잔에서 떨어지는 물방울 애니메이션)
        drop_y = int((self.animation_timer * 10) % 20)
        if drop_y < 15:
            pygame.draw.circle(sign_surf, mug_light, (beer_cx - 3, beer_cy + 5 + drop_y // 3), 1)

        screen.blit(sign_surf, (sign_main_x - sign_w // 2, sign_main_y))

        # === 측면 현수막 간판 (흔들리는) ===
        hang_sign_x = x + w + 5
        hang_sign_y = y + 35

        # 쇠고리 (철제)
        for i in range(5):
            cy = y + 20 + i * 4
            pygame.draw.circle(screen, (65, 65, 75), (hang_sign_x + 20, cy), 3, 1)
            pygame.draw.circle(screen, (110, 110, 120), (hang_sign_x + 20, cy), 2, 1)

        # 현수막 간판
        hang_surf = pygame.Surface((42, 32), pygame.SRCALPHA)
        for sy in range(32):
            grad = 0.6 + 0.4 * math.sin(sy * 0.18)
            color = (int(90 * grad), int(55 * grad), int(35 * grad))
            pygame.draw.line(hang_surf, color, (0, sy), (42, sy))

        # 테두리
        pygame.draw.rect(hang_surf, (55, 35, 20), (0, 0, 42, 32), 2, border_radius=3)

        # "ALE" 텍스트 (맥주)
        try:
            font = pygame.font.Font(None, 16)
            ale_text = font.render("ALE", True, (255, 220, 150))
            hang_surf.blit(ale_text, (10, 10))
        except:
            # 폰트 없으면 간단한 장식
            pygame.draw.rect(hang_surf, (255, 220, 150), (8, 10, 26, 12), 1)

        # 간판 흔들림 애니메이션
        swing = math.sin(self.animation_timer * 1.8) * 8
        rotated_hang = pygame.transform.rotate(hang_surf, swing)
        hang_rect = rotated_hang.get_rect(center=(hang_sign_x + 21, hang_sign_y + 16))
        screen.blit(rotated_hang, hang_rect)

        # === 입구 랜턴 (양쪽) ===
        for lx in [door_x - 15, door_x + door_w + 8]:
            # 랜턴 글로우
            lantern_glow = 0.6 + 0.4 * abs(math.sin(self.animation_timer * 3.5 + lx * 0.1))
            glow_surf = pygame.Surface((28, 28), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (255, 190, 90, int(100 * lantern_glow)), (14, 14), 14)
            screen.blit(glow_surf, (lx - 6, door_y - 30))

            # 랜턴 지지대
            pygame.draw.line(screen, (60, 50, 40), (lx + 4, door_y - 25), (lx + 4, door_y - 8), 2)

            # 랜턴 본체
            pygame.draw.rect(screen, (50, 40, 30), (lx, door_y - 22, 10, 14), border_radius=2)
            pygame.draw.rect(screen, (70, 60, 45), (lx + 1, door_y - 21, 8, 1))

            # 랜턴 불빛
            light_color = (255, int(200 + 55 * lantern_glow), int(100 + 50 * lantern_glow))
            pygame.draw.rect(screen, light_color, (lx + 2, door_y - 19, 6, 10))

        # === 맥주통 장식 (건물 옆) ===
        barrel_x = x - 20
        barrel_y = y + h - 28

        # 통 본체
        pygame.draw.ellipse(screen, (70, 45, 25), (barrel_x, barrel_y, 18, 25))
        pygame.draw.ellipse(screen, (95, 60, 35), (barrel_x + 2, barrel_y + 2, 14, 21))

        # 통 띠 (금속)
        pygame.draw.ellipse(screen, (90, 85, 75), (barrel_x + 1, barrel_y + 5, 16, 4), 1)
        pygame.draw.ellipse(screen, (90, 85, 75), (barrel_x + 1, barrel_y + 16, 16, 4), 1)

        # 통 하이라이트
        pygame.draw.line(screen, (130, 90, 55), (barrel_x + 5, barrel_y + 3), (barrel_x + 5, barrel_y + 22), 1)

        # 두 번째 통 (살짝 뒤에)
        pygame.draw.ellipse(screen, (60, 38, 20), (barrel_x + 12, barrel_y - 5, 16, 22))
        pygame.draw.ellipse(screen, (80, 50, 30), (barrel_x + 14, barrel_y - 3, 12, 18))
        pygame.draw.ellipse(screen, (80, 75, 65), (barrel_x + 13, barrel_y + 2, 14, 3), 1)

        # === 화분 (2층 창가) ===
        for px in [x - 8, x + w - 22]:
            # 화분
            pygame.draw.polygon(screen, (140, 85, 60),
                              [(px, y + 50), (px + 14, y + 50), (px + 12, y + 58), (px + 2, y + 58)])
            pygame.draw.line(screen, (170, 110, 75), (px + 1, y + 51), (px + 13, y + 51), 1)

            # 꽃/식물
            for fi in range(3):
                fx = px + 4 + fi * 3
                pygame.draw.line(screen, (60, 120, 50), (fx, y + 50), (fx, y + 44), 1)
                flower_color = [(255, 100, 100), (255, 200, 100), (255, 150, 200)][fi]
                pygame.draw.circle(screen, flower_color, (fx, y + 43), 3)

        # === 앰비언트 오클루전 ===
        self._draw_ambient_occlusion(screen, pygame.Rect(x - floor2_overhang, y + 18, w + floor2_overhang * 2, h - 15), intensity=0.22)

        # 파티클 렌더링
        self._draw_particles(screen, building_id, (x, y))

    # =========================================================================
    # ⭐ 스타뱅크 - 코스믹 크리스탈 은행 (초고퀄리티)
    # =========================================================================
    def _draw_bank(self, screen, building, x, y, building_id):
        """스타뱅크 - 고급 환전소 (Star Point ⇄ Gold Exchange)"""
        w, h = building.width, building.height

        # 색상 팔레트 - 우아한 고급 테마
        GOLD = (255, 215, 0)                # 순금
        GOLD_LIGHT = (255, 235, 120)        # 밝은 금
        GOLD_DARK = (200, 165, 0)           # 진한 금
        MARBLE_WHITE = (250, 248, 245)      # 대리석 흰색
        MARBLE = (235, 230, 225)            # 대리석
        MARBLE_SHADOW = (200, 195, 190)     # 대리석 그림자
        ROYAL_BLUE = (65, 105, 225)         # 로열 블루
        STAR_SILVER = (220, 220, 235)       # 별빛 은색
        ACCENT_CYAN = (100, 200, 255)       # 포인트 시안
        DEEP_PURPLE = (75, 0, 130)          # 깊은 보라

        # 애니메이션
        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 1.2))
        glow = abs(math.sin(self.animation_timer * 1.5))
        rotate = self.animation_timer * 20  # 느린 회전

        # ========================================================================
        # 1. 고급 그림자 (깊이감)
        # ========================================================================
        for i in range(12, 0, -2):
            shadow_alpha = 20 + i * 2
            shadow_surf = pygame.Surface((w + 20, 20), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (20, 15, 10, shadow_alpha),
                               (0, 0, w + 20, 18 - i // 2))
            screen.blit(shadow_surf, (x - 10, y + h + i - 8))

        # ========================================================================
        # 2. 황금 글로우 (우아한 빛)
        # ========================================================================
        for i in range(3):
            glow_size = 30 - i * 9
            glow_alpha = int((45 - i * 12) * glow)
            if glow_alpha > 0:
                glow_surf = pygame.Surface((w + glow_size * 2, h + glow_size * 2), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (*GOLD, glow_alpha),
                                (0, 0, w + glow_size * 2, h + glow_size * 2), border_radius=10)
                screen.blit(glow_surf, (x - glow_size, y - glow_size))

        # ========================================================================
        # 3. 대리석 기단 (3단 계단)
        # ========================================================================
        for i in range(3):
            step_y = y + h - 8 + i * 4
            step_w = w + 12 - i * 4
            step_x = x - 6 + i * 2

            # 대리석 그라데이션
            step_surf = pygame.Surface((int(step_w), 5), pygame.SRCALPHA)
            for sy in range(5):
                grad = 0.88 + 0.12 * (1 - sy / 5)
                color = (int(240 * grad), int(235 * grad), int(230 * grad))
                pygame.draw.line(step_surf, color, (0, sy), (int(step_w), sy))
            screen.blit(step_surf, (int(step_x), step_y))

            # 황금 테두리
            pygame.draw.line(screen, GOLD_LIGHT, (int(step_x), step_y), (int(step_x + step_w), step_y), 2)

        # ========================================================================
        # 4. 메인 건물 본체 (대리석)
        # ========================================================================
        building_surf = pygame.Surface((w, h - 25), pygame.SRCALPHA)
        for i in range(h - 25):
            grad = 0.94 + 0.06 * math.sin(i * 0.08)
            color = (int(245 * grad), int(242 * grad), int(238 * grad))
            pygame.draw.line(building_surf, color, (0, i), (w, i))
        screen.blit(building_surf, (x, y + 20))

        # 대리석 질감 (미세한 패턴)
        for i in range(5):
            vein_y = y + 28 + i * (h - 35) // 5
            vein_alpha = random.randint(15, 35)
            pygame.draw.line(screen, (*MARBLE_SHADOW, vein_alpha),
                            (x + 8, vein_y), (x + w - 8, vein_y + random.randint(-3, 3)), 1)

        # ========================================================================
        # 5. 황금 기둥 (양쪽 2개 - 우아함)
        # ========================================================================
        pillar_positions = [x + 8, x + w - 18]
        pillar_w = 10
        pillar_h = h - 30

        for px in pillar_positions:
            # 기둥 그라데이션
            for i in range(pillar_w):
                grad = 0.6 + 0.4 * abs(i - pillar_w / 2) / (pillar_w / 2)
                for py in range(pillar_h):
                    height_grad = 0.75 + 0.25 * math.sin(py * 0.06)
                    final_grad = grad * height_grad
                    color = (int(GOLD[0] * final_grad),
                            int(GOLD[1] * final_grad),
                            int(50 * final_grad))
                    screen.set_at((px + i, y + 18 + py), color)

            # 하이라이트
            pygame.draw.line(screen, GOLD_LIGHT, (px + 3, y + 18), (px + 3, y + 18 + pillar_h), 2)

        # ========================================================================
        # 6. 지붕 - 황금 아치 (우아한 곡선)
        # ========================================================================
        roof_points = [
            (x - 12, y + 20),
            (x + w // 2, y - 15),
            (x + w + 12, y + 20)
        ]

        # 지붕 그라데이션
        roof_surf = pygame.Surface((w + 30, 40), pygame.SRCALPHA)
        for i in range(40):
            grad = 0.92 - i * 0.012
            color = (int(GOLD[0] * grad), int(GOLD[1] * grad), int(60 * grad))
            progress = i / 40
            half_width = int((w // 2 + 12) * (1 - progress * 0.88))
            cx = w // 2 + 15
            pygame.draw.line(roof_surf, color, (cx - half_width, i), (cx + half_width, i))
        screen.blit(roof_surf, (x - 15, y - 15))

        # 지붕 테두리
        pygame.draw.polygon(screen, GOLD_DARK, roof_points, 4)
        inner_roof = [
            (x - 5, y + 18),
            (x + w // 2, y - 8),
            (x + w + 5, y + 18)
        ]
        pygame.draw.polygon(screen, GOLD_LIGHT, inner_roof, 2)

        # ========================================================================
        # 7. 환전 엠블렘 (★ ⇄ $ - 지붕 위)
        # ========================================================================
        emblem_y = y + 2

        # 왼쪽: 별 (스타 포인트)
        star_x = x + w // 2 - 20
        # 별 배경
        pygame.draw.circle(screen, ROYAL_BLUE, (star_x, emblem_y), 13)
        pygame.draw.circle(screen, ACCENT_CYAN, (star_x, emblem_y), 11)
        pygame.draw.circle(screen, GOLD, (star_x, emblem_y), 11, 2)

        # 5각 별
        star_points = []
        for i in range(5):
            angle_out = math.radians(i * 72 - 90)
            px = star_x + 7 * math.cos(angle_out)
            py = emblem_y + 7 * math.sin(angle_out)
            star_points.append((px, py))
            angle_in = math.radians(i * 72 + 36 - 90)
            px_in = star_x + 3 * math.cos(angle_in)
            py_in = emblem_y + 3 * math.sin(angle_in)
            star_points.append((px_in, py_in))
        pygame.draw.polygon(screen, GOLD, star_points)

        # 중앙: 교환 화살표
        arrow_x = x + w // 2
        # 이중 화살표
        pygame.draw.line(screen, GOLD_LIGHT, (star_x + 15, emblem_y), (arrow_x + 15, emblem_y), 3)
        # 화살촉
        pygame.draw.polygon(screen, GOLD_LIGHT, [
            (arrow_x + 15, emblem_y), (arrow_x + 10, emblem_y - 4), (arrow_x + 10, emblem_y + 4)
        ])
        pygame.draw.polygon(screen, GOLD_LIGHT, [
            (star_x + 15, emblem_y), (star_x + 20, emblem_y - 4), (star_x + 20, emblem_y + 4)
        ])

        # 오른쪽: 금화 (골드)
        coin_x = x + w // 2 + 20
        # 금화 글로우
        coin_glow = pygame.Surface((30, 30), pygame.SRCALPHA)
        pygame.draw.circle(coin_glow, (*GOLD, int(70 * glow)), (15, 15), 15)
        screen.blit(coin_glow, (coin_x - 15, emblem_y - 15))

        # 금화 본체 (3D)
        pygame.draw.circle(screen, GOLD_DARK, (coin_x + 1, emblem_y + 1), 12)  # 그림자
        pygame.draw.circle(screen, GOLD, (coin_x, emblem_y), 12)  # 본체
        pygame.draw.circle(screen, GOLD_LIGHT, (coin_x - 2, emblem_y - 2), 6)  # 하이라이트
        pygame.draw.circle(screen, GOLD_DARK, (coin_x, emblem_y), 12, 2)  # 테두리

        # $ 심볼
        font = pygame.font.Font(None, 22)
        dollar = font.render("$", True, (180, 140, 30))
        screen.blit(dollar, (coin_x - 5, emblem_y - 8))

        # ========================================================================
        # 8. 입구 - 고급 대리석 문
        # ========================================================================
        door_w = max(26, w // 2 + 5)
        door_h = max(38, h - 50)
        door_x = x + (w - door_w) // 2
        door_y = y + max(28, h - door_h - 8)

        # 문 프레임 (황금)
        frame_thickness = 4
        pygame.draw.rect(screen, GOLD_DARK, (door_x - frame_thickness, door_y - frame_thickness,
                        door_w + frame_thickness * 2, door_h + frame_thickness * 2), border_radius=6)
        pygame.draw.rect(screen, GOLD, (door_x - 2, door_y - 2,
                        door_w + 4, door_h + 4), border_radius=5)

        # 문 본체 (대리석 그라데이션)
        door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
        for dy in range(door_h):
            grad = 0.7 + 0.3 * (dy / door_h)
            r = int(ROYAL_BLUE[0] * (1 - grad) + MARBLE[0] * grad)
            g = int(ROYAL_BLUE[1] * (1 - grad) + MARBLE[1] * grad)
            b = int(ROYAL_BLUE[2] * (1 - grad) + MARBLE[2] * grad)
            pygame.draw.line(door_surf, (r, g, b), (0, dy), (door_w, dy))
        screen.blit(door_surf, (door_x, door_y))

        # 문 패널 (2개 - 좌우 대칭)
        panel_w = (door_w - 16) // 2
        panel_h = door_h - 16
        for panel_idx, panel_x_offset in enumerate([6, door_w // 2 + 2]):
            panel_x = door_x + panel_x_offset
            panel_y = door_y + 8

            # 패널 본체
            panel_surf = pygame.Surface((panel_w, panel_h), pygame.SRCALPHA)
            for py in range(panel_h):
                grad = 0.75 + 0.25 * math.sin(py * 0.15)
                color = (int(225 * grad), int(220 * grad), int(215 * grad))
                pygame.draw.line(panel_surf, color, (0, py), (panel_w, py))
            screen.blit(panel_surf, (panel_x, panel_y))

            # 패널 테두리 (황금)
            pygame.draw.rect(screen, GOLD, (panel_x, panel_y, panel_w, panel_h), 2, border_radius=3)

            # 패널 중앙 장식 (별/금화 번갈아)
            deco_x = panel_x + panel_w // 2
            deco_y = panel_y + panel_h // 2

            if panel_idx == 0:
                # 별 장식
                small_star = []
                for i in range(5):
                    angle = math.radians(i * 72 - 90)
                    px = deco_x + 5 * math.cos(angle)
                    py = deco_y + 5 * math.sin(angle)
                    small_star.append((px, py))
                    angle_in = math.radians(i * 72 + 36 - 90)
                    px_in = deco_x + 2 * math.cos(angle_in)
                    py_in = deco_y + 2 * math.sin(angle_in)
                    small_star.append((px_in, py_in))
                pygame.draw.polygon(screen, ACCENT_CYAN, small_star)
            else:
                # 금화 장식
                pygame.draw.circle(screen, GOLD, (deco_x, deco_y), 6)
                pygame.draw.circle(screen, GOLD_LIGHT, (deco_x - 1, deco_y - 1), 3)

        # 문 손잡이 (황금 고리)
        handle_y = door_y + door_h // 2
        for handle_x in [door_x + 10, door_x + door_w - 10]:
            pygame.draw.circle(screen, GOLD_DARK, (handle_x, handle_y), 5, 2)
            pygame.draw.circle(screen, GOLD, (handle_x, handle_y), 4, 2)

        # ========================================================================
        # 9. 명판 (StarBank)
        # ========================================================================
        plate_y = y + 12
        plate_w = 60
        plate_h = 14
        plate_x = x + (w - plate_w) // 2

        # 명판 배경
        plate_surf = pygame.Surface((plate_w, plate_h), pygame.SRCALPHA)
        for py in range(plate_h):
            grad = 0.85 + 0.15 * (1 - abs(py - plate_h / 2) / (plate_h / 2))
            color = (int(GOLD[0] * grad), int(GOLD[1] * grad), int(50 * grad))
            pygame.draw.line(plate_surf, color, (0, py), (plate_w, py))
        screen.blit(plate_surf, (plate_x, plate_y))

        # 명판 테두리
        pygame.draw.rect(screen, GOLD_DARK, (plate_x, plate_y, plate_w, plate_h), 2, border_radius=3)

        # StarBank 텍스트
        name_font = pygame.font.Font(None, 16)
        bank_text = name_font.render("StarBank", True, (80, 60, 20))
        text_rect = bank_text.get_rect(center=(plate_x + plate_w // 2, plate_y + plate_h // 2))
        screen.blit(bank_text, text_rect)

        # ========================================================================
        # 10. 우아한 장식 파티클 (절제된 반짝임)
        # ========================================================================
        sparkle_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        random.seed(building_id * 13 + int(self.animation_timer * 1.5))
        for _ in range(6):  # 적은 수의 파티클
            sx = random.randint(10, w - 10)
            sy = random.randint(15, h - 20)
            star_alpha = random.randint(150, 220)
            star_size = random.randint(1, 2)

            # 우아한 반짝임
            pygame.draw.circle(sparkle_surf, (*GOLD_LIGHT, star_alpha), (sx, sy), star_size)
            pygame.draw.line(sparkle_surf, (*GOLD_LIGHT, star_alpha // 2),
                           (sx - star_size * 3, sy), (sx + star_size * 3, sy), 1)
            pygame.draw.line(sparkle_surf, (*GOLD_LIGHT, star_alpha // 2),
                           (sx, sy - star_size * 3), (sx, sy + star_size * 3), 1)
        screen.blit(sparkle_surf, (x, y))
        random.seed()

        # 파티클 생성 (절제된)
        if random.random() < 0.05:
            self.particles[building_id].append({
                'x': x + random.randint(15, w - 15),
                'y': y + random.randint(20, h - 25),
                'vx': random.uniform(-5, 5),
                'vy': random.uniform(-18, -8),
                'life': 1.8,
                'type': 'gold_sparkle',
                'color': random.choice([GOLD, GOLD_LIGHT, ACCENT_CYAN])
            })

        # 앰비언트 오클루전
        self._draw_ambient_occlusion(screen, pygame.Rect(x - 10, y + 18, w + 20, h - 18), intensity=0.2)

        # 파티클 렌더링
        self._draw_particles(screen, building_id, (x, y))

    def _draw_academy(self, screen, building, x, y, building_id):
        """아카데미 학원 - 마법 학교 스타일 (디자인 1)"""
        w, h = building.width, building.height

        # 색상 팔레트
        STONE_GRAY = (120, 120, 130)
        STONE_DARK = (80, 80, 90)
        MAGIC_PURPLE = (150, 100, 255)
        MAGIC_BLUE = (100, 150, 255)
        WINDOW_GOLD = (255, 230, 150)
        ROOF_RED = (150, 50, 50)
        BOOK_BROWN = (139, 90, 43)

        # 애니메이션
        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 1.5))
        magic_glow = abs(math.sin(self.animation_timer * 2))
        float_offset = 5 * math.sin(self.animation_timer * 1.2)

        # 1. 마법 오라
        for i in range(4):
            aura_size = 35 - i * 8
            aura_alpha = int((70 - i * 15) * pulse)
            aura_surf = pygame.Surface((w + aura_size * 2, h + aura_size * 2), pygame.SRCALPHA)
            pygame.draw.ellipse(aura_surf, (*MAGIC_PURPLE, aura_alpha),
                               (0, 0, w + aura_size * 2, h + aura_size * 2))
            screen.blit(aura_surf, (x - aura_size, y - aura_size))

        # 2. 돌 성벽 (메인 건물)
        castle_surf = pygame.Surface((w, h - 20), pygame.SRCALPHA)
        for i in range(h - 20):
            grad = 0.7 + 0.3 * math.sin(i * 0.1)
            r = int(STONE_GRAY[0] * grad)
            g = int(STONE_GRAY[1] * grad)
            b = int(STONE_GRAY[2] * grad)
            pygame.draw.line(castle_surf, (r, g, b), (0, i), (w, i))
        screen.blit(castle_surf, (x, y + 15))

        # 돌 블록 텍스처
        for row in range(3):
            for col in range(4):
                block_x = x + 8 + col * 18
                block_y = y + 20 + row * 18
                pygame.draw.rect(screen, STONE_DARK, (block_x, block_y, 16, 16), 1)

        # 3. 탑 3개 (중앙이 제일 높음)
        towers = [
            (x + 8, y + 5, 16, h - 25),           # 왼쪽 탑
            (x + w // 2 - 10, y - 5, 20, h - 15), # 중앙 탑 (제일 높음)
            (x + w - 24, y + 5, 16, h - 25)       # 오른쪽 탑
        ]

        for tower_x, tower_y, tower_w, tower_h in towers:
            # 탑 본체
            tower_surf = pygame.Surface((tower_w, tower_h), pygame.SRCALPHA)
            for i in range(tower_h):
                grad = 0.75 + 0.25 * math.sin(i * 0.08)
                color = (int(STONE_GRAY[0] * grad), int(STONE_GRAY[1] * grad), int(STONE_GRAY[2] * grad))
                pygame.draw.line(tower_surf, color, (0, i), (tower_w, i))
            screen.blit(tower_surf, (tower_x, tower_y))

            # 탑 테두리
            pygame.draw.rect(screen, STONE_DARK, (tower_x, tower_y, tower_w, tower_h), 2)

            # 성벽 톱니 (꼭대기)
            for i in range(3):
                merlon_x = tower_x + i * (tower_w // 3)
                pygame.draw.rect(screen, STONE_GRAY, (merlon_x, tower_y - 4, tower_w // 4, 4))

            # 탑 지붕 (뾰족한 원뿔)
            roof_points = [
                (tower_x, tower_y),
                (tower_x + tower_w // 2, tower_y - 12),
                (tower_x + tower_w, tower_y)
            ]
            pygame.draw.polygon(screen, ROOF_RED, roof_points)
            pygame.draw.polygon(screen, STONE_DARK, roof_points, 2)

        # 4. 마법 창문 (빛나는)
        windows = [
            (x + w // 2 - 8, y + 25),  # 중앙 위
            (x + 18, y + 35),          # 왼쪽
            (x + w - 26, y + 35),      # 오른쪽
            (x + w // 2 - 8, y + 50)   # 중앙 아래
        ]

        for win_x, win_y in windows:
            # 창문 글로우
            glow_alpha = int(120 * magic_glow)
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*WINDOW_GOLD, glow_alpha), (0, 0, 20, 20))
            screen.blit(glow_surf, (win_x - 2, win_y - 2))

            # 창문 본체 (아치형)
            pygame.draw.rect(screen, WINDOW_GOLD, (win_x, win_y, 16, 18), border_radius=8)
            pygame.draw.line(screen, STONE_DARK, (win_x + 8, win_y), (win_x + 8, win_y + 18), 2)
            pygame.draw.line(screen, STONE_DARK, (win_x, win_y + 9), (win_x + 16, win_y + 9), 2)

        # 5. 정문 (아치형 대문)
        door_w = 22
        door_h = 30
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h - 5

        # 아치 프레임
        pygame.draw.rect(screen, STONE_DARK, (door_x - 3, door_y - 3, door_w + 6, door_h + 6), border_radius=12)

        # 문 본체
        door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
        for i in range(door_h):
            grad = 0.4 + 0.3 * (i / door_h)
            color = (int(BOOK_BROWN[0] * grad), int(BOOK_BROWN[1] * grad), int(BOOK_BROWN[2] * grad))
            pygame.draw.line(door_surf, color, (0, i), (door_w, i))
        screen.blit(door_surf, (door_x, door_y))

        # 문 장식 (마법진)
        circle_center = (door_x + door_w // 2, door_y + door_h // 2)
        pygame.draw.circle(screen, MAGIC_PURPLE, circle_center, 8, 2)
        pygame.draw.circle(screen, MAGIC_BLUE, circle_center, 5, 1)

        # 6. 떠다니는 마법책 (아카데미 상징)
        book_y = y + 8 + float_offset
        book_x = x + w // 2 - 10

        # 책 글로우
        for i in range(3):
            glow_alpha = int((90 - i * 25) * pulse)
            pygame.draw.rect(screen, (*MAGIC_BLUE, glow_alpha),
                            (book_x - i * 2, book_y - i * 2, 20 + i * 4, 14 + i * 4), border_radius=2)

        # 책 본체
        pygame.draw.rect(screen, BOOK_BROWN, (book_x, book_y, 20, 14), border_radius=2)
        pygame.draw.rect(screen, (100, 60, 20), (book_x, book_y, 20, 14), 2, border_radius=2)

        # 책 페이지
        pygame.draw.line(screen, (200, 180, 140), (book_x + 10, book_y), (book_x + 10, book_y + 14), 1)

        # 마법 기호
        pygame.draw.circle(screen, MAGIC_PURPLE, (book_x + 10, book_y + 7), 3)

        # 7. Academy 각인
        title_y = y + h - 12
        title_font = pygame.font.Font(None, 14)

        # 마법 글로우
        for offset in range(2, 0, -1):
            glow_alpha = int((80 - offset * 30) * magic_glow)
            glow_text = title_font.render("ACADEMY", True, (*MAGIC_PURPLE, glow_alpha))
            glow_rect = glow_text.get_rect(center=(x + w // 2, title_y))
            screen.blit(glow_text, (glow_rect.x - offset, glow_rect.y))
            screen.blit(glow_text, (glow_rect.x + offset, glow_rect.y))

        title_text = title_font.render("ACADEMY", True, WINDOW_GOLD)
        title_rect = title_text.get_rect(center=(x + w // 2, title_y))
        screen.blit(title_text, title_rect)

        # 8. 마법 파티클 (반짝이는 별)
        random.seed(building_id * 13 + int(self.animation_timer * 3))
        for _ in range(8):
            px = random.randint(x + 5, x + w - 5)
            py = random.randint(y + 10, y + h - 15)

            particle_alpha = random.randint(120, 200)
            particle_color = random.choice([MAGIC_PURPLE, MAGIC_BLUE, WINDOW_GOLD])
            size = random.randint(1, 2)

            # 십자 반짝임
            pygame.draw.circle(screen, (*particle_color, particle_alpha), (px, py), size)
            pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                            (px - 3, py), (px + 3, py), 1)
            pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                            (px, py - 3), (px, py + 3), 1)
        random.seed()

    # =========================================================================
    # ❓ 미스터리 - 차원의 틈 (5가지 고유 디자인)
    # =========================================================================
    def _draw_mystery(self, screen, building, x, y, building_id):
        """미스터리 건물 - 차원의 틈 (5가지 디자인)"""
        from .mystery_designs import MYSTERY_DESIGNS

        # 건물 ID에 따른 디자인 선택 (1-5)
        design_id = (building_id % 5) + 1

        # 해당 디자인 함수 호출
        if design_id in MYSTERY_DESIGNS:
            MYSTERY_DESIGNS[design_id](screen, building, x, y, building_id, self.animation_timer, self.particles)
        else:
            # 기본 디자인 (폴백)
            self._draw_mystery_default(screen, building, x, y)

    def _draw_mystery_default(self, screen, building, x, y):
        """미스터리 건물 기본 디자인 (폴백용)"""
        w, h = building.width, building.height
        VOID_PURPLE = (100, 0, 150)
        VOID_DARK = (50, 0, 80)

        # 건물 본체
        pygame.draw.rect(screen, VOID_DARK, (x, y, w, h))
        pygame.draw.rect(screen, VOID_PURPLE, (x, y, w, h), 2)

        # ? 마크
        font = pygame.font.Font(None, int(h * 0.6))
        text = font.render("?", True, VOID_PURPLE)
        text_rect = text.get_rect(center=(x + w//2, y + h//2))
        screen.blit(text, text_rect)

    # =========================================================================
    # 🎰 가챠샵 - 화려한 가챠 머신
    # =========================================================================
    def _draw_gacha(self, screen, building, x, y, building_id):
        """가챠샵 - 화려한 가챠 머신 (고품질)"""
        w, h = building.width, building.height

        # 1. 3D 그림자 (무지개빛 틴트)
        shadow_surf = pygame.Surface((w + 15, h + 15), pygame.SRCALPHA)
        for i in range(8):
            alpha = 60 - i * 7
            color_shift = int(i * 10)
            pygame.draw.rect(shadow_surf, (50 + color_shift, 30, 60 + color_shift, max(0, alpha)),
                           (8 - i, 8 - i, w + i, h + i), border_radius=12)
        screen.blit(shadow_surf, (x + 5, y + 5))

        # 2. 다중 레이어 무지개 글로우
        glow_pulse = abs(math.sin(self.animation_timer * 3))
        for layer in range(4):
            glow_size = (w + 60 - layer * 10, h + 60 - layer * 10)
            glow_surf = pygame.Surface(glow_size, pygame.SRCALPHA)
            # 무지개 색상 순환
            hue = (self.animation_timer * 50 + layer * 30) % 360
            r = int(127 + 127 * math.sin(math.radians(hue)))
            g = int(127 + 127 * math.sin(math.radians(hue + 120)))
            b = int(127 + 127 * math.sin(math.radians(hue + 240)))
            alpha = int((50 - layer * 10) * glow_pulse)
            pygame.draw.ellipse(glow_surf, (r, g, b, alpha), (0, 0, *glow_size))
            screen.blit(glow_surf, (x - 30 + layer * 5, y - 30 + layer * 5))

        # 3. 건물 본체 (레드-골드 그라데이션)
        for i in range(h):
            ratio = i / h
            r = int(200 + 55 * ratio)
            g = int(50 + 100 * ratio)
            b = int(50 - 30 * ratio)
            pygame.draw.line(screen, (r, g, b), (x, y + i), (x + w, y + i))

        # 4. 돔 지붕 (블루-퍼플 그라데이션 + 입체감)
        dome_h = int(h * 0.3)
        dome_y = y - dome_h // 2
        for i in range(dome_h):
            ratio = i / dome_h
            # 타원형 돔
            dome_width = int(w * (1 - (ratio - 0.5) ** 2 * 2))
            dome_x = x + (w - dome_width) // 2
            # 그라데이션 색상
            r = int(100 - 50 * ratio)
            g = int(50 + 100 * ratio)
            b = int(200 + 55 * (1 - ratio))
            pygame.draw.line(screen, (r, g, b), (dome_x, dome_y + i), (dome_x + dome_width, dome_y + i))

        # 5. 돔 상단 별 (큰 회전 별)
        star_x = x + w // 2
        star_y = dome_y
        self._draw_gacha_star_hq(screen, star_x, star_y, 18)

        # 6. 가챠 머신 몸체 (골드 그라데이션 프레임)
        machine_w = int(w * 0.7)
        machine_h = int(h * 0.5)
        machine_x = x + (w - machine_w) // 2
        machine_y = y + int(h * 0.15)

        # 골드 프레임
        for thick in range(5):
            frame_color = (255 - thick * 20, 215 - thick * 20, 0)
            pygame.draw.rect(screen, frame_color,
                           (machine_x - thick, machine_y - thick, machine_w + thick * 2, machine_h + thick * 2),
                           1)

        # 7. 유리 돔 (캡슐 디스플레이) + 반사광
        glass_y = machine_y + 5
        glass_h = int(machine_h * 0.6)
        glass_surf = pygame.Surface((machine_w - 10, glass_h), pygame.SRCALPHA)
        pygame.draw.ellipse(glass_surf, (200, 230, 255, 150), (0, 0, machine_w - 10, glass_h))
        # 반사광
        pygame.draw.ellipse(glass_surf, (255, 255, 255, 80),
                          (5, 5, (machine_w - 10) // 3, glass_h // 3))
        screen.blit(glass_surf, (machine_x + 5, glass_y))

        # 8. 캡슐들 (11개 - 다양한 색상 + 애니메이션)
        capsule_colors = [
            (255, 100, 100), (100, 255, 100), (100, 100, 255),
            (255, 255, 100), (255, 100, 255), (100, 255, 255),
            (255, 150, 0), (150, 0, 255), (0, 255, 150),
            (255, 200, 200), (200, 200, 255)
        ]

        capsule_positions = [
            (0.2, 0.3), (0.4, 0.25), (0.6, 0.3), (0.8, 0.35),
            (0.15, 0.55), (0.35, 0.6), (0.55, 0.58), (0.75, 0.62),
            (0.25, 0.8), (0.5, 0.85), (0.7, 0.78)
        ]

        for idx, (color, (px, py)) in enumerate(zip(capsule_colors, capsule_positions)):
            capsule_x = machine_x + int(machine_w * px)
            capsule_y = glass_y + int(glass_h * py)
            # 바운스 애니메이션
            bounce = int(3 * math.sin(self.animation_timer * 2 + idx * 0.5))
            capsule_size = 6
            # 캡슐 그림자
            pygame.draw.circle(screen, (0, 0, 0, 30), (capsule_x + 1, capsule_y + 1 + bounce), capsule_size)
            # 캡슐 본체
            pygame.draw.circle(screen, color, (capsule_x, capsule_y + bounce), capsule_size)
            # 캡슐 하이라이트
            pygame.draw.circle(screen, (255, 255, 255, 200),
                             (capsule_x - 2, capsule_y - 2 + bounce), capsule_size // 2)

        # 9. 캡슐 배출구
        outlet_y = machine_y + machine_h - 15
        outlet_w = int(machine_w * 0.4)
        outlet_x = machine_x + (machine_w - outlet_w) // 2
        pygame.draw.rect(screen, (50, 50, 50), (outlet_x, outlet_y, outlet_w, 12), border_radius=3)
        pygame.draw.rect(screen, (100, 100, 100), (outlet_x, outlet_y, outlet_w, 12), 1, border_radius=3)

        # 10. 회전 손잡이 (메탈 그라데이션)
        handle_x = x + w - 15
        handle_y = machine_y + machine_h // 2
        handle_angle = self.animation_timer * 1.5
        handle_length = 12
        handle_end_x = handle_x + int(handle_length * math.cos(handle_angle))
        handle_end_y = handle_y + int(handle_length * math.sin(handle_angle))
        pygame.draw.line(screen, (180, 180, 180), (handle_x, handle_y), (handle_end_x, handle_end_y), 3)
        pygame.draw.circle(screen, (220, 220, 220), (handle_x, handle_y), 5)
        pygame.draw.circle(screen, (255, 0, 0), (handle_end_x, handle_end_y), 6)

        # 11. 네온 "GACHA" 사인 (글자별 무지개 글로우)
        try:
            font = pygame.font.Font(None, 16)
            text_surface = font.render("GACHA", True, (255, 255, 255))
            text_x = x + (w - text_surface.get_width()) // 2
            text_y = y + h - 25

            # 글자별 무지개 글로우
            for i, char in enumerate("GACHA"):
                char_surf = font.render(char, True, (255, 255, 255))
                char_x = text_x + i * 11
                # 글로우 효과
                glow_surf = pygame.Surface((char_surf.get_width() + 20, char_surf.get_height() + 20), pygame.SRCALPHA)
                hue = (self.animation_timer * 100 + i * 60) % 360
                r = int(127 + 127 * math.sin(math.radians(hue)))
                g = int(127 + 127 * math.sin(math.radians(hue + 120)))
                b = int(127 + 127 * math.sin(math.radians(hue + 240)))
                for layer in range(3):
                    alpha = 100 - layer * 30
                    pygame.draw.circle(glow_surf, (r, g, b, alpha),
                                     (char_surf.get_width() // 2 + 10, char_surf.get_height() // 2 + 10),
                                     8 - layer * 2)
                screen.blit(glow_surf, (char_x - 10, text_y - 10))
                screen.blit(char_surf, (char_x, text_y))
        except:
            pass

        # 12. 하단 희귀도 별 5개 (펄스 애니메이션)
        star_y_base = y + h - 10
        for i in range(5):
            star_x_pos = x + (w // 6) * (i + 1)
            pulse = abs(math.sin(self.animation_timer * 3 + i * 0.3))
            star_color = (255, int(215 * pulse), 0)
            self._draw_gacha_star_hq(screen, star_x_pos, star_y_base, 4 + int(2 * pulse))

        # 13. 코인 투입구 (측면)
        coin_slot_x = x + 5
        coin_slot_y = machine_y + machine_h // 3
        pygame.draw.rect(screen, (100, 100, 100), (coin_slot_x, coin_slot_y, 8, 15), border_radius=2)
        pygame.draw.rect(screen, (200, 200, 0), (coin_slot_x, coin_slot_y, 8, 3))

        # 14. 무지개 파티클 효과
        if building_id not in self.particles:
            self.particles[building_id] = []

        # 파티클 생성 (확률적)
        if random.random() < 0.1:
            particle_x = x + random.randint(10, w - 10)
            particle_y = y + random.randint(10, h - 10)
            hue = random.randint(0, 360)
            r = int(127 + 127 * math.sin(math.radians(hue)))
            g = int(127 + 127 * math.sin(math.radians(hue + 120)))
            b = int(127 + 127 * math.sin(math.radians(hue + 240)))
            self.particles[building_id].append({
                'x': particle_x,
                'y': particle_y,
                'color': (r, g, b),
                'life': 1.0,
                'vx': random.uniform(-1, 1),
                'vy': random.uniform(-2, -0.5)
            })

        # 파티클 업데이트 및 렌더링
        for particle in self.particles[building_id][:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 0.02
            if particle['life'] <= 0:
                self.particles[building_id].remove(particle)
            else:
                alpha = int(255 * particle['life'])
                color = (*particle['color'], alpha)
                size = max(1, int(3 * particle['life']))
                particle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(particle_surf, color, (size, size), size)
                screen.blit(particle_surf, (int(particle['x']), int(particle['y'])))

        # 15. 앰비언트 오클루전 (그림자 디테일)
        ao_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.rect(ao_surf, (0, 0, 0, 30), (0, h - 20, w, 20))
        screen.blit(ao_surf, (x, y))

    def _draw_gacha_star_hq(self, screen, x, y, size):
        """가챠샵 상단 큰 별 (고품질)"""
        rotation = self.animation_timer * 2
        glow_pulse = abs(math.sin(self.animation_timer * 4))

        # 다중 레이어 글로우
        for layer in range(4):
            glow_size = size + 12 - layer * 3
            glow_surf = pygame.Surface((glow_size * 3, glow_size * 3), pygame.SRCALPHA)
            # 무지개 글로우
            hue = (self.animation_timer * 100 + layer * 40) % 360
            r = int(127 + 127 * math.sin(math.radians(hue)))
            g = int(127 + 127 * math.sin(math.radians(hue + 120)))
            b = int(127 + 127 * math.sin(math.radians(hue + 240)))
            alpha = int((80 - layer * 15) * glow_pulse)
            pygame.draw.circle(glow_surf, (r, g, b, alpha),
                             (glow_size * 3 // 2, glow_size * 3 // 2), glow_size)
            screen.blit(glow_surf, (x - glow_size * 3 // 2, y - glow_size * 3 // 2))

        # 별 포인트 계산
        points = []
        for i in range(10):
            angle = rotation + i * math.pi / 5 - math.pi / 2
            r = size if i % 2 == 0 else size * 0.4
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points.append((px, py))

        # 별 그림자
        shadow_points = [(p[0] + 2, p[1] + 2) for p in points]
        pygame.draw.polygon(screen, (100, 80, 0), shadow_points)

        # 별 본체 (그라데이션 효과)
        pygame.draw.polygon(screen, (255, 220, 50), points)

        # 별 하이라이트
        inner_points = []
        for i in range(10):
            angle = rotation + i * math.pi / 5 - math.pi / 2
            r = (size * 0.7) if i % 2 == 0 else (size * 0.3)
            px = x + r * math.cos(angle) - 1
            py = y + r * math.sin(angle) - 1
            inner_points.append((px, py))
        pygame.draw.polygon(screen, (255, 250, 150), inner_points)

        # 별 테두리
        pygame.draw.polygon(screen, (255, 255, 200), points, 2)

        # 중앙 반짝임
        sparkle_alpha = int(200 * glow_pulse)
        sparkle_surf = pygame.Surface((10, 10), pygame.SRCALPHA)
        pygame.draw.circle(sparkle_surf, (255, 255, 255, sparkle_alpha), (5, 5), 3)
        screen.blit(sparkle_surf, (x - 5, y - 5))

    def _draw_mini_star_hq(self, surface, x, y, size, color):
        """미니 별 고품질 렌더링"""
        points = []
        for i in range(10):
            angle = i * math.pi / 5 - math.pi / 2
            r = size if i % 2 == 0 else size * 0.4
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points.append((px, py))

        # 별 본체
        pygame.draw.polygon(surface, color, points)
        # 테두리
        pygame.draw.polygon(surface, (255, 255, 220), points, 1)
        # 중앙 하이라이트
        pygame.draw.circle(surface, (255, 255, 255, 150), (x, y), size // 3)

    def _draw_mini_star(self, surface, x, y, size, color):
        """미니 별 그리기"""
        points = []
        for i in range(10):
            angle = i * math.pi / 5 - math.pi / 2
            r = size if i % 2 == 0 else size * 0.4
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points.append((px, py))
        pygame.draw.polygon(surface, color[:3], points)

    # =========================================================================
    # 기본 건물
    # =========================================================================
    def _draw_default(self, screen, building, x, y):
        """기본 건물 (폴백)"""
        pygame.draw.rect(screen, building.info['color'],
                        (x, y, building.width, building.height), border_radius=5)
        pygame.draw.rect(screen, Colors.TEXT_WHITE,
                        (x, y, building.width, building.height), 2, border_radius=5)

    # =========================================================================
    # 파티클 시스템
    # =========================================================================
    def _draw_particles(self, screen, building_id, offset):
        """파티클 그리기 - 파티클 좌표는 이미 카메라 보정됨"""
        if building_id not in self.particles:
            return

        for p in self.particles[building_id]:
            # 파티클 좌표는 draw_building에서 카메라 이동에 따라 이미 업데이트됨
            px = p['x']
            py = p['y']
            alpha = min(255, max(0, int(255 * (p['life'] / 2.0))))

            if p['type'] == 'sparkle':
                size = 3 + int(3 * p['life'])
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                sparkle_color = p.get('color', (255, 255, 255))
                pygame.draw.circle(surf, (*sparkle_color, alpha), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'ember':
                ember_color = p.get('color', (255, 150, 50))
                pygame.draw.circle(screen, ember_color, (int(px), int(py)), 2)

            elif p['type'] == 'smoke':
                size = p.get('size', 10) + int((2.0 - p['life']) * 5)
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (100, 100, 100, min(alpha, 100)), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'spark':
                spark_color = p.get('color', (255, 200, 100))
                pygame.draw.circle(screen, spark_color, (int(px), int(py)), 2)

            elif p['type'] == 'magic':
                size = int(4 * p['life'])
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                magic_color = p.get('color', (150, 150, 255))
                pygame.draw.circle(surf, (*magic_color, alpha), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'leaf':
                surf = pygame.Surface((10, 6), pygame.SRCALPHA)
                leaf_color = p.get('color', (100, 180, 80))  # 기본 색상 추가
                pygame.draw.ellipse(surf, (*leaf_color, alpha), (0, 0, 10, 6))
                rotated = pygame.transform.rotate(surf, p.get('rotation', 0))
                screen.blit(rotated, (px - 5, py - 3))
                p['rotation'] = p.get('rotation', 0) + 180 * 0.016

            elif p['type'] == 'ancient_magic':
                size = int(5 * p['life'])
                ancient_color = p.get('color', (255, 215, 0))
                # 별 모양
                star_points = []
                for i in range(6):
                    angle = i * math.pi / 3 + self.animation_timer * 2
                    r = size if i % 2 == 0 else size * 0.5
                    star_points.append((px + r * math.cos(angle), py + r * math.sin(angle)))
                if len(star_points) >= 3:
                    surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
                    offset_points = [(pt[0] - px + size * 1.5, pt[1] - py + size * 1.5) for pt in star_points]
                    pygame.draw.polygon(surf, (*ancient_color, alpha), offset_points)
                    screen.blit(surf, (px - size * 1.5, py - size * 1.5))

            elif p['type'] == 'pixel':
                pixel_color = p.get('color', (0, 255, 0))
                pygame.draw.rect(screen, pixel_color, (int(px), int(py), 4, 4))

            elif p['type'] == 'gold_sparkle':
                size = int(4 * p['life'])
                gold_color = p.get('color', (255, 215, 0))
                pygame.draw.circle(screen, gold_color, (int(px), int(py)), size)

            elif p['type'] == 'void':
                size = int(6 * p['life'])
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                void_color = p.get('color', (100, 0, 150))
                pygame.draw.circle(surf, (*void_color, alpha), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'gacha_star':
                size = int(8 * p['life'])
                gacha_color = p.get('color', (255, 200, 50))
                # 별 모양 파티클
                gacha_points = []
                for i in range(10):
                    angle = i * math.pi / 5 - math.pi / 2 + self.animation_timer * 3
                    r = size if i % 2 == 0 else size * 0.4
                    gacha_points.append((px + r * math.cos(angle), py + r * math.sin(angle)))
                if len(gacha_points) >= 3:
                    surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
                    offset_points = [(pt[0] - px + size * 1.5, pt[1] - py + size * 1.5) for pt in gacha_points]
                    pygame.draw.polygon(surf, (*gacha_color, alpha), offset_points)
                    screen.blit(surf, (px - size * 1.5, py - size * 1.5))

    # =========================================================================
    # 🛒 아이템 상점 - 선택된 디자인에 따라 다른 스타일
    # =========================================================================
    def _draw_item_shop(self, screen, building, x, y, building_id):
        """아이템 상점 - 5가지 디자인 중 선택된 스타일 적용"""
        from .constants import BUILDING_INFO, SHOP_DESIGNS, SELECTED_SHOP_DESIGN

        w, h = building.width, building.height
        selected_design = SHOP_DESIGNS[SELECTED_SHOP_DESIGN]
        style = selected_design["style"]

        # 애니메이션
        pulse = 0.8 + 0.2 * abs(math.sin(self.animation_timer * 2))
        glow = abs(math.sin(self.animation_timer * 1.5))

        # 스타일별 건물 그리기
        if style == "cyberpunk":
            # 네온 마켓
            self._draw_cyberpunk_shop(screen, x, y, w, h, selected_design, pulse, glow)
        elif style == "fantasy":
            # 마법 상점
            self._draw_fantasy_shop(screen, x, y, w, h, selected_design, pulse, glow)
        elif style == "steampunk":
            # 기어 상회
            self._draw_steampunk_shop(screen, x, y, w, h, selected_design, pulse, glow)
        elif style == "nature":
            # 숲속 교역소
            self._draw_nature_shop(screen, x, y, w, h, selected_design, pulse, glow)
        elif style == "luxury":
            # 황금 갤러리
            self._draw_luxury_shop(screen, x, y, w, h, selected_design, pulse, glow)

    def _draw_cyberpunk_shop(self, screen, x, y, w, h, design, pulse, glow):
        """사이버펑크 스타일 상점 - UHD 초고퀄리티"""
        color = design["color"]
        secondary = design["secondary_color"]

        # 다층 네온 글로우 (8레이어)
        for i in range(8):
            glow_size = 30 - i * 3
            glow_alpha = int(150 * glow / (i + 1))
            glow_surf = pygame.Surface((w + glow_size * 2, h + glow_size * 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*color, glow_alpha),
                           (0, 0, w + glow_size * 2, h + glow_size * 2), border_radius=15)
            screen.blit(glow_surf, (x - glow_size, y - glow_size))

        # 외곽 네온 프레임 (3중)
        for offset in range(3):
            frame_alpha = int(220 - offset * 60)
            pygame.draw.rect(screen, (*secondary, frame_alpha),
                           (x - offset * 2, y - offset * 2, w + offset * 4, h + offset * 4),
                           3, border_radius=12 + offset * 2)

        # 그라데이션 배경
        for i in range(h):
            gradient_alpha = int(80 + 40 * (i / h) * pulse)
            gradient_color = (
                int(40 + 20 * math.sin(self.animation_timer + i * 0.05)),
                int(40 + 20 * math.cos(self.animation_timer + i * 0.05)),
                int(60 + 30 * math.sin(self.animation_timer * 1.5 + i * 0.05))
            )
            pygame.draw.line(screen, gradient_color, (x, y + i), (x + w, y + i))

        # 메인 박스 테두리
        pygame.draw.rect(screen, color, (x, y, w, h), 4, border_radius=12)

        # 홀로그램 네온 라인 (애니메이션)
        for i in range(6):
            line_y = y + 15 + i * 12
            line_offset = int(10 * math.sin(self.animation_timer * 2 + i * 0.5))
            alpha = int(255 * pulse * abs(math.sin(self.animation_timer * 1.5 + i * 0.3)))

            # 글로우 효과
            for j in range(3):
                glow_width = 6 - j * 2
                glow_alpha = alpha // (j + 1)
                pygame.draw.line(screen, (*secondary, glow_alpha),
                               (x + 15 + line_offset, line_y),
                               (x + w - 15 + line_offset, line_y), glow_width)

            # 메인 라인
            pygame.draw.line(screen, secondary,
                           (x + 15 + line_offset, line_y),
                           (x + w - 15 + line_offset, line_y), 2)

        # 회로 패턴
        circuit_color = (*color, int(180 * glow))
        for i in range(4):
            for j in range(3):
                cx = x + 10 + i * 18
                cy = y + 10 + j * 20
                pygame.draw.circle(screen, circuit_color, (cx, cy), 2)
                if i < 3:
                    pygame.draw.line(screen, circuit_color, (cx, cy), (cx + 18, cy), 1)

        # 디지털 입자 효과
        for i in range(15):
            particle_x = x + (i * 7 + int(self.animation_timer * 50)) % w
            particle_y = y + h // 2 + int(10 * math.sin(self.animation_timer * 3 + i))
            particle_alpha = int(200 * abs(math.sin(self.animation_timer * 2 + i * 0.5)))
            pygame.draw.circle(screen, (*secondary, particle_alpha), (particle_x, particle_y), 2)

    def _draw_fantasy_shop(self, screen, x, y, w, h, design, pulse, glow):
        """판타지 스타일 상점 - UHD 초고퀄리티"""
        color = design["color"]
        secondary = design["secondary_color"]

        # 다층 마법 오라 (6레이어)
        for i in range(6):
            aura_size = 40 - i * 5
            aura_alpha = int(120 * pulse / (i + 1))
            aura_surf = pygame.Surface((w + aura_size * 2, h + aura_size * 2), pygame.SRCALPHA)
            pygame.draw.ellipse(aura_surf, (*color, aura_alpha), (0, 0, w + aura_size * 2, h + aura_size * 2))
            screen.blit(aura_surf, (x - aura_size, y - aura_size))

        # 마법 파티클 효과 (회전)
        for i in range(20):
            angle = (self.animation_timer * 2 + i * 18) * math.pi / 180
            radius = 40 + 10 * math.sin(self.animation_timer * 3 + i * 0.3)
            px = x + w // 2 + int(radius * math.cos(angle))
            py = y + h // 2 + int(radius * math.sin(angle))
            particle_alpha = int(200 * abs(math.sin(self.animation_timer * 2 + i * 0.2)))
            pygame.draw.circle(screen, (*secondary, particle_alpha), (px, py), 3)
            # 파티클 글로우
            pygame.draw.circle(screen, (*secondary, particle_alpha // 2), (px, py), 5)

        # 그라데이션 건물 본체
        for i in range(h - 15):
            gradient_ratio = i / (h - 15)
            base_color = (
                int(60 + 40 * gradient_ratio * pulse),
                int(40 + 60 * gradient_ratio * pulse),
                int(100 + 55 * gradient_ratio * pulse)
            )
            pygame.draw.line(screen, base_color, (x, y + 10 + i), (x + w, y + 10 + i))

        pygame.draw.rect(screen, color, (x, y + 10, w, h - 15), 3, border_radius=8)

        # 화려한 지붕 (다층 그라데이션)
        roof_layers = 5
        for layer in range(roof_layers):
            layer_offset = layer * 2
            layer_alpha = int(255 - layer * 40)
            roof_color = (
                int(secondary[0] * (1 - layer * 0.1)),
                int(secondary[1] * (1 - layer * 0.1)),
                int(secondary[2] * (1 - layer * 0.1))
            )
            roof_points = [
                (x + layer_offset, y + 10 - layer_offset),
                (x + w // 2, y - 5 - layer * 3),
                (x + w - layer_offset, y + 10 - layer_offset)
            ]
            pygame.draw.polygon(screen, roof_color, roof_points)

        # 복잡한 마법진 (3중 회전)
        cx = x + w // 2
        cy = y + h // 2

        # 외곽 마법진
        for ring in range(3):
            ring_radius = 20 + ring * 8
            ring_alpha = int(200 * glow / (ring + 1))

            # 회전하는 룬 문자
            for i in range(8):
                angle = (self.animation_timer * (1 + ring * 0.5) + i * 45) * math.pi / 180
                rx = cx + int(ring_radius * math.cos(angle))
                ry = cy + int(ring_radius * math.sin(angle))
                pygame.draw.circle(screen, (*secondary, ring_alpha), (rx, ry), 2)

            pygame.draw.circle(screen, (*secondary, ring_alpha), (cx, cy), ring_radius, 2)

        # 중앙 코어
        core_alpha = int(255 * pulse)
        for i in range(4):
            core_size = 8 - i * 2
            pygame.draw.circle(screen, (*color, core_alpha // (i + 1)), (cx, cy), core_size)

        # 마법 광선 (8방향)
        for i in range(8):
            angle = (self.animation_timer * 1.5 + i * 45) * math.pi / 180
            beam_length = 15 + 5 * abs(math.sin(self.animation_timer * 2 + i * 0.5))
            ex = cx + int(beam_length * math.cos(angle))
            ey = cy + int(beam_length * math.sin(angle))
            beam_alpha = int(180 * pulse)
            pygame.draw.line(screen, (*secondary, beam_alpha), (cx, cy), (ex, ey), 2)

    def _draw_steampunk_shop(self, screen, x, y, w, h, design, pulse, glow):
        """스팀펑크 스타일 상점 - UHD 초고퀄리티"""
        color = design["color"]
        secondary = design["secondary_color"]

        # 증기 효과 (아래에서 위로)
        for i in range(10):
            steam_y = y + h - int((self.animation_timer * 30 + i * 15) % (h + 20))
            steam_x = x + w // 2 + int(10 * math.sin(self.animation_timer * 2 + i))
            steam_alpha = int(100 * (1 - (h - steam_y) / h) * glow)
            steam_size = int(5 + 3 * ((h - steam_y) / h))
            pygame.draw.circle(screen, (200, 200, 200, steam_alpha), (steam_x, steam_y), steam_size)

        # 금속 질감 그라데이션
        for i in range(h):
            gradient_ratio = i / h
            metallic_shine = abs(math.sin((gradient_ratio * 4 + self.animation_timer) * math.pi))
            base_color = (
                int(80 + 40 * metallic_shine * pulse),
                int(60 + 30 * metallic_shine * pulse),
                int(40 + 20 * metallic_shine * pulse)
            )
            pygame.draw.line(screen, base_color, (x, y + i), (x + w, y + i))

        # 3중 테두리
        pygame.draw.rect(screen, color, (x, y, w, h), 4, border_radius=8)
        pygame.draw.rect(screen, secondary, (x + 3, y + 3, w - 6, h - 6), 2, border_radius=6)
        pygame.draw.rect(screen, color, (x + 6, y + 6, w - 12, h - 12), 1, border_radius=4)

        # 리벳 패턴 (대폭 증가)
        for row in range(8):
            for col in range(10):
                rivet_x = x + 8 + col * 8
                rivet_y = y + 8 + row * 9
                # 리벳 헤드
                pygame.draw.circle(screen, secondary, (rivet_x, rivet_y), 2)
                # 하이라이트
                pygame.draw.circle(screen, (200, 180, 150), (rivet_x - 1, rivet_y - 1), 1)

        # 복잡한 기어 시스템 (3개 연결)
        cx = x + w // 2
        cy = y + h // 2

        # 메인 기어 (중앙)
        gear_angle = self.animation_timer * 50
        for gear_idx, (gx_offset, gy_offset, radius, teeth) in enumerate([
            (0, 0, 18, 12),      # 중앙 대형
            (-20, -15, 12, 8),   # 좌상 중형
            (20, 15, 10, 6)      # 우하 소형
        ]):
            gx = cx + gx_offset
            gy = cy + gy_offset
            angle_mult = 1 if gear_idx % 2 == 0 else -1

            # 기어 본체
            pygame.draw.circle(screen, secondary, (gx, gy), radius, 3)
            pygame.draw.circle(screen, (60, 50, 30), (gx, gy), radius - 4)

            # 기어 톱니
            for i in range(teeth):
                angle = (gear_angle * angle_mult + i * (360 / teeth)) * math.pi / 180
                tooth_x1 = gx + int((radius - 2) * math.cos(angle))
                tooth_y1 = gy + int((radius - 2) * math.sin(angle))
                tooth_x2 = gx + int((radius + 4) * math.cos(angle))
                tooth_y2 = gy + int((radius + 4) * math.sin(angle))
                pygame.draw.line(screen, color, (tooth_x1, tooth_y1), (tooth_x2, tooth_y2), 3)

            # 중앙 축
            pygame.draw.circle(screen, color, (gx, gy), radius // 3)
            pygame.draw.circle(screen, (100, 90, 70), (gx, gy), radius // 4)

        # 연결 체인/벨트
        for i in range(3):
            chain_y = y + 15 + i * 20
            for j in range(8):
                chain_x = x + 10 + j * 10
                link_offset = int(3 * math.sin(self.animation_timer * 3 + j * 0.5))
                pygame.draw.circle(screen, secondary, (chain_x, chain_y + link_offset), 2)
                if j < 7:
                    pygame.draw.line(screen, secondary,
                                   (chain_x, chain_y + link_offset),
                                   (chain_x + 10, chain_y + link_offset), 1)

        # 압력 게이지 (애니메이션)
        gauge_x = x + 10
        gauge_y = y + 10
        gauge_w = 20
        gauge_h = 8
        pygame.draw.rect(screen, (40, 40, 40), (gauge_x, gauge_y, gauge_w, gauge_h), border_radius=2)
        pressure = abs(math.sin(self.animation_timer * 2)) * gauge_w
        pressure_color = (int(255 * pressure / gauge_w), int(255 * (1 - pressure / gauge_w)), 0)
        pygame.draw.rect(screen, pressure_color, (gauge_x, gauge_y, int(pressure), gauge_h), border_radius=2)

    def _draw_nature_shop(self, screen, x, y, w, h, design, pulse, glow):
        """자연 스타일 상점 - UHD 초고퀄리티"""
        color = design["color"]
        secondary = design["secondary_color"]

        # 나뭇잎 파티클 효과 (떨어지는 잎)
        for i in range(12):
            leaf_x = x + (i * 7 + int(self.animation_timer * 20)) % w
            leaf_y = y + int((self.animation_timer * 25 + i * 10) % (h + 30)) - 30
            leaf_rotation = (self.animation_timer * 100 + i * 30) % 360
            leaf_alpha = int(180 * abs(math.sin(self.animation_timer + i * 0.3)))

            # 나뭇잎 모양
            leaf_size = 4
            leaf_points = [
                (leaf_x + int(leaf_size * math.cos(math.radians(leaf_rotation))),
                 leaf_y + int(leaf_size * math.sin(math.radians(leaf_rotation)))),
                (leaf_x + int(leaf_size * math.cos(math.radians(leaf_rotation + 120))),
                 leaf_y + int(leaf_size * math.sin(math.radians(leaf_rotation + 120)))),
                (leaf_x + int(leaf_size * math.cos(math.radians(leaf_rotation + 240))),
                 leaf_y + int(leaf_size * math.sin(math.radians(leaf_rotation + 240))))
            ]
            pygame.draw.polygon(screen, (*color, leaf_alpha), leaf_points)

        # 나무 질감 그라데이션
        for i in range(h - 20):
            wood_pattern = abs(math.sin((i + self.animation_timer * 10) * 0.3)) * 30
            wood_color = (
                int(139 + wood_pattern * pulse),
                int(90 + wood_pattern * 0.5 * pulse),
                int(43 + wood_pattern * 0.3 * pulse)
            )
            pygame.draw.line(screen, wood_color, (x, y + 15 + i), (x + w, y + 15 + i))

        # 나무 테두리
        pygame.draw.rect(screen, color, (x, y + 15, w, h - 20), 3, border_radius=10)
        pygame.draw.rect(screen, (100, 70, 30), (x + 2, y + 17, w - 4, h - 24), 1, border_radius=8)

        # 화려한 지붕 (여러 레이어)
        for layer in range(4):
            layer_offset = layer * 3
            roof_color = (
                int(secondary[0] * (1 - layer * 0.15)),
                int(secondary[1] * (1 - layer * 0.15)),
                int(secondary[2] * (1 - layer * 0.15))
            )
            roof_points = [
                (x + layer_offset, y + 15 - layer_offset),
                (x + w // 2, y - layer * 2),
                (x + w - layer_offset, y + 15 - layer_offset)
            ]
            pygame.draw.polygon(screen, roof_color, roof_points)
            if layer > 0:
                pygame.draw.lines(screen, color, False, roof_points, 1)

        # 창문 (빛 효과)
        for i in range(2):
            window_x = x + 15 + i * 35
            window_y = y + 30
            window_w = 20
            window_h = 15

            # 창문 글로우
            window_alpha = int(150 * pulse)
            pygame.draw.rect(screen, (*color, window_alpha // 2),
                           (window_x - 2, window_y - 2, window_w + 4, window_h + 4), border_radius=3)
            pygame.draw.rect(screen, (255, 255, 200), (window_x, window_y, window_w, window_h), border_radius=2)
            pygame.draw.rect(screen, (100, 70, 30), (window_x, window_y, window_w, window_h), 2, border_radius=2)

            # 십자 창틀
            pygame.draw.line(screen, (100, 70, 30),
                           (window_x + window_w // 2, window_y),
                           (window_x + window_w // 2, window_y + window_h), 2)
            pygame.draw.line(screen, (100, 70, 30),
                           (window_x, window_y + window_h // 2),
                           (window_x + window_w, window_y + window_h // 2), 2)

        # 덩굴 식물 (양옆)
        for side in [-1, 1]:
            vine_x = x + w // 2 + side * (w // 2 - 5)
            for i in range(10):
                vine_y = y + 20 + i * 6
                vine_offset = int(3 * math.sin(self.animation_timer * 2 + i * 0.5))
                leaf_alpha = int(200 * abs(math.cos(self.animation_timer + i * 0.3)))

                # 줄기
                pygame.draw.circle(screen, (50, 100, 50),
                                 (vine_x + vine_offset * side, vine_y), 1)

                # 잎
                if i % 2 == 0:
                    pygame.draw.circle(screen, (*color, leaf_alpha),
                                     (vine_x + vine_offset * side + side * 5, vine_y), 3)

        # 꽃 장식
        for i in range(5):
            flower_x = x + 15 + i * 15
            flower_y = y + h - 10
            petal_alpha = int(220 * pulse * abs(math.sin(self.animation_timer * 2 + i * 0.5)))

            # 꽃잎 (5개)
            for petal in range(5):
                petal_angle = (petal * 72 + self.animation_timer * 30) * math.pi / 180
                petal_x = flower_x + int(4 * math.cos(petal_angle))
                petal_y = flower_y + int(4 * math.sin(petal_angle))
                pygame.draw.circle(screen, (255, 100, 150, petal_alpha), (petal_x, petal_y), 3)

            # 꽃 중심
            pygame.draw.circle(screen, (255, 200, 50), (flower_x, flower_y), 2)

    def _draw_luxury_shop(self, screen, x, y, w, h, design, pulse, glow):
        """고급 스타일 상점 - UHD 초고퀄리티"""
        color = design["color"]
        secondary = design["secondary_color"]

        # 다층 황금 광채 (10레이어)
        for i in range(10):
            glow_size = 50 - i * 4
            glow_alpha = int(150 * pulse / (i + 1))
            glow_surf = pygame.Surface((w + glow_size * 2, h + glow_size * 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*color, glow_alpha), (0, 0, w + glow_size * 2, h + glow_size * 2),
                           border_radius=15 + i)
            screen.blit(glow_surf, (x - glow_size, y - glow_size))

        # 반짝이는 입자 효과
        for i in range(25):
            sparkle_angle = (self.animation_timer * 80 + i * 14.4) * math.pi / 180
            sparkle_radius = 35 + 10 * abs(math.sin(self.animation_timer * 2 + i * 0.2))
            sparkle_x = x + w // 2 + int(sparkle_radius * math.cos(sparkle_angle))
            sparkle_y = y + h // 2 + int(sparkle_radius * math.sin(sparkle_angle))
            sparkle_alpha = int(255 * abs(math.sin(self.animation_timer * 3 + i * 0.4)))

            # 십자 반짝임
            sparkle_size = 3 + int(2 * abs(math.sin(self.animation_timer * 4 + i)))
            pygame.draw.line(screen, (*color, sparkle_alpha),
                           (sparkle_x - sparkle_size, sparkle_y),
                           (sparkle_x + sparkle_size, sparkle_y), 2)
            pygame.draw.line(screen, (*color, sparkle_alpha),
                           (sparkle_x, sparkle_y - sparkle_size),
                           (sparkle_x, sparkle_y + sparkle_size), 2)

        # 프리미엄 그라데이션 배경
        for i in range(h):
            gradient_ratio = i / h
            shimmer = abs(math.sin((gradient_ratio * 5 + self.animation_timer * 2) * math.pi)) * 30
            base_color = (
                int(50 + shimmer * pulse),
                int(45 + shimmer * 0.9 * pulse),
                int(40 + shimmer * 0.8 * pulse)
            )
            pygame.draw.line(screen, base_color, (x, y + i), (x + w, y + i))

        # 다중 황금 테두리 (5중)
        for i in range(5):
            offset = i * 2
            border_alpha = int(255 - i * 40)
            border_color = (
                int(color[0] * (1 - i * 0.1)),
                int(color[1] * (1 - i * 0.1)),
                int(color[2] * (1 - i * 0.1))
            )
            pygame.draw.rect(screen, border_color,
                           (x + offset, y + offset, w - offset * 2, h - offset * 2),
                           2, border_radius=12 - i)

        # 은색 장식 테두리 (애니메이션)
        for i in range(3):
            silver_offset = 8 + i * 4
            silver_alpha = int(200 * abs(math.cos(self.animation_timer * 1.5 + i)))
            pygame.draw.rect(screen, (*secondary, silver_alpha),
                           (x + silver_offset, y + silver_offset,
                            w - silver_offset * 2, h - silver_offset * 2),
                           1, border_radius=10 - i)

        # 회전하는 다이아몬드 (중앙)
        cx = x + w // 2
        cy = y + h // 2
        diamond_rotation = self.animation_timer * 50

        # 다이아몬드 글로우 효과
        for glow_layer in range(5):
            glow_scale = 1.4 - glow_layer * 0.1
            glow_alpha = int(150 * pulse / (glow_layer + 1))
            diamond_points = [
                (cx + int(15 * glow_scale * math.cos(math.radians(diamond_rotation + 90))),
                 cy + int(15 * glow_scale * math.sin(math.radians(diamond_rotation + 90)))),
                (cx + int(12 * glow_scale * math.cos(math.radians(diamond_rotation))),
                 cy + int(12 * glow_scale * math.sin(math.radians(diamond_rotation)))),
                (cx + int(15 * glow_scale * math.cos(math.radians(diamond_rotation + 270))),
                 cy + int(15 * glow_scale * math.sin(math.radians(diamond_rotation + 270)))),
                (cx + int(12 * glow_scale * math.cos(math.radians(diamond_rotation + 180))),
                 cy + int(12 * glow_scale * math.sin(math.radians(diamond_rotation + 180))))
            ]
            pygame.draw.polygon(screen, (*secondary, glow_alpha), diamond_points)

        # 메인 다이아몬드
        main_diamond_points = [
            (cx + int(12 * math.cos(math.radians(diamond_rotation + 90))),
             cy + int(12 * math.sin(math.radians(diamond_rotation + 90)))),
            (cx + int(10 * math.cos(math.radians(diamond_rotation))),
             cy + int(10 * math.sin(math.radians(diamond_rotation)))),
            (cx + int(12 * math.cos(math.radians(diamond_rotation + 270))),
             cy + int(12 * math.sin(math.radians(diamond_rotation + 270)))),
            (cx + int(10 * math.cos(math.radians(diamond_rotation + 180))),
             cy + int(10 * math.sin(math.radians(diamond_rotation + 180))))
        ]
        pygame.draw.polygon(screen, secondary, main_diamond_points)
        pygame.draw.polygon(screen, color, main_diamond_points, 2)

        # 내부 광선
        for i in range(4):
            beam_angle = (diamond_rotation + i * 90) * math.pi / 180
            beam_length = 8
            beam_x = cx + int(beam_length * math.cos(beam_angle))
            beam_y = cy + int(beam_length * math.sin(beam_angle))
            pygame.draw.line(screen, color, (cx, cy), (beam_x, beam_y), 1)

        # 코너 장식 (4개)
        for corner_idx, (corner_x, corner_y) in enumerate([
            (x + 10, y + 10), (x + w - 10, y + 10),
            (x + 10, y + h - 10), (x + w - 10, y + h - 10)
        ]):
            corner_alpha = int(200 * abs(math.sin(self.animation_timer * 2 + corner_idx * 0.5)))
            # L자 장식
            pygame.draw.line(screen, (*color, corner_alpha),
                           (corner_x - 5, corner_y), (corner_x + 5, corner_y), 2)
            pygame.draw.line(screen, (*color, corner_alpha),
                           (corner_x, corner_y - 5), (corner_x, corner_y + 5), 2)


# 싱글톤 인스턴스
_building_designer = None

def get_building_designer():
    """BuildingDesigner 싱글톤 반환"""
    global _building_designer
    if _building_designer is None:
        _building_designer = BuildingDesigner()
    return _building_designer
