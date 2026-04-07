"""
뿔딸기 변신가면 (Horn Strawberry Mask) - 전설 아이템 효과 모듈

머리 부위 전설 아이템.
커맨드 입력(A→W→D, 1.5초 이내)으로 게이지 소모 후 60초간 뿔딸기로 변신.
변신 중: 패들 30% 크기 증가, 이동속도 8, 공 타격 시 게이지 +30
전용 스킬 3종: 뿔박치기(W), 딸기장판(S홀드), 딸기먹기(Space/클릭)
"""

import math
import random
import pygame

# ── 상수 ──────────────────────────────────────────────────
COMMAND_SEQUENCE = [pygame.K_a, pygame.K_w, pygame.K_d]  # A→W→D
COMMAND_TIMEOUT = 1.5  # 커맨드 입력 허용 시간 (초)
TRANSFORM_GAUGE_COST = 300  # 기본 게이지 소모 (롤옵션으로 변동)
TRANSFORM_DURATION = 60.0  # 기본 변신 지속시간 (초, 롤옵션으로 변동)
TRANSFORM_START_EVENT_DURATION = 3.0  # 변신 시작 이벤트 시간 (초)
TRANSFORM_END_EVENT_DURATION = 2.0  # 변신 해제 이벤트 시간 (초)

# 변신 중 능력치
TRANSFORM_PADDLE_SIZE_BONUS = 0.30  # 패들 크기 30% 증가 (기본)
TRANSFORM_MOVE_SPEED = 8  # 이동속도
TRANSFORM_GAUGE_ON_HIT = 30  # 공 타격 시 게이지 회복

# 스킬: 뿔박치기 (W)
HORN_CHARGE_GAUGE_COST = 300
HORN_CHARGE_COOLDOWN = 20.0  # 초
HORN_CHARGE_PHASES = {
    "CHARGING": 0.43,   # 돌진
    "IMPACT": 0.2,      # 충돌
    "RETURNING": 0.5,   # 복귀
    "STUN": 1.0,        # 경직
}

# 스킬: 딸기장판 (S 홀드)
STRAWBERRY_FIELD_GAUGE_COST = 100  # 홀딩 중 총 소모
STRAWBERRY_FIELD_COOLDOWN = 10.0
STRAWBERRY_FIELD_HOLD_MIN = 1.0  # 최소 홀드 시간 (초)
STRAWBERRY_FIELD_WIDTH = 120
STRAWBERRY_FIELD_HEIGHT = 12

# 스킬: 딸기먹기 (Space/클릭)
STRAWBERRY_EAT_DURATION = 0.8  # 먹는 시간 (초)
STRAWBERRY_EAT_GAUGE_RECOVER = 150
STRAWBERRY_EAT_COOLDOWN = 0.8
STRAWBERRY_STEM_SPEED_MULT = 1.2  # 권총 대비 120% 속도

# ── 색상 팔레트 ──────────────────────────────────────────
STRAWBERRY_RED = (220, 40, 50)
STRAWBERRY_DARK = (180, 20, 30)
STRAWBERRY_LIGHT = (240, 70, 70)
STRAWBERRY_HIGHLIGHT = (255, 120, 120)
GREEN_DARK = (30, 100, 20)
GREEN_MID = (50, 150, 40)
GREEN_BRIGHT = (80, 200, 60)
SEED_COLOR = (240, 220, 100)


class HornStrawberryTransformState:
    """뿔딸기 변신 상태 관리"""

    # 상태 머신
    IDLE = 0               # 미변신
    TRANSFORM_EVENT = 1    # 변신 이벤트 연출 중 (3초)
    TRANSFORMED = 2        # 변신 상태
    DETRANSFORM_EVENT = 3  # 변신 해제 이벤트 연출 중 (2초)

    def __init__(self):
        self.active = False  # 아이템 장착 중
        self.state = self.IDLE
        self.transform_timer = 0.0  # 변신 남은 시간
        self.event_timer = 0.0  # 이벤트 연출 타이머

        # 커맨드 입력 추적
        self.command_buffer = []  # 입력된 키 시퀀스
        self.command_timer = 0.0  # 커맨드 입력 타이머
        self.prev_keys = {}  # 이전 프레임 키 상태

        # 스킬 상태
        self.horn_charge = HornChargeSkill()
        self.strawberry_field = StrawberryFieldSkill()
        self.strawberry_eat = StrawberryEatSkill()

        # 변신 연출 파티클
        self.event_particles = []
        self.flash_alpha = 0

        # 롤옵션 캐시 (장착 시 동기화)
        self._transform_duration = TRANSFORM_DURATION
        self._gauge_cost = TRANSFORM_GAUGE_COST
        self._paddle_size_bonus = TRANSFORM_PADDLE_SIZE_BONUS

    def sync_roll_options(self, legendary_item):
        """전설 아이템 인스턴스에서 롤옵션 값 동기화"""
        if legendary_item:
            self._transform_duration = legendary_item.transform_duration
            self._gauge_cost = legendary_item.gauge_cost
            self._paddle_size_bonus = legendary_item.paddle_size_bonus / 100.0

    def reset(self):
        """게임 종료/메뉴 복귀 시 완전 초기화"""
        self.state = self.IDLE
        self.transform_timer = 0.0
        self.event_timer = 0.0
        self.command_buffer.clear()
        self.command_timer = 0.0
        self.prev_keys.clear()
        self.horn_charge.reset()
        self.strawberry_field.reset()
        self.strawberry_eat.reset()
        self.event_particles.clear()
        self.flash_alpha = 0

    @property
    def is_transformed(self):
        return self.state == self.TRANSFORMED

    @property
    def is_event_playing(self):
        return self.state in (self.TRANSFORM_EVENT, self.DETRANSFORM_EVENT)

    def update_command_input(self, keys, dt):
        """커맨드 입력 감지 (A→W→D)"""
        if self.state != self.IDLE or not self.active:
            return False

        # 커맨드 타이머 업데이트
        if self.command_buffer:
            self.command_timer += dt
            if self.command_timer > COMMAND_TIMEOUT:
                self.command_buffer.clear()
                self.command_timer = 0.0

        # 키 트리거 감지 (눌림 순간만)
        for key in COMMAND_SEQUENCE:
            was_pressed = self.prev_keys.get(key, False)
            is_pressed = keys[key]
            if is_pressed and not was_pressed:
                expected_idx = len(self.command_buffer)
                if expected_idx < len(COMMAND_SEQUENCE) and COMMAND_SEQUENCE[expected_idx] == key:
                    self.command_buffer.append(key)
                    if expected_idx == 0:
                        self.command_timer = 0.0  # 첫 입력 시 타이머 시작
                else:
                    # 잘못된 키 → 리셋
                    self.command_buffer.clear()
                    self.command_timer = 0.0

        # 키 상태 저장
        for key in COMMAND_SEQUENCE:
            self.prev_keys[key] = keys[key]

        # 커맨드 완성 확인
        if len(self.command_buffer) >= len(COMMAND_SEQUENCE):
            self.command_buffer.clear()
            self.command_timer = 0.0
            return True  # 커맨드 완성!

        return False

    def try_transform(self, current_gauge, consume_gauge_fn):
        """변신 시도 (게이지 충분하면 변신 시작)"""
        cost = self._gauge_cost
        if current_gauge >= cost:
            consume_gauge_fn(cost)
            self.state = self.TRANSFORM_EVENT
            self.event_timer = TRANSFORM_START_EVENT_DURATION
            self.flash_alpha = 255
            self._spawn_transform_particles()
            return True
        return False

    def update(self, dt):
        """매 프레임 업데이트"""
        if self.state == self.TRANSFORM_EVENT:
            self.event_timer -= dt
            self.flash_alpha = max(0, int(255 * (self.event_timer / TRANSFORM_START_EVENT_DURATION)))
            self._update_event_particles(dt)
            if self.event_timer <= 0:
                self.state = self.TRANSFORMED
                self.transform_timer = self._transform_duration
                self.horn_charge.reset()
                self.strawberry_field.reset()
                self.strawberry_eat.reset()

        elif self.state == self.TRANSFORMED:
            self.transform_timer -= dt
            # 스킬 쿨타임 업데이트
            self.horn_charge.update_cooldown(dt)
            self.strawberry_field.update_cooldown(dt)
            self.strawberry_eat.update_cooldown(dt)

            if self.transform_timer <= 0:
                self.state = self.DETRANSFORM_EVENT
                self.event_timer = TRANSFORM_END_EVENT_DURATION
                self.flash_alpha = 255
                self._spawn_transform_particles()

        elif self.state == self.DETRANSFORM_EVENT:
            self.event_timer -= dt
            self.flash_alpha = max(0, int(255 * (self.event_timer / TRANSFORM_END_EVENT_DURATION)))
            self._update_event_particles(dt)
            if self.event_timer <= 0:
                self.state = self.IDLE
                self.flash_alpha = 0

        # 이벤트 파티클 업데이트 (항상)
        self._update_event_particles(dt)

    def _spawn_transform_particles(self):
        """변신 이벤트 파티클 생성"""
        self.event_particles.clear()
        for _ in range(40):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            self.event_particles.append({
                "x": 0, "y": 0,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "life": random.uniform(1.0, 2.5),
                "max_life": 2.5,
                "color": random.choice([
                    STRAWBERRY_RED, STRAWBERRY_LIGHT, GREEN_MID,
                    GREEN_BRIGHT, SEED_COLOR, STRAWBERRY_HIGHLIGHT
                ]),
                "size": random.uniform(3, 8),
            })

    def _update_event_particles(self, dt):
        """이벤트 파티클 업데이트"""
        alive = []
        for p in self.event_particles:
            p["life"] -= dt
            p["x"] += p["vx"]
            p["y"] += p["vy"]
            p["vy"] += 0.15  # 중력
            if p["life"] > 0:
                alive.append(p)
        self.event_particles = alive

    def draw_transform_event(self, screen, player_x, player_y):
        """변신/해제 이벤트 연출 그리기"""
        if self.state not in (self.TRANSFORM_EVENT, self.DETRANSFORM_EVENT):
            return

        w, h = screen.get_size()

        # 화면 플래시
        if self.flash_alpha > 0:
            flash_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            if self.state == self.TRANSFORM_EVENT:
                flash_surf.fill((255, 100, 100, min(180, self.flash_alpha)))
            else:
                flash_surf.fill((200, 200, 255, min(150, self.flash_alpha)))
            screen.blit(flash_surf, (0, 0))

        # 이벤트 텍스트
        is_transforming = self.state == self.TRANSFORM_EVENT
        text = "뿔딸기변신!" if is_transforming else "변신해제..."
        progress = 1.0 - (self.event_timer / (TRANSFORM_START_EVENT_DURATION if is_transforming else TRANSFORM_END_EVENT_DURATION))

        # 텍스트 크기 애니메이션
        base_size = 48
        if progress < 0.3:
            text_scale = progress / 0.3
        elif progress > 0.8:
            text_scale = (1.0 - progress) / 0.2
        else:
            text_scale = 1.0
        font_size = max(16, int(base_size * text_scale))

        try:
            font = pygame.font.SysFont("malgungothic", font_size)
            # 텍스트 그림자
            shadow_surf = font.render(text, True, (0, 0, 0))
            shadow_rect = shadow_surf.get_rect(center=(w // 2 + 2, h // 2 - 40 + 2))
            screen.blit(shadow_surf, shadow_rect)
            # 메인 텍스트
            text_color = STRAWBERRY_RED if is_transforming else (150, 150, 200)
            text_surf = font.render(text, True, text_color)
            text_rect = text_surf.get_rect(center=(w // 2, h // 2 - 40))
            screen.blit(text_surf, text_rect)
        except Exception:
            pass

        # 파티클 렌더링
        for p in self.event_particles:
            alpha = max(0, min(255, int(255 * p["life"] / p["max_life"])))
            px = int(player_x + p["x"])
            py = int(player_y + p["y"])
            sz = max(1, int(p["size"] * (p["life"] / p["max_life"])))
            ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
            c = (*p["color"], alpha)
            pygame.draw.circle(ps, c, (sz, sz), sz)
            screen.blit(ps, (px - sz, py - sz))

    def draw_strawberry_paddle(self, screen, x, y, width, height):
        """변신 상태 패들 - 뿔딸기 캐릭터로 그리기"""
        if not self.is_transformed:
            return

        cx = x + width // 2
        cy = y + height // 2

        # ── 딸기 본체 (패들 크기에 맞춤) ──
        body_w = width
        body_h = height + 8
        body_y = y - 4

        # 그림자
        pygame.draw.ellipse(screen, (100, 10, 15, 80),
                           (x + 2, body_y + 3, body_w, body_h))
        # 본체
        pygame.draw.ellipse(screen, STRAWBERRY_RED,
                           (x, body_y, body_w, body_h))
        # 하이라이트
        pygame.draw.ellipse(screen, STRAWBERRY_LIGHT,
                           (x + 4, body_y + 2, body_w - 8, body_h // 2))
        pygame.draw.ellipse(screen, STRAWBERRY_HIGHLIGHT,
                           (x + 8, body_y + 3, body_w - 16, 6))
        # 외곽선
        pygame.draw.ellipse(screen, STRAWBERRY_DARK,
                           (x, body_y, body_w, body_h), 2)

        # ── 딸기 씨앗 ──
        seed_rng = random.Random(77)
        num_seeds = max(4, width // 12)
        for _ in range(num_seeds):
            sx = x + 6 + seed_rng.randint(0, max(1, body_w - 12))
            sy = body_y + 5 + seed_rng.randint(0, max(1, body_h - 10))
            dx = (sx - cx) / (body_w / 2)
            dy = (sy - (cy)) / (body_h / 2)
            if dx * dx + dy * dy < 0.7:
                pygame.draw.ellipse(screen, SEED_COLOR, (sx, sy, 3, 2))

        # ── 뿔 2개 (초록 꼭지) ──
        horn_base_y = body_y - 1
        horn_spacing = width // 4
        for side in [-1, 1]:
            hx = cx + side * horn_spacing
            sway = math.sin(pygame.time.get_ticks() * 0.003 + side) * 2
            pts = [
                (hx - 4, horn_base_y),
                (hx + 4, horn_base_y),
                (hx + sway, horn_base_y - 18),
            ]
            pygame.draw.polygon(screen, GREEN_MID, pts)
            pygame.draw.polygon(screen, GREEN_DARK, pts, 1)
            # 뿔 하이라이트
            pts_hi = [
                (hx - 1, horn_base_y - 1),
                (hx + 2, horn_base_y - 1),
                (hx + sway * 0.5, horn_base_y - 13),
            ]
            pygame.draw.polygon(screen, GREEN_BRIGHT, pts_hi)

        # ── 눈 (작은 검은 원) ──
        eye_y = cy - 1
        for ex_side in [-1, 1]:
            eye_x = cx + ex_side * (width // 5)
            pygame.draw.circle(screen, (20, 5, 5), (int(eye_x), int(eye_y)), 3)
            pygame.draw.circle(screen, (255, 255, 255), (int(eye_x) - 1, int(eye_y) - 1), 1)


class HornChargeSkill:
    """뿔박치기 스킬 (오니마루 뿔박치기 기반 + 딸기잔상 트레일)"""

    PHASE_CHARGING = 0
    PHASE_IMPACT = 1
    PHASE_RETURNING = 2
    PHASE_STUN = 3

    def __init__(self):
        self.active = False
        self.phase = self.PHASE_CHARGING
        self.phase_timer = 0.0
        self.cooldown = 0.0
        self.start_y = 0
        self.target_y = 65  # 보스 패들 하단
        self.current_y_offset = 0
        self.current_x_offset = 0
        self.trail_positions = []  # 딸기 잔상 위치들
        self.knockback_applied = False
        self.impact_particles = []

    def reset(self):
        self.active = False
        self.phase = self.PHASE_CHARGING
        self.phase_timer = 0.0
        self.cooldown = 0.0
        self.current_y_offset = 0
        self.current_x_offset = 0
        self.trail_positions.clear()
        self.knockback_applied = False
        self.impact_particles.clear()

    def can_use(self, current_gauge):
        return not self.active and self.cooldown <= 0 and current_gauge >= HORN_CHARGE_GAUGE_COST

    def activate(self, player_y, consume_gauge_fn):
        if consume_gauge_fn(HORN_CHARGE_GAUGE_COST):
            self.active = True
            self.phase = self.PHASE_CHARGING
            self.phase_timer = HORN_CHARGE_PHASES["CHARGING"]
            self.start_y = player_y
            self.current_y_offset = 0
            self.current_x_offset = 0
            self.trail_positions.clear()
            self.knockback_applied = False
            self.impact_particles.clear()
            return True
        return False

    def update(self, dt, player_x, player_y):
        """스킬 업데이트. 반환: (y_offset, x_offset, apply_knockback, is_stunned)"""
        if not self.active:
            return 0, 0, False, False

        self.phase_timer -= dt
        apply_kb = False
        is_stunned = False

        if self.phase == self.PHASE_CHARGING:
            # 상대방 쪽으로 돌진
            progress = 1.0 - (self.phase_timer / HORN_CHARGE_PHASES["CHARGING"])
            progress = min(1.0, max(0.0, progress))
            # 이징 (ease-in)
            eased = progress * progress
            target_offset = -(player_y - self.target_y)
            self.current_y_offset = target_offset * eased
            # 딸기 잔상 추가
            if len(self.trail_positions) < 20:
                self.trail_positions.append({
                    "x": player_x, "y": player_y + self.current_y_offset,
                    "alpha": 200, "size": 1.0
                })
            if self.phase_timer <= 0:
                self.phase = self.PHASE_IMPACT
                self.phase_timer = HORN_CHARGE_PHASES["IMPACT"]

        elif self.phase == self.PHASE_IMPACT:
            if not self.knockback_applied:
                apply_kb = True
                self.knockback_applied = True
                # 충돌 파티클 생성
                for _ in range(15):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(2, 6)
                    self.impact_particles.append({
                        "x": 0, "y": 0,
                        "vx": math.cos(angle) * speed,
                        "vy": math.sin(angle) * speed,
                        "life": random.uniform(0.3, 0.8),
                        "color": random.choice([STRAWBERRY_RED, GREEN_MID, SEED_COLOR]),
                        "size": random.uniform(2, 5),
                    })
            if self.phase_timer <= 0:
                self.phase = self.PHASE_RETURNING
                self.phase_timer = HORN_CHARGE_PHASES["RETURNING"]

        elif self.phase == self.PHASE_RETURNING:
            progress = 1.0 - (self.phase_timer / HORN_CHARGE_PHASES["RETURNING"])
            progress = min(1.0, max(0.0, progress))
            eased = 1.0 - (1.0 - progress) * (1.0 - progress)  # ease-out
            target_offset = -(player_y - self.target_y)
            self.current_y_offset = target_offset * (1.0 - eased)
            if self.phase_timer <= 0:
                self.phase = self.PHASE_STUN
                self.phase_timer = HORN_CHARGE_PHASES["STUN"]
                self.current_y_offset = 0

        elif self.phase == self.PHASE_STUN:
            is_stunned = True
            self.current_y_offset = 0
            if self.phase_timer <= 0:
                self.active = False
                self.cooldown = HORN_CHARGE_COOLDOWN
                self.current_y_offset = 0

        # 잔상 페이드아웃
        for trail in self.trail_positions:
            trail["alpha"] = max(0, trail["alpha"] - 8)
            trail["size"] *= 0.97

        # 충돌 파티클 업데이트
        alive = []
        for p in self.impact_particles:
            p["life"] -= dt
            p["x"] += p["vx"]
            p["y"] += p["vy"]
            if p["life"] > 0:
                alive.append(p)
        self.impact_particles = alive

        return self.current_y_offset, self.current_x_offset, apply_kb, is_stunned

    def update_cooldown(self, dt):
        if self.cooldown > 0:
            self.cooldown -= dt

    def draw_trail(self, screen, player_x, player_y):
        """딸기 잔상 트레일 그리기"""
        for trail in self.trail_positions:
            if trail["alpha"] <= 5:
                continue
            sz = max(4, int(20 * trail["size"]))
            s = pygame.Surface((sz, sz), pygame.SRCALPHA)
            alpha = min(255, trail["alpha"])
            pygame.draw.ellipse(s, (*STRAWBERRY_RED, alpha), (0, 0, sz, sz))
            # 작은 뿔
            horn_h = max(2, sz // 4)
            pygame.draw.polygon(s, (*GREEN_MID, alpha),
                              [(sz // 3, 0), (sz // 3 + 2, 0), (sz // 3 + 1, -horn_h)])
            pygame.draw.polygon(s, (*GREEN_MID, alpha),
                              [(sz * 2 // 3, 0), (sz * 2 // 3 + 2, 0), (sz * 2 // 3 + 1, -horn_h)])
            screen.blit(s, (int(trail["x"]) - sz // 2, int(trail["y"]) - sz // 2))

        # 충돌 파티클
        for p in self.impact_particles:
            alpha = max(0, min(255, int(255 * p["life"] / 0.8)))
            px = int(player_x + p["x"])
            py = int(player_y + self.current_y_offset + p["y"])
            sz = max(1, int(p["size"]))
            ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*p["color"], alpha), (sz, sz), sz)
            screen.blit(ps, (px - sz, py - sz))


class StrawberryFieldSkill:
    """딸기장판 스킬 (네크로 뼈장막 기반, 딸기 비주얼)"""

    def __init__(self):
        self.holding = False
        self.hold_timer = 0.0
        self.cooldown = 0.0
        self.gauge_consumed = 0
        self.barriers = []  # 활성 장판 리스트

    def reset(self):
        self.holding = False
        self.hold_timer = 0.0
        self.cooldown = 0.0
        self.gauge_consumed = 0
        self.barriers.clear()

    def can_use(self):
        return not self.holding and self.cooldown <= 0

    def start_hold(self):
        if self.can_use():
            self.holding = True
            self.hold_timer = 0.0
            self.gauge_consumed = 0
            return True
        return False

    def update_hold(self, dt, current_gauge, consume_gauge_fn, player_x, player_y):
        """홀딩 업데이트. 반환: True면 장판 설치 완료"""
        if not self.holding:
            return False

        self.hold_timer += dt
        # 프레임당 게이지 소모 (총 100을 1초에 걸쳐)
        gauge_per_sec = STRAWBERRY_FIELD_GAUGE_COST / STRAWBERRY_FIELD_HOLD_MIN
        consume_amount = gauge_per_sec * dt
        if current_gauge >= consume_amount and self.gauge_consumed < STRAWBERRY_FIELD_GAUGE_COST:
            consume_gauge_fn(consume_amount)
            self.gauge_consumed += consume_amount
        else:
            # 게이지 부족 → 홀드 종료
            self.holding = False
            self.hold_timer = 0.0
            return False

        # 1초 이상 홀드 시 장판 설치
        if self.hold_timer >= STRAWBERRY_FIELD_HOLD_MIN:
            self.holding = False
            self.cooldown = STRAWBERRY_FIELD_COOLDOWN
            # 장판 생성 (플레이어 앞에)
            barrier_x = player_x - STRAWBERRY_FIELD_WIDTH // 2
            barrier_y = player_y - 40  # 패들 앞쪽
            # 기존 장판과 간격 체크
            min_spacing = 110
            for b in self.barriers:
                if abs(b["y"] - barrier_y) < min_spacing and b["alive"]:
                    barrier_y = b["y"] - min_spacing
            self.barriers.append({
                "x": barrier_x, "y": barrier_y,
                "w": STRAWBERRY_FIELD_WIDTH, "h": STRAWBERRY_FIELD_HEIGHT,
                "alive": True, "build_timer": 0.0, "built": False,
                "hp": 1,  # 공 1회 반사 후 파괴
                "death_timer": 0.0, "dying": False,
                "seeds": self._generate_seeds(STRAWBERRY_FIELD_WIDTH, STRAWBERRY_FIELD_HEIGHT),
            })
            return True
        return False

    def release_hold(self):
        """홀드 해제 (S키 뗌 - 1초 미만이면 취소)"""
        if self.holding and self.hold_timer < STRAWBERRY_FIELD_HOLD_MIN:
            self.holding = False
            self.hold_timer = 0.0

    @staticmethod
    def _generate_seeds(w, h):
        """장판 위 씨앗 위치 생성"""
        seeds = []
        rng = random.Random(42)
        for _ in range(w // 8):
            seeds.append((rng.randint(4, w - 4), rng.randint(2, h - 2)))
        return seeds

    def update_cooldown(self, dt):
        if self.cooldown > 0:
            self.cooldown -= dt
        # 장판 업데이트
        alive = []
        for b in self.barriers:
            if b["dying"]:
                b["death_timer"] += dt
                if b["death_timer"] > 0.6:
                    continue  # 파괴 완료
            elif not b["built"]:
                b["build_timer"] += dt
                if b["build_timer"] >= 0.5:
                    b["built"] = True
            alive.append(b)
        self.barriers = alive

    def check_ball_collision(self, ball_rect):
        """공과 장판 충돌 체크. 반환: True면 공 반사 필요"""
        for b in self.barriers:
            if not b["alive"] or not b["built"] or b["dying"]:
                continue
            barrier_rect = pygame.Rect(b["x"], b["y"], b["w"], b["h"])
            if barrier_rect.colliderect(ball_rect):
                b["hp"] -= 1
                if b["hp"] <= 0:
                    b["alive"] = False
                    b["dying"] = True
                    b["death_timer"] = 0.0
                return True
        return False

    def draw_barriers(self, screen):
        """딸기장판 그리기"""
        for b in self.barriers:
            if b["dying"]:
                # 파괴 애니메이션 (딸기 파편 흩어짐)
                progress = b["death_timer"] / 0.6
                alpha = max(0, int(255 * (1.0 - progress)))
                for sx, sy in b["seeds"]:
                    scatter_x = sx + (random.random() - 0.5) * 30 * progress
                    scatter_y = sy + progress * 20
                    s = pygame.Surface((4, 3), pygame.SRCALPHA)
                    pygame.draw.ellipse(s, (*SEED_COLOR, alpha), (0, 0, 4, 3))
                    screen.blit(s, (int(b["x"] + scatter_x), int(b["y"] + scatter_y)))
                continue

            if not b["built"]:
                # 건설 중 (반투명)
                progress = b["build_timer"] / 0.5
                alpha = int(180 * progress)
            else:
                alpha = 220

            # 장판 본체 (딸기 젤리 느낌)
            surf = pygame.Surface((b["w"], b["h"]), pygame.SRCALPHA)
            pygame.draw.rect(surf, (*STRAWBERRY_RED, alpha),
                           (0, 0, b["w"], b["h"]), border_radius=4)
            pygame.draw.rect(surf, (*STRAWBERRY_DARK, alpha),
                           (0, 0, b["w"], b["h"]), 1, border_radius=4)
            # 씨앗
            for sx, sy in b["seeds"]:
                pygame.draw.circle(surf, (*SEED_COLOR, alpha), (sx, sy), 2)
            # 빛 반사
            pygame.draw.rect(surf, (*STRAWBERRY_HIGHLIGHT, alpha // 2),
                           (3, 2, b["w"] - 6, 3), border_radius=2)
            screen.blit(surf, (int(b["x"]), int(b["y"])))


class StrawberryEatSkill:
    """딸기먹기 스킬 - 딸기를 먹고 꼭지 투척"""

    def __init__(self):
        self.eating = False
        self.eat_timer = 0.0
        self.cooldown = 0.0
        self.projectiles = []  # 발사된 꼭지 투사체

    def reset(self):
        self.eating = False
        self.eat_timer = 0.0
        self.cooldown = 0.0
        self.projectiles.clear()

    def can_use(self):
        return not self.eating and self.cooldown <= 0

    def activate(self):
        if self.can_use():
            self.eating = True
            self.eat_timer = STRAWBERRY_EAT_DURATION
            return True
        return False

    def update(self, dt, player_x, player_y, recover_gauge_fn, recover_dash_fn):
        """먹기 업데이트. 반환: True면 이동 불가 상태"""
        if self.eating:
            self.eat_timer -= dt
            if self.eat_timer <= 0:
                self.eating = False
                self.cooldown = STRAWBERRY_EAT_COOLDOWN
                # 먹기 완료: 게이지 회복 + 대시 토큰 회복
                recover_gauge_fn(STRAWBERRY_EAT_GAUGE_RECOVER)
                recover_dash_fn(1)
                # 꼭지 투사체 발사
                self._fire_stem(player_x, player_y)
            return True  # 이동 불가

        # 투사체 업데이트
        alive = []
        for p in self.projectiles:
            p["y"] -= p["speed"] * dt * 60  # 프레임 독립
            p["rotation"] += p["rot_speed"] * dt * 60
            p["life"] -= dt
            if p["life"] > 0 and p["y"] > -20:
                alive.append(p)
        self.projectiles = alive

        return False

    def _fire_stem(self, player_x, player_y):
        """딸기 꼭지 투사체 발사"""
        # 코만도 권총 속도의 120%
        base_speed = 7  # 권총 기본 속도
        speed = base_speed * STRAWBERRY_STEM_SPEED_MULT
        self.projectiles.append({
            "x": player_x, "y": player_y - 20,
            "speed": speed,
            "rotation": 0,
            "rot_speed": 5,
            "life": 3.0,
            "damage": 1,
            "stun_duration": 0.3,  # 짧은 스턴
            "knockback": 73,  # 오니마루 뿔박치기와 동일한 넉백
        })

    def update_cooldown(self, dt):
        if self.cooldown > 0:
            self.cooldown -= dt

    def check_boss_collision(self, boss_rect):
        """보스와 꼭지 투사체 충돌 체크. 반환: hit된 투사체 or None"""
        for p in self.projectiles:
            proj_rect = pygame.Rect(int(p["x"]) - 5, int(p["y"]) - 5, 10, 10)
            if proj_rect.colliderect(boss_rect):
                self.projectiles.remove(p)
                return p
        return None

    def draw(self, screen, player_x, player_y):
        """먹기 모션 + 투사체 그리기"""
        # 먹기 모션 (패들 위에 딸기 아이콘 + 먹기 이펙트)
        if self.eating:
            progress = 1.0 - (self.eat_timer / STRAWBERRY_EAT_DURATION)
            # 딸기 아이콘 (줄어듦)
            size = max(4, int(16 * (1.0 - progress)))
            s = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.ellipse(s, STRAWBERRY_RED, (0, 0, size, size))
            screen.blit(s, (int(player_x) - size // 2, int(player_y) - 25 - size // 2))
            # 먹기 파티클 (빨간 입자)
            if progress > 0.3:
                for _ in range(2):
                    px = player_x + random.randint(-10, 10)
                    py = player_y - 20 + random.randint(-5, 5)
                    ps = pygame.Surface((3, 3), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (*STRAWBERRY_LIGHT, 180), (1, 1), 1)
                    screen.blit(ps, (int(px), int(py)))

        # 꼭지 투사체
        for p in self.projectiles:
            self._draw_stem_projectile(screen, p)

    @staticmethod
    def _draw_stem_projectile(screen, proj):
        """딸기 꼭지 투사체 그리기"""
        x, y = int(proj["x"]), int(proj["y"])
        rot = proj["rotation"]
        # 꼭지 본체 (초록 + 갈색 줄기)
        sz = 10
        s = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
        center = sz
        # 잎사귀 (3개)
        for i in range(3):
            angle = rot + i * (math.pi * 2 / 3)
            lx = center + math.cos(angle) * 5
            ly = center + math.sin(angle) * 5
            pts = [
                (center, center),
                (int(lx - 2), int(ly)),
                (int(lx + 2), int(ly)),
            ]
            pygame.draw.polygon(s, GREEN_MID, pts)
        # 중앙 (줄기)
        pygame.draw.circle(s, GREEN_DARK, (center, center), 3)
        pygame.draw.circle(s, (100, 70, 30), (center, center), 2)
        screen.blit(s, (x - sz, y - sz))


# ── 싱글톤 인스턴스 ──────────────────────────────────────
_transform_state = None

def get_transform_state():
    """뿔딸기 변신 상태 싱글톤"""
    global _transform_state
    if _transform_state is None:
        _transform_state = HornStrawberryTransformState()
    return _transform_state

def reset_transform_state():
    """변신 상태 완전 초기화 (게임 종료/메뉴 복귀)"""
    global _transform_state
    if _transform_state:
        _transform_state.reset()
