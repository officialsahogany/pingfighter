# downtown/bodyguard_follower.py
# 광장에서 플레이어를 따라다니는 호위무사 팔로워 시스템
# 실제 영웅 스프라이트(HeroPaddleRenderer)를 사용하여 렌더링

import pygame
from pixel_font_manager import get_pixel_font_path
import pygame.freetype
import math
import random
import os

from localization.manager import get_localization_manager
_loc = get_localization_manager()
def _t(key, fallback=""):
    return _loc.get_text(key, fallback)

from .constants import SCREEN_WIDTH, SCREEN_HEIGHT, resource_path

# ------------------------------------------------------------------
# 영웅 컨셉별 광장 대사 (캐주얼/일상)
# ------------------------------------------------------------------
HERO_IDLE_DIALOGUES = {
    "mugen": [
        "...검은 내 영혼의 연장이다.",
        "이 광장에도 어둠이 숨어있군.",
        "네 뒤는 내가 지킨다.",
        "바람이 차갑군... 전장의 냄새다.",
        "쓸데없는 소리는 하지 마라.",
    ],
    "kraken": [
        "...깊은 바다가 그립군.",
        "이 곳의 공기는 너무 건조해.",
        "촉수가 근질거린다...",
        "먹이 냄새가 나는 건 기분 탓인가.",
        "물이 있는 곳으로 가자.",
    ],
    "chronos": [
        "흐흐... 재미있는 곳이군.",
        "마법의 기운이 느껴져.",
        "주문을 외우고 싶어지는 날씨야.",
        "조심해, 저주는 어디에나 있으니까.",
        "오늘 점괘가 좋지 않아.",
    ],
    "onimaru": [
        "크하하! 싸울 놈은 없나!",
        "뿔이 근질근질하다...",
        "이런 평화로운 곳도 나쁘진 않군.",
        "술 한 잔 하고 싶군.",
        "약한 놈들뿐이야...",
    ],
    "maria": [
        "인형들이 속삭이고 있어...",
        "이 광장, 무대로 딱 좋겠다.",
        "누가 나한테 말 거는 거야...?",
        "후후... 재미있는 사람들이 많네.",
        "인형이 되고 싶지 않으면 조심해.",
    ],
    "ignis": [
        "드래곤의 불꽃이 타오른다!",
        "명예를 위해 검을 들었다.",
        "이 갑옷이 좀 덥긴 하지...",
        "용기란 두려움을 이기는 것이다.",
        "함께 싸울 수 있어 영광이다.",
    ],
    "gear": [
        "이 톱니바퀴 좀 봐! 완벽해!",
        "새로운 발명 아이디어가 떠올랐어!",
        "증기 엔진 점검할 시간이야.",
        "이 광장에 공방을 차리고 싶다...",
        "기계는 배신하지 않아.",
    ],
    "kurokage": [
        "....",
        "그림자 속에 적이 있다.",
        "발소리를 줄여라.",
        "닌자는 말이 필요 없다.",
        "...뒤를 조심해.",
    ],
    "banshee": [
        "저승의 바람이 불어오네...",
        "내 비명을 듣고 싶어...?",
        "유령이 되는 건 나쁘지 않아.",
        "이 세상은 너무 시끄러워.",
        "차가운 곳이 좋아...",
    ],
    "necro": [
        "해골들이 인사하고 싶대.",
        "죽음은 끝이 아니야, 시작이지.",
        "이 광장 밑에 뭔가 묻혀있어.",
        "뼈로 만든 왕좌가 그리워.",
        "후후... 재미있는 영혼이 보여.",
    ],
    "joker": [
        "하하하! 재미있는 곳이군!",
        "서프라이즈~ 기대해도 좋아!",
        "광대는 항상 웃어야 해!",
        "카드 한 장 뽑아볼래?",
        "지루한 건 참을 수 없어!",
    ],
    "mirage": [
        "사막의 신기루를 보여줄까?",
        "모래바람이 불어올 때가 됐어.",
        "환상과 현실의 경계... 모호하지.",
        "이 광장도 신기루일지 몰라.",
        "너는 진짜 네가 맞아...?",
    ],
    "android": [
        "[시스템 정상 가동 중]",
        "[경계 모드 활성화]",
        "[전투 데이터 분석 중...]",
        "[감정 모듈... 에러]",
        "[호위 임무 수행 중]",
    ],
    "ra": [
        "번개의 힘이 차오른다!",
        "매의 눈으로 모든 것을 본다.",
        "태양신의 가호가 함께하길.",
        "하늘을 날고 싶은 날이군.",
        "천둥소리가 그립다...",
    ],
    "monkeyking": [
        "우끼끼! 여기 재밌는 데잖아!",
        "바나나 없어? 배고파!",
        "나무 위가 더 편한데...",
        "누구든 한 판 붙자!",
        "밀림이 그립다... 우끼.",
    ],
}

# 기본 대사 (매핑 안 된 영웅용)
DEFAULT_DIALOGUES = [
    "...",
    "주변을 경계 중이다.",
    "함께라서 든든하군.",
    "언제든 준비되어 있다.",
    "조용한 하루로군.",
]


class BodyguardFollower:
    """투기장 우승 영웅의 인장을 장착하면 광장에서 플레이어 뒤를 따라다니는 호위무사."""

    # 영웅 렌더러 싱글톤 (클래스 레벨 공유)
    _renderer = None
    # 한글 폰트 캐시 (클래스 레벨 공유)
    _speech_font = None

    @classmethod
    def _get_renderer(cls):
        """HeroPaddleRenderer 싱글톤 가져오기."""
        if cls._renderer is None:
            try:
                from .hero_paddles import get_hero_paddle_renderer
                cls._renderer = get_hero_paddle_renderer()
            except Exception as e:
                print(f"[BodyguardFollower] HeroPaddleRenderer 로드 실패: {e}")
        return cls._renderer

    @classmethod
    def _get_speech_font(cls):
        """말풍선용 한글 폰트 (캐시)."""
        if cls._speech_font is None:
            font_size = 21
            # 1차: 픽셀 폰트
            try:
                pixel_font_path = get_pixel_font_path()
                if os.path.exists(pixel_font_path):
                    cls._speech_font = pygame.freetype.Font(pixel_font_path, font_size)
            except Exception:
                pass
            # 2차: NanumSquare
            if cls._speech_font is None:
                try:
                    font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
                    if os.path.exists(font_path):
                        cls._speech_font = pygame.freetype.Font(font_path, font_size)
                except Exception:
                    pass
            # 3차: 시스템 폰트
            if cls._speech_font is None:
                try:
                    if os.path.exists("C:/Windows/Fonts/malgun.ttf"):
                        cls._speech_font = pygame.freetype.Font("C:/Windows/Fonts/malgun.ttf", font_size)
                    elif os.path.exists("/System/Library/Fonts/AppleSDGothicNeo.ttc"):
                        cls._speech_font = pygame.freetype.Font("/System/Library/Fonts/AppleSDGothicNeo.ttc", font_size)
                except Exception:
                    pass
            # 4차: 기본 폰트
            if cls._speech_font is None:
                try:
                    cls._speech_font = pygame.freetype.SysFont("malgungothic", font_size)
                except Exception:
                    cls._speech_font = pygame.freetype.SysFont(None, font_size)
        return cls._speech_font

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

        # 영웅 스프라이트 크기 (광장용 축소 스케일)
        self.render_width = 70   # 렌더링 너비
        self.render_height = 40  # 렌더링 높이

        # 플레이어 위치 히스토리 (딜레이 따라가기용)
        self.position_history = []
        self.history_max_length = 30

        # 시각 효과
        self.effect_timer = 0.0
        self.spawn_alpha = 0
        self.is_spawned = False

        # --- idle 동작 시스템 ---
        self.idle_timer = 0.0           # 정지 경과 시간
        self.idle_action_active = False  # idle 동작 진행 중
        self.idle_action_type = None     # "look_around", "fidget" 등
        self.idle_action_timer = 0.0     # idle 동작 경과
        self.idle_action_duration = 0.0  # idle 동작 지속 시간
        self.idle_look_direction = 0     # 딴청 방향

        # --- 대화 시스템 ---
        self.speech_bubble = None   # 현재 표시 중인 대사
        self.speech_timer = 0.0     # 대사 남은 시간
        self.talk_cooldown = 0.0    # 대화 쿨다운

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

        # 대화 타이머
        if self.speech_bubble:
            self.speech_timer -= dt
            if self.speech_timer <= 0:
                self.speech_bubble = None
        if self.talk_cooldown > 0:
            self.talk_cooldown -= dt

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
            # 이동 시 idle 타이머 리셋
            self.idle_timer = 0.0
            self.idle_action_active = False
        else:
            if not self.idle_action_active:
                self.direction = player_direction
            # idle 타이머 누적
            self.idle_timer += dt

        # --- idle 동작 처리 ---
        self._update_idle(dt)

        # 영웅 렌더러 애니메이션 업데이트
        renderer = self._get_renderer()
        if renderer:
            renderer.update(dt)
            renderer.update_movement(self.hero_id, self.x, dt)

            # idle 동작: 렌더러 상태 직접 오버라이드
            if self.idle_action_active:
                if self.idle_action_type == "look_around":
                    self._apply_idle_look_to_renderer(renderer)
                elif self.idle_action_type == "fidget":
                    self._apply_idle_fidget_to_renderer(renderer)

    # ------------------------------------------------------------------
    # Idle 동작
    # ------------------------------------------------------------------

    def _update_idle(self, dt):
        """5초 이상 정지 시 자체 idle 동작."""
        if self.idle_action_active:
            self.idle_action_timer += dt
            if self.idle_action_timer >= self.idle_action_duration:
                # idle 동작 종료
                self.idle_action_active = False
                self.idle_action_type = None
                self.idle_timer = 0.0  # 리셋하여 다시 5초 후 발동
            return

        # 5초 이상 정지하면 idle 동작 시작
        if self.idle_timer >= 5.0:
            self._start_idle_action()

    def _start_idle_action(self):
        """랜덤 idle 동작 시작."""
        self.idle_action_active = True
        self.idle_action_timer = 0.0

        # 랜덤 동작 선택
        action = random.choice(["look_around", "look_around", "fidget"])
        self.idle_action_type = action

        if action == "look_around":
            # 좌우 두리번거리기
            self.idle_action_duration = random.uniform(2.5, 4.0)
            self.idle_look_direction = random.choice([1, 2])  # 좌 or 우
        elif action == "fidget":
            # 제자리 안절부절
            self.idle_action_duration = random.uniform(1.5, 3.0)

    def _apply_idle_look_to_renderer(self, renderer):
        """idle look_around 중 렌더러의 side_blend/move_dir 직접 설정."""
        if self.hero_id not in renderer.hero_states:
            return
        state = renderer.hero_states[self.hero_id]
        phase = self.idle_action_timer / max(self.idle_action_duration, 0.1)

        # 좌↔우 전환 (부드러운 보간)
        if phase < 0.25:
            # 정면 → 한쪽으로
            blend = min(1.0, phase / 0.25)
            target_dir = -1.0 if self.idle_look_direction == 1 else 1.0
        elif phase < 0.5:
            # 한쪽 유지
            blend = 1.0
            target_dir = -1.0 if self.idle_look_direction == 1 else 1.0
        elif phase < 0.75:
            # 반대쪽으로 전환
            sub = (phase - 0.5) / 0.25
            blend = 1.0
            dir1 = -1.0 if self.idle_look_direction == 1 else 1.0
            dir2 = -dir1
            target_dir = dir1 + (dir2 - dir1) * sub
        else:
            # 반대쪽 → 정면으로 돌아오기
            blend = max(0.0, 1.0 - (phase - 0.75) / 0.25)
            target_dir = 1.0 if self.idle_look_direction == 1 else -1.0

        state["side_blend"] = state["side_blend"] * 0.7 + (0.75 * blend) * 0.3
        state["move_dir"] = state["move_dir"] * 0.7 + target_dir * 0.3
        # 약간의 머리 기울임
        state["head_tilt"] = math.sin(self.idle_action_timer * 2.0) * 0.4 * blend

    def _apply_idle_fidget_to_renderer(self, renderer):
        """idle fidget 중 렌더러의 body_bob/arm_swing 설정."""
        if self.hero_id not in renderer.hero_states:
            return
        state = renderer.hero_states[self.hero_id]
        t = self.idle_action_timer
        # 몸 들썩임 + 팔 미세 흔들림
        state["body_bob"] = math.sin(t * 5) * 0.5
        state["arm_swing"] = math.sin(t * 3.7) * 0.3
        state["head_tilt"] = math.sin(t * 2.5) * 0.35

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
    # 대화 시스템
    # ------------------------------------------------------------------

    def can_talk(self):
        """대화 가능 여부."""
        return self.talk_cooldown <= 0 and self.speech_bubble is None

    def start_dialogue(self):
        """대화 시작 - 영웅 컨셉별 랜덤 대사 반환."""
        if not self.can_talk():
            return None

        dialogues = HERO_IDLE_DIALOGUES.get(self.hero_id, DEFAULT_DIALOGUES)
        idx = random.randint(0, len(dialogues) - 1)
        if self.hero_id in HERO_IDLE_DIALOGUES:
            dialogue = _t(f"idlg.{self.hero_id}.{idx}", dialogues[idx])
        else:
            dialogue = _t(f"idlg.default.{idx}", dialogues[idx])

        self.speech_bubble = dialogue
        self.speech_timer = 4.0
        self.talk_cooldown = 3.0  # 3초 쿨다운

        # 대화 시작 시 idle 중단, 플레이어 쪽 바라봄
        self.idle_action_active = False
        self.idle_timer = 0.0

        return dialogue

    def get_rect(self):
        """클릭 판정용 렉트."""
        w, h = 40, 50
        return pygame.Rect(int(self.x) - w // 2, int(self.y) - h // 2, w, h)

    # ------------------------------------------------------------------
    # 렌더링
    # ------------------------------------------------------------------

    def draw(self, screen, camera_offset=(0, 0)):
        """호위무사 팔로워 그리기 - 실제 영웅 스프라이트 사용."""
        if not self.is_spawned:
            return

        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 화면 밖 컬링
        if draw_x < -100 or draw_x > SCREEN_WIDTH + 100:
            return
        if draw_y < -100 or draw_y > SCREEN_HEIGHT + 100:
            return

        # 그림자
        self._draw_shadow(screen, draw_x, draw_y)

        # 영웅 캐릭터 스프라이트 (HeroPaddleRenderer 사용)
        self._draw_hero_sprite(screen, draw_x, draw_y)

        # 말풍선
        if self.speech_bubble:
            self._draw_speech_bubble(screen, draw_x, draw_y)

    def _draw_shadow(self, screen, x, y):
        """그림자 그리기."""
        shadow_w = 36
        shadow_h = 10
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        shadow_alpha = min(self.spawn_alpha, 50)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, shadow_alpha),
                            (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (int(x) - shadow_w // 2, int(y) + 12))

    def _draw_hero_sprite(self, screen, x, y):
        """HeroPaddleRenderer를 사용하여 실제 영웅 스프라이트 그리기."""
        renderer = self._get_renderer()
        if not renderer:
            self._draw_fallback(screen, x, y)
            return

        # idle 동작 중이면 방향 오버라이드
        idle_dir = self._get_idle_direction()
        d = idle_dir if idle_dir is not None else self.direction

        # 방향 → facing 변환
        if d == 3:  # 위를 바라봄 = 뒷모습
            facing = "up"
        else:  # 아래/좌/우 = 정면 (좌우는 side_blend로 처리)
            facing = "down"

        # idle fidget: 상하 바운스 + 좌우 흔들림
        x_offset = 0
        y_offset = 0
        if self.idle_action_active and self.idle_action_type == "fidget":
            y_offset = math.sin(self.idle_action_timer * 5) * 3
            x_offset = math.sin(self.idle_action_timer * 3.3) * 2

        renderer.draw_hero_paddle(
            screen,
            self.hero_id,
            x + x_offset, y + y_offset,
            self.render_width,
            self.render_height,
            facing=facing,
            color=self.hero_color,
            scale_mode="paddle",
        )

    def _draw_fallback(self, screen, x, y):
        """HeroPaddleRenderer 없을 때 폴백 렌더링."""
        r, g, b = self.hero_color
        pygame.draw.ellipse(screen, self.hero_color,
                            (int(x) - 12, int(y) - 15, 24, 30), border_radius=4)
        pygame.draw.ellipse(screen, (min(255, r + 50), min(255, g + 50), min(255, b + 50)),
                            (int(x) - 12, int(y) - 15, 24, 30), width=2)

    def _draw_speech_bubble(self, screen, x, y):
        """말풍선 그리기."""
        font = self._get_speech_font()
        if not font:
            return

        text_surface, text_rect = font.render(self.speech_bubble, (40, 40, 40))
        text_w = text_rect.width + 24
        text_h = text_rect.height + 15

        bubble_x = x - text_w // 2
        bubble_y = y - 55  # 스프라이트 위

        # 화면 밖 방지
        bubble_x = max(5, min(SCREEN_WIDTH - text_w - 5, bubble_x))

        # 말풍선 배경
        bubble_surf = pygame.Surface((text_w, text_h + 12), pygame.SRCALPHA)
        pygame.draw.rect(bubble_surf, (255, 255, 255, 240),
                         (0, 0, text_w, text_h), border_radius=12)
        pygame.draw.rect(bubble_surf, (80, 80, 80),
                         (0, 0, text_w, text_h), 2, border_radius=12)

        # 꼬리
        pygame.draw.polygon(bubble_surf, (255, 255, 255, 240), [
            (text_w // 2 - 9, text_h),
            (text_w // 2 + 9, text_h),
            (text_w // 2, text_h + 12),
        ])
        pygame.draw.line(bubble_surf, (80, 80, 80),
                         (text_w // 2 - 9, text_h), (text_w // 2, text_h + 12), 2)
        pygame.draw.line(bubble_surf, (80, 80, 80),
                         (text_w // 2 + 9, text_h), (text_w // 2, text_h + 12), 2)

        screen.blit(bubble_surf, (int(bubble_x), int(bubble_y)))
        screen.blit(text_surface, (int(bubble_x) + 12, int(bubble_y) + 7))


class BodyguardFollowerManager:
    """광장에서 최대 2명의 호위무사 팔로워를 관리."""

    def __init__(self):
        self.followers = []
        self._last_seal_ids = []
        self._refresh_cooldown = 0.0  # 주기적 갱신용 타이머

    def refresh_from_equipped_seals(self, player_x=None, player_y=None):
        """장착된 hero_seal 아이템을 읽어 팔로워 생성/갱신.
        인장 해제 시 팔로워가 사라지고, 장착 시에만 존재."""
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
        if new_ids == self._last_seal_ids:
            return False  # 변경 없음

        self._last_seal_ids = new_ids

        # 팔로워 재생성 (인장 없으면 빈 리스트 = 팔로워 없음)
        self.followers.clear()
        for idx, seal in enumerate(seals[:2]):
            follower = BodyguardFollower(seal, follow_index=idx)
            # 위치 정보가 있으면 즉시 스폰
            if player_x is not None and player_y is not None:
                follower.spawn_at(player_x, player_y)
            self.followers.append(follower)

        return True  # 변경됨

    def spawn_all(self, player_x: float, player_y: float):
        """모든 팔로워를 플레이어 근처에 스폰."""
        for follower in self.followers:
            follower.spawn_at(player_x, player_y)

    def update(self, dt: float, player_x: float, player_y: float,
               player_direction: int, player_is_moving: bool):
        """모든 팔로워 업데이트."""
        # 주기적으로 장착 상태 갱신 (2초마다)
        self._refresh_cooldown -= dt
        if self._refresh_cooldown <= 0:
            self._refresh_cooldown = 2.0
            self.refresh_from_equipped_seals(player_x, player_y)

        for follower in self.followers:
            follower.update(dt, player_x, player_y, player_direction, player_is_moving)

    def draw(self, screen, camera_offset=(0, 0)):
        """모든 팔로워 그리기 (Y-sort 없이 단독 사용 시)."""
        for follower in self.followers:
            follower.draw(screen, camera_offset)

    # ------------------------------------------------------------------
    # 대화 상호작용
    # ------------------------------------------------------------------

    def try_talk_to_follower_at(self, world_x, world_y, player_x, player_y, max_dist=100):
        """월드 좌표(클릭 위치)로 팔로워 대화 시도. 성공 시 대사 반환."""
        for follower in self.followers:
            if not follower.is_spawned:
                continue
            rect = follower.get_rect()
            if rect.collidepoint(world_x, world_y):
                # 플레이어와의 거리 체크
                dist = math.sqrt((player_x - follower.x) ** 2 +
                                 (player_y - follower.y) ** 2)
                if dist <= max_dist:
                    return follower.start_dialogue()
        return None

    def try_talk_to_nearest_follower(self, player_x, player_y, radius=70):
        """플레이어 근처 팔로워에게 말 걸기 (SPACE키용). 성공 시 대사 반환."""
        for follower in self.followers:
            if not follower.is_spawned:
                continue
            dist = math.sqrt((player_x - follower.x) ** 2 +
                             (player_y - follower.y) ** 2)
            if dist <= radius and follower.can_talk():
                return follower.start_dialogue()
        return None
