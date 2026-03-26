"""
부메랑 (Boomerang) 액티브 아이템 효과
- 플레이어 위치에서 보스 쪽으로 발사
- 보스 패들에 명중 시 넉백 + 스턴
- 돌아오면서 필드 아이템을 줍고 아이템 회수
- 돌아오면 부메랑 아이템이 다시 인벤토리에 추가됨
- 공에 닿으면 부메랑 파괴
- 실제 부메랑처럼 불규칙한 곡선 궤도
"""

import os
import pygame
import math
import random

# 상수
BOOMERANG_SPEED = 9.8               # 부메랑 이동 속도 (+40%)
BOOMERANG_RETURN_SPEED = 8.4        # 돌아오는 속도 (+40%)
BOOMERANG_STUN_FRAMES = 90          # 보스 스턴 시간 (1.5초)
BOOMERANG_KNOCKBACK_POWER = 14      # 넉백 세기
BOOMERANG_KNOCKBACK_TIMER = 15      # 넉백 지속 프레임
BOOMERANG_ITEM_PICKUP_RADIUS = 55   # 아이템 줍기 반경
BOOMERANG_SIZE = 31                 # 부메랑 크기 (+30%)
BOOMERANG_ROTATION_SPEED = 18       # 회전 속도 (도/프레임) - 빠르게
BOOMERANG_MAX_TRAVEL_Y = 25         # 최대 도달 Y (보스 근처)
BOOMERANG_CURVE_AMPLITUDE = 60      # 좌우 곡선 기본 진폭 (증가)


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

        # 불규칙 궤도 파라미터 랜덤 생성
        curve_dir = random.choice([-1, 1])
        # 메인 곡선 진폭 (랜덤 변동)
        main_amp = BOOMERANG_CURVE_AMPLITUDE * random.uniform(0.7, 1.4)
        # 2차 진동 (작은 흔들림 추가)
        wobble_amp = random.uniform(8, 20)
        wobble_freq = random.uniform(2.5, 4.5)
        # 바람 드리프트 (한쪽으로 살짝 밀림)
        wind_drift = random.uniform(-25, 25)
        # 속도 변동 계수
        speed_jitter = random.uniform(0.85, 1.15)

        boomerang = {
            "x": float(player_x),
            "y": float(player_y - 20),
            "phase": "outgoing",       # outgoing → returning
            "angle": 0.0,              # 회전 각도 (시각용)
            "travel_t": 0.0,           # 이동 진행도 (0~1)
            "start_x": float(player_x),
            "start_y": float(player_y - 20),
            "curve_dir": curve_dir,    # 주 곡선 방향
            "main_amp": main_amp,      # 주 곡선 진폭
            "wobble_amp": wobble_amp,  # 2차 미세 진동 진폭
            "wobble_freq": wobble_freq,  # 2차 진동 주파수
            "wind_drift": wind_drift,  # 바람 드리프트
            "speed_jitter": speed_jitter,  # 속도 변동
            "hit_boss": False,
            "picked_items": [],
            # 귀환 시 불규칙 궤도용
            "return_wobble_phase": random.uniform(0, math.pi * 2),
            "return_wobble_amp": random.uniform(15, 35),
            "return_wobble_freq": random.uniform(0.08, 0.15),
        }
        self.boomerangs.append(boomerang)

        if self.debug:
            print(f"[BOOMERANG] 발사! x={player_x}, y={player_y}, "
                  f"amp={main_amp:.1f}, wobble={wobble_amp:.1f}, "
                  f"drift={wind_drift:.1f}")

    def deactivate(self):
        """부메랑 비활성화"""
        self.boomerangs.clear()
        self.particles.clear()
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
                # 위로 올라감 (보스 방향) - 속도 변동 적용
                effective_speed = BOOMERANG_SPEED * boom["speed_jitter"]
                boom["travel_t"] += effective_speed / (self.player_y - BOOMERANG_MAX_TRAVEL_Y)
                boom["travel_t"] = min(boom["travel_t"], 1.0)

                t = boom["travel_t"]
                target_y = BOOMERANG_MAX_TRAVEL_Y

                # Y 이동 (위로)
                boom["y"] = boom["start_y"] + (target_y - boom["start_y"]) * t

                # X 불규칙 궤도: 주 곡선 + 2차 진동 + 바람 드리프트
                # 주 사인파 곡선 (비대칭 - 실제 부메랑처럼)
                main_curve = math.sin(t * math.pi * 1.2) * boom["main_amp"] * boom["curve_dir"]
                # 2차 미세 진동 (빠르게 흔들림)
                wobble = math.sin(t * math.pi * boom["wobble_freq"]) * boom["wobble_amp"]
                # 바람 드리프트 (직선적으로 밀림)
                drift = boom["wind_drift"] * t
                # 약간의 프레임별 랜덤 노이즈
                noise = random.uniform(-1.5, 1.5)

                boom["x"] = boom["start_x"] + main_curve + wobble + drift + noise

                # 화면 밖으로 나가지 않도록 클램프
                boom["x"] = max(10, min(self.width - 10, boom["x"]))

                # 보스 충돌 체크
                if boss_rect and not boom["hit_boss"]:
                    boom_rect = pygame.Rect(
                        int(boom["x"]) - BOOMERANG_SIZE // 2,
                        int(boom["y"]) - BOOMERANG_SIZE // 2,
                        BOOMERANG_SIZE, BOOMERANG_SIZE
                    )
                    if boom_rect.colliderect(boss_rect):
                        boom["hit_boss"] = True
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
                # 플레이어에게 돌아옴 (불규칙 궤도)
                dx = self.player_x - boom["x"]
                dy = self.player_y - boom["y"]
                dist = math.sqrt(dx * dx + dy * dy)

                if dist < 30:
                    # 플레이어에게 도착 → 회수 + 부메랑 아이템 재추가
                    events.append({
                        "type": "returned",
                        "picked_items": boom["picked_items"],
                    })
                    to_remove.append(i)
                    if self.debug:
                        print(f"[BOOMERANG] 회수 완료! 주운 아이템: {len(boom['picked_items'])}개")
                    continue

                # 플레이어 방향으로 이동 + 사이드 흔들림
                if dist > 0:
                    nx = dx / dist
                    ny = dy / dist

                    # 수직 방향 (횡방향 흔들림용)
                    perp_x = -ny
                    perp_y = nx

                    # 귀환 궤도 흔들림
                    boom["return_wobble_phase"] += boom["return_wobble_freq"]
                    lateral = math.sin(boom["return_wobble_phase"]) * boom["return_wobble_amp"]
                    # 가까울수록 흔들림 감소 (안정적으로 착지)
                    lateral *= min(1.0, dist / 200.0)

                    # 약간의 속도 변동
                    speed_var = BOOMERANG_RETURN_SPEED * random.uniform(0.9, 1.1)

                    boom["x"] += nx * speed_var + perp_x * lateral * 0.15
                    boom["y"] += ny * speed_var + perp_y * lateral * 0.15

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

            # 궤적 파티클 생성
            if random.random() < 0.6:
                self.particles.append({
                    "x": boom["x"] + random.uniform(-6, 6),
                    "y": boom["y"] + random.uniform(-6, 6),
                    "alpha": 200,
                    "size": random.randint(2, 5),
                    "color": random.choice([
                        (200, 150, 80),
                        (220, 180, 100),
                        (180, 120, 60),
                        (255, 210, 120),  # 밝은 잔상
                    ])
                })

        # 제거 (뒤에서부터)
        for idx in sorted(to_remove, reverse=True):
            if idx < len(self.boomerangs):
                self.boomerangs.pop(idx)

        # 파티클 업데이트
        for p in self.particles[:]:
            p["alpha"] -= 7
            if p["alpha"] <= 0:
                self.particles.remove(p)

        # 모든 부메랑이 사라지면 비활성화
        if not self.boomerangs:
            self.active = False

        return events

    def _spawn_break_particles(self, x, y):
        """부메랑 파괴 시 파편 파티클"""
        for _ in range(16):
            angle = random.uniform(0, math.pi * 2)
            self.particles.append({
                "x": x + math.cos(angle) * random.uniform(0, 12),
                "y": y + math.sin(angle) * random.uniform(0, 12),
                "alpha": 255,
                "size": random.randint(3, 7),
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
        """개별 부메랑 그리기 (회전하는 V자 - 3D 입체 폴리곤)"""
        cx = int(boom["x"])
        cy = int(boom["y"])
        angle_rad = math.radians(boom["angle"])
        half = BOOMERANG_SIZE // 2

        arm_length = half + 4
        spread_angle = math.radians(75)

        # 색상
        wood_base = (170, 110, 55)
        wood_light = (215, 165, 85)
        wood_dark = (120, 70, 30)
        wood_shadow = (90, 50, 20)
        stripe_red = (230, 60, 50)
        stripe_blue = (60, 140, 230)
        gold = (255, 210, 80)

        a1 = angle_rad - spread_angle / 2
        a2 = angle_rad + spread_angle / 2

        # 팔 끝점
        e1x = cx + math.cos(a1) * arm_length
        e1y = cy + math.sin(a1) * arm_length
        e2x = cx + math.cos(a2) * arm_length
        e2y = cy + math.sin(a2) * arm_length

        # 팔 두께 (폴리곤용)
        hw = 4  # 팔 반폭
        tw = 2  # 팔 끝 반폭

        # 팔 1 폴리곤 (4점)
        p1_x, p1_y = -math.sin(a1) * hw, math.cos(a1) * hw
        t1_x, t1_y = -math.sin(a1) * tw, math.cos(a1) * tw
        arm1_poly = [
            (cx + p1_x, cy + p1_y),
            (e1x + t1_x, e1y + t1_y),
            (e1x - t1_x, e1y - t1_y),
            (cx - p1_x, cy - p1_y),
        ]
        # 어두운 면
        arm1_dark = [
            (cx - p1_x, cy - p1_y),
            (e1x - t1_x, e1y - t1_y),
            (e1x, e1y),
            (cx, cy),
        ]
        pygame.draw.polygon(screen, wood_dark, [(int(x), int(y)) for x, y in arm1_dark])
        # 밝은 면
        arm1_light = [
            (cx + p1_x, cy + p1_y),
            (e1x + t1_x, e1y + t1_y),
            (e1x, e1y),
            (cx, cy),
        ]
        pygame.draw.polygon(screen, wood_base, [(int(x), int(y)) for x, y in arm1_light])
        # 외곽선
        pygame.draw.polygon(screen, wood_shadow, [(int(x), int(y)) for x, y in arm1_poly], 1)

        # 팔 2 폴리곤
        p2_x, p2_y = -math.sin(a2) * hw, math.cos(a2) * hw
        t2_x, t2_y = -math.sin(a2) * tw, math.cos(a2) * tw
        arm2_poly = [
            (cx + p2_x, cy + p2_y),
            (e2x + t2_x, e2y + t2_y),
            (e2x - t2_x, e2y - t2_y),
            (cx - p2_x, cy - p2_y),
        ]
        arm2_dark = [
            (cx - p2_x, cy - p2_y),
            (e2x - t2_x, e2y - t2_y),
            (e2x, e2y),
            (cx, cy),
        ]
        pygame.draw.polygon(screen, wood_dark, [(int(x), int(y)) for x, y in arm2_dark])
        arm2_light = [
            (cx + p2_x, cy + p2_y),
            (e2x + t2_x, e2y + t2_y),
            (e2x, e2y),
            (cx, cy),
        ]
        pygame.draw.polygon(screen, wood_base, [(int(x), int(y)) for x, y in arm2_light])
        pygame.draw.polygon(screen, wood_shadow, [(int(x), int(y)) for x, y in arm2_poly], 1)

        # 나뭇결 하이라이트
        for arm_a, ex, ey in [(a1, e1x, e1y), (a2, e2x, e2y)]:
            for gi in range(2):
                t = 0.35 + gi * 0.25
                gx = cx + (ex - cx) * t
                gy = cy + (ey - cy) * t
                g_perp_x = -math.sin(arm_a) * 3
                g_perp_y = math.cos(arm_a) * 3
                pygame.draw.line(screen, wood_light,
                                (int(gx + g_perp_x * 0.6), int(gy + g_perp_y * 0.6)),
                                (int(gx - g_perp_x * 0.3), int(gy - g_perp_y * 0.3)), 1)

        # 팔 끝 장식
        for ex, ey, col in [(e1x, e1y, stripe_red), (e2x, e2y, stripe_blue)]:
            pygame.draw.circle(screen, col, (int(ex), int(ey)), 3)
            # 하이라이트 점
            pygame.draw.circle(screen, (255, 255, 255), (int(ex) - 1, int(ey) - 1), 1)

        # 중앙 금색 볼트
        pygame.draw.circle(screen, wood_shadow, (cx + 1, cy + 1), 4)
        pygame.draw.circle(screen, wood_dark, (cx, cy), 4)
        pygame.draw.circle(screen, gold, (cx, cy), 3)
        pygame.draw.circle(screen, (255, 235, 150), (cx - 1, cy - 1), 1)

        # 글로우 효과 (귀환 시 더 강하게)
        if boom["phase"] == "returning":
            glow_r = BOOMERANG_SIZE + 8
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (100, 200, 255, 35), (glow_r, glow_r), glow_r)
            pygame.draw.circle(glow_surf, (150, 220, 255, 20), (glow_r, glow_r), glow_r - 4)
            screen.blit(glow_surf, (cx - glow_r, cy - glow_r))


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
