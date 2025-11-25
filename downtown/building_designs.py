# downtown/building_designs.py
# 건물별 고유 디자인 시스템

import pygame
import math
import random
from .constants import BuildingType, Colors, TILE_SIZE

class BuildingDesigner:
    """건물별 고유 디자인 렌더러"""

    def __init__(self):
        self.animation_timer = 0
        # 파티클 저장
        self.particles = {}

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

        # 건물 타입별 그리기
        if building.type == BuildingType.CASINO:
            self._draw_casino(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.COLOSSEUM:
            self._draw_colosseum(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.BLACKSMITH:
            self._draw_blacksmith(screen, building, draw_x, draw_y, building_id)
        elif building.type == BuildingType.SHOP:
            self._draw_shop(screen, building, draw_x, draw_y, building_id)
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
        else:
            self._draw_default(screen, building, draw_x, draw_y)

    # =========================================================================
    # 🎰 카지노 - 사이버펑크 네온 스타일
    # =========================================================================
    def _draw_casino(self, screen, building, x, y, building_id):
        """카지노 - 화려한 네온 사이버펑크"""
        w, h = building.width, building.height

        # 그림자
        shadow = pygame.Surface((w + 10, h + 10), pygame.SRCALPHA)
        pygame.draw.rect(shadow, (0, 0, 0, 100), (10, 10, w, h), border_radius=5)
        screen.blit(shadow, (x - 5, y - 5))

        # 메인 건물 - 어두운 금속 느낌
        pygame.draw.rect(screen, (30, 30, 40), (x, y, w, h), border_radius=8)

        # 네온 스트라이프 (대각선)
        stripe_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        for i in range(-h, w, 20):
            color_idx = (i // 20) % 3
            colors = [Colors.NEON_PINK, Colors.NEON_CYAN, Colors.NEON_PURPLE]
            alpha = int(80 + 40 * math.sin(self.animation_timer * 3 + i * 0.1))
            pygame.draw.line(stripe_surf, (*colors[color_idx], alpha),
                           (i, h), (i + h, 0), 3)
        screen.blit(stripe_surf, (x, y))

        # 프레임
        pygame.draw.rect(screen, Colors.NEON_PINK, (x, y, w, h), 3, border_radius=8)

        # 상단 네온 사인 "CASINO"
        sign_y = y - 30
        sign_w = min(w - 20, 120)
        sign_x = x + (w - sign_w) // 2

        # 네온 사인 글로우
        glow_pulse = abs(math.sin(self.animation_timer * 4))
        glow_surf = pygame.Surface((sign_w + 30, 40), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*Colors.NEON_PINK, int(100 * glow_pulse)),
                        (0, 0, sign_w + 30, 40), border_radius=5)
        screen.blit(glow_surf, (sign_x - 15, sign_y - 5))

        # 사인 배경
        pygame.draw.rect(screen, (20, 20, 30), (sign_x, sign_y, sign_w, 30), border_radius=5)

        # 깜빡이는 텍스트
        if int(self.animation_timer * 8) % 2 == 0:
            font = pygame.font.Font(None, 28)
            text = font.render("CASINO", True, Colors.NEON_PINK)
            screen.blit(text, (sign_x + sign_w // 2 - text.get_width() // 2, sign_y + 5))

        # 네온 라인 장식
        line_y = y + h - 15
        for i in range(3):
            pulse = abs(math.sin(self.animation_timer * 5 + i * 0.5))
            color = Colors.NEON_CYAN if i % 2 == 0 else Colors.NEON_PINK
            pygame.draw.line(screen, color,
                           (x + 10, line_y + i * 4), (x + w - 10, line_y + i * 4), 2)

        # 슬롯머신 아이콘들 (회전)
        self._draw_slot_icons(screen, x + w // 2, y + h // 2 - 10)

        # 입구 (네온 프레임)
        door_w, door_h = 35, 45
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h
        pygame.draw.rect(screen, (10, 10, 20), (door_x, door_y, door_w, door_h))
        pulse = abs(math.sin(self.animation_timer * 3))
        pygame.draw.rect(screen, (*Colors.NEON_CYAN, int(200 + 55 * pulse)),
                        (door_x, door_y, door_w, door_h), 3)

        # 파티클 (동전 반짝임)
        if random.random() < 0.1:
            self.particles[building_id].append({
                'x': x + random.randint(10, w - 10),
                'y': y + random.randint(10, h - 30),
                'life': 0.5,
                'type': 'sparkle',
                'color': Colors.UI_ACCENT
            })

        self._draw_particles(screen, building_id, (x, y))

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
    # ⚔️ 콜로세움 - 고대 로마 신전 스타일
    # =========================================================================
    def _draw_colosseum(self, screen, building, x, y, building_id):
        """콜로세움 - 웅장한 고대 신전"""
        w, h = building.width, building.height

        # 그림자
        shadow_surf = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 80), (10, h, w, 20))
        screen.blit(shadow_surf, (x - 5, y))

        # 기단 (계단)
        base_color = (180, 160, 140)
        for i in range(3):
            step_y = y + h - 15 + i * 5
            step_w = w - i * 20
            step_x = x + i * 10
            pygame.draw.rect(screen, base_color, (step_x, step_y, step_w, 8))
            pygame.draw.rect(screen, (150, 130, 110), (step_x, step_y, step_w, 8), 1)

        # 메인 건물 (원형 아레나 느낌)
        main_color = (200, 180, 160)
        dark_color = (150, 130, 110)

        # 아치형 구조
        arch_count = max(3, w // 50)
        arch_width = (w - 20) // arch_count

        for i in range(arch_count):
            arch_x = x + 10 + i * arch_width
            # 아치 배경
            pygame.draw.rect(screen, main_color,
                           (arch_x, y + 30, arch_width - 5, h - 50))
            # 아치 (반원)
            pygame.draw.arc(screen, dark_color,
                          (arch_x, y + 25, arch_width - 5, 40),
                          0, math.pi, 3)
            # 아치 내부 어둡게
            pygame.draw.rect(screen, (60, 50, 40),
                           (arch_x + 5, y + 45, arch_width - 15, h - 70))

        # 기둥들
        pillar_positions = [x + 5, x + w - 20]
        for px in pillar_positions:
            # 기둥 본체
            pygame.draw.rect(screen, (220, 200, 180), (px, y + 20, 15, h - 35))
            # 기둥 음영
            pygame.draw.rect(screen, (180, 160, 140), (px, y + 20, 5, h - 35))
            # 기둥 상단 장식
            pygame.draw.rect(screen, (200, 180, 160), (px - 3, y + 15, 21, 10))
            # 기둥 하단
            pygame.draw.rect(screen, (200, 180, 160), (px - 2, y + h - 20, 19, 8))

        # 삼각형 지붕 (페디먼트)
        roof_points = [
            (x - 5, y + 20),
            (x + w // 2, y - 25),
            (x + w + 5, y + 20)
        ]
        pygame.draw.polygon(screen, (180, 160, 140), roof_points)
        pygame.draw.polygon(screen, dark_color, roof_points, 3)

        # 지붕 내부 장식 (독수리/방패)
        shield_x = x + w // 2
        shield_y = y
        pygame.draw.circle(screen, (150, 130, 110), (shield_x, shield_y), 15)
        pygame.draw.circle(screen, Colors.UI_ACCENT, (shield_x, shield_y), 12)
        # 검 장식
        pygame.draw.line(screen, (100, 80, 60), (shield_x, shield_y - 8), (shield_x, shield_y + 8), 3)
        pygame.draw.line(screen, (100, 80, 60), (shield_x - 6, shield_y - 3), (shield_x + 6, shield_y - 3), 3)

        # 깃발
        flag_x = x + w - 30
        flag_y = y - 20
        # 깃대
        pygame.draw.line(screen, (100, 80, 60), (flag_x, flag_y), (flag_x, flag_y + 40), 3)
        # 깃발 (펄럭임)
        wave = math.sin(self.animation_timer * 3) * 5
        flag_points = [
            (flag_x, flag_y),
            (flag_x + 25 + wave, flag_y + 8),
            (flag_x + 20 + wave * 0.5, flag_y + 15),
            (flag_x, flag_y + 20)
        ]
        pygame.draw.polygon(screen, (180, 50, 50), flag_points)

        # 횃불 효과
        torch_positions = [(x + 25, y + 35), (x + w - 35, y + 35)]
        for tx, ty in torch_positions:
            self._draw_torch(screen, tx, ty, building_id)

        self._draw_particles(screen, building_id, (x, y))

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
    # 🔨 대장장이 - 화산/용광로 스타일
    # =========================================================================
    def _draw_blacksmith(self, screen, building, x, y, building_id):
        """대장장이 - 불타는 용광로"""
        w, h = building.width, building.height

        # 연기 파티클
        if random.random() < 0.2:
            self.particles[building_id].append({
                'x': x + w // 2 + random.randint(-10, 10),
                'y': y - 10,
                'vx': random.uniform(-10, 10),
                'vy': random.uniform(-40, -20),
                'life': 2.0,
                'type': 'smoke',
                'size': random.randint(8, 15)
            })

        # 그림자
        pygame.draw.ellipse(screen, (0, 0, 0, 80),
                           (x - 5, y + h - 5, w + 10, 15))

        # 메인 건물 (검은 돌/철)
        base_color = (50, 45, 45)
        pygame.draw.rect(screen, base_color, (x, y + 20, w, h - 20), border_radius=5)

        # 벽돌 텍스처
        brick_color = (70, 60, 55)
        for row in range(0, h - 30, 15):
            offset = 10 if (row // 15) % 2 == 0 else 0
            for col in range(-offset, w, 30):
                bx = x + col
                by = y + 25 + row
                if x <= bx < x + w - 5:
                    pygame.draw.rect(screen, brick_color, (bx, by, 28, 13), border_radius=2)

        # 굴뚝
        chimney_x = x + w - 30
        chimney_w = 25
        pygame.draw.rect(screen, (40, 35, 35), (chimney_x, y - 30, chimney_w, 50))
        pygame.draw.rect(screen, (60, 55, 50), (chimney_x - 3, y - 35, chimney_w + 6, 8))

        # 굴뚝에서 나오는 불빛
        glow_pulse = abs(math.sin(self.animation_timer * 5))
        glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (255, 100, 50, int(100 * glow_pulse)), (20, 30), 15)
        screen.blit(glow_surf, (chimney_x - 8, y - 50))

        # 용광로 (앞면)
        furnace_w = min(50, w - 20)
        furnace_x = x + (w - furnace_w) // 2
        furnace_y = y + h - 60

        # 용광로 틀
        pygame.draw.rect(screen, (80, 70, 60), (furnace_x - 5, furnace_y - 5, furnace_w + 10, 45))
        pygame.draw.rect(screen, (60, 50, 45), (furnace_x - 5, furnace_y - 5, furnace_w + 10, 45), 3)

        # 불타는 내부
        fire_pulse = abs(math.sin(self.animation_timer * 8))
        inner_color = (255, int(100 + 80 * fire_pulse), 30)
        pygame.draw.rect(screen, inner_color, (furnace_x, furnace_y, furnace_w, 35))

        # 불꽃 효과
        for i in range(3):
            flame_x = furnace_x + 10 + i * 15
            flame_h = 20 + math.sin(self.animation_timer * 10 + i) * 10
            points = [
                (flame_x, furnace_y),
                (flame_x - 8, furnace_y + 35),
                (flame_x + 8, furnace_y + 35)
            ]
            pygame.draw.polygon(screen, (255, 200, 50), points)

        # 모루
        anvil_x = x + 15
        anvil_y = y + h - 25
        pygame.draw.rect(screen, (60, 60, 70), (anvil_x, anvil_y, 30, 15))  # 상단
        pygame.draw.rect(screen, (50, 50, 60), (anvil_x + 5, anvil_y + 15, 20, 10))  # 하단

        # 망치 (위아래로 움직임)
        hammer_y_offset = abs(math.sin(self.animation_timer * 6)) * 15
        hammer_x = anvil_x + 35
        hammer_y = anvil_y - 20 - hammer_y_offset
        pygame.draw.rect(screen, (100, 80, 60), (hammer_x + 8, hammer_y, 4, 25))  # 자루
        pygame.draw.rect(screen, (80, 80, 90), (hammer_x, hammer_y - 5, 20, 12))  # 머리

        # 스파크 효과
        if hammer_y_offset < 3 and random.random() < 0.5:
            for _ in range(3):
                self.particles[building_id].append({
                    'x': anvil_x + 20,
                    'y': anvil_y,
                    'vx': random.uniform(-100, 100),
                    'vy': random.uniform(-80, -30),
                    'life': 0.3,
                    'type': 'spark',
                    'color': (255, 255, 100),
                    'gravity': True
                })

        # 간판
        sign_text = "⚒️ FORGE"
        font = pygame.font.Font(None, 20)
        text = font.render(sign_text, True, Colors.NEON_ORANGE)
        screen.blit(text, (x + w // 2 - text.get_width() // 2, y + 5))

        self._draw_particles(screen, building_id, (x, y))

    # =========================================================================
    # 🛒 아이템 상점 - 마법의 에너지 스타일
    # =========================================================================
    def _draw_shop(self, screen, building, x, y, building_id):
        """아이템 상점 - 마법 상점"""
        w, h = building.width, building.height

        # 마법 글로우 배경
        glow_surf = pygame.Surface((w + 40, h + 40), pygame.SRCALPHA)
        pulse = abs(math.sin(self.animation_timer * 2))
        pygame.draw.ellipse(glow_surf, (100, 150, 255, int(50 * pulse)),
                           (0, 0, w + 40, h + 40))
        screen.blit(glow_surf, (x - 20, y - 20))

        # 메인 건물 (보라색 톤)
        base_color = (40, 30, 60)
        pygame.draw.rect(screen, base_color, (x, y + 15, w, h - 15), border_radius=10)

        # 지붕 (뾰족한 마법사 모자 스타일)
        roof_color = (60, 40, 100)
        roof_points = [
            (x - 10, y + 20),
            (x + w // 2, y - 35),
            (x + w + 10, y + 20)
        ]
        pygame.draw.polygon(screen, roof_color, roof_points)
        pygame.draw.polygon(screen, (80, 60, 130), roof_points, 3)

        # 지붕 별 장식
        star_x = x + w // 2
        star_y = y - 25
        self._draw_magic_star(screen, star_x, star_y, 10, Colors.UI_ACCENT)

        # 마법 룬 문양
        rune_y = y + h // 2
        for i in range(3):
            rune_x = x + 20 + i * (w - 40) // 2
            angle = self.animation_timer * 2 + i * (math.pi * 2 / 3)
            rune_color = (150 + int(50 * math.sin(angle)), 100, 255)
            self._draw_rune(screen, rune_x, rune_y, rune_color)

        # 진열창
        window_w = w - 30
        window_h = 35
        window_x = x + 15
        window_y = y + 35

        pygame.draw.rect(screen, (20, 20, 40), (window_x, window_y, window_w, window_h), border_radius=5)
        pygame.draw.rect(screen, (100, 150, 255), (window_x, window_y, window_w, window_h), 2, border_radius=5)

        # 진열된 아이템들 (반짝임)
        item_icons = ['💎', '⚗️', '📜', '🔮']
        for i, icon in enumerate(item_icons):
            if i < window_w // 25:
                ix = window_x + 12 + i * 25
                iy = window_y + 10
                bounce = math.sin(self.animation_timer * 3 + i) * 3
                font = pygame.font.Font(None, 20)
                text = font.render(icon, True, (255, 255, 255))
                screen.blit(text, (ix, iy + bounce))

        # 문
        door_w, door_h = 30, 45
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        pygame.draw.rect(screen, (50, 30, 70), (door_x, door_y, door_w, door_h), border_radius=5)
        # 문 아치
        pygame.draw.arc(screen, (100, 150, 255),
                       (door_x - 5, door_y - 10, door_w + 10, 30), 0, math.pi, 3)

        # 간판 (떠다니는 느낌)
        sign_y = y - 5 + math.sin(self.animation_timer * 2) * 3
        sign_surf = pygame.Surface((80, 25), pygame.SRCALPHA)
        pygame.draw.rect(sign_surf, (40, 30, 60, 230), (0, 0, 80, 25), border_radius=5)
        pygame.draw.rect(sign_surf, (150, 100, 255), (0, 0, 80, 25), 2, border_radius=5)
        font = pygame.font.Font(None, 18)
        text = font.render("MAGIC SHOP", True, Colors.TEXT_WHITE)
        sign_surf.blit(text, (5, 5))
        screen.blit(sign_surf, (x + w // 2 - 40, sign_y))

        # 마법 파티클
        if random.random() < 0.15:
            self.particles[building_id].append({
                'x': x + random.randint(0, w),
                'y': y + h,
                'vx': random.uniform(-20, 20),
                'vy': random.uniform(-60, -30),
                'life': 1.5,
                'type': 'magic',
                'color': random.choice([(100, 150, 255), (200, 100, 255), (150, 255, 200)])
            })

        self._draw_particles(screen, building_id, (x, y))

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
    # 🐾 펫 상점 - 자연/숲 스타일
    # =========================================================================
    def _draw_pet_shop(self, screen, building, x, y, building_id):
        """펫 상점 - 자연친화적 디자인"""
        w, h = building.width, building.height

        # 풀/덩굴 배경
        for i in range(5):
            vine_x = x + random.randint(0, w)
            vine_h = random.randint(20, 40)
            pygame.draw.line(screen, (50, 120, 50),
                           (vine_x, y + h), (vine_x + random.randint(-10, 10), y + h - vine_h), 2)

        # 메인 건물 (나무 느낌)
        wood_color = (101, 67, 33)
        pygame.draw.rect(screen, wood_color, (x, y + 20, w, h - 20), border_radius=8)

        # 나무 결 텍스처
        for i in range(0, w - 5, 8):
            pygame.draw.line(screen, (80, 50, 25),
                           (x + i, y + 25), (x + i, y + h - 5), 1)

        # 초가지붕
        roof_color = (180, 160, 100)
        for layer in range(3):
            roof_y = y + 15 - layer * 8
            roof_w = w + 20 - layer * 10
            roof_x = x - 10 + layer * 5

            pygame.draw.ellipse(screen, roof_color,
                              (roof_x, roof_y, roof_w, 25))

        # 지붕 위 새
        bird_x = x + w - 25
        bird_y = y - 5 + math.sin(self.animation_timer * 4) * 3
        pygame.draw.ellipse(screen, (200, 150, 100), (bird_x, bird_y, 15, 10))
        pygame.draw.circle(screen, (200, 150, 100), (bird_x + 13, bird_y + 3), 5)
        # 부리
        pygame.draw.polygon(screen, (255, 200, 100),
                           [(bird_x + 17, bird_y + 4), (bird_x + 22, bird_y + 5), (bird_x + 17, bird_y + 6)])

        # 창문 (새장 모양)
        cage_x = x + 15
        cage_y = y + 40
        cage_w, cage_h = 35, 40

        pygame.draw.rect(screen, (60, 40, 20), (cage_x, cage_y, cage_w, cage_h), border_radius=5)
        # 새장 바
        for i in range(5):
            bar_x = cage_x + 5 + i * 7
            pygame.draw.line(screen, (150, 120, 80), (bar_x, cage_y + 5), (bar_x, cage_y + cage_h - 5), 2)

        # 창문 안 작은 동물
        pet_y = cage_y + 20 + math.sin(self.animation_timer * 5) * 5
        pygame.draw.circle(screen, (255, 200, 150), (cage_x + cage_w // 2, int(pet_y)), 8)
        pygame.draw.circle(screen, (50, 50, 50), (cage_x + cage_w // 2 - 3, int(pet_y) - 2), 2)
        pygame.draw.circle(screen, (50, 50, 50), (cage_x + cage_w // 2 + 3, int(pet_y) - 2), 2)

        # 문 (둥근 아치)
        door_w, door_h = 30, 45
        door_x = x + w - door_w - 15
        door_y = y + h - door_h

        pygame.draw.rect(screen, (70, 45, 25), (door_x, door_y, door_w, door_h))
        pygame.draw.arc(screen, (90, 60, 35),
                       (door_x - 5, door_y - 15, door_w + 10, 30), 0, math.pi, 5)

        # 발자국 장식
        paw_y = y + h + 5
        for i in range(3):
            paw_x = x + 20 + i * 30
            self._draw_paw_print(screen, paw_x, paw_y, (100, 80, 60))

        # 간판
        sign_surf = pygame.Surface((70, 25), pygame.SRCALPHA)
        pygame.draw.rect(sign_surf, (80, 50, 30), (0, 0, 70, 25), border_radius=5)
        font = pygame.font.Font(None, 16)
        text = font.render("🐾 PETS", True, Colors.TEXT_WHITE)
        sign_surf.blit(text, (10, 5))
        screen.blit(sign_surf, (x + w // 2 - 35, y + 5))

        # 나뭇잎 파티클
        if random.random() < 0.1:
            self.particles[building_id].append({
                'x': x + random.randint(0, w),
                'y': y,
                'vx': random.uniform(-30, 30),
                'vy': random.uniform(20, 40),
                'life': 2.0,
                'type': 'leaf',
                'rotation': random.uniform(0, 360),
                'color': random.choice([(100, 180, 80), (80, 150, 60)])
            })

        self._draw_particles(screen, building_id, (x, y))

    def _draw_paw_print(self, screen, x, y, color):
        """발자국 그리기"""
        pygame.draw.ellipse(screen, color, (x, y, 12, 10))
        pygame.draw.circle(screen, color, (x - 2, y - 5), 4)
        pygame.draw.circle(screen, color, (x + 5, y - 7), 4)
        pygame.draw.circle(screen, color, (x + 12, y - 5), 4)

    # =========================================================================
    # 👴 현자의 오두막 - 이집트/고대 마법 스타일
    # =========================================================================
    def _draw_elder_hut(self, screen, building, x, y, building_id):
        """현자의 오두막 - 피라미드/고대 이집트"""
        w, h = building.width, building.height

        # 신비로운 글로우
        glow_pulse = abs(math.sin(self.animation_timer * 1.5))
        glow_surf = pygame.Surface((w + 60, h + 60), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (255, 215, 0, int(40 * glow_pulse)),
                           (0, 0, w + 60, h + 60))
        screen.blit(glow_surf, (x - 30, y - 30))

        # 피라미드 형태
        pyramid_color = (194, 178, 128)
        dark_sand = (160, 140, 100)

        # 피라미드 본체
        pyramid_points = [
            (x + w // 2, y - 20),  # 꼭대기
            (x - 10, y + h),       # 왼쪽 하단
            (x + w + 10, y + h)    # 오른쪽 하단
        ]
        pygame.draw.polygon(screen, pyramid_color, pyramid_points)

        # 피라미드 음영 (오른쪽 면)
        shadow_points = [
            (x + w // 2, y - 20),
            (x + w // 2 + 10, y + h // 2),
            (x + w + 10, y + h)
        ]
        pygame.draw.polygon(screen, dark_sand, shadow_points)

        # 피라미드 벽돌 라인
        for i in range(5):
            line_y = y + 10 + i * (h // 5)
            left_x = x + (w // 2) * (i / 5) - 5
            right_x = x + w - (w // 2) * (i / 5) + 5
            pygame.draw.line(screen, dark_sand, (left_x, line_y), (right_x, line_y), 1)

        # 눈 (호루스의 눈) - 중앙
        eye_x = x + w // 2
        eye_y = y + 30

        # 눈 글로우
        eye_glow = pygame.Surface((50, 40), pygame.SRCALPHA)
        pygame.draw.ellipse(eye_glow, (255, 200, 50, int(100 * glow_pulse)), (0, 0, 50, 40))
        screen.blit(eye_glow, (eye_x - 25, eye_y - 15))

        # 눈 본체
        pygame.draw.ellipse(screen, (255, 255, 200), (eye_x - 15, eye_y - 8, 30, 16))
        pygame.draw.ellipse(screen, (30, 100, 150), (eye_x - 8, eye_y - 5, 16, 10))
        pygame.draw.circle(screen, (0, 0, 0), (eye_x, eye_y), 4)
        # 눈 아래 장식
        pygame.draw.line(screen, (30, 100, 150), (eye_x, eye_y + 8), (eye_x - 10, eye_y + 20), 3)
        pygame.draw.line(screen, (30, 100, 150), (eye_x - 10, eye_y + 20), (eye_x - 5, eye_y + 25), 2)

        # 입구 (검은 공간)
        door_w = 25
        door_h = 40
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        # 입구 (사다리꼴)
        door_points = [
            (door_x + 3, door_y),
            (door_x + door_w - 3, door_y),
            (door_x + door_w, door_y + door_h),
            (door_x, door_y + door_h)
        ]
        pygame.draw.polygon(screen, (20, 15, 10), door_points)
        pygame.draw.polygon(screen, (255, 215, 0), door_points, 2)

        # 이집트 기둥 (양쪽)
        for px in [x + 5, x + w - 15]:
            pygame.draw.rect(screen, (180, 160, 120), (px, y + 30, 10, h - 30))
            # 기둥 상단 장식
            pygame.draw.rect(screen, (200, 180, 140), (px - 3, y + 25, 16, 10))
            # 상형문자 장식
            for i in range(3):
                hy = y + 45 + i * 20
                pygame.draw.rect(screen, (150, 130, 100), (px + 2, hy, 6, 10))

        # 떠다니는 고대 문자
        for i in range(3):
            char_x = x + 20 + i * 30
            char_y = y - 10 + math.sin(self.animation_timer * 2 + i) * 5
            chars = ['𓂀', '𓃭', '𓆣']  # 이집트 상형문자 스타일
            font = pygame.font.Font(None, 20)
            # 간단한 기호로 대체
            symbols = ['◈', '◊', '☥']
            text = font.render(symbols[i], True, (255, 215, 0, int(200 * glow_pulse)))
            screen.blit(text, (char_x, char_y))

        # 마법 파티클 (금빛)
        if random.random() < 0.1:
            self.particles[building_id].append({
                'x': x + w // 2 + random.randint(-30, 30),
                'y': y + random.randint(0, h),
                'vx': random.uniform(-10, 10),
                'vy': random.uniform(-40, -20),
                'life': 1.5,
                'type': 'ancient_magic',
                'color': (255, 215, 0)
            })

        self._draw_particles(screen, building_id, (x, y))

    # =========================================================================
    # 🎮 아케이드 - 레트로 사이버 스타일
    # =========================================================================
    def _draw_arcade(self, screen, building, x, y, building_id):
        """아케이드 - 레트로 게임 스타일"""
        w, h = building.width, building.height

        # 메인 건물
        pygame.draw.rect(screen, (30, 30, 50), (x, y + 10, w, h - 10), border_radius=5)

        # 네온 테두리
        colors = [Colors.NEON_PINK, Colors.NEON_CYAN, Colors.NEON_GREEN]
        for i, color in enumerate(colors):
            offset = i * 3
            alpha = int(150 + 100 * math.sin(self.animation_timer * 4 + i))
            pygame.draw.rect(screen, color,
                           (x - offset, y + 10 - offset, w + offset * 2, h - 10 + offset * 2),
                           2, border_radius=5 + offset)

        # 대형 스크린 (상단)
        screen_x = x + 10
        screen_y = y + 20
        screen_w = w - 20
        screen_h = 50

        pygame.draw.rect(screen, (0, 0, 0), (screen_x, screen_y, screen_w, screen_h))

        # 스크린 내용 (레트로 게임 화면)
        self._draw_retro_screen(screen, screen_x, screen_y, screen_w, screen_h)

        # 아케이드 기계들
        machine_w = 25
        machine_h = 45
        for i in range(min(3, (w - 20) // 30)):
            mx = x + 15 + i * 30
            my = y + h - machine_h - 5

            # 기계 본체
            machine_color = random.choice([(80, 40, 80), (40, 80, 80), (80, 80, 40)])
            pygame.draw.rect(screen, machine_color, (mx, my, machine_w, machine_h), border_radius=3)

            # 기계 화면
            pygame.draw.rect(screen, (0, 20, 0), (mx + 3, my + 5, machine_w - 6, 20))
            # 화면 내용 (랜덤 픽셀)
            for _ in range(5):
                px = mx + 5 + random.randint(0, machine_w - 12)
                py = my + 8 + random.randint(0, 14)
                pygame.draw.rect(screen, Colors.NEON_GREEN, (px, py, 3, 3))

        # ARCADE 간판
        sign_colors = [Colors.NEON_PINK, Colors.NEON_CYAN, Colors.NEON_GREEN, Colors.NEON_ORANGE]
        sign_y = y - 5
        text = "ARCADE"
        font = pygame.font.Font(None, 28)

        for i, char in enumerate(text):
            color_idx = (i + int(self.animation_timer * 5)) % len(sign_colors)
            char_surf = font.render(char, True, sign_colors[color_idx])
            screen.blit(char_surf, (x + 15 + i * 15, sign_y))

        # 픽셀 파티클
        if random.random() < 0.2:
            self.particles[building_id].append({
                'x': x + random.randint(0, w),
                'y': y + random.randint(0, h),
                'life': 0.3,
                'type': 'pixel',
                'color': random.choice(sign_colors)
            })

        self._draw_particles(screen, building_id, (x, y))

    def _draw_retro_screen(self, screen, x, y, w, h):
        """레트로 게임 화면"""
        # 스캔라인 효과
        for i in range(0, h, 2):
            pygame.draw.line(screen, (0, 30, 0), (x, y + i), (x + w, y + i), 1)

        # 간단한 게임 화면 (팩맨 스타일)
        pacman_x = x + 10 + (int(self.animation_timer * 50) % (w - 30))
        pacman_y = y + h // 2

        # 팩맨
        mouth_angle = abs(math.sin(self.animation_timer * 10)) * 45
        pygame.draw.circle(screen, Colors.NEON_YELLOW, (int(pacman_x), pacman_y), 8)
        # 입
        pygame.draw.polygon(screen, (0, 0, 0), [
            (pacman_x, pacman_y),
            (pacman_x + 10, pacman_y - 5),
            (pacman_x + 10, pacman_y + 5)
        ])

        # 점들
        for i in range(5):
            dot_x = x + 30 + i * 15
            if dot_x > pacman_x + 10:
                pygame.draw.circle(screen, Colors.TEXT_WHITE, (dot_x, pacman_y), 2)

    # =========================================================================
    # 🍺 선술집 - 중세 판타지 스타일
    # =========================================================================
    def _draw_tavern(self, screen, building, x, y, building_id):
        """선술집 - 중세 목조 건물"""
        w, h = building.width, building.height

        # 따뜻한 빛 글로우
        glow_surf = pygame.Surface((w + 40, h + 20), pygame.SRCALPHA)
        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 2))
        pygame.draw.ellipse(glow_surf, (255, 200, 100, int(60 * pulse)),
                           (0, h - 30, w + 40, 50))
        screen.blit(glow_surf, (x - 20, y))

        # 기초 (돌)
        pygame.draw.rect(screen, (100, 90, 80), (x - 5, y + h - 15, w + 10, 20))

        # 1층 (돌/회반죽)
        pygame.draw.rect(screen, (180, 170, 150), (x, y + h // 2, w, h // 2))

        # 2층 (목재 + 회반죽)
        pygame.draw.rect(screen, (200, 190, 170), (x - 10, y + 15, w + 20, h // 2 - 10))

        # 목재 프레임
        wood_color = (80, 50, 30)
        # 수직 빔
        pygame.draw.rect(screen, wood_color, (x - 10, y + 15, 8, h - 15))
        pygame.draw.rect(screen, wood_color, (x + w + 2, y + 15, 8, h - 15))
        pygame.draw.rect(screen, wood_color, (x + w // 2 - 4, y + 15, 8, h - 15))
        # 수평 빔
        pygame.draw.rect(screen, wood_color, (x - 10, y + h // 2, w + 20, 8))
        pygame.draw.rect(screen, wood_color, (x - 10, y + 15, w + 20, 8))
        # 대각선 빔
        pygame.draw.line(screen, wood_color, (x, y + 25), (x + w // 4, y + h // 2), 5)
        pygame.draw.line(screen, wood_color, (x + w, y + 25), (x + w * 3 // 4, y + h // 2), 5)

        # 지붕 (갈색 기와)
        roof_color = (120, 80, 50)
        roof_points = [
            (x - 20, y + 20),
            (x + w // 2, y - 25),
            (x + w + 20, y + 20)
        ]
        pygame.draw.polygon(screen, roof_color, roof_points)

        # 지붕 기와 라인
        for i in range(4):
            ty = y - 5 + i * 8
            pygame.draw.line(screen, (100, 60, 35),
                           (x - 15 + i * 5, ty + 20), (x + w + 15 - i * 5, ty + 20), 2)

        # 굴뚝 + 연기
        chimney_x = x + w - 20
        pygame.draw.rect(screen, (100, 80, 70), (chimney_x, y - 15, 15, 30))

        # 연기
        if random.random() < 0.15:
            self.particles[building_id].append({
                'x': chimney_x + 7,
                'y': y - 15,
                'vx': random.uniform(-5, 5),
                'vy': random.uniform(-30, -15),
                'life': 2.0,
                'type': 'smoke',
                'size': random.randint(5, 10)
            })

        # 창문 (따뜻한 빛)
        window_positions = [(x + 10, y + 30), (x + w - 35, y + 30)]
        for wx, wy in window_positions:
            # 창틀
            pygame.draw.rect(screen, wood_color, (wx - 2, wy - 2, 29, 29))
            # 창문 빛
            light_pulse = 0.8 + 0.2 * math.sin(self.animation_timer * 3 + wx)
            light_color = (255, int(200 * light_pulse), int(100 * light_pulse))
            pygame.draw.rect(screen, light_color, (wx, wy, 25, 25))
            # 창살
            pygame.draw.line(screen, wood_color, (wx + 12, wy), (wx + 12, wy + 25), 2)
            pygame.draw.line(screen, wood_color, (wx, wy + 12), (wx + 25, wy + 12), 2)

        # 문
        door_x = x + (w - 30) // 2
        door_y = y + h - 50
        pygame.draw.rect(screen, (60, 40, 25), (door_x, door_y, 30, 50), border_radius=3)
        pygame.draw.rect(screen, wood_color, (door_x, door_y, 30, 50), 3, border_radius=3)
        # 손잡이
        pygame.draw.circle(screen, (180, 150, 100), (door_x + 24, door_y + 30), 4)

        # 간판 (나무 현수막)
        sign_x = x + w - 15
        sign_y = y + 25
        # 쇠사슬
        pygame.draw.line(screen, (100, 100, 110), (sign_x + 15, y + 20), (sign_x + 15, sign_y), 2)
        # 간판
        sign_surf = pygame.Surface((45, 30), pygame.SRCALPHA)
        pygame.draw.rect(sign_surf, (80, 50, 30), (0, 0, 45, 30), border_radius=3)
        font = pygame.font.Font(None, 16)
        text = font.render("🍺", True, Colors.TEXT_WHITE)
        sign_surf.blit(text, (15, 5))
        swing = math.sin(self.animation_timer * 2) * 5
        rotated = pygame.transform.rotate(sign_surf, swing)
        screen.blit(rotated, (sign_x - 5, sign_y))

        self._draw_particles(screen, building_id, (x, y))

    # =========================================================================
    # 🏦 은행 - 그리스 신전 스타일
    # =========================================================================
    def _draw_bank(self, screen, building, x, y, building_id):
        """은행 - 웅장한 그리스 신전"""
        w, h = building.width, building.height

        # 대리석 베이스 색상
        marble = (240, 235, 230)
        marble_dark = (200, 195, 190)

        # 기단 (3단 계단)
        for i in range(3):
            step_y = y + h - 10 + i * 5
            step_w = w + 10 - i * 6
            step_x = x - 5 + i * 3
            pygame.draw.rect(screen, marble_dark, (step_x, step_y, step_w, 6))

        # 메인 건물
        pygame.draw.rect(screen, marble, (x, y + 25, w, h - 35))

        # 기둥들 (이오니아식)
        pillar_count = max(3, w // 35)
        pillar_spacing = (w - 20) // (pillar_count - 1)

        for i in range(pillar_count):
            px = x + 10 + i * pillar_spacing
            self._draw_ionic_pillar(screen, px, y + 20, h - 45)

        # 삼각형 지붕 (페디먼트)
        roof_points = [
            (x - 10, y + 25),
            (x + w // 2, y - 15),
            (x + w + 10, y + 25)
        ]
        pygame.draw.polygon(screen, marble, roof_points)
        pygame.draw.polygon(screen, marble_dark, roof_points, 3)

        # 지붕 내부 장식 (금화)
        coin_x = x + w // 2
        coin_y = y + 5
        pygame.draw.circle(screen, Colors.UI_ACCENT, (coin_x, coin_y), 12)
        pygame.draw.circle(screen, (200, 170, 50), (coin_x, coin_y), 10)
        font = pygame.font.Font(None, 20)
        text = font.render("$", True, (150, 120, 30))
        screen.blit(text, (coin_x - 5, coin_y - 7))

        # 입구 (큰 청동 문)
        door_w = min(40, w // 2)
        door_h = h - 50
        door_x = x + (w - door_w) // 2
        door_y = y + 30

        pygame.draw.rect(screen, (80, 70, 50), (door_x, door_y, door_w, door_h))
        # 문 패널
        panel_h = door_h // 3
        for i in range(3):
            py = door_y + 5 + i * panel_h
            pygame.draw.rect(screen, (100, 90, 70),
                           (door_x + 5, py, door_w - 10, panel_h - 8), border_radius=2)
        # 문 손잡이 (사자 머리)
        pygame.draw.circle(screen, (180, 160, 100), (door_x + door_w // 2, door_y + door_h // 2), 8)

        # 금빛 파티클
        if random.random() < 0.05:
            self.particles[building_id].append({
                'x': x + random.randint(10, w - 10),
                'y': y + random.randint(20, h - 20),
                'life': 1.0,
                'type': 'gold_sparkle',
                'color': Colors.UI_ACCENT
            })

        # BANK 글자
        font = pygame.font.Font(None, 22)
        text = font.render("BANK", True, marble_dark)
        screen.blit(text, (x + w // 2 - text.get_width() // 2, y + 10))

        self._draw_particles(screen, building_id, (x, y))

    def _draw_ionic_pillar(self, screen, x, y, height):
        """이오니아식 기둥"""
        pillar_w = 12
        marble = (240, 235, 230)
        shadow = (200, 195, 190)

        # 기둥 본체
        pygame.draw.rect(screen, marble, (x - pillar_w // 2, y, pillar_w, height))
        # 음영
        pygame.draw.rect(screen, shadow, (x - pillar_w // 2, y, 3, height))

        # 상단 (이오니아식 볼류트)
        pygame.draw.rect(screen, marble, (x - pillar_w // 2 - 4, y - 5, pillar_w + 8, 8))
        # 볼류트 (소용돌이)
        pygame.draw.circle(screen, shadow, (x - pillar_w // 2 - 2, y - 1), 4, 1)
        pygame.draw.circle(screen, shadow, (x + pillar_w // 2 + 2, y - 1), 4, 1)

        # 하단
        pygame.draw.rect(screen, marble, (x - pillar_w // 2 - 2, y + height - 5, pillar_w + 4, 8))

    # =========================================================================
    # ❓ 미스터리 - 신비로운 보이드 스타일
    # =========================================================================
    def _draw_mystery(self, screen, building, x, y, building_id):
        """미스터리 - 차원의 틈"""
        w, h = building.width, building.height

        # 검은 보이드 배경
        void_surf = pygame.Surface((w, h), pygame.SRCALPHA)

        # 보이드 중심
        cx, cy = w // 2, h // 2

        # 소용돌이 효과
        for ring in range(8, 0, -1):
            radius = ring * 15
            angle_offset = self.animation_timer * (ring * 0.3)

            alpha = int(200 - ring * 20)
            color = (
                int(80 + 20 * math.sin(self.animation_timer + ring)),
                0,
                int(120 + 30 * math.sin(self.animation_timer * 0.5 + ring))
            )

            points = []
            for i in range(12):
                angle = angle_offset + i * (math.pi * 2 / 12)
                r = radius + math.sin(angle * 3 + self.animation_timer * 2) * 10
                px = cx + r * math.cos(angle)
                py = cy + r * math.sin(angle)
                points.append((px, py))

            if len(points) >= 3:
                pygame.draw.polygon(void_surf, (*color, alpha), points, 2)

        # 중심 (더 진한 검정)
        pygame.draw.circle(void_surf, (10, 0, 20), (cx, cy), 30)
        pygame.draw.circle(void_surf, (30, 0, 50), (cx, cy), 25)

        # 물음표
        pulse = abs(math.sin(self.animation_timer * 3))
        font = pygame.font.Font(None, 48)
        question = font.render("?", True, (150 + int(100 * pulse), 50, 200))
        void_surf.blit(question, (cx - 10, cy - 20))

        screen.blit(void_surf, (x, y))

        # 프레임
        frame_color = (100, 0, 150)
        pygame.draw.rect(screen, frame_color, (x, y, w, h), 3, border_radius=10)

        # 깜빡이는 코너 장식
        corner_size = 10
        corners = [
            (x, y), (x + w - corner_size, y),
            (x, y + h - corner_size), (x + w - corner_size, y + h - corner_size)
        ]
        for i, (cx, cy) in enumerate(corners):
            blink = (int(self.animation_timer * 5) + i) % 4 == 0
            color = Colors.NEON_PURPLE if blink else (50, 0, 80)
            pygame.draw.rect(screen, color, (cx, cy, corner_size, corner_size))

        # 미스터리 파티클 (차원의 틈에서 나오는 것)
        if random.random() < 0.2:
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(30, 60)
            self.particles[building_id].append({
                'x': x + w // 2,
                'y': y + h // 2,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 1.0,
                'type': 'void',
                'color': (random.randint(100, 200), 0, random.randint(150, 255))
            })

        self._draw_particles(screen, building_id, (x, y))

    # =========================================================================
    # 🌟 가챠샵 - 화려한 별빛 스타일
    # =========================================================================
    def _draw_gacha(self, screen, building, x, y, building_id):
        """가챠샵 - 화려한 가챠 머신"""
        w, h = building.width, building.height

        # 반짝이는 글로우 배경
        glow_pulse = abs(math.sin(self.animation_timer * 3))
        glow_surf = pygame.Surface((w + 50, h + 50), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (255, 200, 50, int(80 * glow_pulse)),
                           (0, 0, w + 50, h + 50))
        screen.blit(glow_surf, (x - 25, y - 25))

        # 메인 건물 (빨간색 + 금색 조합)
        pygame.draw.rect(screen, (180, 50, 60), (x, y + 10, w, h - 10), border_radius=10)

        # 금색 테두리
        pygame.draw.rect(screen, (255, 200, 50), (x, y + 10, w, h - 10), 4, border_radius=10)

        # 상단 아치형 지붕 (파란색 돔)
        dome_rect = (x - 10, y - 20, w + 20, 50)
        pygame.draw.ellipse(screen, (50, 100, 180), dome_rect)
        pygame.draw.ellipse(screen, (255, 200, 50), dome_rect, 3)

        # 별 장식 (지붕 위)
        star_x = x + w // 2
        star_y = y - 25
        self._draw_gacha_star(screen, star_x, star_y, 15)

        # 가챠 머신 본체 (중앙)
        machine_w = min(55, w - 20)
        machine_h = h - 40
        machine_x = x + (w - machine_w) // 2
        machine_y = y + 25

        # 머신 외곽
        pygame.draw.rect(screen, (220, 180, 50), (machine_x - 5, machine_y - 5, machine_w + 10, machine_h + 10), border_radius=8)
        pygame.draw.rect(screen, (60, 30, 30), (machine_x, machine_y, machine_w, machine_h), border_radius=5)

        # 캡슐 보관 구역 (투명 돔)
        capsule_y = machine_y + 10
        capsule_h = machine_h - 50
        pygame.draw.ellipse(screen, (200, 200, 220, 150),
                           (machine_x + 5, capsule_y, machine_w - 10, capsule_h))
        pygame.draw.ellipse(screen, (255, 255, 255),
                           (machine_x + 5, capsule_y, machine_w - 10, capsule_h), 2)

        # 캡슐들 (다양한 색상)
        capsule_colors = [
            (255, 100, 100),  # 빨강
            (100, 200, 255),  # 파랑
            (255, 255, 100),  # 노랑
            (200, 100, 255),  # 보라
            (100, 255, 150),  # 초록
            (255, 180, 100),  # 주황
        ]

        for i in range(8):
            cx = machine_x + 12 + (i % 3) * 15 + random.randint(-2, 2)
            cy = capsule_y + 15 + (i // 3) * 18
            bounce = math.sin(self.animation_timer * 4 + i) * 2
            color = capsule_colors[i % len(capsule_colors)]
            # 캡슐 (상하 반구)
            pygame.draw.circle(screen, color, (int(cx), int(cy + bounce)), 6)
            pygame.draw.circle(screen, (255, 255, 255), (int(cx - 2), int(cy + bounce - 2)), 2)

        # 캡슐 배출구
        slot_y = machine_y + machine_h - 25
        pygame.draw.rect(screen, (30, 30, 30), (machine_x + 10, slot_y, machine_w - 20, 20), border_radius=5)
        pygame.draw.rect(screen, (255, 200, 50), (machine_x + 10, slot_y, machine_w - 20, 20), 2, border_radius=5)

        # 손잡이 (회전)
        handle_x = machine_x + machine_w + 5
        handle_y = machine_y + machine_h // 2
        rotation = self.animation_timer * 2
        pygame.draw.circle(screen, (150, 150, 160), (handle_x, handle_y), 8)
        handle_end_x = handle_x + math.cos(rotation) * 15
        handle_end_y = handle_y + math.sin(rotation) * 15
        pygame.draw.line(screen, (200, 200, 210), (handle_x, handle_y), (int(handle_end_x), int(handle_end_y)), 4)
        pygame.draw.circle(screen, (255, 100, 100), (int(handle_end_x), int(handle_end_y)), 5)

        # 간판 "GACHA" (반짝이는 네온)
        sign_y = y - 5
        sign_text = "GACHA"
        font = pygame.font.Font(None, 26)

        for i, char in enumerate(sign_text):
            char_pulse = abs(math.sin(self.animation_timer * 5 + i * 0.5))
            brightness = int(200 + 55 * char_pulse)
            char_color = (brightness, brightness, int(brightness * 0.6))
            char_surf = font.render(char, True, char_color)
            screen.blit(char_surf, (x + 15 + i * 14, sign_y))

        # 레어리티 표시 (별)
        rarity_y = y + h - 15
        for i in range(5):
            star_pulse = abs(math.sin(self.animation_timer * 3 + i * 0.3))
            alpha = int(150 + 105 * star_pulse)
            star_surf = pygame.Surface((12, 12), pygame.SRCALPHA)
            self._draw_mini_star(star_surf, 6, 6, 5, (255, 200, 50, alpha))
            screen.blit(star_surf, (x + 10 + i * 14, rarity_y))

        # 파티클 (별 반짝임)
        if random.random() < 0.2:
            self.particles[building_id].append({
                'x': x + random.randint(5, w - 5),
                'y': y + random.randint(5, h - 5),
                'vx': random.uniform(-30, 30),
                'vy': random.uniform(-50, -20),
                'life': 1.0,
                'type': 'gacha_star',
                'color': random.choice([(255, 200, 50), (255, 255, 100), (255, 150, 200)])
            })

        self._draw_particles(screen, building_id, (x, y))

    def _draw_gacha_star(self, screen, x, y, size):
        """가챠샵 상단 큰 별"""
        # 회전하는 별
        rotation = self.animation_timer * 2
        points = []
        for i in range(10):
            angle = rotation + i * math.pi / 5 - math.pi / 2
            r = size if i % 2 == 0 else size * 0.4
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points.append((px, py))

        # 글로우
        glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        glow_pulse = abs(math.sin(self.animation_timer * 4))
        pygame.draw.circle(glow_surf, (255, 255, 100, int(100 * glow_pulse)), (size * 2, size * 2), size + 5)
        screen.blit(glow_surf, (x - size * 2, y - size * 2))

        # 별 본체
        pygame.draw.polygon(screen, (255, 220, 50), points)
        pygame.draw.polygon(screen, (255, 255, 200), points, 2)

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
        """파티클 그리기"""
        if building_id not in self.particles:
            return

        ox, oy = offset
        for p in self.particles[building_id]:
            px = p['x']
            py = p['y']
            alpha = int(255 * (p['life'] / 2.0))

            if p['type'] == 'sparkle':
                size = 3 + int(3 * p['life'])
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*p['color'], alpha), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'ember':
                pygame.draw.circle(screen, p['color'], (int(px), int(py)), 2)

            elif p['type'] == 'smoke':
                size = p.get('size', 10) + int((2.0 - p['life']) * 5)
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (100, 100, 100, min(alpha, 100)), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'spark':
                pygame.draw.circle(screen, p['color'], (int(px), int(py)), 2)

            elif p['type'] == 'magic':
                size = int(4 * p['life'])
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*p['color'], alpha), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'leaf':
                surf = pygame.Surface((10, 6), pygame.SRCALPHA)
                pygame.draw.ellipse(surf, (*p['color'], alpha), (0, 0, 10, 6))
                rotated = pygame.transform.rotate(surf, p.get('rotation', 0))
                screen.blit(rotated, (px - 5, py - 3))
                p['rotation'] = p.get('rotation', 0) + 180 * 0.016

            elif p['type'] == 'ancient_magic':
                size = int(5 * p['life'])
                # 별 모양
                points = []
                for i in range(6):
                    angle = i * math.pi / 3 + self.animation_timer * 2
                    r = size if i % 2 == 0 else size * 0.5
                    points.append((px + r * math.cos(angle), py + r * math.sin(angle)))
                if len(points) >= 3:
                    surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
                    offset_points = [(p[0] - px + size * 1.5, p[1] - py + size * 1.5) for p in points]
                    pygame.draw.polygon(surf, (*p['color'], alpha), offset_points)
                    screen.blit(surf, (px - size * 1.5, py - size * 1.5))

            elif p['type'] == 'pixel':
                pygame.draw.rect(screen, p['color'], (int(px), int(py), 4, 4))

            elif p['type'] == 'gold_sparkle':
                size = int(4 * p['life'])
                pygame.draw.circle(screen, p['color'], (int(px), int(py)), size)

            elif p['type'] == 'void':
                size = int(6 * p['life'])
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*p['color'], alpha), (size, size), size)
                screen.blit(surf, (px - size, py - size))

            elif p['type'] == 'gacha_star':
                size = int(8 * p['life'])
                # 별 모양 파티클
                points = []
                for i in range(10):
                    angle = i * math.pi / 5 - math.pi / 2 + self.animation_timer * 3
                    r = size if i % 2 == 0 else size * 0.4
                    points.append((px + r * math.cos(angle), py + r * math.sin(angle)))
                if len(points) >= 3:
                    surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
                    offset_points = [(pt[0] - px + size * 1.5, pt[1] - py + size * 1.5) for pt in points]
                    pygame.draw.polygon(surf, (*p['color'], alpha), offset_points)
                    screen.blit(surf, (px - size * 1.5, py - size * 1.5))


# 싱글톤 인스턴스
_building_designer = None

def get_building_designer():
    """BuildingDesigner 싱글톤 반환"""
    global _building_designer
    if _building_designer is None:
        _building_designer = BuildingDesigner()
    return _building_designer
