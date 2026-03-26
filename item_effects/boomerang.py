"""
부메랑 (Boomerang) 액티브 아이템 효과
- 플레이어 위치에서 보스 쪽으로 발사 (유도 기능)
- 보스 패들에 명중 시 넉백 + 스턴
- 돌아오면서 필드 아이템을 줍고 아이템 회수
- 돌아오면 부메랑 아이템이 다시 인벤토리에 추가됨
- 공에 닿으면 부메랑 파괴 (파편 이펙트)
- 실제 부메랑처럼 불규칙한 곡선 궤도 + 보스 유도
"""

import os
import pygame
import math
import random

# 상수
BOOMERANG_SPEED = 9.8               # 부메랑 이동 속도
BOOMERANG_RETURN_SPEED = 8.4        # 돌아오는 속도
BOOMERANG_STUN_FRAMES = 36          # 보스 스턴 시간 (0.6초)
BOOMERANG_KNOCKBACK_POWER = 14      # 넉백 세기
BOOMERANG_KNOCKBACK_TIMER = 15      # 넉백 지속 프레임
BOOMERANG_ITEM_PICKUP_RADIUS = 55   # 아이템 줍기 반경
BOOMERANG_SIZE = 31                 # 부메랑 크기
BOOMERANG_ROTATION_SPEED = 18       # 회전 속도 (도/프레임)
BOOMERANG_MAX_TRAVEL_Y = 25         # 최대 도달 Y (보스 근처)
BOOMERANG_CURVE_AMPLITUDE = 60      # 좌우 곡선 기본 진폭
BOOMERANG_HOMING_STRENGTH = 0.35    # 보스 유도 강도 (0=없음, 1=완전 추적)



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
                 player_x=380, player_y=710, speed_multiplier=1.0):
        """부메랑 발사

        Args:
            speed_multiplier: 코만도암 등 외부 속도 배율 (기본 1.0)
        """
        self.active = True
        self.width = width
        self.height = height
        self.player_x = player_x
        self.player_y = player_y

        # 불규칙 궤도 파라미터 랜덤 생성
        curve_dir = random.choice([-1, 1])
        main_amp = BOOMERANG_CURVE_AMPLITUDE * random.uniform(0.7, 1.4)
        wobble_amp = random.uniform(8, 20)
        wobble_freq = random.uniform(2.5, 4.5)
        wind_drift = random.uniform(-25, 25)
        speed_jitter = random.uniform(0.85, 1.15) * speed_multiplier

        boomerang = {
            "x": float(player_x),
            "y": float(player_y - 20),
            "vx": 0.0,                # 실제 X속도 (유도용)
            "phase": "outgoing",
            "angle": 0.0,
            "travel_t": 0.0,
            "start_x": float(player_x),
            "start_y": float(player_y - 20),
            "curve_dir": curve_dir,
            "main_amp": main_amp,
            "wobble_amp": wobble_amp,
            "wobble_freq": wobble_freq,
            "wind_drift": wind_drift,
            "speed_jitter": speed_jitter,
            "speed_multiplier": speed_multiplier,  # 코만도암 속도 배율
            "hit_boss": False,
            "picked_items": [],
            # 귀환 시 불규칙 궤도용
            "return_wobble_phase": random.uniform(0, math.pi * 2),
            "return_wobble_amp": random.uniform(15, 35),
            "return_wobble_freq": random.uniform(0.08, 0.15),
            # 유도 관련
            "homing_offset_x": 0.0,   # 유도로 누적된 X 오프셋
        }
        self.boomerangs.append(boomerang)

        if self.debug:
            print(f"[BOOMERANG] 발사! x={player_x}, y={player_y}")

    def deactivate(self):
        """부메랑 비활성화"""
        self.boomerangs.clear()
        self.particles.clear()
        self.active = False

        if self.debug:
            print("[BOOMERANG] 비활성화")

    def update(self, boss_rect=None, ball_rect=None, player_rect=None, item_list=None):
        """매 프레임 업데이트"""
        if not self.active:
            # 비활성이어도 잔여 파티클 업데이트 (파괴 이펙트)
            if self.particles:
                for p in self.particles[:]:
                    p["x"] += p.get("vx", 0)
                    p["y"] += p.get("vy", 0)
                    if abs(p.get("vx", 0)) > 0.1 or abs(p.get("vy", 0)) > 0.1:
                        p["vy"] = p.get("vy", 0) + 0.15
                        p["vx"] = p.get("vx", 0) * 0.98
                    p["alpha"] -= 5
                    if p["alpha"] <= 0:
                        self.particles.remove(p)
            return []

        if player_rect is not None:
            self.player_x = player_rect.centerx
            self.player_y = player_rect.centery

        events = []
        to_remove = []

        for i, boom in enumerate(self.boomerangs):
            boom["angle"] += BOOMERANG_ROTATION_SPEED

            if boom["phase"] == "outgoing":
                effective_speed = BOOMERANG_SPEED * boom["speed_jitter"]
                dt = effective_speed / (self.player_y - BOOMERANG_MAX_TRAVEL_Y)
                boom["travel_t"] += dt
                boom["travel_t"] = min(boom["travel_t"], 1.0)

                t = boom["travel_t"]
                target_y = BOOMERANG_MAX_TRAVEL_Y
                # 속도 배율 (유도/궤도 보상용) - 빠를수록 값이 큼
                speed_ratio = boom["speed_multiplier"]

                # Y 이동 (위로)
                boom["y"] = boom["start_y"] + (target_y - boom["start_y"]) * t

                # X 불규칙 궤도: 주 곡선 + 2차 진동 + 바람 드리프트
                main_curve = math.sin(t * math.pi * 1.2) * boom["main_amp"] * boom["curve_dir"]
                wobble = math.sin(t * math.pi * boom["wobble_freq"]) * boom["wobble_amp"]
                drift = boom["wind_drift"] * t
                noise = random.uniform(-1.5, 1.5)

                base_x = boom["start_x"] + main_curve + wobble + drift + noise

                # === 보스 유도 (homing) ===
                # 속도가 빨라지면 프레임당 t 증가량(dt)이 커져 유도 누적 기회가 줄어듬
                # → dt에 비례하여 유도 보간량을 스케일링하여 총 유도량을 일정하게 유지
                if boss_rect is not None:
                    boss_cx = boss_rect.centerx
                    dx_to_boss = boss_cx - base_x
                    homing_factor = max(0, (t - 0.2)) * BOOMERANG_HOMING_STRENGTH
                    # 기준 dt (speed_multiplier=1.0일 때)
                    base_dt = BOOMERANG_SPEED / (self.player_y - BOOMERANG_MAX_TRAVEL_Y)
                    # dt가 클수록(빠를수록) 보간량도 비례 증가 → 총 유도량 동일
                    homing_lerp = 0.08 * (dt / base_dt) if base_dt > 0 else 0.08
                    boom["homing_offset_x"] += dx_to_boss * homing_factor * homing_lerp
                    max_homing = self.width * 0.4
                    boom["homing_offset_x"] = max(-max_homing, min(max_homing, boom["homing_offset_x"]))

                boom["x"] = base_x + boom["homing_offset_x"]

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
                            print(f"[BOOMERANG] 보스 명중!")

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
                dx = self.player_x - boom["x"]
                dy = self.player_y - boom["y"]
                dist = math.sqrt(dx * dx + dy * dy)
                if dist < 30:
                    # 플레이어에게 도착 → 회수
                    events.append({
                        "type": "returned",
                        "picked_items": boom["picked_items"],
                    })
                    to_remove.append(i)
                    if self.debug:
                        print(f"[BOOMERANG] 회수 완료! 주운 아이템: {len(boom['picked_items'])}개")
                    continue

                if dist > 0:
                    nx = dx / dist
                    ny = dy / dist
                    perp_x = -ny
                    perp_y = nx

                    boom["return_wobble_phase"] += boom["return_wobble_freq"]
                    lateral = math.sin(boom["return_wobble_phase"]) * boom["return_wobble_amp"]
                    lateral *= min(1.0, dist / 200.0)

                    speed_var = BOOMERANG_RETURN_SPEED * boom["speed_multiplier"] * random.uniform(0.9, 1.1)

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
                    "vx": 0, "vy": 0,
                    "alpha": 200,
                    "size": random.randint(2, 5),
                    "color": random.choice([
                        (200, 150, 80),
                        (220, 180, 100),
                        (180, 120, 60),
                        (255, 210, 120),
                    ])
                })

        # 제거 (뒤에서부터)
        for idx in sorted(to_remove, reverse=True):
            if idx < len(self.boomerangs):
                self.boomerangs.pop(idx)

        # 파티클 업데이트 (속도 적용)
        for p in self.particles[:]:
            p["x"] += p.get("vx", 0)
            p["y"] += p.get("vy", 0)
            # 중력 (파편용)
            if abs(p.get("vx", 0)) > 0.1 or abs(p.get("vy", 0)) > 0.1:
                p["vy"] = p.get("vy", 0) + 0.15  # 중력
                p["vx"] = p.get("vx", 0) * 0.98   # 공기저항
            p["alpha"] -= 5
            if p["alpha"] <= 0:
                self.particles.remove(p)

        # 모든 부메랑이 사라지면 비활성화
        if not self.boomerangs:
            self.active = False

        return events

    def _spawn_break_particles(self, x, y):
        """부메랑 파괴 시 나무 파편이 사방으로 튀기는 이펙트"""
        # 큰 나무 파편 (빠르게 튀어나감)
        for _ in range(10):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(3.0, 7.0)
            size = random.randint(4, 8)
            self.particles.append({
                "x": x + random.uniform(-4, 4),
                "y": y + random.uniform(-4, 4),
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - random.uniform(1, 3),  # 위로 약간
                "alpha": 255,
                "size": size,
                "color": random.choice([
                    (180, 120, 60),   # 나무색
                    (160, 100, 40),   # 어두운 나무
                    (140, 85, 35),    # 진한 나무
                    (200, 150, 80),   # 밝은 나무
                ])
            })
        # 작은 먼지/톱밥 (느리게 퍼짐)
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(1.0, 3.5)
            self.particles.append({
                "x": x + random.uniform(-6, 6),
                "y": y + random.uniform(-6, 6),
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "alpha": 200,
                "size": random.randint(2, 4),
                "color": random.choice([
                    (255, 220, 150),  # 톱밥/먼지
                    (240, 200, 120),
                    (220, 180, 100),
                ])
            })
        # 빨간/파란 장식 파편 (팁 조각)
        for col in [(230, 60, 50), (60, 140, 230)]:
            for _ in range(3):
                angle = random.uniform(0, math.pi * 2)
                speed = random.uniform(2.5, 5.5)
                self.particles.append({
                    "x": x + random.uniform(-3, 3),
                    "y": y + random.uniform(-3, 3),
                    "vx": math.cos(angle) * speed,
                    "vy": math.sin(angle) * speed - 1.5,
                    "alpha": 255,
                    "size": random.randint(2, 4),
                    "color": col,
                })
        # 금색 볼트 조각 (중앙부 파편)
        for _ in range(2):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2.0, 4.0)
            self.particles.append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 2,
                "alpha": 255,
                "size": random.randint(3, 5),
                "color": (255, 210, 80),  # 금색
            })

    def draw_effects(self, screen, **kwargs):
        """부메랑 및 이펙트 그리기"""
        if not self.active and not self.particles:
            return

        # 파티클 그리기
        for p in self.particles:
            if p["alpha"] > 0:
                sz = p["size"]
                surf = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                color = (*p["color"], min(255, int(p["alpha"])))
                # 빠르게 움직이는 파편은 길쭉하게
                if abs(p.get("vx", 0)) > 2 or abs(p.get("vy", 0)) > 2:
                    # 이동 방향으로 늘린 타원
                    rect = pygame.Rect(0, 0, sz * 2, sz * 2)
                    pygame.draw.ellipse(surf, color, rect)
                else:
                    pygame.draw.circle(surf, color, (sz, sz), sz)
                screen.blit(surf, (int(p["x"] - sz), int(p["y"] - sz)))

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

        wood_base = (170, 110, 55)
        wood_light = (215, 165, 85)
        wood_dark = (120, 70, 30)
        wood_shadow = (90, 50, 20)
        stripe_red = (230, 60, 50)
        stripe_blue = (60, 140, 230)
        gold = (255, 210, 80)

        a1 = angle_rad - spread_angle / 2
        a2 = angle_rad + spread_angle / 2

        e1x = cx + math.cos(a1) * arm_length
        e1y = cy + math.sin(a1) * arm_length
        e2x = cx + math.cos(a2) * arm_length
        e2y = cy + math.sin(a2) * arm_length

        hw = 4
        tw = 2

        # 팔 1 폴리곤
        p1_x, p1_y = -math.sin(a1) * hw, math.cos(a1) * hw
        t1_x, t1_y = -math.sin(a1) * tw, math.cos(a1) * tw
        arm1_poly = [
            (cx + p1_x, cy + p1_y),
            (e1x + t1_x, e1y + t1_y),
            (e1x - t1_x, e1y - t1_y),
            (cx - p1_x, cy - p1_y),
        ]
        arm1_dark = [
            (cx - p1_x, cy - p1_y), (e1x - t1_x, e1y - t1_y),
            (e1x, e1y), (cx, cy),
        ]
        pygame.draw.polygon(screen, wood_dark, [(int(x), int(y)) for x, y in arm1_dark])
        arm1_light = [
            (cx + p1_x, cy + p1_y), (e1x + t1_x, e1y + t1_y),
            (e1x, e1y), (cx, cy),
        ]
        pygame.draw.polygon(screen, wood_base, [(int(x), int(y)) for x, y in arm1_light])
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
            (cx - p2_x, cy - p2_y), (e2x - t2_x, e2y - t2_y),
            (e2x, e2y), (cx, cy),
        ]
        pygame.draw.polygon(screen, wood_dark, [(int(x), int(y)) for x, y in arm2_dark])
        arm2_light = [
            (cx + p2_x, cy + p2_y), (e2x + t2_x, e2y + t2_y),
            (e2x, e2y), (cx, cy),
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
            pygame.draw.circle(screen, (255, 255, 255), (int(ex) - 1, int(ey) - 1), 1)

        # 중앙 금색 볼트
        pygame.draw.circle(screen, wood_shadow, (cx + 1, cy + 1), 4)
        pygame.draw.circle(screen, wood_dark, (cx, cy), 4)
        pygame.draw.circle(screen, gold, (cx, cy), 3)
        pygame.draw.circle(screen, (255, 235, 150), (cx - 1, cy - 1), 1)

        # 글로우 효과 (귀환 시)
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
                       player_x=380, player_y=710, speed_multiplier=1.0):
    """부메랑 발사"""
    boom = get_boomerang_instance()
    boom.activate(game_state, current_stage, width, height, player_x, player_y,
                  speed_multiplier=speed_multiplier)
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
