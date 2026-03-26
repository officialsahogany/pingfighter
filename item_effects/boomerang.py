"""
부메랑 (Boomerang) 액티브 아이템 효과
- 플레이어 위치에서 보스 쪽으로 발사
- 보스 패들에 명중 시 넉백 + 스턴
- 돌아오면서 필드 아이템을 줍고 아이템 회수
- 공에 닿으면 부메랑 파괴
"""

import os
import pygame
import math
import random

# 상수
BOOMERANG_SPEED = 7.0           # 부메랑 이동 속도
BOOMERANG_RETURN_SPEED = 6.0    # 돌아오는 속도
BOOMERANG_STUN_FRAMES = 90      # 보스 스턴 시간 (1.5초)
BOOMERANG_KNOCKBACK_POWER = 14  # 넉백 세기
BOOMERANG_KNOCKBACK_TIMER = 15  # 넉백 지속 프레임
BOOMERANG_ITEM_PICKUP_RADIUS = 50  # 아이템 줍기 반경
BOOMERANG_SIZE = 24             # 부메랑 크기
BOOMERANG_ROTATION_SPEED = 15   # 회전 속도 (도/프레임)
BOOMERANG_MAX_TRAVEL_Y = 30     # 최대 도달 Y (보스 근처)
BOOMERANG_CURVE_AMPLITUDE = 40  # 좌우 곡선 진폭


class Boomerang:
    def __init__(self):
        self.active = False
        self.boomerangs = []  # 활성 부메랑 리스트
        self.particles = []   # 궤적 파티클
        self.width = 760
        self.height = 750
        self.player_x = 380
        self.player_y = 710
        self.debug = os.environ.get("DEBUG_BOOMERANG", "0") == "1"

    def activate(self, game_state=None, current_stage=None, width=760, height=750,
                 player_x=380, player_y=710):
        """부메랑 발사"""
        self.active = True
        self.width = width
        self.height = height
        self.player_x = player_x
        self.player_y = player_y

        # 부메랑 생성
        boomerang = {
            "x": float(player_x),
            "y": float(player_y - 20),
            "phase": "outgoing",  # outgoing → returning
            "angle": 0.0,         # 회전 각도 (시각용)
            "travel_t": 0.0,      # 이동 진행도 (0~1)
            "start_x": float(player_x),
            "start_y": float(player_y - 20),
            "curve_offset": random.choice([-1, 1]),  # 좌/우 곡선 방향
            "hit_boss": False,     # 보스 명중 여부
            "picked_items": [],    # 주운 아이템 목록
        }
        self.boomerangs.append(boomerang)

        if self.debug:
            print(f"[BOOMERANG] 발사! x={player_x}, y={player_y}")

    def deactivate(self):
        """부메랑 비활성화"""
        self.boomerangs.clear()
        self.particles.clear()
        if not self.boomerangs:
            self.active = False

        if self.debug:
            print("[BOOMERANG] 비활성화")

    def update(self, boss_rect=None, ball_rect=None, player_rect=None, item_list=None):
        """매 프레임 업데이트

        Args:
            boss_rect: 보스 패들 Rect
            ball_rect: 공 Rect
            player_rect: 플레이어 패들 Rect
            item_list: 필드 아이템 리스트

        Returns:
            list: 이벤트 리스트 (boss_hit, item_pickup, destroyed, returned)
        """
        if not self.active:
            return []

        # 플레이어 위치 업데이트
        if player_rect is not None:
            self.player_x = player_rect.centerx
            self.player_y = player_rect.centery

        events = []
        to_remove = []

        for i, boom in enumerate(self.boomerangs):
            boom["angle"] += BOOMERANG_ROTATION_SPEED

            if boom["phase"] == "outgoing":
                # 위로 올라감 (보스 방향)
                boom["travel_t"] += BOOMERANG_SPEED / (self.player_y - BOOMERANG_MAX_TRAVEL_Y)
                boom["travel_t"] = min(boom["travel_t"], 1.0)

                # 곡선 궤적 (사인파)
                t = boom["travel_t"]
                target_y = BOOMERANG_MAX_TRAVEL_Y
                boom["y"] = boom["start_y"] + (target_y - boom["start_y"]) * t
                curve = math.sin(t * math.pi) * BOOMERANG_CURVE_AMPLITUDE * boom["curve_offset"]
                boom["x"] = boom["start_x"] + curve

                # 보스 충돌 체크
                if boss_rect and not boom["hit_boss"]:
                    boom_rect = pygame.Rect(
                        int(boom["x"]) - BOOMERANG_SIZE // 2,
                        int(boom["y"]) - BOOMERANG_SIZE // 2,
                        BOOMERANG_SIZE, BOOMERANG_SIZE
                    )
                    if boom_rect.colliderect(boss_rect):
                        boom["hit_boss"] = True
                        # 넉백 방향: 보스 중앙 기준
                        direction = 1 if boom["x"] >= boss_rect.centerx else -1
                        events.append({
                            "type": "boss_hit",
                            "stun_frames": BOOMERANG_STUN_FRAMES,
                            "knockback_power": BOOMERANG_KNOCKBACK_POWER,
                            "knockback_timer": BOOMERANG_KNOCKBACK_TIMER,
                            "knockback_direction": direction,
                            "x": boom["x"],
                            "y": boom["y"],
                        })
                        if self.debug:
                            print(f"[BOOMERANG] 보스 명중! 스턴={BOOMERANG_STUN_FRAMES}f")

                # 공 충돌 체크 (부메랑 파괴)
                if ball_rect:
                    boom_rect = pygame.Rect(
                        int(boom["x"]) - BOOMERANG_SIZE // 2,
                        int(boom["y"]) - BOOMERANG_SIZE // 2,
                        BOOMERANG_SIZE, BOOMERANG_SIZE
                    )
                    if boom_rect.colliderect(ball_rect):
                        events.append({
                            "type": "destroyed",
                            "x": boom["x"],
                            "y": boom["y"],
                        })
                        to_remove.append(i)
                        # 파괴 파티클
                        self._spawn_break_particles(boom["x"], boom["y"])
                        if self.debug:
                            print("[BOOMERANG] 공에 맞아 파괴!")
                        continue

                # 최대 도달 지점 도달 → 귀환
                if boom["travel_t"] >= 1.0:
                    boom["phase"] = "returning"
                    boom["travel_t"] = 0.0
                    boom["start_x"] = boom["x"]
                    boom["start_y"] = boom["y"]

            elif boom["phase"] == "returning":
                # 플레이어에게 돌아옴
                dx = self.player_x - boom["x"]
                dy = self.player_y - boom["y"]
                dist = math.sqrt(dx * dx + dy * dy)

                if dist < 25:
                    # 플레이어에게 도착 → 회수
                    events.append({
                        "type": "returned",
                        "picked_items": boom["picked_items"],
                    })
                    to_remove.append(i)
                    if self.debug:
                        print(f"[BOOMERANG] 회수 완료! 주운 아이템: {len(boom['picked_items'])}개")
                    continue

                # 플레이어 방향으로 이동
                if dist > 0:
                    nx = dx / dist
                    ny = dy / dist
                    boom["x"] += nx * BOOMERANG_RETURN_SPEED
                    boom["y"] += ny * BOOMERANG_RETURN_SPEED

                # 돌아오면서 필드 아이템 줍기
                if item_list is not None:
                    for item in item_list[:]:
                        item_x = item.get("x", 0)
                        item_y = item.get("y", 0)
                        item_dx = boom["x"] - item_x
                        item_dy = boom["y"] - item_y
                        item_dist = math.sqrt(item_dx * item_dx + item_dy * item_dy)
                        if item_dist < BOOMERANG_ITEM_PICKUP_RADIUS:
                            boom["picked_items"].append(item.copy())
                            item_list.remove(item)
                            events.append({
                                "type": "item_pickup",
                                "item": item,
                                "x": item_x,
                                "y": item_y,
                            })
                            if self.debug:
                                print(f"[BOOMERANG] 아이템 픽업: {item.get('name', '?')}")

                # 공 충돌 체크 (귀환 중에도)
                if ball_rect:
                    boom_rect = pygame.Rect(
                        int(boom["x"]) - BOOMERANG_SIZE // 2,
                        int(boom["y"]) - BOOMERANG_SIZE // 2,
                        BOOMERANG_SIZE, BOOMERANG_SIZE
                    )
                    if boom_rect.colliderect(ball_rect):
                        events.append({
                            "type": "destroyed",
                            "x": boom["x"],
                            "y": boom["y"],
                        })
                        to_remove.append(i)
                        self._spawn_break_particles(boom["x"], boom["y"])
                        if self.debug:
                            print("[BOOMERANG] 귀환 중 공에 맞아 파괴!")
                        continue

            # 궤적 파티클 생성 (2프레임마다)
            if random.random() < 0.5:
                self.particles.append({
                    "x": boom["x"] + random.uniform(-5, 5),
                    "y": boom["y"] + random.uniform(-5, 5),
                    "alpha": 180,
                    "size": random.randint(2, 4),
                    "color": random.choice([
                        (200, 150, 80),   # 갈색/나무색
                        (220, 180, 100),  # 밝은 나무색
                        (180, 120, 60),   # 어두운 나무색
                    ])
                })

        # 제거 (뒤에서부터)
        for idx in sorted(to_remove, reverse=True):
            if idx < len(self.boomerangs):
                self.boomerangs.pop(idx)

        # 파티클 업데이트
        for p in self.particles[:]:
            p["alpha"] -= 8
            if p["alpha"] <= 0:
                self.particles.remove(p)

        # 모든 부메랑이 사라지면 비활성화
        if not self.boomerangs:
            self.active = False

        return events

    def _spawn_break_particles(self, x, y):
        """부메랑 파괴 시 파편 파티클"""
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(1, 4)
            self.particles.append({
                "x": x + math.cos(angle) * random.uniform(0, 10),
                "y": y + math.sin(angle) * random.uniform(0, 10),
                "alpha": 255,
                "size": random.randint(3, 6),
                "color": random.choice([
                    (200, 150, 80),
                    (160, 100, 40),
                    (255, 200, 100),
                    (120, 80, 30),
                ])
            })

    def draw_effects(self, screen, **kwargs):
        """부메랑 및 이펙트 그리기"""
        if not self.active and not self.particles:
            return

        # 파티클 그리기
        for p in self.particles:
            if p["alpha"] > 0:
                surf = pygame.Surface((p["size"] * 2, p["size"] * 2), pygame.SRCALPHA)
                color = (*p["color"], min(255, int(p["alpha"])))
                pygame.draw.circle(surf, color, (p["size"], p["size"]), p["size"])
                screen.blit(surf, (int(p["x"] - p["size"]), int(p["y"] - p["size"])))

        # 부메랑 그리기
        for boom in self.boomerangs:
            self._draw_boomerang(screen, boom)

    def _draw_boomerang(self, screen, boom):
        """개별 부메랑 그리기 (회전하는 V자 모양)"""
        cx = int(boom["x"])
        cy = int(boom["y"])
        angle_rad = math.radians(boom["angle"])
        half = BOOMERANG_SIZE // 2

        # 부메랑 모양: 두 개의 팔 (V자 → 부메랑)
        arm_length = half + 2
        arm_width = 5

        # 부메랑의 3개 꼭짓점 (V자 모양)
        # 중심점에서 각도 기준으로 두 팔 생성
        spread_angle = math.radians(70)  # V자 벌어지는 각도

        # 팔 1
        arm1_end_x = cx + math.cos(angle_rad - spread_angle / 2) * arm_length
        arm1_end_y = cy + math.sin(angle_rad - spread_angle / 2) * arm_length

        # 팔 2
        arm2_end_x = cx + math.cos(angle_rad + spread_angle / 2) * arm_length
        arm2_end_y = cy + math.sin(angle_rad + spread_angle / 2) * arm_length

        # 팔 뒤쪽 (두께를 위한 점)
        back_offset = arm_width
        arm1_back_x = cx + math.cos(angle_rad - spread_angle / 2 + 0.3) * (arm_length - back_offset)
        arm1_back_y = cy + math.sin(angle_rad - spread_angle / 2 + 0.3) * (arm_length - back_offset)

        arm2_back_x = cx + math.cos(angle_rad + spread_angle / 2 - 0.3) * (arm_length - back_offset)
        arm2_back_y = cy + math.sin(angle_rad + spread_angle / 2 - 0.3) * (arm_length - back_offset)

        # 나무색 부메랑 본체
        wood_color = (180, 120, 60)
        wood_highlight = (220, 170, 90)
        wood_shadow = (140, 85, 35)

        # 팔 1 그리기
        pygame.draw.line(screen, wood_color,
                         (cx, cy), (int(arm1_end_x), int(arm1_end_y)), 5)
        pygame.draw.line(screen, wood_highlight,
                         (cx, cy), (int(arm1_end_x), int(arm1_end_y)), 3)

        # 팔 2 그리기
        pygame.draw.line(screen, wood_color,
                         (cx, cy), (int(arm2_end_x), int(arm2_end_y)), 5)
        pygame.draw.line(screen, wood_highlight,
                         (cx, cy), (int(arm2_end_x), int(arm2_end_y)), 3)

        # 중심점 강조
        pygame.draw.circle(screen, wood_shadow, (cx, cy), 3)

        # 팔 끝 장식 (줄무늬)
        stripe_color = (255, 80, 80)
        pygame.draw.circle(screen, stripe_color, (int(arm1_end_x), int(arm1_end_y)), 3)
        pygame.draw.circle(screen, stripe_color, (int(arm2_end_x), int(arm2_end_y)), 3)

        # 글로우 효과 (반투명)
        if boom["phase"] == "returning":
            glow_surf = pygame.Surface((BOOMERANG_SIZE * 3, BOOMERANG_SIZE * 3), pygame.SRCALPHA)
            glow_color = (100, 200, 255, 40)
            pygame.draw.circle(glow_surf, glow_color,
                               (BOOMERANG_SIZE * 3 // 2, BOOMERANG_SIZE * 3 // 2),
                               BOOMERANG_SIZE)
            screen.blit(glow_surf, (cx - BOOMERANG_SIZE * 3 // 2, cy - BOOMERANG_SIZE * 3 // 2))


# 싱글톤 인스턴스
boomerang_instance = None


def get_boomerang_instance():
    global boomerang_instance
    if boomerang_instance is None:
        boomerang_instance = Boomerang()
    return boomerang_instance


def activate_boomerang(game_state=None, current_stage=None, width=760, height=750,
                       player_x=380, player_y=710):
    """부메랑 발사"""
    boom = get_boomerang_instance()
    boom.activate(game_state, current_stage, width, height, player_x, player_y)
    return True


def deactivate_boomerang():
    """부메랑 비활성화"""
    boom = get_boomerang_instance()
    boom.deactivate()


def update_boomerang(boss_rect=None, ball_rect=None, player_rect=None, item_list=None):
    """부메랑 업데이트"""
    boom = get_boomerang_instance()
    return boom.update(boss_rect, ball_rect, player_rect, item_list)


def draw_boomerang_effects(screen, **kwargs):
    """부메랑 이펙트 그리기"""
    boom = get_boomerang_instance()
    boom.draw_effects(screen, **kwargs)


def is_boomerang_active():
    """부메랑 활성화 여부"""
    boom = get_boomerang_instance()
    return boom.active
