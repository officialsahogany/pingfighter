"""
역경의 갑옷 (Adversity Armor) - 패시브 아이템
실점 후 20~30% 확률로 무적 발동.
무적 발동 시 다음 라운드 8~15초 동안 무적 (공이 바닥에 닿아도 반사됨).
무적 동안 플레이어 패들 주변에 오오라 발생.
다음 서브 시 공 속도 +20%.
"""

import math
import random
import os

# pygame은 런타임에만 사용 (테스트 호환성)
try:
    import pygame
except ImportError:
    pygame = None


class AdversityArmor:
    """역경의 갑옷 패시브 아이템 클래스"""

    def __init__(self):
        self.active = False  # 아이템 보유 여부
        self.invincible = False  # 현재 무적 상태
        self.invincible_timer = 0  # 무적 남은 프레임
        self.invincible_duration_frames = 0  # 이번 무적의 총 프레임
        self.serve_speed_boost = False  # 서브 시 속도 부스트 활성화 여부
        self.pending_invincible = False  # 다음 라운드에 무적 발동 예약

        # 롤 옵션 기본값 (ensure_passive_rolls로 덮어씀)
        self.trigger_chance_pct = 25  # 무적 발동 확률 (20~30%)
        self.invincible_duration_sec = 10  # 무적 지속시간 (8~15초)
        self.serve_speed_bonus_pct = 20  # 서브 속도 보너스 (고정 20%)

        # 오라 이펙트용
        self._aura_phase = 0.0  # 오라 애니메이션 위상
        self._aura_particles = []  # 오라 파티클 리스트

        # 방어막 이펙트용
        self._barrier_phase = 0.0  # 방어막 애니메이션 위상
        self._barrier_particles = []  # 방어막 에너지 파티클
        self._barrier_flash = 0  # 발동 순간 플래시 (프레임)

    def activate(self):
        """아이템 보유 활성화"""
        self.active = True

    def deactivate(self):
        """아이템 효과 전부 비활성화 (게임 종료/메뉴 복귀 시)"""
        self.active = False
        self.invincible = False
        self.invincible_timer = 0
        self.invincible_duration_frames = 0
        self.serve_speed_boost = False
        self.pending_invincible = False
        self._aura_phase = 0.0
        self._aura_particles.clear()
        self._barrier_phase = 0.0
        self._barrier_particles.clear()
        self._barrier_flash = 0

    def on_point_lost(self):
        """실점 시 호출 - 무적 발동 확률 체크"""
        if not self.active:
            return False

        roll = random.random() * 100
        if roll <= self.trigger_chance_pct:
            # 무적 발동 예약 (다음 라운드 시작 시 적용)
            self.pending_invincible = True
            self.serve_speed_boost = True
            return True
        return False

    def on_round_start(self):
        """라운드 시작 시 호출 - 예약된 무적 적용"""
        if self.pending_invincible:
            self.invincible = True
            self.invincible_duration_frames = int(self.invincible_duration_sec * 60)
            self.invincible_timer = self.invincible_duration_frames
            self.pending_invincible = False
            self._aura_particles.clear()
            self._barrier_particles.clear()
            self._barrier_flash = 30  # 발동 순간 0.5초 플래시
            return True
        return False

    def consume_serve_speed_boost(self):
        """서브 속도 보너스 소비 (1회성)"""
        if self.serve_speed_boost:
            self.serve_speed_boost = False
            return self.serve_speed_bonus_pct / 100.0  # 0.2 (20%)
        return 0.0

    def is_invincible(self):
        """현재 무적 상태인지 반환"""
        return self.active and self.invincible and self.invincible_timer > 0

    def update(self, dt_frames=1):
        """매 프레임 호출"""
        if not self.active:
            return

        if self.invincible and self.invincible_timer > 0:
            self.invincible_timer -= dt_frames
            self._aura_phase += 0.05  # 오라 회전 속도

            # 오라 파티클 생성
            if random.random() < 0.3:
                angle = random.uniform(0, math.pi * 2)
                speed = random.uniform(0.5, 1.5)
                self._aura_particles.append({
                    "angle": angle,
                    "radius": random.uniform(30, 50),
                    "speed": speed,
                    "life": random.randint(20, 40),
                    "max_life": random.randint(20, 40),
                    "size": random.randint(2, 5),
                })

            # 파티클 업데이트
            alive = []
            for p in self._aura_particles:
                p["life"] -= 1
                p["angle"] += p["speed"] * 0.05
                p["radius"] += 0.2
                if p["life"] > 0:
                    alive.append(p)
            self._aura_particles = alive

            # 방어막 파티클 생성 (바닥 벽 주변)
            self._barrier_phase += 0.08
            if random.random() < 0.5:
                self._barrier_particles.append({
                    "x_offset": random.uniform(-300, 300),
                    "y": 0.0,
                    "speed": random.uniform(0.3, 1.0),
                    "life": random.randint(25, 50),
                    "max_life": random.randint(25, 50),
                    "size": random.randint(2, 4),
                })

            # 방어막 파티클 업데이트
            alive_bp = []
            for bp in self._barrier_particles:
                bp["life"] -= 1
                bp["y"] -= bp["speed"]  # 위로 올라감
                if bp["life"] > 0:
                    alive_bp.append(bp)
            self._barrier_particles = alive_bp

            # 발동 플래시 감소
            if self._barrier_flash > 0:
                self._barrier_flash -= 1

            if self.invincible_timer <= 0:
                self.invincible = False
                self.invincible_timer = 0
                self._aura_particles.clear()
                self._barrier_particles.clear()
                self._barrier_flash = 0

    def draw_effects(self, screen, player_rect, game_area_left=80, game_area_width=600, screen_height=750):
        """무적 오라 이펙트 + 바닥 방어막 그리기"""
        if not self.active or not self.invincible or not pygame:
            return

        cx = player_rect.centerx
        cy = player_rect.centery

        # ── 패들 주변 오라 ──
        # 외곽 글로우 (투명도 변화)
        glow_alpha = int(80 + 40 * math.sin(self._aura_phase * 2))
        glow_radius = 55 + int(8 * math.sin(self._aura_phase * 1.5))
        glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surface, (255, 200, 50, glow_alpha), (glow_radius, glow_radius), glow_radius)
        screen.blit(glow_surface, (cx - glow_radius, cy - glow_radius))

        # 내부 빛 링
        ring_radius = 40 + int(5 * math.sin(self._aura_phase * 3))
        ring_alpha = int(120 + 60 * math.sin(self._aura_phase * 2.5))
        ring_surface = pygame.Surface((ring_radius * 2 + 4, ring_radius * 2 + 4), pygame.SRCALPHA)
        pygame.draw.circle(ring_surface, (255, 220, 100, ring_alpha), (ring_radius + 2, ring_radius + 2), ring_radius, 2)
        screen.blit(ring_surface, (cx - ring_radius - 2, cy - ring_radius - 2))

        # 패들 오라 파티클
        for p in self._aura_particles:
            alpha = int(200 * (p["life"] / max(p["max_life"], 1)))
            px = cx + int(math.cos(p["angle"]) * p["radius"])
            py = cy + int(math.sin(p["angle"]) * p["radius"])
            size = p["size"]
            if alpha > 0:
                ps = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (255, 230, 120, min(alpha, 255)), (size, size), size)
                screen.blit(ps, (px - size, py - size))

        # ── 바닥 보호벽 이펙트 ──
        barrier_y = screen_height - 6  # 바닥에서 약간 위
        barrier_left = game_area_left
        barrier_right = game_area_left + game_area_width
        barrier_cx = barrier_left + game_area_width // 2

        # 발동 순간 플래시 (화면 하단 전체 밝게)
        if self._barrier_flash > 0:
            flash_alpha = int(180 * (self._barrier_flash / 30.0))
            flash_h = 60
            flash_surf = pygame.Surface((game_area_width, flash_h), pygame.SRCALPHA)
            flash_surf.fill((255, 220, 100, flash_alpha))
            screen.blit(flash_surf, (barrier_left, screen_height - flash_h))

        # 메인 방어막 라인 (맥동하는 에너지 장벽)
        time_ratio = max(0.0, self.invincible_timer / max(self.invincible_duration_frames, 1))
        pulse = math.sin(self._barrier_phase * 3)

        # 외곽 글로우 라인 (두꺼운 반투명)
        line_alpha = int((50 + 30 * pulse) * time_ratio) + 20
        glow_h = 12 + int(4 * pulse)
        glow_surf = pygame.Surface((game_area_width, glow_h), pygame.SRCALPHA)
        glow_surf.fill((255, 200, 50, min(line_alpha, 255)))
        screen.blit(glow_surf, (barrier_left, barrier_y - glow_h // 2))

        # 코어 방어막 라인 (밝은 실선)
        core_alpha = int((160 + 60 * pulse) * time_ratio) + 40
        pygame.draw.line(screen, (255, 240, 150), (barrier_left, barrier_y), (barrier_right, barrier_y), 2)

        # 에너지 노드 (방어막 위 빛나는 점들)
        node_count = 8
        for i in range(node_count):
            nx = barrier_left + int(game_area_width * (i + 0.5) / node_count)
            node_offset = math.sin(self._barrier_phase * 2 + i * 0.8) * 3
            ny = barrier_y + int(node_offset)
            node_alpha = int((140 + 80 * math.sin(self._barrier_phase * 4 + i)) * time_ratio) + 30
            node_r = 3 + int(2 * math.sin(self._barrier_phase * 3 + i * 1.2))
            ns = pygame.Surface((node_r * 2, node_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(ns, (255, 255, 200, min(node_alpha, 255)), (node_r, node_r), node_r)
            screen.blit(ns, (nx - node_r, ny - node_r))

        # 방어막 상승 파티클
        for bp in self._barrier_particles:
            bp_alpha = int(180 * (bp["life"] / max(bp["max_life"], 1)) * time_ratio) + 10
            bpx = barrier_cx + int(bp["x_offset"])
            bpy = barrier_y + int(bp["y"])
            sz = bp["size"]
            if bp_alpha > 0 and barrier_left <= bpx <= barrier_right:
                bps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(bps, (255, 220, 100, min(bp_alpha, 255)), (sz, sz), sz)
                screen.blit(bps, (bpx - sz, bpy - sz))

        # 양쪽 끝 기둥 에너지 (방어막 앵커)
        for anchor_x in (barrier_left, barrier_right):
            pillar_h = 20 + int(6 * pulse)
            pillar_alpha = int((80 + 40 * pulse) * time_ratio) + 20
            pillar_surf = pygame.Surface((6, pillar_h), pygame.SRCALPHA)
            pillar_surf.fill((255, 200, 80, min(pillar_alpha, 255)))
            screen.blit(pillar_surf, (anchor_x - 3, barrier_y - pillar_h))

    def get_remaining_seconds(self):
        """무적 남은 시간(초) 반환"""
        if self.invincible:
            return max(0, self.invincible_timer / 60.0)
        return 0.0


# 싱글톤 인스턴스
_adversity_armor_instance = None


def get_adversity_armor_instance():
    """싱글톤 인스턴스 반환"""
    global _adversity_armor_instance
    if _adversity_armor_instance is None:
        _adversity_armor_instance = AdversityArmor()
    return _adversity_armor_instance


def activate_adversity_armor():
    """아이템 획득 시 호출"""
    inst = get_adversity_armor_instance()
    inst.activate()


def deactivate_adversity_armor():
    """게임 종료/메뉴 복귀 시 호출"""
    inst = get_adversity_armor_instance()
    inst.deactivate()


def reset_adversity_armor():
    """완전 초기화"""
    inst = get_adversity_armor_instance()
    inst.deactivate()


def configure_adversity_armor(trigger_chance_pct=None, invincible_duration_sec=None):
    """롤 옵션 값을 인스턴스에 적용"""
    inst = get_adversity_armor_instance()
    if trigger_chance_pct is not None:
        inst.trigger_chance_pct = trigger_chance_pct
    if invincible_duration_sec is not None:
        inst.invincible_duration_sec = invincible_duration_sec
