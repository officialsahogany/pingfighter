"""하수인 (Henchman) 시스템

투기장에서 포획한 영웅이 호위무사가 아닌 하수인으로 전환되어
플레이어가 수동으로 클릭하여 스킬을 발동시키는 시스템.

- 호위무사와 달리 자동 순찰/자동 시전 없음
- 플레이어가 필러 아이콘을 클릭해야만 발동
- 쿨타임 3.8배 (기본 쿨타임 × HENCHMAN_TOTAL_CD_MULT)
- 여러 명의 하수인을 동시에 보유 가능
"""
import random
import math
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
PADDLE_WIDTH = 120
PADDLE_HEIGHT = 40

# 하수인 애니메이션 타이밍
HENCH_ENTER_DURATION = 0.5     # 등장 시간 (초)
HENCH_CAST_DURATION = 0.8      # 시전 포즈 시간
HENCH_EXIT_DURATION = 0.4      # 퇴장 시간

# 하수인 쿨타임 총 배율 (기본 스킬 쿨타임 × 4.2)
HENCHMAN_TOTAL_CD_MULT = 4.2

# 하수인 등장 Y 위치 (호위무사와 동일)
HENCH_TOP_Y = 45   # TOP_PADDLE_Y(25) + 20 — 호위무사 상단 Y와 동일 (상반신 잘림 방지)
HENCH_Y = 710       # BOTTOM_PADDLE_Y와 동일

# 아이콘 크기
HENCH_ICON_SIZE = 42

# 채널링 스킬 ID (하수인이 스킬 지속 중 화면에 남아야 하는 스킬)
# 나머지 스킬은 시전 포즈 후 즉시 퇴장하고, 스킬 이펙트만 독립적으로 지속
HENCH_CHANNELED_SKILLS = frozenset({'steam_barrier', 'gatling_burst', 'tentacle_wrap', 'puppet_control', 'doll_curse'})
# 채널링 스킬의 최대 체류 시간 (안전 타임아웃)
HENCH_CHANNEL_MAX_STAY = 12.0


# ============================================================================
# 영웅 표시 정보
# ============================================================================
HERO_DISPLAY_INFO = {
    "mugen":    {"name": "무겐",    "color": (120, 60, 180)},
    "kraken":   {"name": "크라켄",  "color": (40, 120, 140)},
    "chronos":  {"name": "크로노스","color": (200, 170, 100)},
    "onimaru":  {"name": "오니마루","color": (200, 50, 70)},
    "maria":    {"name": "연화",    "color": (180, 100, 150)},
    "ignis":    {"name": "이그니스","color": (220, 100, 40)},
    "gear":     {"name": "기어",    "color": (140, 100, 60)},
    "kurokage": {"name": "쿠로카게","color": (50, 50, 70)},
}


# ============================================================================
# 프록시 클래스 (ingame_bodyguard.py와 동일)
# ============================================================================
class _PaddleProxy:
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
    def __init__(self, rect, vx=0, vy=0):
        self.x = rect.x
        self.y = rect.y
        self.width = rect.width
        self.height = rect.height
        self.centerx = getattr(rect, 'centerx', rect.x + rect.width // 2)
        self.centery = getattr(rect, 'centery', rect.y + rect.height // 2)
        self.vx = vx
        self.vy = vy
        self._original_vx = vx
        self._original_vy = vy

    @property
    def vel_changed(self):
        return (self.vx != self._original_vx or
                self.vy != self._original_vy)


class _MinimalSkillManager:
    def __init__(self):
        self.game_state = {'is_henchman': True}
        self.screen_effects = []


class _GuardPaddle:
    """하수인 위치를 패들처럼 사용하기 위한 가상 패들"""
    def __init__(self, x, y, is_top=False, width=PADDLE_WIDTH, height=PADDLE_HEIGHT):
        self.x = x - width // 2
        self.y = y
        self.width = width
        self.height = height
        self.centerx = x
        self.centery = y + height // 2
        self.is_top = is_top
        self.is_bodyguard = True
        self.paddle_scale = 1.0
        self.power = 1.0

    def get_rect(self):
        return pygame.Rect(int(self.x), int(self.y), self.width, self.height)


# ============================================================================
# 하수인 슬롯
# ============================================================================
class HenchmanSlot:
    """개별 하수인의 런타임 상태"""

    def __init__(self, hero_data: dict, skill_instance, cooldown_max: float):
        self.hero_data = hero_data
        self.skill_instance = skill_instance
        self.cooldown = 0.0           # 초기에는 즉시 사용 가능
        self.cooldown_max = cooldown_max
        self.phase = None             # None / "entering" / "casting" / "exiting"
        self.anim_timer = 0.0
        self.x = 0.0
        self.y = HENCH_Y
        self.target_x = 0.0          # 진입 목표 X
        self.entry_side = "left"      # "left" or "right"
        self.icon_rect = pygame.Rect(0, 0, 0, 0)  # 필러 아이콘 영역
        self.ready_flash_timer = 0.0   # 쿨타임 완충 시 반짝임 타이머 (초)
        self._was_on_cooldown = False   # 쿨타임→완충 전환 감지용

    @property
    def hero_id(self):
        return self.hero_data.get("id", "")

    @property
    def hero_name(self):
        return self.hero_data.get("name", "?")

    @property
    def hero_color(self):
        info = HERO_DISPLAY_INFO.get(self.hero_id)
        if info:
            return info.get("color", (200, 200, 200))
        return self.hero_data.get("color", (200, 200, 200))

    @property
    def is_ready(self):
        """쿨타임 완료 + 애니메이션 미진행"""
        return self.cooldown <= 0 and self.phase is None

    @property
    def is_on_cooldown(self):
        return self.cooldown > 0

    @property
    def cooldown_ratio(self):
        if self.cooldown_max <= 0:
            return 0.0
        return min(1.0, max(0.0, self.cooldown / self.cooldown_max))


# ============================================================================
# 하수인 시스템
# ============================================================================
class HenchmanSystem:
    """수동 클릭 발동 하수인 시스템 (is_top=True이면 AI 상단 하수인)"""

    def __init__(self, is_top=False):
        self.slots = []              # list[HenchmanSlot]
        self.skill_manager = None    # _MinimalSkillManager
        self.hero_paddle_renderer = None
        self.is_top = is_top         # True=상단(AI), False=하단(플레이어)
        self._font = None
        self._font_small = None
        self._icon_cache = {}        # 서피스 캐시
        self._ready_sound = None     # 쿨타임 완충 사운드
        self._ready_sound_loaded = False

    def _play_ready_sound(self):
        """쿨타임 완충 사운드 재생 (lazy load)"""
        if self.is_top:
            return  # AI 하수인은 사운드 없음
        if not self._ready_sound_loaded:
            self._ready_sound_loaded = True
            try:
                import sys
                base = getattr(sys, '_MEIPASS', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
                path = os.path.join(base, "sounds", "hasooincool.wav")
                if os.path.exists(path) and pygame and pygame.mixer.get_init():
                    self._ready_sound = pygame.mixer.Sound(path)
                    self._ready_sound.set_volume(0.5)
            except Exception:
                self._ready_sound = None
        if self._ready_sound:
            try:
                self._ready_sound.play()
            except Exception:
                pass

    def setup(self, henchman_list: list, skill_selections: dict = None,
              skill_manager=None, hero_paddle_renderer=None):
        """하수인 슬롯 초기화"""
        self.slots = []
        self.skill_manager = skill_manager or _MinimalSkillManager()
        self.hero_paddle_renderer = hero_paddle_renderer

        if not henchman_list:
            return

        for hero_data in henchman_list:
            hero_id = hero_data.get("id", "")
            # 스킬 인스턴스 생성
            skill = self._create_skill_instance(hero_id, skill_selections)
            if not skill:
                continue
            # game_state 연결
            skill.game_state = self.skill_manager.game_state
            # 쿨타임 계산
            cd = skill.cooldown * HENCHMAN_TOTAL_CD_MULT
            slot = HenchmanSlot(hero_data, skill, cooldown_max=cd)
            self.slots.append(slot)
            print(f"[Henchman] 하수인 등록: {hero_data.get('name', '?')} "
                  f"(스킬: {skill.korean_name}, 쿨타임: {cd:.1f}초)")

    def _create_skill_instance(self, hero_id: str, skill_selections: dict = None):
        """영웅 ID로 스킬 인스턴스 하나 생성"""
        try:
            from downtown.hero_skills import HERO_SKILL_CLASSES
            skill_classes = HERO_SKILL_CLASSES.get(hero_id, [])
            if not skill_classes:
                return None
            # skill_selections에서 배정된 스킬 인덱스 확인
            selected_idx = 0
            if skill_selections:
                selected_idx = skill_selections.get(hero_id, 0)
            if selected_idx < 0 or selected_idx >= len(skill_classes):
                selected_idx = 0
            return skill_classes[selected_idx]()
        except Exception as e:
            print(f"[Henchman] 스킬 생성 실패 ({hero_id}): {e}")
            return None

    # ========================================================================
    # 업데이트
    # ========================================================================
    def update(self, dt: float, boss_rect=None, player_rect=None,
               ball_rect=None, ball_vx=0, ball_vy=0) -> dict:
        """매 프레임 업데이트. boss_effects dict 반환."""
        if not self.slots:
            return {}

        # 프록시 생성
        top_paddle = _PaddleProxy(boss_rect, is_top=True) if boss_rect else \
            _PaddleProxy(pygame.Rect(380, 25, 120, 40), is_top=True)
        bottom_paddle = _PaddleProxy(player_rect, is_top=False) if player_rect else \
            _PaddleProxy(pygame.Rect(380, 710, 120, 40), is_top=False)
        ball = _BallProxy(ball_rect, ball_vx, ball_vy) if ball_rect else None

        for slot in self.slots:
            try:
                # 쿨타임 틱
                if slot.cooldown > 0:
                    slot._was_on_cooldown = True
                    slot.cooldown = max(0.0, slot.cooldown - dt)
                    # 쿨타임 완충 순간 감지 → 반짝임 + 사운드
                    if slot.cooldown <= 0 and slot._was_on_cooldown:
                        slot.ready_flash_timer = 1.5  # 1.5초간 반짝임
                        slot._was_on_cooldown = False
                        self._play_ready_sound()

                # 반짝임 타이머 틱
                if slot.ready_flash_timer > 0:
                    slot.ready_flash_timer = max(0.0, slot.ready_flash_timer - dt)

                # 페이즈 업데이트
                if slot.phase is None:
                    continue

                slot.anim_timer += dt

                if slot.phase == "entering":
                    self._update_entering(slot, dt, ball)
                elif slot.phase == "casting":
                    self._update_casting(slot, dt, top_paddle, bottom_paddle, ball)
                elif slot.phase == "exiting":
                    self._update_exiting(slot, dt)
            except Exception as e:
                # 개별 슬롯 예외 시 해당 슬롯만 강제 퇴장 처리
                print(f"[Henchman] 슬롯 업데이트 예외 ({slot.hero_name}): {e}")
                if slot.phase is not None:
                    skill = slot.skill_instance
                    if skill and skill.is_active:
                        skill.is_active = False
                    slot.phase = "exiting"
                    slot.anim_timer = 0.0

        # 스킬 이펙트 업데이트 (활성 스킬만 + 후처리 필요 스킬)
        game_state = self.skill_manager.game_state if self.skill_manager else {}
        # is_top=True(AI): target=bottom_paddle, is_top=False(플레이어): target=top_paddle
        skill_target_paddle = bottom_paddle if self.is_top else top_paddle
        for slot in self.slots:
            skill = slot.skill_instance
            if not skill:
                continue
            _oil_lingering = self._skill_has_lingering_effects(skill)
            if skill.is_active or _oil_lingering:
                try:
                    guard_paddle = _GuardPaddle(slot.x, slot.y, is_top=self.is_top)
                    skill.update(dt, guard_paddle, skill_target_paddle, ball, game_state)
                    # OilSpill: 발사체/웅덩이가 모두 소진되면 비활성화
                    if (getattr(skill, 'skill_id', '') == 'oil_spill'
                            and not skill.oil_projectiles
                            and not skill.oil_puddles):
                        skill.is_active = False
                except Exception:
                    # _update_active_effect 예외 시 active_timer는 이미 감소했지만
                    # is_active = False 처리가 누락될 수 있으므로 수동 체크
                    # duration=0 스킬은 active_timer 체크 스킵 (자체 관리)
                    if skill.active_timer <= 0 and skill.duration > 0:
                        skill.is_active = False
            else:
                # 비활성 스킬도 dying_clones 등 후처리가 필요한 경우 업데이트
                # (ShadowClone 등 소멸 애니메이션이 is_active=False 후에도 필요)
                if hasattr(skill, 'dying_clones') and skill.dying_clones:
                    try:
                        skill.update(dt, _GuardPaddle(slot.x, slot.y, is_top=self.is_top),
                                     skill_target_paddle, ball, game_state)
                    except Exception:
                        pass

        # 스킬 업데이트 후 casting 상태 재검증:
        # 채널링 스킬이 이 프레임에서 비활성화되었으면 즉시 exiting으로 전환
        # (일반 스킬은 _update_casting에서 이미 퇴장 처리됨)
        for slot in self.slots:
            if slot.phase == "casting":
                skill = slot.skill_instance
                skill_id = getattr(skill, 'skill_id', '') if skill else ''
                if skill_id in HENCH_CHANNELED_SKILLS:
                    skill_done = (not skill.is_active) if skill else True
                    if skill_done and slot.anim_timer >= HENCH_CAST_DURATION:
                        slot.phase = "exiting"
                        slot.anim_timer = 0.0

        # boss_effects 추출
        return self._extract_boss_effects(ball)

    def _update_entering(self, slot: HenchmanSlot, dt: float, ball=None):
        """화면 밖에서 게임 영역으로 진입"""
        progress = min(1.0, slot.anim_timer / HENCH_ENTER_DURATION)
        # 이즈 아웃
        t = 1.0 - (1.0 - progress) ** 2

        if slot.entry_side == "left":
            start_x = GAME_AREA_X - 60
        else:
            start_x = GAME_AREA_X + GAME_AREA_WIDTH + 60

        slot.x = start_x + (slot.target_x - start_x) * t

        if progress >= 1.0:
            slot.x = slot.target_x
            slot.phase = "casting"
            slot.anim_timer = 0.0
            try:
                self._activate_skill(slot, ball)
            except Exception as e:
                # 스킬 발동 실패해도 casting→exiting 흐름은 유지
                print(f"[Henchman] _activate_skill 예외: {e}")

    def _update_casting(self, slot: HenchmanSlot, dt: float,
                        top_paddle, bottom_paddle, ball):
        """시전 포즈 (스킬 실행 중)

        스킬 유형에 따라 두 가지 퇴장 전략:
        - 채널링 스킬 (HENCH_CHANNELED_SKILLS): 스킬 효과가 끝날 때까지 대기 후 퇴장
        - 일반 스킬: 시전 포즈(0.8초) 완료 즉시 퇴장, 스킬 이펙트는 독립적으로 지속
        """
        skill = slot.skill_instance
        skill_id = getattr(skill, 'skill_id', '') if skill else ''
        is_channeled = skill_id in HENCH_CHANNELED_SKILLS

        if is_channeled:
            # === 채널링 스킬: 스킬 효과 종료까지 대기 ===
            skill_done = (not skill.is_active) if skill else True

            # active_timer 만료 시 즉시 종료 처리
            if not skill_done and skill:
                timer = getattr(skill, 'active_timer', None)
                if timer is not None and timer <= 0 and skill.duration > 0:
                    try:
                        gs = self.skill_manager.game_state if self.skill_manager else {}
                        skill._end_effect(None, None, None, gs)
                    except Exception:
                        pass
                    skill.is_active = False
                    if hasattr(skill, 'possessed_skill') and skill.possessed_skill:
                        skill.possessed_skill.is_active = False
                    skill_done = True

            # 채널링 안전 타임아웃
            if not skill_done:
                max_stay = HENCH_CAST_DURATION + skill.duration + 1.0
                max_stay = min(max_stay, HENCH_CHANNEL_MAX_STAY)
                if slot.anim_timer >= max_stay:
                    if skill:
                        try:
                            gs = self.skill_manager.game_state if self.skill_manager else {}
                            skill._end_effect(None, None, None, gs)
                        except Exception:
                            pass
                        skill.is_active = False
                        if hasattr(skill, 'possessed_skill') and skill.possessed_skill:
                            skill.possessed_skill.is_active = False
                    skill_done = True
        else:
            # === 일반 스킬: 시전 포즈 후 즉시 퇴장 ===
            # 스킬 이펙트(발사체, 소환물, 장벽 등)는 is_active 기반으로 독립 지속
            skill_done = True

        if slot.anim_timer >= HENCH_CAST_DURATION and skill_done:
            slot.phase = "exiting"
            slot.anim_timer = 0.0

    def _update_exiting(self, slot: HenchmanSlot, dt: float):
        """게임 영역에서 퇴장"""
        progress = min(1.0, slot.anim_timer / HENCH_EXIT_DURATION)
        t = progress ** 2  # 이즈 인

        if slot.entry_side == "left":
            end_x = GAME_AREA_X - 60
        else:
            end_x = GAME_AREA_X + GAME_AREA_WIDTH + 60

        slot.x = slot.target_x + (end_x - slot.target_x) * t

        if progress >= 1.0:
            slot.phase = None
            slot.anim_timer = 0.0
            # 쿨타임 시작
            slot.cooldown = slot.cooldown_max
            # 개틀링 버스트 변신 상태 초기화 (잔류 방지)
            if self.hero_paddle_renderer and slot.hero_id == "android":
                state = self.hero_paddle_renderer._get_state(slot.hero_id)
                state['gatling_firing'] = False
                state['gatling_recoil'] = 0
                state['gatling_mounting'] = False
                state['gatling_mount_progress'] = 0.0
                state['gatling_dismounting'] = False
                state['gatling_dismount_progress'] = 0.0
                state['gatling_aim_angle'] = None

    def _activate_skill(self, slot: HenchmanSlot, ball=None):
        """하수인 스킬 발동"""
        skill = slot.skill_instance
        if not skill:
            return

        game_state = self.skill_manager.game_state if self.skill_manager else {}
        guard_paddle = _GuardPaddle(slot.x, slot.y, is_top=self.is_top)
        # is_top=True: AI 상단 하수인 → 타겟=하단 플레이어
        # is_top=False: 플레이어 하단 하수인 → 타겟=상단 보스
        if self.is_top:
            target_paddle = _PaddleProxy(pygame.Rect(380, 710, 120, 40), is_top=False)
        else:
            target_paddle = _PaddleProxy(pygame.Rect(380, 25, 120, 40), is_top=True)

        skill.caster_is_top = self.is_top
        skill.current_cooldown = 0

        # 이전 효과 종료
        if skill.is_active:
            try:
                skill._end_effect(guard_paddle, target_paddle, ball, game_state)
            except Exception:
                pass
            skill.is_active = False

        # 상태 갱신
        try:
            skill.update(0.016, guard_paddle, target_paddle, ball, game_state)
        except Exception:
            pass

        # caster 보호 (is_top=True이면 상단 AI, False이면 하단 플레이어)
        # demon_step(귀신발걸음)은 hero 패들에 직접 효과를 주므로 보호 스킵
        skill_id = getattr(skill, 'skill_id', '')
        skip_caster_protect = (skill_id == 'demon_step')

        saved = {}
        if not skip_caster_protect:
            caster_prefix = 'top_paddle' if self.is_top else 'bottom_paddle'
            for key in list(game_state.keys()):
                if key.startswith(caster_prefix):
                    saved[key] = game_state[key]

        result = skill.use(guard_paddle, target_paddle, ball, game_state)

        if not skip_caster_protect:
            for key, val in saved.items():
                game_state[key] = val

        # 글로벌 game_state 키 차단
        if skill_id == 'horn_charge':
            game_state['horn_charge_active'] = False
        elif skill_id == 'steam_barrier':
            game_state['steam_barrier_caster_frozen'] = False
            game_state['steam_barrier_thaw_speed'] = 0.0

        # duration=0 스킬 수동 활성화
        if result and not skill.is_active and skill.duration <= 0:
            skill.is_active = True

        if result:
            self._play_skill_sound(result)
            self._apply_status_effects(result, target_paddle, game_state)
            print(f"[Henchman] {slot.hero_name} → {skill.korean_name} 발동 성공!")
        else:
            print(f"[Henchman] {slot.hero_name} → {skill.korean_name} 발동 실패")

    @staticmethod
    def _skill_has_lingering_effects(skill) -> bool:
        """스킬에 아직 진행 중인 잔여 이펙트가 있는지 확인 (OilSpill 발사체/웅덩이 등)"""
        if not skill:
            return False
        skill_id = getattr(skill, 'skill_id', '')
        if skill_id == 'oil_spill':
            return bool(getattr(skill, 'oil_projectiles', [])
                        or getattr(skill, 'oil_puddles', []))
        return False

    _skill_sound_cache = {}

    def _play_skill_sound(self, result):
        """스킬 사운드 재생 (프로젝트 루트 sounds/ 폴더에서 직접 로드)"""
        if not result:
            return
        sound_key = result.get('sound') if isinstance(result, dict) else None
        if not sound_key:
            return

        if sound_key not in HenchmanSystem._skill_sound_cache:
            try:
                project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                filepath = os.path.join(project_root, "sounds", f"{sound_key}.wav")
                if os.path.exists(filepath):
                    HenchmanSystem._skill_sound_cache[sound_key] = pygame.mixer.Sound(filepath)
                else:
                    HenchmanSystem._skill_sound_cache[sound_key] = None
            except Exception:
                HenchmanSystem._skill_sound_cache[sound_key] = None

        sound = HenchmanSystem._skill_sound_cache.get(sound_key)
        if sound:
            try:
                sound.play()
            except Exception:
                pass

    def _apply_status_effects(self, result, target_paddle, game_state):
        """상태 효과 적용 (is_top 기반으로 올바른 타겟에 적용)

        스킬 결과에서 두 가지 형식을 모두 처리:
        1) target_status: StatusEffect enum (hero_skills 표준 반환값)
        2) status_effects: [{'type': 'stun', ...}] (레거시 형식)
        """
        if not isinstance(result, dict):
            return

        # 타겟 프리픽스 결정 (opponent = 상대방)
        # is_top=True(AI 상단): opponent=bottom_paddle, self=top_paddle
        # is_top=False(플레이어 하단): opponent=top_paddle, self=bottom_paddle
        target_prefix = 'bottom_paddle' if self.is_top else 'top_paddle'

        # === 1) target_status 처리 (hero_skills 표준 형식) ===
        target_status = result.get('target_status')
        if target_status:
            try:
                from downtown.hero_skills import StatusEffect
                if target_status == StatusEffect.STUN:
                    game_state[f'{target_prefix}_stunned'] = True
                elif target_status == StatusEffect.SLOW:
                    game_state[f'{target_prefix}_slowed'] = True
                    game_state[f'{target_prefix}_slow_amount'] = result.get('slow_amount', 0.5)
                elif target_status == StatusEffect.CONFUSION:
                    game_state[f'{target_prefix}_confused'] = True
                elif target_status == StatusEffect.SHRINK:
                    game_state[f'{target_prefix}_shrink'] = True
                    game_state[f'{target_prefix}_shrink_scale'] = result.get('shrink_amount', 0.5)
                elif target_status == StatusEffect.BLIND:
                    game_state['blind_target_is_top'] = not self.is_top
                elif target_status == StatusEffect.PUPPET:
                    game_state[f'{target_prefix}_locked'] = True
            except ImportError:
                pass

        # === 2) status_effects 처리 (레거시 형식) ===
        effects = result.get('status_effects', [])
        if isinstance(effects, dict):
            effects = [effects]
        for effect in effects:
            if not isinstance(effect, dict):
                continue
            etype = effect.get('type', '')
            target = effect.get('target', 'opponent')
            if target == 'opponent':
                prefix = 'bottom_paddle' if self.is_top else 'top_paddle'
            else:
                prefix = 'top_paddle' if self.is_top else 'bottom_paddle'
            if etype == 'stun':
                game_state[f'{prefix}_stunned'] = True
            elif etype == 'slow':
                game_state[f'{prefix}_slowed'] = True
                game_state[f'{prefix}_slow_amount'] = effect.get('amount', 0.5)
            elif etype == 'confuse':
                game_state[f'{prefix}_confused'] = True
            elif etype == 'shrink':
                game_state[f'{prefix}_shrink'] = True
                game_state[f'{prefix}_shrink_scale'] = effect.get('scale', 0.5)

    def _extract_boss_effects(self, ball) -> dict:
        """game_state에서 보스 효과 추출.

        주의: stun/slow/confuse/shrink 등 상태 효과는 스킬이 직접
        arena_skill_manager.game_state에 설정/해제하므로 여기서 pop하지 않는다.
        보스 AI가 game_state를 직접 읽어 처리한다.
        여기서는 넉백, 프리즈, 공 속도 변경, 화면 흔들림 등만 추출한다.
        """
        gs = self.skill_manager.game_state if self.skill_manager else {}
        boss_effects = {}

        # 넉백: game_state에 남겨두고 pingfighter.py의 직접 체크에서 처리
        # (여기서 consume하면 pingfighter.py에서 읽기 전에 사라짐)
        # 프리즈 (일회성 트리거)
        if gs.get('dark_slash_freeze', False):
            boss_effects['freeze'] = True
        if gs.get('hell_fire_freeze', False):
            boss_effects['freeze'] = True
        # 공 속도 변경
        if ball and ball.vel_changed:
            boss_effects['ball_vx'] = ball.vx
            boss_effects['ball_vy'] = ball.vy

        # 화면 흔들림
        for fx in (self.skill_manager.screen_effects if self.skill_manager else []):
            boss_effects['screen_shake'] = True
            boss_effects['shake_intensity'] = fx.get('intensity', 15)
        if self.skill_manager:
            self.skill_manager.screen_effects.clear()

        return boss_effects

    # ========================================================================
    # 자동 발동 (auto-trigger)
    # ========================================================================
    def auto_trigger(self):
        """쿨타임이 완료된 하수인을 자동으로 발동.

        매 프레임 호출하면, 준비된 하수인이 있으면 하나씩 순서대로 자동 발동한다.
        동시에 여러 하수인이 발동 중이면 겹치지 않도록 한 명만 발동.
        """
        if not self.slots:
            return
        # 이미 발동 중인(애니메이션 진행 중인) 하수인이 있으면 대기
        any_active = any(s.phase is not None for s in self.slots)
        if any_active:
            return
        # 준비된 하수인 중 첫 번째를 발동
        for i, slot in enumerate(self.slots):
            if slot.is_ready:
                self._trigger_henchman(i)
                return

    # ========================================================================
    # 클릭 핸들링
    # ========================================================================
    def handle_click(self, mouse_pos) -> bool:
        """마우스 클릭으로 하수인 발동. 발동 성공 시 True."""
        if not mouse_pos or not self.slots:
            return False

        for i, slot in enumerate(self.slots):
            if slot.icon_rect.collidepoint(mouse_pos) and slot.is_ready:
                self._trigger_henchman(i)
                return True
        return False

    def trigger_by_index(self, index: int) -> bool:
        """단축키(1/2/3)로 하수인 발동. 성공 시 True."""
        if index < 0 or index >= len(self.slots):
            return False
        if self.slots[index].is_ready:
            self._trigger_henchman(index)
            return True
        return False

    def _trigger_henchman(self, index: int):
        """하수인 발동 시작 (진입 애니메이션)"""
        slot = self.slots[index]
        if not slot.is_ready:
            return

        # 진입 방향 랜덤
        slot.entry_side = random.choice(["left", "right"])
        if slot.entry_side == "left":
            slot.x = GAME_AREA_X - 60
        else:
            slot.x = GAME_AREA_X + GAME_AREA_WIDTH + 60
        # 타겟 X: 게임 영역 내 랜덤 위치
        slot.target_x = random.uniform(GAME_AREA_X + 80, GAME_AREA_X + GAME_AREA_WIDTH - 80)
        slot.y = HENCH_TOP_Y if self.is_top else HENCH_Y  # 상단 AI: 호위무사 높이, 하단: 플레이어 영역
        slot.phase = "entering"
        slot.anim_timer = 0.0
        print(f"[Henchman] {slot.hero_name} 발동! (진입: {slot.entry_side})")

    # ========================================================================
    # 렌더링 - 게임 내 캐릭터
    # ========================================================================
    def draw(self, screen, boss_rect=None, player_rect=None, ball_rect=None):
        """하수인 캐릭터 + 스킬 이펙트 렌더링"""
        if not self.slots:
            return

        top_paddle = _PaddleProxy(boss_rect, is_top=True) if boss_rect else None
        bottom_paddle = _PaddleProxy(player_rect, is_top=False) if player_rect else None
        ball = _BallProxy(ball_rect) if ball_rect else None

        if top_paddle is None:
            top_paddle = _PaddleProxy(pygame.Rect(380, 25, 120, 40), is_top=True)
        if bottom_paddle is None:
            bottom_paddle = _PaddleProxy(pygame.Rect(380, 710, 120, 40), is_top=False)

        game_state = self.skill_manager.game_state if self.skill_manager else {}
        # is_top=True(AI): target=bottom_paddle, is_top=False(플레이어): target=top_paddle
        draw_target_paddle = bottom_paddle if self.is_top else top_paddle

        for slot in self.slots:
            skill = slot.skill_instance
            # 스킬 이펙트 그리기 (활성 상태 또는 소멸 애니메이션/잔여 이펙트)
            if skill:
                has_dying = hasattr(skill, 'dying_clones') and skill.dying_clones
                _oil_lingering = self._skill_has_lingering_effects(skill)
                if skill.is_active or has_dying or _oil_lingering:
                    try:
                        guard_paddle = _GuardPaddle(slot.x, slot.y, is_top=self.is_top)
                        skill.draw(screen, guard_paddle, draw_target_paddle, ball, game_state)
                    except Exception:
                        pass

            # 캐릭터 그리기 (페이즈 활성 시)
            if slot.phase is not None:
                self._draw_henchman_character(screen, slot)

    def _draw_henchman_character(self, screen, slot: HenchmanSlot):
        """단일 하수인 캐릭터 렌더링"""
        ix, iy = int(slot.x), int(slot.y)
        color = slot.hero_color

        # 개틀링 버스트 변신 상태 동기화 (hero_paddles 렌더러 연동)
        if self.hero_paddle_renderer and slot.hero_id == "android":
            game_state = self.skill_manager.game_state if self.skill_manager else {}
            side = 'top' if self.is_top else 'bottom'
            state = self.hero_paddle_renderer._get_state(slot.hero_id)
            state['gatling_firing'] = game_state.get(f'gatling_burst_active_{side}', False)
            state['gatling_recoil'] = game_state.get(f'gatling_recoil_{side}', 0)
            state['gatling_mounting'] = game_state.get(f'gatling_mounting_{side}', False)
            state['gatling_mount_progress'] = game_state.get(f'gatling_mount_progress_{side}', 0.0)
            state['gatling_dismounting'] = game_state.get(f'gatling_dismounting_{side}', False)
            state['gatling_dismount_progress'] = game_state.get(f'gatling_dismount_progress_{side}', 0.0)
            state['gatling_aim_angle'] = game_state.get(f'gatling_aim_angle_{side}', None)

        # 글로우 효과
        glow_r = 30
        glow_size = glow_r * 2
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        glow_alpha = 100 if slot.phase == "casting" else 50
        pygame.draw.circle(glow_surf, (*color, glow_alpha), (glow_r, glow_r), glow_r)
        screen.blit(glow_surf, (ix - glow_r, iy - glow_r))

        # 캐릭터 그리기
        if self.hero_paddle_renderer:
            try:
                self.hero_paddle_renderer.draw_hero_paddle(
                    screen,
                    slot.hero_id,
                    ix, iy,
                    110, PADDLE_HEIGHT,
                    facing="up",
                    color=color,
                    scale_mode="paddle"
                )
            except Exception:
                pygame.draw.circle(screen, color, (ix, iy), 15)
        else:
            pygame.draw.circle(screen, color, (ix, iy), 15)
            pygame.draw.circle(screen, (255, 255, 255), (ix, iy), 15, 2)

    # ========================================================================
    # 렌더링 - 필러 아이콘
    # ========================================================================
    def draw_pillar_icons(self, screen, game_offset_x=0, game_offset_y=0,
                          game_scale=1.0, mouse_pos=None,
                          bodyguard_icon_top_y=None) -> dict:
        """왼쪽 필러에 하수인 아이콘 렌더링 (호위무사 위에 위로 쌓기). hover_info 반환."""
        if not self.slots:
            return None

        _s = game_scale
        icon_sz = max(24, int(HENCH_ICON_SIZE * _s))
        gap = max(4, int(6 * _s))

        # 하수인 아이콘은 호위무사 아이콘 바로 위에 위로 쌓기
        n = len(self.slots)
        total_height = n * icon_sz + (n - 1) * gap
        if bodyguard_icon_top_y is not None:
            # 호위무사 아이콘 상단에서 gap만큼 위부터 시작 (위로 쌓기)
            start_y = int(bodyguard_icon_top_y) - max(4, int(8 * _s)) - total_height
        else:
            # 폴백: 게임 영역 하단 80% 위치
            game_h = int(SCREEN_HEIGHT * _s)
            start_y = game_offset_y + int(game_h * 0.80) - total_height

        # X: 왼쪽 필러 중앙
        frame_x = game_offset_x - icon_sz - int(8 * _s)
        if frame_x < 2:
            frame_x = 2

        hover_info = None

        for i, slot in enumerate(self.slots):
            iy = start_y + i * (icon_sz + gap)

            # 화면 밖이면 스킵
            if iy < 0 or iy + icon_sz > screen.get_height():
                break

            slot.icon_rect = pygame.Rect(frame_x, iy, icon_sz, icon_sz)

            # 배경
            bg_color = (35, 30, 25)
            if slot.is_ready:
                bg_color = (50, 45, 35)
            pygame.draw.rect(screen, bg_color, slot.icon_rect, border_radius=4)

            # 캐릭터 아이콘 (hero paddle renderer)
            inner_margin = 3
            inner_sz = icon_sz - inner_margin * 2
            if self.hero_paddle_renderer and inner_sz > 10:
                try:
                    self.hero_paddle_renderer.draw_hero_paddle(
                        screen,
                        slot.hero_id,
                        frame_x + icon_sz // 2,
                        iy + icon_sz // 2,
                        inner_sz, inner_sz,
                        facing="up",
                        color=slot.hero_color,
                        scale_mode="icon"
                    )
                except Exception:
                    pygame.draw.circle(screen, slot.hero_color,
                                       (frame_x + icon_sz // 2, iy + icon_sz // 2),
                                       inner_sz // 3)
            else:
                pygame.draw.circle(screen, slot.hero_color,
                                   (frame_x + icon_sz // 2, iy + icon_sz // 2),
                                   inner_sz // 3)

            # 쿨타임 오버레이
            if slot.is_on_cooldown:
                ratio = slot.cooldown_ratio
                overlay_h = int(icon_sz * ratio)
                if overlay_h > 0:
                    ov_surf = pygame.Surface((icon_sz, overlay_h), pygame.SRCALPHA)
                    ov_surf.fill((255, 255, 255, 160))
                    screen.blit(ov_surf, (frame_x, iy + icon_sz - overlay_h))

                # 쿨타임 숫자
                cd_text = f"{int(slot.cooldown) + 1}"
                font = self._get_font(max(10, int(12 * _s)))
                if font:
                    ts, _ = font.render(cd_text, (40, 40, 40))
                    screen.blit(ts, (frame_x + icon_sz // 2 - ts.get_width() // 2,
                                     iy + icon_sz // 2 - ts.get_height() // 2))

            # 테두리
            if slot.is_ready:
                # 준비 완료: 밝은 골드 테두리 + 펄스
                pulse = 0.6 + 0.4 * abs(math.sin(pygame.time.get_ticks() * 0.003))
                border_alpha = int(200 * pulse)
                border_surf = pygame.Surface((icon_sz + 4, icon_sz + 4), pygame.SRCALPHA)
                pygame.draw.rect(border_surf, (210, 180, 100, border_alpha),
                                 (0, 0, icon_sz + 4, icon_sz + 4), 2, border_radius=5)
                screen.blit(border_surf, (frame_x - 2, iy - 2))

                # 쿨타임 완충 직후 반짝임 이펙트
                if slot.ready_flash_timer > 0:
                    t = pygame.time.get_ticks()
                    fade = min(1.0, slot.ready_flash_timer / 0.5)  # 마지막 0.5초 페이드아웃

                    # 1) 전체 백색 플래시 오버레이 (빠른 점멸)
                    blink = abs(math.sin(t * 0.012))  # 빠른 깜빡임
                    flash_alpha = int(120 * blink * fade)
                    if flash_alpha > 0:
                        flash_surf = pygame.Surface((icon_sz, icon_sz), pygame.SRCALPHA)
                        flash_surf.fill((255, 255, 220, flash_alpha))
                        screen.blit(flash_surf, (frame_x, iy))

                    # 2) 모서리 반짝이 파티클 (4개 코너 순환)
                    cx, cy = frame_x + icon_sz // 2, iy + icon_sz // 2
                    half = icon_sz // 2 + 2
                    for ci in range(4):
                        angle = (t * 0.006) + ci * (math.pi / 2)
                        sx = cx + int(half * math.cos(angle))
                        sy = cy + int(half * math.sin(angle))
                        sparkle_r = max(1, int(3 * _s * fade * (0.5 + 0.5 * abs(math.sin(t * 0.01 + ci)))))
                        sparkle_alpha = int(220 * fade)
                        sp_surf = pygame.Surface((sparkle_r * 2 + 2, sparkle_r * 2 + 2), pygame.SRCALPHA)
                        pygame.draw.circle(sp_surf, (255, 255, 180, sparkle_alpha),
                                           (sparkle_r + 1, sparkle_r + 1), sparkle_r)
                        screen.blit(sp_surf, (sx - sparkle_r - 1, sy - sparkle_r - 1))
            elif slot.phase is not None:
                # 발동 중: 밝은 하이라이트
                pygame.draw.rect(screen, (255, 220, 120),
                                 (frame_x - 1, iy - 1, icon_sz + 2, icon_sz + 2),
                                 2, border_radius=5)
            else:
                # 쿨타임 중: 어두운 테두리
                pygame.draw.rect(screen, (80, 70, 60),
                                 slot.icon_rect, 1, border_radius=4)

            # "하" 라벨 (하수인 구분용)
            label_font = self._get_font(max(8, int(9 * _s)))
            if label_font:
                ls, _ = label_font.render("하", (160, 140, 100))
                screen.blit(ls, (frame_x + 2, iy + 1))

            # 호버 감지
            if mouse_pos and slot.icon_rect.collidepoint(mouse_pos):
                # 호버 테두리
                pygame.draw.rect(screen, (255, 220, 140),
                                 (frame_x - 2, iy - 2, icon_sz + 4, icon_sz + 4),
                                 2, border_radius=5)
                hover_info = {
                    "type": "henchman",
                    "name": slot.hero_name,
                    "color": slot.hero_color,
                    "cooldown": slot.cooldown,
                    "cooldown_max": slot.cooldown_max,
                    "is_ready": slot.is_ready,
                    "phase": slot.phase,
                    "skill": slot.skill_instance,
                    "screen_x": frame_x,
                    "screen_y": iy,
                    "side": "bottom",
                }

        return hover_info

    def draw_pillar_icons_top(self, screen, game_offset_x=0, game_offset_y=0,
                               game_scale=1.0, mouse_pos=None) -> dict:
        """왼쪽 필러 상단에 AI 하수인 아이콘 렌더링 (위에서 아래로 쌓기). hover_info 반환."""
        if not self.slots:
            return None

        _s = game_scale
        icon_sz = max(24, int(HENCH_ICON_SIZE * _s))
        gap = max(4, int(6 * _s))

        # Y 시작: 게임 영역 상단 + 약간의 여백
        start_y = game_offset_y + int(10 * _s)

        # X: 왼쪽 필러 중앙 (하단 하수인과 동일한 X)
        frame_x = game_offset_x - icon_sz - int(8 * _s)
        if frame_x < 2:
            frame_x = 2

        hover_info = None

        for i, slot in enumerate(self.slots):
            iy = start_y + i * (icon_sz + gap)

            if iy < 0 or iy + icon_sz > screen.get_height():
                break

            slot.icon_rect = pygame.Rect(frame_x, iy, icon_sz, icon_sz)

            # 배경
            bg_color = (35, 30, 25)
            if slot.is_ready:
                bg_color = (50, 45, 35)
            pygame.draw.rect(screen, bg_color, slot.icon_rect, border_radius=4)

            # 캐릭터 아이콘
            inner_margin = 3
            inner_sz = icon_sz - inner_margin * 2
            if self.hero_paddle_renderer and inner_sz > 10:
                try:
                    self.hero_paddle_renderer.draw_hero_paddle(
                        screen,
                        slot.hero_id,
                        frame_x + icon_sz // 2,
                        iy + icon_sz // 2,
                        inner_sz, inner_sz,
                        facing="down",
                        color=slot.hero_color,
                        scale_mode="icon"
                    )
                except Exception:
                    pygame.draw.circle(screen, slot.hero_color,
                                       (frame_x + icon_sz // 2, iy + icon_sz // 2),
                                       inner_sz // 3)
            else:
                pygame.draw.circle(screen, slot.hero_color,
                                   (frame_x + icon_sz // 2, iy + icon_sz // 2),
                                   inner_sz // 3)

            # 쿨타임 오버레이
            if slot.is_on_cooldown:
                ratio = slot.cooldown_ratio
                overlay_h = int(icon_sz * ratio)
                if overlay_h > 0:
                    ov_surf = pygame.Surface((icon_sz, overlay_h), pygame.SRCALPHA)
                    ov_surf.fill((255, 255, 255, 160))
                    screen.blit(ov_surf, (frame_x, iy + icon_sz - overlay_h))

                # 쿨타임 숫자
                cd_text = f"{int(slot.cooldown) + 1}"
                font = self._get_font(max(10, int(12 * _s)))
                if font:
                    ts, _ = font.render(cd_text, (40, 40, 40))
                    screen.blit(ts, (frame_x + icon_sz // 2 - ts.get_width() // 2,
                                     iy + icon_sz // 2 - ts.get_height() // 2))

            # 테두리
            if slot.is_ready:
                pulse = 0.6 + 0.4 * abs(math.sin(pygame.time.get_ticks() * 0.003))
                border_alpha = int(200 * pulse)
                border_surf = pygame.Surface((icon_sz + 4, icon_sz + 4), pygame.SRCALPHA)
                pygame.draw.rect(border_surf, (210, 180, 100, border_alpha),
                                 (0, 0, icon_sz + 4, icon_sz + 4), 2, border_radius=5)
                screen.blit(border_surf, (frame_x - 2, iy - 2))

                # 쿨타임 완충 직후 반짝임 이펙트
                if slot.ready_flash_timer > 0:
                    t = pygame.time.get_ticks()
                    fade = min(1.0, slot.ready_flash_timer / 0.5)
                    blink = abs(math.sin(t * 0.012))
                    flash_alpha = int(120 * blink * fade)
                    if flash_alpha > 0:
                        flash_surf = pygame.Surface((icon_sz, icon_sz), pygame.SRCALPHA)
                        flash_surf.fill((255, 255, 220, flash_alpha))
                        screen.blit(flash_surf, (frame_x, iy))
                    cx, cy = frame_x + icon_sz // 2, iy + icon_sz // 2
                    half = icon_sz // 2 + 2
                    for ci in range(4):
                        angle = (t * 0.006) + ci * (math.pi / 2)
                        sx = cx + int(half * math.cos(angle))
                        sy = cy + int(half * math.sin(angle))
                        sparkle_r = max(1, int(3 * _s * fade * (0.5 + 0.5 * abs(math.sin(t * 0.01 + ci)))))
                        sparkle_alpha = int(220 * fade)
                        sp_surf = pygame.Surface((sparkle_r * 2 + 2, sparkle_r * 2 + 2), pygame.SRCALPHA)
                        pygame.draw.circle(sp_surf, (255, 255, 180, sparkle_alpha),
                                           (sparkle_r + 1, sparkle_r + 1), sparkle_r)
                        screen.blit(sp_surf, (sx - sparkle_r - 1, sy - sparkle_r - 1))

            elif slot.phase is not None:
                pygame.draw.rect(screen, (255, 220, 120),
                                 (frame_x - 1, iy - 1, icon_sz + 2, icon_sz + 2),
                                 2, border_radius=5)
            else:
                pygame.draw.rect(screen, (80, 70, 60),
                                 slot.icon_rect, 1, border_radius=4)

            # "하" 라벨 (하수인 구분용)
            label_font = self._get_font(max(8, int(9 * _s)))
            if label_font:
                ls, _ = label_font.render("하", (160, 140, 100))
                screen.blit(ls, (frame_x + 2, iy + 1))

            # 호버 감지
            if mouse_pos and slot.icon_rect.collidepoint(mouse_pos):
                pygame.draw.rect(screen, (255, 220, 140),
                                 (frame_x - 2, iy - 2, icon_sz + 4, icon_sz + 4),
                                 2, border_radius=5)
                hover_info = {
                    "type": "henchman",
                    "name": slot.hero_name,
                    "color": slot.hero_color,
                    "cooldown": slot.cooldown,
                    "cooldown_max": slot.cooldown_max,
                    "is_ready": slot.is_ready,
                    "phase": slot.phase,
                    "skill": slot.skill_instance,
                    "screen_x": frame_x,
                    "screen_y": iy,
                    "side": "top",
                }

        return hover_info

    def _get_font(self, size=12):
        """한글 폰트 반환 (캐싱)"""
        cache_key = size
        if cache_key in self._icon_cache:
            return self._icon_cache[cache_key]
        try:
            font_paths = [
                os.path.join("fonts", "Pretendard-Bold.ttf"),
                os.path.join("fonts", "NanumSquareB.ttf"),
            ]
            for fp in font_paths:
                full_path = fp
                try:
                    import sys
                    base = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
                    # game_mechanics 폴더에서 한 단계 위로
                    base = os.path.dirname(base)
                    full_path = os.path.join(base, fp)
                except Exception:
                    pass
                if os.path.exists(full_path):
                    font = pygame.freetype.Font(full_path, size)
                    self._icon_cache[cache_key] = font
                    return font
        except Exception:
            pass
        self._icon_cache[cache_key] = None
        return None

    # ========================================================================
    # 리셋
    # ========================================================================
    def reset(self):
        """모든 하수인 상태 초기화"""
        # 활성 스킬 종료
        gs = self.skill_manager.game_state if self.skill_manager else {}
        for slot in self.slots:
            skill = slot.skill_instance
            if skill and skill.is_active:
                try:
                    skill._end_effect(None, None, None, gs)
                except Exception:
                    pass
                skill.is_active = False
        self.slots = []
        self._icon_cache = {}

    def reset_active_skills(self):
        """득점 시 활성 스킬 리셋"""
        gs = self.skill_manager.game_state if self.skill_manager else {}
        for slot in self.slots:
            skill = slot.skill_instance
            if skill and skill.is_active:
                try:
                    if hasattr(skill, 'reset_for_new_round'):
                        skill.reset_for_new_round(gs)
                    else:
                        skill._end_effect(None, None, None, gs)
                        skill.is_active = False
                except Exception:
                    skill.is_active = False
            # 진행 중인 애니메이션도 리셋
            if slot.phase is not None:
                slot.phase = None
                slot.anim_timer = 0.0
                # 스킬 사용 중이었으면 쿨타임 부여 (다음 라운드 즉시 재사용 방지)
                slot.cooldown = slot.cooldown_max


# ============================================================================
# 싱글턴
# ============================================================================
_henchman_instance = None


def get_henchman_system() -> HenchmanSystem:
    global _henchman_instance
    if _henchman_instance is None:
        _henchman_instance = HenchmanSystem()
    return _henchman_instance
