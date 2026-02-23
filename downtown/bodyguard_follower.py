# downtown/bodyguard_follower.py
# 광장에서 플레이어를 따라다니는 호위무사 팔로워 시스템

import pygame
import math
import random

from .constants import SCREEN_WIDTH, SCREEN_HEIGHT


class BodyguardFollower:
    """투기장 우승 영웅의 인장을 장착하면 광장에서 플레이어 뒤를 따라다니는 호위무사."""

    def __init__(self, hero_data: dict, follow_index: int = 0):
        """
        Args:
            hero_data: hero_seal 아이템 딕셔너리 (hero_id, hero_name, hero_color, hero_title 포함)
            follow_index: 0=첫 번째 팔로워(가까움), 1=두 번째 팔로워(멀리)
        """
        # 영웅 정보
        self.hero_id = hero_data.get("hero_id", "")
        self.hero_name = hero_data.get("hero_name", "???")
        raw_color = hero_data.get("hero_color", (200, 200, 200))
        self.hero_color = tuple(raw_color) if isinstance(raw_color, (list, tuple)) else (200, 200, 200)
        self.hero_title = hero_data.get("hero_title", "")
        self.follow_index = follow_index

        # 위치 (월드 좌표)
        self.x = 0.0
        self.y = 0.0

        # 따라가기 파라미터
        self.follow_distance = 50 + follow_index * 40  # 1번: 50px, 2번: 90px
        self.follow_speed = 0.08  # 보간 팩터

        # 이동 상태
        self.is_moving = False
        self.direction = 0  # 0=하, 1=좌, 2=우, 3=상
        self.vx = 0.0
        self.vy = 0.0

        # 걷기 애니메이션 (연속 사인 기반, NPC와 동일 패턴)
        self.walk_progress = 0.0   # 0 ~ 2π
        self.walk_speed_variation = random.uniform(0.9, 1.1)
        self.stride_length = random.uniform(0.9, 1.1)

        # 크기
        self.width = 22
        self.height = 38

        # 플레이어 위치 히스토리 (딜레이 따라가기용)
        self.position_history = []
        self.history_max_length = 30

        # 시각 효과
        self.effect_timer = 0.0
        self.spawn_alpha = 0
        self.is_spawned = False

        # NPC ID 시뮬레이션 (외모 특성 결정용)
        self._appearance_seed = hash(self.hero_id) if self.hero_id else random.randint(0, 99999)

        # 이름 태그용 폰트 (나중에 초기화)
        self._name_font = None

    def spawn_at(self, x: float, y: float):
        """광장 진입 시 초기 위치 설정."""
        offset_y = self.follow_distance
        self.x = x
        self.y = y + offset_y
        self.position_history = [(x, y)] * self.history_max_length
        self.spawn_alpha = 0
        self.is_spawned = True

    def update(self, dt: float, player_x: float, player_y: float,
               player_direction: int, player_is_moving: bool):
        """팔로워 위치, 애니메이션 업데이트."""
        if not self.is_spawned:
            return

        self.effect_timer += dt

        # 페이드인
        if self.spawn_alpha < 255:
            self.spawn_alpha = min(255, self.spawn_alpha + int(400 * dt))

        # 플레이어 위치 히스토리 기록
        self.position_history.append((player_x, player_y))
        if len(self.position_history) > self.history_max_length:
            self.position_history.pop(0)

        # 히스토리에서 지연된 위치 가져오기
        delay_frames = 10 + self.follow_index * 8
        history_index = max(0, len(self.position_history) - 1 - delay_frames)
        trail_x, trail_y = self.position_history[history_index]

        # 플레이어 방향 기반 오프셋 (항상 뒤에 위치)
        offset_x, offset_y = self._get_direction_offset(player_direction)
        target_x = trail_x + offset_x
        target_y = trail_y + offset_y

        # 스무스 보간
        old_x, old_y = self.x, self.y
        lerp_factor = min(1.0, self.follow_speed * 60 * dt)

        # 너무 멀면 러버밴딩 (빠르게 추격)
        dist = math.sqrt((target_x - self.x) ** 2 + (target_y - self.y) ** 2)
        if dist > self.follow_distance * 3:
            lerp_factor = min(1.0, lerp_factor * 3)

        self.x += (target_x - self.x) * lerp_factor
        self.y += (target_y - self.y) * lerp_factor

        # 속도 계산 (애니메이션용)
        safe_dt = max(dt, 0.001)
        self.vx = (self.x - old_x) / safe_dt
        self.vy = (self.y - old_y) / safe_dt

        # 이동 상태 및 방향 결정
        speed = math.sqrt(self.vx ** 2 + self.vy ** 2)
        self.is_moving = speed > 5.0

        if self.is_moving:
            if abs(self.vx) > abs(self.vy):
                self.direction = 1 if self.vx < 0 else 2
            else:
                self.direction = 3 if self.vy < 0 else 0
        else:
            self.direction = player_direction

        # 걷기 애니메이션 (NPC 패턴: npc.py 728~748)
        if self.is_moving:
            walk_rate = 6.0 * self.walk_speed_variation * (speed / 200.0 + 0.5)
            self.walk_progress += dt * walk_rate
            if self.walk_progress >= 2 * math.pi:
                self.walk_progress -= 2 * math.pi
        else:
            if self.walk_progress > 0.1:
                self.walk_progress *= 0.85
            else:
                self.walk_progress = 0

    def _get_direction_offset(self, player_direction: int):
        """플레이어 방향 기준 뒤쪽 오프셋 계산."""
        d = self.follow_distance
        offsets = {
            0: (0, -d),    # 플레이어 아래 향함 → 팔로워 위에
            1: (d, 0),     # 플레이어 왼쪽 향함 → 팔로워 오른쪽에
            2: (-d, 0),    # 플레이어 오른쪽 향함 → 팔로워 왼쪽에
            3: (0, d),     # 플레이어 위 향함 → 팔로워 아래에
        }
        return offsets.get(player_direction, (0, -d))

    # ------------------------------------------------------------------
    # 렌더링
    # ------------------------------------------------------------------

    def draw(self, screen, camera_offset=(0, 0)):
        """호위무사 팔로워 그리기."""
        if not self.is_spawned:
            return

        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 화면 밖 컬링
        if draw_x < -80 or draw_x > SCREEN_WIDTH + 80:
            return
        if draw_y < -80 or draw_y > SCREEN_HEIGHT + 80:
            return

        # 그림자
        self._draw_shadow(screen, draw_x, draw_y)

        # 영웅 색상 글로우
        self._draw_hero_glow(screen, draw_x, draw_y)

        # 본체 (프로시저럴 휴머노이드)
        self._draw_humanoid(screen, draw_x, draw_y)

        # 이름 태그
        self._draw_name_tag(screen, draw_x, draw_y)

    def _draw_shadow(self, screen, x, y):
        """그림자 그리기."""
        shadow_w = int(self.width * 0.6)
        shadow_h = int(shadow_w * 0.3)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        shadow_alpha = min(self.spawn_alpha, 40)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, shadow_alpha),
                            (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (int(x) - shadow_w // 2, int(y) + self.height // 3))

    def _draw_hero_glow(self, screen, x, y):
        """영웅 색상 글로우 이펙트."""
        if self.spawn_alpha < 100:
            return
        glow_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
        glow_alpha = int(25 + 12 * math.sin(self.effect_timer * 2))
        r, g, b = self.hero_color
        pygame.draw.circle(glow_surf, (r, g, b, glow_alpha), (15, 15), 15)
        screen.blit(glow_surf, (int(x) - 15, int(y) - 10))

    def _draw_humanoid(self, screen, x, y):
        """프로시저럴 휴머노이드 그리기 - 4방향 자연스러운 렌더링."""
        d = self.direction  # 0=하, 1=좌, 2=우, 3=상
        is_side = d in (1, 2)  # 좌우 = 측면 뷰
        facing_right = (d == 2)
        facing_back = (d == 3)

        body_color = self.hero_color
        skin_color = (255, 220, 180)
        npc_id = self._appearance_seed

        body_dark = tuple(max(0, c - 30) for c in body_color)
        body_light = tuple(min(255, c + 30) for c in body_color)
        skin_dark = tuple(max(0, c - 25) for c in skin_color)
        hair_color = tuple(max(0, c - 60) for c in body_color)
        shoe_color = (40, 30, 25)

        # --- 걷기 애니메이션 ---
        is_walking = self.is_moving
        if is_walking:
            wp = self.walk_progress
            stride = self.stride_length
            leg_swing = math.sin(wp) * 2.5 * stride
            bob_offset = int(abs(math.sin(wp * 2)) * 1.0)
            body_lean = math.sin(wp) * 0.5
        else:
            bob_offset = int(0.5 * math.sin(self.effect_timer * 1.2))
            leg_swing = 0
            body_lean = 0

        center_x = int(x)
        feet_y = int(y + self.height // 3)

        if is_walking:
            left_foot_swing = int(leg_swing)
            right_foot_swing = -int(leg_swing)
            left_lift = int(max(0, leg_swing) * 0.8)
            right_lift = int(max(0, -leg_swing) * 0.8)
        else:
            left_foot_swing = 0
            right_foot_swing = 0
            left_lift = 0
            right_lift = 0

        # ================================================================
        # 측면 뷰 (좌/우)
        # ================================================================
        if is_side:
            flip = -1 if facing_right else 1  # 좌: +x 앞쪽, 우: -x 앞쪽

            # 몸통 기울기 (이동 방향으로 살짝)
            lean_x = int(body_lean * (-flip))
            cx = center_x + lean_x

            # --- 뒤쪽 팔 (몸통 뒤에 먼저 그림) ---
            arm_w, arm_h = 4, 12
            torso_w_side = 10  # 측면 몸통 폭 (좁음)
            torso_h = 16
            torso_y = feet_y - 5 - 14 - torso_h + bob_offset + 2
            arm_y = torso_y + 2

            if is_walking:
                back_arm_swing = int(-leg_swing * 0.6)  # 뒷팔은 다리 반대
            else:
                back_arm_swing = int(1.5 * math.sin(self.effect_timer * 1.0 + 0.8))

            back_arm_x = cx + flip * 1  # 몸 안쪽에 살짝
            pygame.draw.rect(screen, body_dark,
                             (back_arm_x - arm_w // 2, arm_y + back_arm_swing,
                              arm_w, arm_h - 2), border_radius=2)
            pygame.draw.ellipse(screen, skin_color,
                                (back_arm_x - 2, arm_y + arm_h - 4 + back_arm_swing, 4, 4))

            # --- 뒤쪽 다리 + 발 ---
            leg_w_side, leg_h = 5, 14
            shoe_w, shoe_h = 7, 5

            # 뒤쪽 다리: 걸을 때 앞뒤(화면상 X축)로 스윙
            back_foot_x = cx + flip * (-right_foot_swing)  # 이동방향으로 스윙
            back_foot_y = feet_y - shoe_h - right_lift
            back_leg_y = feet_y - shoe_h - leg_h - right_lift

            pygame.draw.rect(screen, tuple(max(0, c - 15) for c in body_dark),
                             (back_foot_x - leg_w_side // 2, back_leg_y,
                              leg_w_side, leg_h), border_radius=2)
            pygame.draw.ellipse(screen, tuple(max(0, c - 10) for c in shoe_color),
                                (back_foot_x - shoe_w // 2, back_foot_y, shoe_w, shoe_h))

            # --- 앞쪽 다리 + 발 ---
            front_foot_x = cx + flip * (-left_foot_swing)
            front_foot_y = feet_y - shoe_h - left_lift
            front_leg_y = feet_y - shoe_h - leg_h - left_lift

            pygame.draw.rect(screen, body_dark,
                             (front_foot_x - leg_w_side // 2, front_leg_y,
                              leg_w_side, leg_h), border_radius=2)
            pygame.draw.ellipse(screen, shoe_color,
                                (front_foot_x - shoe_w // 2, front_foot_y, shoe_w, shoe_h))

            # --- 몸통 (측면 = 좁게) ---
            torso_x = cx - torso_w_side // 2
            pygame.draw.rect(screen, body_color,
                             (torso_x, torso_y, torso_w_side, torso_h), border_radius=3)
            # 하이라이트 (앞쪽 면)
            hl_x = torso_x + (torso_w_side - 3 if facing_right else 0)
            pygame.draw.rect(screen, body_light,
                             (hl_x, torso_y + 2, 3, torso_h - 4), border_radius=1)

            # --- 앞쪽 팔 (몸통 위에) ---
            if is_walking:
                front_arm_swing = int(leg_swing * 0.6)
            else:
                front_arm_swing = int(1.5 * math.sin(self.effect_timer * 1.0))

            front_arm_x = cx + flip * (-1)  # 몸 바깥쪽에
            pygame.draw.rect(screen, body_color,
                             (front_arm_x - arm_w // 2, arm_y + front_arm_swing,
                              arm_w, arm_h - 2), border_radius=2)
            pygame.draw.ellipse(screen, skin_color,
                                (front_arm_x - 2, arm_y + arm_h - 4 + front_arm_swing,
                                 4, 4))

            # --- 목 ---
            neck_w, neck_h = 5, 4
            neck_y = torso_y - neck_h + 2
            pygame.draw.rect(screen, skin_color,
                             (cx - neck_w // 2, neck_y, neck_w, neck_h + 2))

            # --- 머리 (측면: 약간 좁게) ---
            head_w, head_h = 13, 15
            if is_walking:
                head_bob = int(math.sin(self.walk_progress * 2) * 0.6)
            else:
                head_bob = 0
            head_y = neck_y - head_h + 4 + bob_offset
            head_x = cx - head_w // 2 + head_bob * (-flip)

            pygame.draw.ellipse(screen, skin_color, (head_x, head_y, head_w, head_h))

            # 머리카락
            pygame.draw.ellipse(screen, hair_color,
                                (head_x - 1, head_y - 2, head_w + 2, head_h // 2 + 5))
            # 뒷머리 (측면에서 보임)
            back_hair_x = head_x + (head_w - 2 if not facing_right else -3)
            pygame.draw.ellipse(screen, hair_color,
                                (back_hair_x, head_y + 1, 5, head_h - 2))

            # 눈 (하나만, 측면이므로)
            eye_cx = cx + flip * (-3)
            eye_y = head_y + head_h // 2 - 1
            pygame.draw.ellipse(screen, (255, 255, 255),
                                (eye_cx - 2, eye_y - 2, 5, 4))
            pygame.draw.circle(screen, (40, 30, 20),
                               (eye_cx + (flip * (-1)), eye_y), 2)
            pygame.draw.circle(screen, (255, 255, 255),
                               (eye_cx + (flip * (-1)), eye_y - 1), 1)

            # 눈썹
            brow_y = eye_y - 4
            brow_color = tuple(max(0, c - 20) for c in hair_color)
            pygame.draw.line(screen, brow_color,
                             (eye_cx - 3, brow_y), (eye_cx + 2, brow_y - 1), 1)

            # 코 (측면 돌출)
            nose_x = cx + flip * (-head_w // 2 - 1)
            nose_y = eye_y + 3
            pygame.draw.polygon(screen, skin_dark, [
                (nose_x, nose_y - 1), (nose_x + flip * (-2), nose_y + 1),
                (nose_x, nose_y + 2)
            ])

            # 입
            mouth_y = head_y + head_h - 4
            mouth_x = cx + flip * (-2)
            pygame.draw.line(screen, (180, 80, 80),
                             (mouth_x - 2, mouth_y), (mouth_x + 1, mouth_y), 1)

        # ================================================================
        # 정면/후면 뷰 (상/하)
        # ================================================================
        else:
            # 몸통 기울기 (걸음걸이 좌우 흔들림)
            cx = center_x + int(body_lean)

            shoe_w, shoe_h = 8, 5

            # --- 발 (상하 이동 → 좌우로 벌어지는 걸음) ---
            left_foot_x = cx - 3 + left_foot_swing
            left_foot_y = feet_y - shoe_h - left_lift
            pygame.draw.ellipse(screen, shoe_color,
                                (left_foot_x - shoe_w // 2, left_foot_y, shoe_w, shoe_h))

            right_foot_x = cx + 3 + right_foot_swing
            right_foot_y = feet_y - shoe_h - right_lift
            pygame.draw.ellipse(screen, shoe_color,
                                (right_foot_x - shoe_w // 2, right_foot_y, shoe_w, shoe_h))

            # --- 다리 ---
            leg_w, leg_h = 6, 14
            pants_color = body_dark

            left_leg_y = feet_y - shoe_h - leg_h - left_lift
            pygame.draw.rect(screen, pants_color,
                             (left_foot_x - leg_w // 2, left_leg_y, leg_w, leg_h),
                             border_radius=2)

            right_leg_y = feet_y - shoe_h - leg_h - right_lift
            pygame.draw.rect(screen, pants_color,
                             (right_foot_x - leg_w // 2, right_leg_y, leg_w, leg_h),
                             border_radius=2)

            # --- 몸통 ---
            torso_w, torso_h = self.width - 4, 16
            torso_y = feet_y - shoe_h - leg_h - torso_h + bob_offset + 2
            torso_x = cx - torso_w // 2

            pygame.draw.rect(screen, body_color,
                             (torso_x, torso_y, torso_w, torso_h), border_radius=4)
            if not facing_back:
                pygame.draw.rect(screen, body_light,
                                 (torso_x + 1, torso_y + 2, 3, torso_h - 4),
                                 border_radius=1)

            # --- 팔 ---
            arm_w, arm_h = 5, 12
            arm_y = torso_y + 2

            if is_walking:
                left_arm_swing = int(leg_swing * 0.6)
                right_arm_swing = int(-leg_swing * 0.6)
            else:
                left_arm_swing = int(1.5 * math.sin(self.effect_timer * 1.0))
                right_arm_swing = int(1.5 * math.sin(self.effect_timer * 1.0 + 0.8))

            # 왼팔
            pygame.draw.rect(screen, body_dark,
                             (torso_x - arm_w + 1,
                              arm_y + left_arm_swing, arm_w, arm_h - 2),
                             border_radius=2)
            pygame.draw.ellipse(screen, skin_color,
                                (torso_x - arm_w + 2,
                                 arm_y + arm_h - 4 + left_arm_swing, 4, 4))

            # 오른팔
            pygame.draw.rect(screen, body_color if not facing_back else body_dark,
                             (torso_x + torso_w - 2,
                              arm_y + right_arm_swing, arm_w, arm_h - 2),
                             border_radius=2)
            pygame.draw.ellipse(screen, skin_color,
                                (torso_x + torso_w - 1,
                                 arm_y + arm_h - 4 + right_arm_swing, 4, 4))

            # --- 목 ---
            neck_w, neck_h = 6, 4
            neck_y = torso_y - neck_h + 2
            pygame.draw.rect(screen, skin_color,
                             (cx - neck_w // 2, neck_y, neck_w, neck_h + 2))

            # --- 머리 ---
            face_types = ["round", "oval", "square", "long"]
            face_type = face_types[(npc_id // 3) % len(face_types)]

            if face_type == "round":
                head_w, head_h = 15, 15
            elif face_type == "oval":
                head_w, head_h = 13, 17
            elif face_type == "square":
                head_w, head_h = 14, 14
            else:
                head_w, head_h = 12, 18

            if is_walking:
                head_sway = int(math.sin(self.walk_progress * 2) * 0.8)
            else:
                head_sway = 0

            head_y = neck_y - head_h + 4 + bob_offset
            head_x = cx - head_w // 2 + head_sway

            pygame.draw.ellipse(screen, skin_color, (head_x, head_y, head_w, head_h))

            # --- 머리카락 ---
            hair_styles = ["short", "medium", "long", "spiky", "curly"]
            hair_style = hair_styles[npc_id % len(hair_styles)]

            if hair_style == "short":
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 1, head_y - 2, head_w + 2, head_h // 2 + 4))
                pygame.draw.rect(screen, hair_color,
                                 (head_x, head_y, head_w, 6), border_radius=3)
            elif hair_style == "medium":
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 5))
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 3, head_y + 2, 5, 10))
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x + head_w - 2, head_y + 2, 5, 10))
            elif hair_style == "long":
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 5))
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 4, head_y + 2, 6, 16))
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x + head_w - 2, head_y + 2, 6, 16))
            elif hair_style == "spiky":
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 1, head_y - 1, head_w + 2, head_h // 2 + 3))
                for i in range(5):
                    spike_x = head_x + 2 + i * 3
                    pygame.draw.polygon(screen, hair_color, [
                        (spike_x, head_y + 2),
                        (spike_x + 2, head_y - 4 - i % 2 * 2),
                        (spike_x + 4, head_y + 2)
                    ])
            else:  # curly
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 6))
                for i in range(4):
                    curl_x = head_x - 1 + i * 4
                    pygame.draw.circle(screen, hair_color, (curl_x + 2, head_y + 1), 3)

            # --- 후면: 머리카락만, 얼굴 없음 ---
            if facing_back:
                # 뒷머리 추가 커버
                pygame.draw.ellipse(screen, hair_color,
                                    (head_x - 1, head_y + head_h // 3,
                                     head_w + 2, head_h // 2))
                return

            # --- 정면 얼굴 ---
            eye_y_pos = head_y + head_h // 2 - 1
            eye_spacing = 4
            eye_w, eye_h = 5, 4

            # 눈 흰자
            pygame.draw.ellipse(screen, (255, 255, 255),
                                (cx - eye_spacing - eye_w // 2,
                                 eye_y_pos - eye_h // 2, eye_w, eye_h))
            pygame.draw.ellipse(screen, (255, 255, 255),
                                (cx + eye_spacing - eye_w // 2,
                                 eye_y_pos - eye_h // 2, eye_w, eye_h))

            # 눈동자
            pupil_color = (40, 30, 20)
            pygame.draw.circle(screen, pupil_color,
                               (cx - eye_spacing, eye_y_pos), 2)
            pygame.draw.circle(screen, pupil_color,
                               (cx + eye_spacing, eye_y_pos), 2)
            # 하이라이트
            pygame.draw.circle(screen, (255, 255, 255),
                               (cx - eye_spacing, eye_y_pos - 1), 1)
            pygame.draw.circle(screen, (255, 255, 255),
                               (cx + eye_spacing + 1, eye_y_pos - 1), 1)

            # 눈썹
            brow_y = eye_y_pos - 4
            brow_color = tuple(max(0, c - 20) for c in hair_color)
            pygame.draw.line(screen, brow_color,
                             (cx - eye_spacing - 2, brow_y),
                             (cx - eye_spacing + 2, brow_y - 1), 1)
            pygame.draw.line(screen, brow_color,
                             (cx + eye_spacing - 1, brow_y - 1),
                             (cx + eye_spacing + 3, brow_y), 1)

            # 코
            nose_y = eye_y_pos + 3
            pygame.draw.circle(screen, skin_dark, (cx, nose_y + 1), 1)

            # 입 (미소)
            mouth_y = head_y + head_h - 4
            pygame.draw.arc(screen, (180, 80, 80),
                            (cx - 3, mouth_y - 1, 6, 4), 3.14, 0, 1)

    def _draw_name_tag(self, screen, x, y):
        """영웅 이름 태그 (머리 위)."""
        if self.spawn_alpha < 200:
            return

        # 폰트 초기화
        if self._name_font is None:
            try:
                from .constants import resource_path
                import os
                font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
                self._name_font = pygame.font.Font(font_path, 11)
            except Exception:
                self._name_font = pygame.font.Font(None, 12)

        # 이름 렌더링
        name_text = self.hero_name
        text_surf = self._name_font.render(name_text, True, (255, 255, 255))
        text_w = text_surf.get_width()
        text_h = text_surf.get_height()

        # 배경 박스
        tag_x = int(x) - text_w // 2 - 3
        tag_y = int(y) - self.height // 2 - text_h - 8
        bg_surf = pygame.Surface((text_w + 6, text_h + 4), pygame.SRCALPHA)
        r, g, b = self.hero_color
        pygame.draw.rect(bg_surf, (r, g, b, 160), (0, 0, text_w + 6, text_h + 4),
                         border_radius=3)
        pygame.draw.rect(bg_surf, (255, 255, 255, 80), (0, 0, text_w + 6, text_h + 4),
                         width=1, border_radius=3)
        screen.blit(bg_surf, (tag_x, tag_y))
        screen.blit(text_surf, (tag_x + 3, tag_y + 2))


class BodyguardFollowerManager:
    """광장에서 최대 2명의 호위무사 팔로워를 관리."""

    def __init__(self):
        self.followers = []
        self._last_seal_ids = []

    def refresh_from_equipped_seals(self):
        """장착된 hero_seal 아이템을 읽어 팔로워 생성/갱신."""
        seals = []
        try:
            import pingfighter
            equipped = pingfighter.get_equipped_passive_items()
            seals = [item for item in equipped
                     if isinstance(item, dict) and item.get("name") == "hero_seal"]
        except Exception:
            pass

        # 변경 여부 확인
        new_ids = [s.get("hero_id", "") for s in seals]
        if new_ids == self._last_seal_ids and self.followers:
            return

        self._last_seal_ids = new_ids

        # 팔로워 재생성
        self.followers.clear()
        for idx, seal in enumerate(seals[:2]):
            follower = BodyguardFollower(seal, follow_index=idx)
            self.followers.append(follower)

    def spawn_all(self, player_x: float, player_y: float):
        """모든 팔로워를 플레이어 근처에 스폰."""
        for follower in self.followers:
            follower.spawn_at(player_x, player_y)

    def update(self, dt: float, player_x: float, player_y: float,
               player_direction: int, player_is_moving: bool):
        """모든 팔로워 업데이트."""
        for follower in self.followers:
            follower.update(dt, player_x, player_y, player_direction, player_is_moving)

    def draw(self, screen, camera_offset=(0, 0)):
        """모든 팔로워 그리기 (Y-sort 없이 단독 사용 시)."""
        for follower in self.followers:
            follower.draw(screen, camera_offset)
