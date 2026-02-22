"""인게임 호위무사 시스템

투기장에서 우승 후 등용한 영웅이 다음 스테이지에서 일정 시간마다
화면 옆에서 등장하여 보스를 공격하는 시스템.

투기장 호위무사(GuardWarriorSystem)를 내부적으로 재사용하여
동일한 UI, 스킬 이펙트, 위치를 보장한다.
"""
import random
import os

try:
    import pygame
    import pygame.freetype
except ImportError:
    pygame = None


# ============================================================================
# 상수
# ============================================================================
GAME_AREA_X = 80           # 게임 영역 시작 X
GAME_AREA_WIDTH = 600      # 게임 영역 너비
SCREEN_WIDTH = 760         # 전체 내부 해상도 너비
SCREEN_HEIGHT = 750        # 전체 내부 해상도 높이

# 영웅별 한국어 이름 및 스킬명
HERO_DISPLAY_INFO = {
    "mugen":    {"name": "무겐",    "skill": "달빛베기",     "color": (120, 60, 180)},
    "kraken":   {"name": "크라켄",  "skill": "촉수휘감기",   "color": (40, 120, 140)},
    "chronos":  {"name": "크로노스","skill": "중력제어",     "color": (200, 170, 100)},
    "onimaru":  {"name": "오니마루","skill": "지옥의 불꽃",  "color": (200, 50, 70)},
    "maria":    {"name": "연화",    "skill": "인형조종",     "color": (180, 100, 150)},
    "ignis":    {"name": "이그니스","skill": "드래곤 브레스", "color": (220, 100, 40)},
    "gear":     {"name": "기어",    "skill": "스팀배리어",   "color": (140, 100, 60)},
    "kurokage": {"name": "쿠로카게","skill": "그림자분신",   "color": (50, 50, 70)},
}

# ── 호위무사 등장 대사 ──
# hero_lines: 호위무사 등장 전 영웅이 먼저 하는 대사
# guard_lines: 호위무사가 화면에 진입 완료 후 하는 대사
GUARD_ENTRANCE_LINES = {
    # ─── 무겐 (귀검사) : 냉철하고 과묵한 검사 ───
    "mugen": {
        "hero_lines": [
            "감옥에서 갈고닦은 검기... 보여줄 차례다.",
            "내 그림자가 움직인다.",
            "어둠의 검이여... 나타나라.",
        ],
        "guard_lines": [
            "...명에 따르겠습니다.",
            "어둠 속에서 주군을 지키겠습니다.",
            "검에 맹세하여, 호위하겠습니다.",
        ],
    },
    # ─── 크라켄 (심해의 포식자) : 기괴하고 탐욕스러운 ───
    "kraken": {
        "hero_lines": [
            "배고프다... 먹잇감을 불러줘.",
            "촉수가 떨려... 누가 올 거야.",
            "심해에서 뭔가 올라오고 있어... 흐흐.",
        ],
        "guard_lines": [
            "크르르... 배가 고프군.",
            "먹잇감의 냄새가 나... 흐흐.",
            "심해의 촉수가 도와주지.",
        ],
    },
    # ─── 키르케 (흑마녀) : 오만하고 우아한 ───
    "chronos": {
        "hero_lines": [
            "후후, 하인을 불러볼까.",
            "본 마녀의 종이 올 시간이야.",
            "흑마법으로 소환한 충실한 수하야.",
        ],
        "guard_lines": [
            "마녀님의 명에 따릅니다.",
            "흑마법의 힘이 함께합니다.",
            "주인님을 위해 싸우겠습니다.",
        ],
    },
    # ─── 오니마루 (요괴무사) : 호쾌하고 전투광 ───
    "onimaru": {
        "hero_lines": [
            "좋다! 든든한 놈이 오고 있다!",
            "하하! 동료가 합류한다!",
            "지옥에서 데려온 녀석이지!",
        ],
        "guard_lines": [
            "뿔의 힘으로 호위하겠습니다!",
            "전장에 왔다! 같이 싸우자!",
            "오니의 맹세로, 지켜드리겠습니다!",
        ],
    },
    # ─── 연화 (인형사) : 소름끼치고 장난스러운 ───
    "maria": {
        "hero_lines": [
            "히히... 인형이 하나 더 움직이네.",
            "새 친구가 오고 있어~",
            "실을 당기면... 나타날 거야.",
        ],
        "guard_lines": [
            "인형의 실에 이끌려 왔어요... 히히.",
            "주인님의 인형이 되어드릴게요~",
            "같이 놀아줄게... 후후.",
        ],
    },
    # ─── 이그니스 (드래곤 나이트) : 열혈 전사 ───
    "ignis": {
        "hero_lines": [
            "불꽃의 원군이 온다! 하하!",
            "내 전우가 합류한다!",
            "드래곤의 동지여, 나타나라!",
        ],
        "guard_lines": [
            "불꽃의 맹세로 호위하겠습니다!",
            "내가 있으니 든든하지? 하하!",
            "함께 싸우자! 용기사의 이름으로!",
        ],
    },
    # ─── 마리 (스팀펑크 메카닉) : 발명가 기질, 자기 기계에 대한 자부심 ───
    "gear": {
        "hero_lines": [
            "내가 만든 작품이 도착했어!",
            "증기 충전 완료! 원군 투입~!",
            "후후, 내 신작이 출격한다!",
        ],
        "guard_lines": [
            "기어 풀가동! 호위 시작합니다!",
            "최선을 다해 호위하겠습니다!",
            "스팀 파워로 지켜드릴게요!",
        ],
    },
    # ─── 쿠로카게 (그림자 닌자) : 과묵하고 냉정한 ───
    "kurokage": {
        "hero_lines": [
            "...그림자가 하나 더 움직인다.",
            "닌자는 혼자 싸우지 않는다.",
            "...원군이다.",
        ],
        "guard_lines": [
            "...임무를 수행합니다.",
            "그림자처럼 호위하겠습니다.",
            "주인님을 보호하라... 그것이 임무.",
        ],
    },
    # ─── 벤시 (유령 여왕) : 서늘하고 기품 있는 유령 ───
    "banshee": {
        "hero_lines": [
            "...차가운 바람이 불어온다.",
            "유령 하나가 더 깨어났어.",
            "한이 서린 영혼이 움직이는군...",
        ],
        "guard_lines": [
            "원한의 힘으로... 지켜드리겠습니다.",
            "유령은 사라지지 않아... 여기서 호위할게.",
            "차가운 비명으로 적을 쫓아드리죠.",
        ],
    },
    # ─── 네크로 (강령술사) : 차분하고 으스스한 강령술사 ───
    "necro": {
        "hero_lines": [
            "영혼들이여... 소환에 응하라.",
            "죽음의 군단에서 하나를 불러내지.",
            "저승에서 동지가 온다...",
        ],
        "guard_lines": [
            "망자의 충성을... 바칩니다.",
            "저승에서 왔습니다. 호위하겠습니다.",
            "죽음의 손길로 적을 막겠습니다.",
        ],
    },
    # ─── 조커 (광대) : 장난기 넘치고 도발적인 광대 ───
    "joker": {
        "hero_lines": [
            "자~ 서프라이즈 게스트 등장~!",
            "하하! 쇼에 조수가 필요하지!",
            "땡! 비밀 게스트 공개~!",
        ],
        "guard_lines": [
            "서프라이즈~! 내가 왔다!",
            "하하! 쇼를 도와줄게~!",
            "최고의 조수가 등장이다! 짜잔~!",
        ],
    },
    # ─── 세트 (사막의 환술사) : 신비롭고 차분한 사막 현자 ───
    "mirage": {
        "hero_lines": [
            "모래바람 속에서 무언가 다가온다...",
            "사막의 신기루가 형체를 갖추는군.",
            "환영이 아니다... 진짜 동지야.",
        ],
        "guard_lines": [
            "사막의 모래가 보낸 호위입니다.",
            "신기루처럼 나타나 적을 막겠습니다.",
            "모래바람의 가호가 함께합니다.",
        ],
    },
    # ─── 안드로이드 (기계 전사) : 감정을 흉내내려 하지만 어색한 로봇 ───
    "android": {
        "hero_lines": [
            "호위 유닛 기동 확인.",
            "지원 병기 투입 승인.",
            "...증원입니다. 전투력 상승.",
        ],
        "guard_lines": [
            "호위 모드 기동. ...든든합니까?",
            "보호 프로토콜 실행합니다.",
            "전투 지원 개시. 이상 없음.",
        ],
    },
    # ─── 호루스 (천둥의 매) : 위엄 있고 냉철한 번개의 지배자 ───
    "ra": {
        "hero_lines": [
            "번개의 사자가 내려온다.",
            "뇌운이 몰려오고 있다... 동지여.",
            "하늘의 매가 원군을 보냈다.",
        ],
        "guard_lines": [
            "번개의 힘으로 호위하겠습니다.",
            "뇌신의 명으로, 적을 심판합니다.",
            "하늘에서 내려온 수호자입니다.",
        ],
    },
    # ─── 원숭이왕 (밀림의 패왕) : 의성어만 가능 ───
    "monkeyking": {
        "hero_lines": [
            "우끼끼!! 우끼끼끼!!",
            "끼끼끽! 우끼~!",
            "우키키!! 끼끽!!",
        ],
        "guard_lines": [
            "우끼끼~! 우끽!",
            "끼끼! 끼끼끼!",
            "우끼!! 우키키키!",
        ],
    },
}


class _MinimalSkillManager:
    """GuardWarriorSystem이 요구하는 최소한의 skill_manager 인터페이스"""
    def __init__(self):
        self.game_state = {'is_ingame_bodyguard': True}
        self.screen_effects = []


class _PaddleProxy:
    """pygame.Rect를 패들 객체처럼 래핑"""
    def __init__(self, rect, is_top):
        self.x = rect.x
        self.y = rect.y
        self.width = rect.width
        self.height = rect.height
        self.centerx = getattr(rect, 'centerx', rect.x + rect.width // 2)
        self.centery = getattr(rect, 'centery', rect.y + rect.height // 2)
        self.is_top = is_top
        self.paddle_scale = 1.0


class _BallProxy:
    """공 Rect + 속도를 래핑 (스킬이 수정한 속도 변경을 추적)

    ArenaBall과 동일하게 x/y = 중심 좌표 사용 (GuardWarriorSystem 충돌 감지 호환)
    """
    def __init__(self, rect, vx=0, vy=0):
        # ArenaBall 호환: x/y는 중심 좌표 (top-left가 아님!)
        self.x = getattr(rect, 'centerx', rect.x + rect.width // 2)
        self.y = getattr(rect, 'centery', rect.y + rect.height // 2)
        self.width = rect.width
        self.height = rect.height
        self.centerx = self.x
        self.centery = self.y
        self.vx = vx
        self.vy = vy
        # 원본 속도 저장 (스킬에 의한 변경량 추적용)
        self._original_vx = vx
        self._original_vy = vy

    @property
    def vel_changed(self):
        """스킬이 공 속도를 변경했는지 확인"""
        return (self.vx != self._original_vx or
                self.vy != self._original_vy)


# 호위무사 순찰 Y 위치 (플레이어 패들 710보다 위에 배치 → 공을 먼저 가로챔)
_BODYGUARD_PATROL_Y = 670


# ============================================================================
# 인게임 호위무사 클래스
# ============================================================================
class InGameBodyguard:
    """스테이지 진행 중 플레이어를 돕는 호위무사 시스템

    투기장 GuardWarriorSystem을 내부적으로 재사용하여 동일한 스킬/UI 제공.
    """

    def __init__(self):
        self.hero_data = None
        self.active = False
        self._guard_system = None   # GuardWarriorSystem 인스턴스
        self._skill_manager = None  # 최소 skill_manager
        self._hero_paddle_renderer = None
        # 등장 대사 시스템
        self._entrance_hero_line = None     # 영웅 등장 전 대사 텍스트
        self._entrance_hero_timer = 0.0     # 영웅 대사 표시 타이머 (초)
        self._entrance_guard_line = None    # 호위무사 등장 후 대사 텍스트 (예약)
        self._entrance_hero_color = (255, 255, 255)  # 영웅 대사 색상

    def setup(self, hero_data: dict, skill_selections: dict = None):
        """호위무사 설정 (투기장 우승 후 등용된 영웅)

        Args:
            hero_data: 영웅 데이터 dict
            skill_selections: 스킬 선택 dict {hero_id: skill_index} (투기장과 동일)
        """
        self.hero_data = hero_data
        self.active = True

        # 등장 대사 설정 (영웅이 먼저 말하고, 호위무사가 등장 후 말함)
        hero_id = hero_data.get("id", "")
        entrance = GUARD_ENTRANCE_LINES.get(hero_id)
        if entrance:
            self._entrance_hero_line = random.choice(entrance["hero_lines"])
            self._entrance_guard_line = random.choice(entrance["guard_lines"])
            self._entrance_hero_timer = 3.0  # 3초간 영웅 대사 표시
            self._entrance_hero_color = hero_data.get("color", (255, 255, 255))
            print(f"[Bodyguard] 영웅 등장 대사: {self._entrance_hero_line}")
        else:
            self._entrance_hero_line = None
            self._entrance_guard_line = None
            self._entrance_hero_timer = 0.0

        # 패들 렌더러 초기화
        try:
            from downtown.hero_paddles import get_hero_paddle_renderer
            self._hero_paddle_renderer = get_hero_paddle_renderer()
        except Exception:
            self._hero_paddle_renderer = None

        # 최소 skill_manager 생성
        self._skill_manager = _MinimalSkillManager()

        # GuardWarriorSystem 생성 및 설정
        try:
            from downtown.colosseum_arena import GuardWarriorSystem
            self._guard_system = GuardWarriorSystem(
                skill_manager=self._skill_manager,
                hero_paddle_renderer=self._hero_paddle_renderer,
            )
            # 플레이어 측(하단) 호위무사로 설정
            # skill_selections 전달: 투기장에서 선택했던 스킬만 사용
            self._guard_system.setup(
                guards_top=[],                # 상단(보스 측)은 없음
                guards_bottom=[hero_data],    # 하단(플레이어 측)에 배치
                initial_delay=(12.0, 18.0),
                skill_selections=skill_selections,
            )
            # 호위무사 등장 대사 전달 (입장 완료 시 말풍선으로 표시)
            if self._entrance_guard_line:
                self._guard_system._entrance_guard_line_bottom = self._entrance_guard_line
            # 순찰 모드 즉시 시작 (기본 동작: 맵에서 상시 순찰)
            self._guard_system.activate_patrol_immediate()
            print(f"[Bodyguard] 호위무사 설정 완료 (GuardWarriorSystem): "
                  f"{hero_data.get('name', '???')} (id={hero_data.get('id')})")
        except Exception as e:
            print(f"[Bodyguard] GuardWarriorSystem 생성 실패: {e}")
            import traceback
            traceback.print_exc()
            self._guard_system = None

    def reset(self):
        """호위무사 시스템 리셋"""
        if self._guard_system:
            self._guard_system.reset()
        self.hero_data = None
        self.active = False
        self._guard_system = None
        self._skill_manager = None
        # 등장 대사 초기화
        self._entrance_hero_line = None
        self._entrance_hero_timer = 0.0
        self._entrance_guard_line = None

    def update(self, dt: float, boss_rect=None, player_rect=None,
               ball_rect=None, ball_vx=0, ball_vy=0) -> dict:
        """매 프레임 업데이트

        Args:
            dt: 델타 타임 (초)
            boss_rect: 보스 pygame.Rect (상단)
            player_rect: 플레이어 pygame.Rect (하단)
            ball_rect: 공 pygame.Rect
            ball_vx, ball_vy: 공 속도
        """
        if not self.active or not self._guard_system:
            return {}

        # 영웅 등장 대사 타이머 감소
        if self._entrance_hero_timer > 0:
            self._entrance_hero_timer -= dt

        # Rect → 프록시 패들/공 변환
        top_paddle = _PaddleProxy(boss_rect, is_top=True) if boss_rect else None
        bottom_paddle = _PaddleProxy(player_rect, is_top=False) if player_rect else None
        ball = _BallProxy(ball_rect, ball_vx, ball_vy) if ball_rect else None

        # 가짜 패들 폴백 (None 방지)
        if top_paddle is None:
            top_paddle = _PaddleProxy(pygame.Rect(380, 25, 120, 40), is_top=True)
        if bottom_paddle is None:
            bottom_paddle = _PaddleProxy(pygame.Rect(380, 710, 120, 40), is_top=False)

        # 순찰 중 호위무사 Y를 플레이어 패들보다 위에 고정 (공 가로채기)
        _phase = self._guard_system.phase_bottom
        if _phase in ("patrolling", "patrol_entering", None):
            self._guard_system.y_bottom = _BODYGUARD_PATROL_Y

        # hero_paddle_top / hero_paddle_bottom 갱신 (해골궁수 등 스킬이 참조)
        # 투기장 SkillManager.update()가 매 프레임 설정하는 것과 동일
        gs = self._skill_manager.game_state
        gs['hero_paddle_top'] = {
            'x': top_paddle.x, 'y': top_paddle.y,
            'width': top_paddle.width, 'height': top_paddle.height,
        }
        gs['hero_paddle_bottom'] = {
            'x': bottom_paddle.x, 'y': bottom_paddle.y,
            'width': bottom_paddle.width, 'height': bottom_paddle.height,
        }

        self._guard_system.update(dt, top_paddle, bottom_paddle, ball)

        # game_state에서 보스(top_paddle) 상태 효과 추출 → pingfighter.py에 전달
        gs = self._skill_manager.game_state
        boss_effects = {}

        # ── 기본 상태 이상 ──

        # 스턴
        if gs.pop('top_paddle_stunned', False):
            boss_effects['stun_frames'] = 90  # 1.5초

        # 둔화
        if gs.pop('top_paddle_slowed', False):
            boss_effects['slow'] = True
            boss_effects['slow_amount'] = gs.pop('top_paddle_slow_amount', 0.5)
            boss_effects['slow_frames'] = 180  # 3초

        # 혼란 (조작 반전)
        if gs.pop('top_paddle_confused', False):
            boss_effects['confuse_frames'] = 180  # 3초

        # 축소 (DwarfMagic은 매 프레임 scale을 갱신하므로 pop이 아닌 get 사용)
        if gs.get('top_paddle_shrink', False):
            boss_effects['shrink'] = True
            boss_effects['shrink_scale'] = gs.get('top_paddle_shrink_scale', 0.5)

        # ── 연화: 꼭두각시 조종 (PUPPET) ──
        if gs.pop('top_paddle_locked', False):
            boss_effects['puppet'] = True
            boss_effects['puppet_x'] = gs.pop('top_paddle_locked_x', None)
            boss_effects['puppet_y'] = gs.pop('top_paddle_locked_y', None)

        # ── 신기루: 모래감옥 (이동 범위 제한) ──
        if gs.get('top_paddle_sand_prison', False):
            boss_effects['sand_prison'] = True
            boss_effects['sand_prison_center_x'] = gs.get('sand_prison_center_x')
            boss_effects['sand_prison_range'] = gs.get('sand_prison_range')

        # ── 오니마루: 뿔 박치기 넉백 ──
        if gs.get('horn_charge_apply_knockback'):
            boss_effects['horn_charge_knockback'] = True
            boss_effects['horn_charge_knockback_dir'] = gs.get('horn_charge_knockback_dir', 1)
            boss_effects['horn_charge_knockback_vel'] = gs.get('horn_charge_knockback_vel', 73)
            boss_effects['horn_charge_target_is_top'] = gs.get('horn_charge_target_is_top', True)
            gs['horn_charge_apply_knockback'] = False  # 1회성 신호 소비

        # ── 화면 정지 효과 (달빛베기 / 도깨비불) ──
        if gs.get('dark_slash_freeze', False):
            boss_effects['freeze'] = True
        if gs.get('hell_fire_freeze', False):
            boss_effects['freeze'] = True

        # ── 도깨비불 공 이펙트 ──
        if gs.get('dokkaebi_ball', False):
            boss_effects['dokkaebi_ball'] = True

        # ── 공 속도 변경 (중력제어, 달빛베기 가속, 도깨비불 등) ──
        if ball and ball.vel_changed:
            boss_effects['ball_vx'] = ball.vx
            boss_effects['ball_vy'] = ball.vy

        # ── 범용 넉백 (개틀링 버스트, 환영수리검, 해골 궁수 등) ──
        if gs.get('top_paddle_knockback', False):
            boss_effects['generic_knockback'] = True
            boss_effects['generic_knockback_dir'] = gs.get('top_paddle_knockback_dir', 1)
            boss_effects['generic_knockback_vel'] = gs.get('top_paddle_knockback_vel', 120)
            gs['top_paddle_knockback'] = False  # 1회성 신호 소비

        # ── 폭탄 서프라이즈 넉백 (프레임 기반 지속 넉백) ──
        if gs.get('top_paddle_bomb_kb_active', False):
            boss_effects['bomb_kb_active'] = True
            boss_effects['bomb_kb_dir'] = gs.get('top_paddle_bomb_kb_dir', 0)
            boss_effects['bomb_kb_vel'] = gs.get('top_paddle_bomb_kb_vel', 0)
            boss_effects['bomb_kb_frames'] = gs.get('top_paddle_bomb_kb_frames', 0)

        # ── 바나나 슬라이스 미끄러짐 ──
        if gs.get('top_paddle_banana_slip_active', False):
            boss_effects['banana_slip_active'] = True
            boss_effects['banana_slip_offset'] = gs.get('top_paddle_banana_slip_offset', 0)

        # ── 감전 이펙트 (천둥 뇌구) ──
        if gs.get('top_paddle_electric_stun', False):
            boss_effects['electric_stun'] = True

        # ── 화면 흔들림 (스킬 game_state 직접 설정) ──
        _gs_shake = gs.pop('screen_shake', 0)
        if _gs_shake:
            boss_effects['screen_shake'] = True
            boss_effects['shake_intensity'] = _gs_shake if isinstance(_gs_shake, (int, float)) else 15

        # ── 호위무사 공 충돌 (순찰/일반/귀신발걸음) ──
        _patrol_hit = gs.pop('guard_patrol_ball_hit', None)
        if _patrol_hit:
            boss_effects['guard_patrol_ball_hit'] = _patrol_hit

        _general_hit = gs.pop('guard_general_ball_hit', None)
        if _general_hit:
            boss_effects['guard_general_ball_hit'] = _general_hit

        _demon_hit = gs.pop('guard_demon_step_ball_hit', None)
        if _demon_hit:
            boss_effects['guard_demon_step_ball_hit'] = _demon_hit

        # ── 화면 효과 (screen_effects 리스트) ──
        for fx in self._skill_manager.screen_effects:
            boss_effects['screen_shake'] = True
            boss_effects['shake_intensity'] = fx.get('intensity', 15)
        self._skill_manager.screen_effects.clear()

        return boss_effects

    def draw(self, screen, boss_rect=None, player_rect=None, ball_rect=None):
        """호위무사 캐릭터 및 스킬 이펙트 그리기"""
        if not self.active or not self._guard_system:
            return

        # Rect → 프록시 변환
        top_paddle = _PaddleProxy(boss_rect, is_top=True) if boss_rect else None
        bottom_paddle = _PaddleProxy(player_rect, is_top=False) if player_rect else None
        ball = _BallProxy(ball_rect) if ball_rect else None

        if top_paddle is None:
            top_paddle = _PaddleProxy(pygame.Rect(380, 25, 120, 40), is_top=True)
        if bottom_paddle is None:
            bottom_paddle = _PaddleProxy(pygame.Rect(380, 710, 120, 40), is_top=False)

        # 순찰 중 호위무사 Y를 플레이어 패들보다 위에 고정 (update와 동일)
        _phase = self._guard_system.phase_bottom
        if _phase in ("patrolling", "patrol_entering", None):
            self._guard_system.y_bottom = _BODYGUARD_PATROL_Y

        self._guard_system.draw(
            screen,
            top_paddle=top_paddle,
            bottom_paddle=bottom_paddle,
            ball=ball,
        )

    def draw_pillar_icon(self, screen, game_offset_x=0, game_offset_y=0,
                         game_scale=1.0):
        """필러에 호위무사 UI 아이콘 표시 (투기장과 동일한 스타일/위치)"""
        if not self.active or not self._guard_system:
            return

        self._guard_system.draw_guard_icons(
            screen,
            game_offset_x=game_offset_x,
            game_offset_y=game_offset_y,
            game_scale=game_scale,
        )

    # ── 초상화 UI 내부 캐시 ──
    _portrait_card_surf = None
    _portrait_overlay_surf = None
    _portrait_card_size = (0, 0)
    _portrait_positions = {}       # key → smooth Y 위치

    def draw_portrait_ui(self, screen, game_offset_x=0, game_offset_y=0,
                         game_scale=1.0):
        """투기장 draw_cooldown_queue 와 동일한 초상화 카드 UI

        왼쪽 필러 하단에 호위무사 스킬별 얼굴 카드를 쿨타임 순으로 표시.
        """
        if not self.active or not self._guard_system or not pygame:
            return

        try:
            entries = self._guard_system.get_all_cooldown_entries()
        except Exception:
            return
        if not entries:
            return

        # 정렬 (발동 중 → 준비 완료 → 쿨타임 짧은 순)
        entries.sort(key=lambda e: (
            0 if e["is_active"] else (1 if e["cooldown_remaining"] <= 0 else 2),
            e["cooldown_remaining"],
        ))

        # 레이아웃 계산
        pillar_x = 0
        pillar_w = game_offset_x if game_offset_x > 0 else 80
        pillar_y = game_offset_y
        pillar_h = int(SCREEN_HEIGHT * game_scale) if game_scale > 0 else SCREEN_HEIGHT

        _scale = pillar_w / 80.0
        card_w = max(20, int(28 * _scale))
        card_h = max(10, int(9 * _scale))
        card_gap = max(1, int(2 * _scale))
        margin_x = max(1, int(3 * _scale))
        total_h = len(entries) * (card_h + card_gap) - card_gap

        # 세로: 중앙 정렬 (투기장과 동일)
        center_y = pillar_y + (pillar_h - total_h) // 2
        start_y = max(pillar_y + 5, center_y)
        # 가로: 오른쪽 정렬 (인게임 영역 바로 왼쪽)
        card_x = pillar_x + pillar_w - card_w - margin_x

        # Surface 캐시
        if InGameBodyguard._portrait_card_size != (card_w, card_h):
            InGameBodyguard._portrait_card_surf = pygame.Surface(
                (card_w, card_h), pygame.SRCALPHA)
            InGameBodyguard._portrait_overlay_surf = pygame.Surface(
                (card_w, card_h), pygame.SRCALPHA)
            InGameBodyguard._portrait_card_size = (card_w, card_h)

        ticks = pygame.time.get_ticks()
        dt = 1.0 / 60.0
        _sin = __import__('math').sin

        # _load_facecard 가져오기 (지연 임포트)
        try:
            from downtown.colosseum_arena import _load_facecard
        except ImportError:
            _load_facecard = None

        # 폴백 portrait renderer
        _portrait_renderer = None
        try:
            from downtown.hero_portraits import get_portrait_renderer
            _portrait_renderer = get_portrait_renderer()
        except Exception:
            pass

        for idx, entry in enumerate(entries):
            target_y = start_y + idx * (card_h + card_gap)
            ekey = entry.get("key", f"e{idx}")

            # 스무스 Y lerp
            cur_y = InGameBodyguard._portrait_positions.get(ekey, target_y)
            cur_y += (target_y - cur_y) * min(1.0, 8.0 * dt)
            InGameBodyguard._portrait_positions[ekey] = cur_y
            draw_y = int(cur_y)

            hero_id = entry["hero_id"]
            hero_color = entry["hero_color"]
            cd_rem = entry["cooldown_remaining"]
            cd_max = entry["cooldown_max"]
            is_active = entry["is_active"]
            is_ready = cd_rem <= 0 and not is_active

            # ── 카드 = 얼굴 초상화 ──
            card = InGameBodyguard._portrait_card_surf
            card.fill((15, 12, 20, 255))

            # 페이스카드 우선, 없으면 프로시저럴
            _fc = _load_facecard(hero_id, card_w, card_h) if _load_facecard else None
            if _fc is not None:
                card.blit(_fc, (0, 0))
            elif _portrait_renderer:
                try:
                    portrait = _portrait_renderer.render_portrait(
                        hero_id, hero_color, card_w, card_h)
                    card.blit(portrait, (0, 0))
                except Exception:
                    pygame.draw.rect(card, hero_color, (0, 0, card_w, card_h),
                                     border_radius=2)

            # ── 쿨타임 명암 오버레이 ──
            overlay = InGameBodyguard._portrait_overlay_surf
            if is_active:
                pulse = 0.5 + 0.5 * _sin(ticks / 150.0)
                overlay.fill((255, 200, 60, int(50 * pulse)))
                card.blit(overlay, (0, 0))
            elif not is_ready and cd_max > 0:
                cd_ratio = 1.0 - min(1.0, cd_rem / cd_max)
                dark_w = max(0, int(card_w * (1.0 - cd_ratio)))
                if dark_w > 0:
                    overlay.fill((0, 0, 0, 140))
                    card.blit(overlay, (card_w - dark_w, 0),
                              (0, 0, dark_w, card_h))

            # ── 테두리 ──
            if is_active:
                pulse = 0.7 + 0.3 * _sin(ticks / 200.0)
                pygame.draw.rect(card, (255, 220, 80, int(220 * pulse)),
                                 (0, 0, card_w, card_h), 2, border_radius=2)
            elif is_ready:
                pulse = 0.6 + 0.4 * _sin(ticks / 350.0)
                pygame.draw.rect(card, (100, 220, 150, int(160 * pulse)),
                                 (0, 0, card_w, card_h), 1, border_radius=2)
            else:
                pygame.draw.rect(card, (50, 50, 60, 120),
                                 (0, 0, card_w, card_h), 1, border_radius=2)

            # 진영 표시 (왼쪽 파란 줄 = 플레이어측)
            _sc = max(1, int(2 * _scale))
            side_color = (220, 70, 70) if entry.get("side") == "top" else (70, 120, 220)
            pygame.draw.rect(card, (*side_color, 180), (0, 1, _sc, card_h - 2))

            screen.blit(card, (card_x, draw_y))

        # 오래된 position 키 정리
        active_keys = {e.get("key", f"e{i}") for i, e in enumerate(entries)}
        stale = [k for k in InGameBodyguard._portrait_positions if k not in active_keys]
        for k in stale:
            del InGameBodyguard._portrait_positions[k]

    def draw_entrance_speech(self, screen, player_rect):
        """영웅의 등장 전 대사 말풍선 그리기 (플레이어 패들 위에 표시)"""
        if not self._entrance_hero_line or self._entrance_hero_timer <= 0:
            return
        if not pygame or not player_rect:
            return

        try:
            import pygame.freetype as _ft

            text = self._entrance_hero_line
            color = self._entrance_hero_color
            if not isinstance(color, (tuple, list)) or len(color) < 3:
                color = (255, 255, 255)

            # 폰트 로드 (루트 또는 fonts/ 폴더에서 탐색)
            font = None
            try:
                _root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                for _rel in ("NanumSquareB.ttf", os.path.join("fonts", "NanumSquareB.ttf")):
                    _fp = os.path.join(_root, _rel)
                    if os.path.exists(_fp):
                        font = _ft.Font(_fp, 16)
                        break
                if font is None:
                    font = _ft.SysFont("malgun gothic", 16)
            except Exception:
                font = _ft.SysFont("malgun gothic", 16)
            if not font:
                return

            text_surf, text_rect = font.render(text, (0, 0, 0))
            tw, th = text_surf.get_size()
            padding = 12

            # 말풍선 크기
            bw = tw + padding * 2
            bh = th + padding
            # 위치: 플레이어 패들 위 (80px 위)
            bx = int(player_rect.centerx - bw // 2)
            by = int(player_rect.top - 80)
            # 화면 경계 보정
            bx = max(GAME_AREA_X + 4, min(bx, GAME_AREA_X + GAME_AREA_WIDTH - bw - 4))
            by = max(4, by)

            # 페이드 효과 (마지막 0.5초 페이드아웃)
            alpha = 255
            if self._entrance_hero_timer < 0.5:
                alpha = int(255 * (self._entrance_hero_timer / 0.5))

            # 말풍선 배경 Surface
            bubble_surf = pygame.Surface((bw, bh), pygame.SRCALPHA)
            # 둥근 모서리 말풍선 배경
            r = 10
            pygame.draw.rect(bubble_surf, (255, 255, 255, alpha), (0, 0, bw, bh), border_radius=r)
            # 테두리
            border_c = (min(255, color[0] + 30), min(255, color[1] + 30), min(255, color[2] + 30), alpha)
            pygame.draw.rect(bubble_surf, border_c, (0, 0, bw, bh), 2, border_radius=r)

            # 말풍선 꼬리 (아래쪽)
            tail_x = bw // 2
            tail_pts = [(tail_x - 6, bh - 1), (tail_x + 6, bh - 1), (tail_x, bh + 8)]
            pygame.draw.polygon(bubble_surf, (255, 255, 255, alpha), tail_pts)
            pygame.draw.lines(bubble_surf, border_c, False,
                              [(tail_x - 6, bh - 1), (tail_x, bh + 8), (tail_x + 6, bh - 1)], 2)

            screen.blit(bubble_surf, (bx, by))

            # 텍스트 (페이드 적용)
            if alpha < 255:
                text_surf_a, _ = font.render(text, (0, 0, 0, alpha))
                screen.blit(text_surf_a, (bx + padding, by + padding // 2))
            else:
                screen.blit(text_surf, (bx + padding, by + padding // 2))

        except Exception as e:
            print(f"[Bodyguard] 등장 대사 렌더링 오류: {e}")

    def reset_active_skills(self):
        """득점 시 호위무사 활성 스킬 리셋"""
        if self._guard_system:
            self._guard_system.reset_active_skills()


# ============================================================================
# 싱글턴 인스턴스
# ============================================================================
_bodyguard_instance = None


def get_bodyguard() -> InGameBodyguard:
    """인게임 호위무사 싱글턴 인스턴스"""
    global _bodyguard_instance
    if _bodyguard_instance is None:
        _bodyguard_instance = InGameBodyguard()
    return _bodyguard_instance
