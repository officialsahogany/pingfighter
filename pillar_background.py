# -*- coding: utf-8 -*-
"""
���러(Pillar) 배경 렌더러
전체화면 모드에서 게임 영역 외의 좌우 공간을 채우는 배경 시스템
"""

import os
import sys
import math
import platform
import pygame

# 스테이지별 특수 배경
from pillar_stadium import StadiumPillarBackground, init_stadium_background, get_stadium_background
from pillar_jungle import MossyStoneFrame as JungleSwampBackground, init_jungle_background, get_jungle_background, get_monkey_event_manager
from pillar_menhera import MenheraPlushFrame, init_menhera_background, get_menhera_background
from pillar_blazing_sun import BlazingSunFrame  # 불타는 태양 효과
from pillar_temple import TemplePillarBackground  # 사원 배경 (스테이지 4)
from pillar_nemesis_ocean import NemesisOceanFrame  # 네메시스 해상전투 배경 (스테이지 5)
from pillar_hongryeon import HongryeonFrame  # 홍련 중국 전통 배경 (스테이지 6)
from pillar_baroque import BaroqueFrame  # 바로크 액자 (메인 메뉴용, 스테이지 0)
from pillar_tetriser import TetriserPillarBackground  # 테트리서 테트리스 배경 (스테이지 7)
from pillar_ninja import NinjaPillarBackground  # 닌자 저택 배경 (스테이지 8)
from pillar_colosseum import ColosseumFrame  # 투기장 배경 (스테이지 30)

# 플랫폼 감지
_is_macos = platform.system() == 'Darwin'

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


class PillarBackgroundRenderer:
    """전체화면 모드에서 필러 영역 배경을 렌더링하는 클래스"""

    # 배경 타입 상수
    TYPE_ARTWORK = "artwork"
    TYPE_DYNAMIC = "dynamic"
    TYPE_SOLID = "solid"

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int,
                 offset_x: int = None, offset_y: int = None,
                 original_game_width: int = None, original_game_height: int = None):
        """
        Args:
            screen_width: 전체화면 너비
            screen_height: 전체화면 높이
            game_width: 게임 영역 너비 (스케일링된 크기)
            game_height: 게임 영역 높이 (스케일링된 크기)
            offset_x: 게임 영역 X 오프셋 (None이면 자동 계산)
            offset_y: 게임 영역 Y 오프셋 (None이면 자동 계산)
            original_game_width: 원본 게임 너비 (스케일링 전)
            original_game_height: 원본 게임 높이 (스케일링 전)
        """
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 원본 게임 크기 (스케일링 전) - 인게임 좌표 변환에 사용
        self.original_game_width = original_game_width if original_game_width else game_width
        self.original_game_height = original_game_height if original_game_height else game_height

        # 게임 영역 오프셋 (전달되면 사용, 없으면 중앙 배치로 계산)
        self.game_offset_x = offset_x if offset_x is not None else (screen_width - game_width) // 2
        self.game_offset_y = offset_y if offset_y is not None else (screen_height - game_height) // 2

        # 필러 영역 크기
        self.left_pillar_width = self.game_offset_x
        self.right_pillar_width = screen_width - game_width - self.game_offset_x
        self.top_pillar_height = self.game_offset_y
        self.bottom_pillar_height = screen_height - game_height - self.game_offset_y

        # 캐시된 서피스
        self._artwork_surface = None
        self._left_pillar_surface = None
        self._right_pillar_surface = None
        self._top_pillar_surface = None
        self._bottom_pillar_surface = None

        # 현재 배경 타입
        self.current_type = self.TYPE_ARTWORK

        # 배경색 (단색 모드용)
        self.bg_color = (15, 15, 25)

        # 현재 스테이지 (동적 배경용)
        self.current_stage = 0

        # 애니메이션 상태
        self.animation_time = 0.0

        # 쿨타임 완료 반짝임 효과 추적 {slot_index: complete_time_ms}
        self._cooldown_complete_flash = {}

        # 스테이지별 특수 배경 (스타디움 등)
        self._baroque_bg = None  # 바로크 액자 (메인 메뉴, 스테이지 0)
        self._stadium_bg = None
        self._jungle_bg = None
        self._menhera_bg = None
        self._blazing_sun_bg = None  # 불타는 태양 효과 (로딩용)
        self._temple_bg = None  # 사원 배경 (스테이지 4)
        self._nemesis_ocean_bg = None  # 네메시스 해상전투 배경 (실제 스테이지 5 = 코드 stage 6)
        self._hongryeon_bg = None  # 홍련 중국 전통 배경 (실제 스테이지 6 = 코드 stage 5)
        self._tetriser_bg = None  # 테트리서 테트리스 배경 (스테이지 7)
        self._ninja_bg = None  # 닌자 저택 배경 (스테이지 8)
        self._colosseum_bg = None  # 투기장 배경 (스테이지 30)

        # 플레이어/보스 위치 (원숭이-바나나 이벤트용)
        self._player_rect = None
        self._boss_rect = None
        self._player_dash_dir = 0  # 플레이어 대쉬 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        self._boss_move_dir = 0  # 보스 이동 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        self._player_in_smoke = False  # 플레이어가 연막 안에 있는지 (바나나 미끄러짐 면역)

        # 불타는 태양 효과 강도 (0.0 ~ 1.0)
        self._blazing_intensity = 0.8

        # 광폭화 인디케이터 관련
        self._rage_indicator_active = False  # 광폭화 모드 활성 여부
        self._rage_indicator_rect = None     # 광폭화 아이콘 영역 (호버 감지용)
        self._rage_icon_surface = None       # 광폭화 아이콘 서피스 (캐시)
        self._rage_icon_w = 52               # 아이콘 가로 크기
        self._rage_icon_h = 68               # 아이콘 세로 크기 (세로가 더 김)
        self._rage_animation_time = 0.0      # 광폭화 아이콘 애니메이션
        self._create_rage_indicator_icon()   # 아이콘 생성

        # 홍련 광폭화 상태 (배경 초기화 전에 설정된 경우 보존)
        self._pending_hongryeon_enraged = False
        self._pending_hongryeon_fire_callback = None
        self._pending_hongryeon_fireball_image = None

        # 퀘스트 양피지 엠블럼 관련
        self._quest_emblem_active = False        # 퀘스트 엠블럼 표시 여부
        self._quest_emblem_rect = None           # 엠블럼 영역 (호버 감지용)
        self._quest_emblem_surface = None        # 엠블럼 서피스 (캐시)
        self._quest_emblem_w = 40                # 엠블럼 가로
        self._quest_emblem_h = 48                # 엠블럼 세로
        self._quest_animation_time = 0.0         # 엠블럼 애니메이션 타이머
        self._quest_completion_glow = False       # 퀘스트 완료 빛 효과
        self._quest_completion_glow_timer = 0.0   # 빛 효과 타이머
        self._quest_tablet_count = 0              # 석판 수집 카운터
        self._quest_tablet_target = 5             # 석판 수집 목표
        self._quest_has_tablet_quest = False       # 석판 퀘스트 활성 여부
        self._create_quest_parchment_icon()      # 양피지 아이콘 생성

        # === 🎮 투기장 영웅 스킬 아이콘 캐시 ===
        self._arena_skill_icon_cache = {}      # {(skill_id, w, h): Surface}
        self._arena_prev_cooldowns = {}        # {slot_index: prev_cooldown} - 쿨다운 완료 감지용
        self._arena_cooldown_flash = {}        # {slot_index: flash_start_time_ms}

        # === 🔧 액티브 아이템 슬롯 UI 최적화용 캐시 ===
        # 폰트 캐시 (매 프레임 로딩 방지)
        self._slot_font_small = None   # 카운트다운용 (size 20)
        self._slot_font_num = None     # 슬롯 번호용 (size 18)
        self._slot_font_notice = None  # 연금술 텍스트용 (한글 폰트)
        self._init_slot_fonts()

        # Surface 캐시 (크기별)
        self._slot_bg_cache = {}       # {(w, h, alpha): Surface}
        self._overlay_cache = {}       # {(w, h, alpha): Surface}

        # 스케일된 아이콘 캐시 {(item_name, w, h): Surface}
        self._scaled_icon_cache = {}

        # 아트워크 로드
        self._load_artwork()

    def _init_slot_fonts(self):
        """슬롯 UI용 폰트 초기화 (한 번만 로딩)"""
        try:
            self._slot_font_small = pygame.font.Font(None, 20)
            self._slot_font_num = pygame.font.Font(None, 18)
            # 한글 폰트
            font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
            if os.path.exists(font_path):
                self._slot_font_notice = pygame.font.Font(font_path, 16)
            else:
                self._slot_font_notice = pygame.font.Font(None, 16)
        except Exception as e:
            print(f"[PillarBG] 슬롯 폰트 초기화 실패: {e}")
            self._slot_font_small = pygame.font.Font(None, 20)
            self._slot_font_num = pygame.font.Font(None, 18)
            self._slot_font_notice = pygame.font.Font(None, 16)

    def _get_cached_surface(self, cache_dict, key, size, fill_color):
        """캐시된 Surface 반환 또는 생성"""
        if key not in cache_dict:
            surf = pygame.Surface(size, pygame.SRCALPHA)
            surf.fill(fill_color)
            cache_dict[key] = surf
        return cache_dict[key]

    def _get_scaled_icon(self, item, icon_size):
        """스케일된 아이콘 캐시에서 반환 또는 생성"""
        item_name = item.get("name") or item.get("effect") or id(item)
        icon = item.get("icon")
        if icon is None:
            return None

        cache_key = (item_name, icon_size[0], icon_size[1])
        if cache_key not in self._scaled_icon_cache:
            self._scaled_icon_cache[cache_key] = pygame.transform.scale(icon, icon_size)
        return self._scaled_icon_cache[cache_key]

    def _load_artwork(self):
        """핑파이터 아트워크 이미지 로드"""
        try:
            # 메인 배경 이미지 (main.jpg 우선, 없으면 start.png)
            artwork_path = resource_path("main.jpg")
            if not os.path.exists(artwork_path):
                artwork_path = resource_path("start.png")

            if os.path.exists(artwork_path):
                self._artwork_surface = pygame.image.load(artwork_path).convert()
                print(f"[PillarBG] 아트워크 로드 완료: {artwork_path} - {self._artwork_surface.get_size()}")
            else:
                print(f"[PillarBG] 아트워크 파일 없음 - 폴백 배경 생성")
                self._create_fallback_artwork()
        except Exception as e:
            print(f"[PillarBG] 아트워크 로드 실패: {e} - 폴백 배경 생성")
            self._create_fallback_artwork()

    def _create_fallback_artwork(self):
        """아트워크 로드 실패 시 그라데이션 폴백 배경 생성"""
        try:
            # 그라데이션 배경 생성 (어두운 보라-파랑 계열)
            self._artwork_surface = pygame.Surface((self.screen_width, self.screen_height))
            for y in range(self.screen_height):
                # 상단: 어두운 보라, 하단: 어두운 파랑
                ratio = y / self.screen_height
                r = int(25 + 10 * ratio)
                g = int(15 + 20 * ratio)
                b = int(40 + 30 * ratio)
                pygame.draw.line(self._artwork_surface, (r, g, b), (0, y), (self.screen_width, y))
            print(f"[PillarBG] 폴백 그라데이션 배경 생성 완료")
        except Exception as e:
            print(f"[PillarBG] 폴백 배경 생성도 실패: {e}")
            self._artwork_surface = None

    def _create_pillar_surfaces(self):
        """필러 서피스 생성 (캐싱)"""
        if self._artwork_surface is None:
            return

        # 아트워크 크기
        art_w, art_h = self._artwork_surface.get_size()

        # 화면 높이에 맞춰 스케일 계산
        scale = self.screen_height / art_h
        scaled_w = int(art_w * scale)
        scaled_h = self.screen_height

        # 스케일된 아트워크
        # smoothscale이 세로 줄무늬 아티팩트를 생성할 수 있으므로 scale 사용
        scaled_artwork = pygame.transform.scale(
            self._artwork_surface, (scaled_w, scaled_h)
        )

        # 왼쪽 필러 (아트워크 왼쪽 부분)
        if self.left_pillar_width > 0:
            self._left_pillar_surface = pygame.Surface(
                (self.left_pillar_width, self.screen_height)
            )
            # 아트워크 왼쪽 부분 추출 (어둡게)
            src_x = 0
            self._left_pillar_surface.blit(scaled_artwork, (0, 0),
                (src_x, 0, self.left_pillar_width, self.screen_height))
            # 어둡게 처리
            dark_overlay = pygame.Surface(
                (self.left_pillar_width, self.screen_height), pygame.SRCALPHA
            )
            dark_overlay.fill((0, 0, 0, 150))
            self._left_pillar_surface.blit(dark_overlay, (0, 0))
            # macOS에서 픽셀 포맷 최적화
            if _is_macos:
                self._left_pillar_surface = self._left_pillar_surface.convert()

        # 오른쪽 필러 (아트워크 오른쪽 부분)
        if self.right_pillar_width > 0:
            self._right_pillar_surface = pygame.Surface(
                (self.right_pillar_width, self.screen_height)
            )
            # 아트워크 오른쪽 부분 추출
            src_x = max(0, scaled_w - self.right_pillar_width)
            self._right_pillar_surface.blit(scaled_artwork, (0, 0),
                (src_x, 0, self.right_pillar_width, self.screen_height))
            # 어둡게 처리
            dark_overlay = pygame.Surface(
                (self.right_pillar_width, self.screen_height), pygame.SRCALPHA
            )
            dark_overlay.fill((0, 0, 0, 150))
            self._right_pillar_surface.blit(dark_overlay, (0, 0))
            # macOS에서 픽셀 포맷 최적화
            if _is_macos:
                self._right_pillar_surface = self._right_pillar_surface.convert()

        # 상단 필러 (아트워크 상단 부분 사용)
        if self.top_pillar_height > 0:
            self._top_pillar_surface = pygame.Surface(
                (self.game_width, self.top_pillar_height)
            )
            # 아트워크의 상단 부분 추출
            # 게임 영역에 해당하는 아트워크 중앙 부분의 상단을 사용
            center_x = (scaled_w - self.game_width) // 2
            self._top_pillar_surface.blit(scaled_artwork, (0, 0),
                (center_x, 0, self.game_width, self.top_pillar_height))
            # 어둡게 처리
            dark_overlay = pygame.Surface(
                (self.game_width, self.top_pillar_height), pygame.SRCALPHA
            )
            dark_overlay.fill((0, 0, 0, 150))
            self._top_pillar_surface.blit(dark_overlay, (0, 0))
            if _is_macos:
                self._top_pillar_surface = self._top_pillar_surface.convert()

        # 하단 필러 (아트워크 하단 부분 사용)
        if self.bottom_pillar_height > 0:
            self._bottom_pillar_surface = pygame.Surface(
                (self.game_width, self.bottom_pillar_height)
            )
            # 아트워크의 하단 부분 추출
            center_x = (scaled_w - self.game_width) // 2
            src_y = max(0, scaled_h - self.bottom_pillar_height)
            self._bottom_pillar_surface.blit(scaled_artwork, (0, 0),
                (center_x, src_y, self.game_width, self.bottom_pillar_height))
            # 어둡게 처리
            dark_overlay = pygame.Surface(
                (self.game_width, self.bottom_pillar_height), pygame.SRCALPHA
            )
            dark_overlay.fill((0, 0, 0, 150))
            self._bottom_pillar_surface.blit(dark_overlay, (0, 0))
            if _is_macos:
                self._bottom_pillar_surface = self._bottom_pillar_surface.convert()

    def set_type(self, bg_type: str):
        """배경 타입 설정"""
        if bg_type in (self.TYPE_ARTWORK, self.TYPE_DYNAMIC, self.TYPE_SOLID):
            self.current_type = bg_type

    def set_stage(self, stage: int):
        """현재 스테이지 설정 (동적 배경용)"""
        self.current_stage = stage

        # 스테이지 0: 메인 메뉴 바로크 액자 초기화
        if stage == 0 and self._baroque_bg is None:
            self._baroque_bg = BaroqueFrame(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 0 메인 메뉴 바로크 액자 초기화 완료")
        elif stage == 0 and self._baroque_bg is not None:
            # 메인 메뉴로 돌아올 때 애니메이션 리셋
            self._baroque_bg.reset_animation()

        # 스테이지 1: 스타디움 배경 초기화
        if stage == 1 and self._stadium_bg is None:
            self._stadium_bg = StadiumPillarBackground(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height,
                self.game_offset_x, self.game_offset_y,
                self.original_game_width, self.original_game_height
            )
            print(f"[PillarBG] 스테이지 1 스타디움 배경 초기화 완료 (offset: {self.game_offset_x}, {self.game_offset_y}, original: {self.original_game_width}x{self.original_game_height})")

        # 스테이지 2: 정글 늪지대 배경 초기화 (원숭이-바나나 이벤트 매니저 포함)
        if stage == 2 and self._jungle_bg is None:
            self._jungle_bg = init_jungle_background(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 2 정글 배경 초기화 완료 (원숭이 이벤트 포함)")

        # 스테이지 3: 멘헤라 인형 배경 초기화
        if stage == 3 and self._menhera_bg is None:
            self._menhera_bg = MenheraPlushFrame(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 3 멘헤라 배경 초기화 완료")

        # 스테이지 4: 사원 배경 초기화
        if stage == 4 and self._temple_bg is None:
            self._temple_bg = TemplePillarBackground(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 4 사원 배경 초기화 완료")

        # 스테이지 5(코드): 홍련 중국 전통 배경 초기화 (게임 내 실제 스테이지 6 = 코드 상 stage 5)
        if stage == 5 and self._hongryeon_bg is None:
            self._hongryeon_bg = HongryeonFrame(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 5(실제 6 홍련) 중국 전통 배경 초기화 완료")
            # 대기 중인 광폭화 상태 적용
            if self._pending_hongryeon_enraged:
                print(f"[PillarBG] 대기 중인 광폭화 상태 적용!")
                self._hongryeon_bg.set_enraged_mode(True)
                if self._pending_hongryeon_fire_callback:
                    self._hongryeon_bg.set_fire_callback(
                        self._pending_hongryeon_fire_callback,
                        self._pending_hongryeon_fireball_image
                    )

        # 스테이지 6(코드): 네메시스 해상전투 배경 초기화 (게임 내 실제 스테이지 5 = 코드 상 stage 6)
        if stage == 6 and self._nemesis_ocean_bg is None:
            self._nemesis_ocean_bg = NemesisOceanFrame(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            pass  # print(f"[PillarBG] 스테이지 6(실제 5 네메시스) 해상전투 배경 초기화 완료")  # 디버그 비활성화

        # 스테이지 7: 테트리서 테트리스 배경 초기화
        if stage == 7 and self._tetriser_bg is None:
            self._tetriser_bg = TetriserPillarBackground(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 7 테트리서 배경 초기화 완료")

        # 스테이지 8: 닌자 저택 배경 초기화
        if stage == 8 and self._ninja_bg is None:
            self._ninja_bg = NinjaPillarBackground(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 8 닌자 저택 배경 초기화 완료")

        # 스테이지 30: 투기장 배경 초기화
        if stage == 30 and self._colosseum_bg is None:
            self._colosseum_bg = ColosseumFrame(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height,
                self.game_offset_x, self.game_offset_y,
                self.original_game_width, self.original_game_height
            )
            print(f"[PillarBG] 스테이지 30 투기장 배경 초기화 완료")

    def set_blazing_intensity(self, intensity: float):
        """불타는 태양 효과 강도 설정 (0.0 ~ 1.0)"""
        self._blazing_intensity = max(0.0, min(1.0, intensity))
        if self._blazing_sun_bg is not None:
            self._blazing_sun_bg.set_intensity(self._blazing_intensity)

    def update(self, dt: float, is_waiting_for_serve: bool = False):
        """애니메이션 업데이트

        Args:
            dt: 델타 타임
            is_waiting_for_serve: 서브 대기 중인지 여부 (뱀 공격 트리거 방지용)
        """
        self._is_waiting_for_serve = is_waiting_for_serve  # 저장
        self.animation_time += dt

        # 스테이지 0: 메인 메뉴 바로크 액자 업데이트
        if self.current_stage == 0 and self._baroque_bg is not None:
            self._baroque_bg.update(dt)

        # 스테이지 1: 스타디움 배경 업데이트
        if self.current_stage == 1 and self._stadium_bg is not None:
            self._stadium_bg.update(dt)

        # 스테이지 2: 정글 배경 업데이트 + 원숭이 이벤트
        if self.current_stage == 2 and self._jungle_bg is not None:
            self._jungle_bg.update(dt)
            # 원숭이-바나나 이벤트 업데이트 (플레이어 & 보스 충돌 체크 + 대쉬 방향 + 연막 상태)
            monkey_mgr = get_monkey_event_manager()
            if monkey_mgr:
                monkey_mgr.update(dt, self._player_rect, self._boss_rect, self._player_dash_dir, self._boss_move_dir, self._player_in_smoke)

        # 스테이지 3: 멘헤라 배경 업데이트
        if self.current_stage == 3 and self._menhera_bg is not None:
            self._menhera_bg.update(dt)

        # 스테이지 4: 사원 배경 업데이트
        if self.current_stage == 4 and self._temple_bg is not None:
            self._temple_bg.update(dt)

        # 스테이지 5(코드): 홍련 중국 전통 배경 업데이트 (게임 내 실제 스테이지 6 = 코드 상 stage 5)
        # 서브 대기 중에는 새 뱀 공격 트리거하지 않음 (기존 뱀 애니메이션은 계속 진행)
        if self.current_stage == 5 and self._hongryeon_bg is not None:
            self._hongryeon_bg.update(dt, is_waiting_for_serve)

        # 스테이지 6(코드): 네메시스 해상전투 배경 업데이트 (게임 내 실제 스테이지 5 = 코드 상 stage 6)
        if self.current_stage == 6 and self._nemesis_ocean_bg is not None:
            self._nemesis_ocean_bg.update(dt)

        # 스테이지 7: 테트리서 배경 업데이트
        # 크리스탈 실드가 활성화된 경우, update_tetriser_with_boss()에서 업데이트함
        if self.current_stage == 7 and self._tetriser_bg is not None:
            if not self._tetriser_bg.crystal_shield.activated:
                self._tetriser_bg.update(dt)

        # 스테이지 8: 닌자 저택 배경 업데이트
        if self.current_stage == 8 and self._ninja_bg is not None:
            self._ninja_bg.update(dt)

        # 스테이지 30: 투기장 배경 업데이트
        if self.current_stage == 30 and self._colosseum_bg is not None:
            self._colosseum_bg.update(dt)

    def draw(self, screen: pygame.Surface):
        """필러 배경 그리기"""
        # 스테이지 0: 메인 메뉴 - 기존 아트워크 배경 위에 바로크 액자 표시
        if self.current_stage == 0 and self._baroque_bg is not None:
            # 1. 먼저 기존 아트워크 배경 그리기
            self._draw_artwork(screen)
            # 2. 그 위에 바로크 액자 그리기
            self._baroque_bg.draw(screen)
            return

        # 스테이지 1: 스타디움 배경 사용
        if self.current_stage == 1 and self._stadium_bg is not None:
            self._stadium_bg.draw(screen)
            return

        # 스테이지 2: 정글 배경 사용 + 원숭이 이벤트
        if self.current_stage == 2 and self._jungle_bg is not None:
            self._jungle_bg.draw(screen)
            # 원숭이-바나나 이벤트 그리기 (필러 영역에)
            monkey_mgr = get_monkey_event_manager()
            if monkey_mgr:
                monkey_mgr.draw(screen)
            return

        # 스테이지 3: 멘헤라 배경 사용
        if self.current_stage == 3 and self._menhera_bg is not None:
            self._menhera_bg.draw(screen)
            return

        # 스테이지 4: 사원 배경 사용
        if self.current_stage == 4 and self._temple_bg is not None:
            self._temple_bg.draw(screen)
            return

        # 스테이지 5(코드): 홍련 중국 전통 배경 사용 (게임 내 실제 스테이지 6 = 코드 상 stage 5)
        if self.current_stage == 5 and self._hongryeon_bg is not None:
            self._hongryeon_bg.draw(screen)
            return

        # 스테이지 6(코드): 네메시스 해상전투 배경 사용 (게임 내 실제 스테이지 5 = 코드 상 stage 6)
        if self.current_stage == 6 and self._nemesis_ocean_bg is not None:
            self._nemesis_ocean_bg.draw(screen)
            return

        # 스테이지 7: 테트리서 배경 사용
        if self.current_stage == 7 and self._tetriser_bg is not None:
            self._tetriser_bg.draw(screen)
            return

        # 스테이지 8: 닌자 저택 배경 사용
        if self.current_stage == 8 and self._ninja_bg is not None:
            self._ninja_bg.draw(screen)
            return

        # 스테이지 30: 투기장 배경 사용
        if self.current_stage == 30 and self._colosseum_bg is not None:
            self._colosseum_bg.draw(screen)
            return

        if self.current_type == self.TYPE_ARTWORK:
            self._draw_artwork(screen)
        elif self.current_type == self.TYPE_DYNAMIC:
            self._draw_dynamic(screen)
        else:
            self._draw_solid(screen)

    def _draw_artwork(self, screen: pygame.Surface):
        """아트워크 배경 그리기"""
        # 캐시된 서피스가 없으면 생성
        if self._left_pillar_surface is None:
            self._create_pillar_surfaces()

        # 아트워크 서피스 생성 실패 시 단색 배경으로 폴백
        if self._left_pillar_surface is None and self._artwork_surface is None:
            self._draw_solid(screen)
            return

        # 왼쪽 필러
        if self._left_pillar_surface and self.left_pillar_width > 0:
            screen.blit(self._left_pillar_surface, (0, 0))

        # 오른쪽 필러
        if self._right_pillar_surface and self.right_pillar_width > 0:
            screen.blit(self._right_pillar_surface,
                       (self.game_offset_x + self.game_width, 0))

        # 상단 필러
        if self._top_pillar_surface and self.top_pillar_height > 0:
            screen.blit(self._top_pillar_surface, (self.game_offset_x, 0))

        # 하단 필러
        if self._bottom_pillar_surface and self.bottom_pillar_height > 0:
            screen.blit(self._bottom_pillar_surface,
                       (self.game_offset_x, self.game_offset_y + self.game_height))

    def _draw_dynamic(self, screen: pygame.Surface):
        """스테이지별 동적 배경 그리기"""
        # 스테이지별 색상 테마
        stage_colors = {
            0: (15, 15, 25),      # 기본 (어두운 남색)
            1: (20, 30, 50),      # 스테이지1 (파란 계열)
            2: (40, 20, 40),      # 스테이지2 (보라 계열)
            3: (50, 30, 40),      # 스테이지3 (분홍 계열)
            4: (30, 30, 30),      # 스테이지4 (회색 계열)
            5: (50, 25, 15),      # 스테이지5 (주황 계열)
            6: (15, 40, 30),      # 스테이지6 (녹색 계열)
        }

        base_color = stage_colors.get(self.current_stage, (15, 15, 25))

        # 애니메이션 효과 (부드러운 색상 변화)
        pulse = (math.sin(self.animation_time * 0.5) + 1) * 0.1
        r = min(255, int(base_color[0] * (1 + pulse)))
        g = min(255, int(base_color[1] * (1 + pulse)))
        b = min(255, int(base_color[2] * (1 + pulse)))

        animated_color = (r, g, b)

        # 좌우 필러
        if self.left_pillar_width > 0:
            pygame.draw.rect(screen, animated_color,
                           (0, 0, self.left_pillar_width, self.screen_height))

        if self.right_pillar_width > 0:
            pygame.draw.rect(screen, animated_color,
                           (self.game_offset_x + self.game_width, 0,
                            self.right_pillar_width, self.screen_height))

        # 상하 필러
        if self.top_pillar_height > 0:
            pygame.draw.rect(screen, animated_color,
                           (self.game_offset_x, 0,
                            self.game_width, self.top_pillar_height))

        if self.bottom_pillar_height > 0:
            pygame.draw.rect(screen, animated_color,
                           (self.game_offset_x, self.game_offset_y + self.game_height,
                            self.game_width, self.bottom_pillar_height))

        # 스테이지별 추가 효과
        self._draw_stage_effects(screen)

    def _draw_stage_effects(self, screen: pygame.Surface):
        """스테이지별 추가 시각 효과"""
        if self.current_stage == 1:
            # 스테이지1: 별 효과
            self._draw_star_particles(screen)
        elif self.current_stage == 5:
            # 스테이지5: 불꽃 효과
            self._draw_fire_particles(screen)

    def _draw_star_particles(self, screen: pygame.Surface):
        """별 파티클 효과"""
        import random
        random.seed(int(self.animation_time * 10) % 1000)

        for _ in range(20):
            if random.random() > 0.3:
                continue
            # 왼쪽 필러에 별
            if self.left_pillar_width > 10:
                x = random.randint(5, self.left_pillar_width - 5)
                y = random.randint(0, self.screen_height)
                brightness = random.randint(100, 255)
                size = random.randint(1, 3)
                pygame.draw.circle(screen, (brightness, brightness, brightness), (x, y), size)

            # 오른쪽 필러에 별
            if self.right_pillar_width > 10:
                x = self.game_offset_x + self.game_width + random.randint(5, self.right_pillar_width - 5)
                y = random.randint(0, self.screen_height)
                brightness = random.randint(100, 255)
                size = random.randint(1, 3)
                pygame.draw.circle(screen, (brightness, brightness, brightness), (x, y), size)

        random.seed()  # 시드 리셋 (다른 랜덤 로직에 영향 방지)

    def _draw_fire_particles(self, screen: pygame.Surface):
        """불꽃 파티클 효과"""
        import random
        random.seed(int(self.animation_time * 15) % 1000)

        for _ in range(15):
            if random.random() > 0.4:
                continue
            # 왼쪽 필러에 불꽃
            if self.left_pillar_width > 10:
                x = random.randint(5, self.left_pillar_width - 5)
                y = self.screen_height - random.randint(0, 200)
                r = random.randint(200, 255)
                g = random.randint(50, 150)
                b = random.randint(0, 50)
                size = random.randint(2, 5)
                pygame.draw.circle(screen, (r, g, b), (x, y), size)

            # 오른쪽 필러에 불꽃
            if self.right_pillar_width > 10:
                x = self.game_offset_x + self.game_width + random.randint(5, self.right_pillar_width - 5)
                y = self.screen_height - random.randint(0, 200)
                r = random.randint(200, 255)
                g = random.randint(50, 150)
                b = random.randint(0, 50)
                size = random.randint(2, 5)
                pygame.draw.circle(screen, (r, g, b), (x, y), size)

        random.seed()  # 시드 리셋 (다른 랜덤 로직에 영향 방지)

    def _draw_solid(self, screen: pygame.Surface):
        """단색 배경 그리기"""
        # 좌우 필러
        if self.left_pillar_width > 0:
            pygame.draw.rect(screen, self.bg_color,
                           (0, 0, self.left_pillar_width, self.screen_height))

        if self.right_pillar_width > 0:
            pygame.draw.rect(screen, self.bg_color,
                           (self.game_offset_x + self.game_width, 0,
                            self.right_pillar_width, self.screen_height))

        # 상하 필러
        if self.top_pillar_height > 0:
            pygame.draw.rect(screen, self.bg_color,
                           (self.game_offset_x, 0,
                            self.game_width, self.top_pillar_height))

        if self.bottom_pillar_height > 0:
            pygame.draw.rect(screen, self.bg_color,
                           (self.game_offset_x, self.game_offset_y + self.game_height,
                            self.game_width, self.bottom_pillar_height))

    def get_game_offset(self) -> tuple:
        """게임 영역 오프셋 반환"""
        return (self.game_offset_x, self.game_offset_y)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경 시 재계산"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 오프셋 재계산
        self.game_offset_x = (screen_width - game_width) // 2
        self.game_offset_y = (screen_height - game_height) // 2

        # 필러 크기 재계산
        self.left_pillar_width = self.game_offset_x
        self.right_pillar_width = screen_width - game_width - self.game_offset_x
        self.top_pillar_height = self.game_offset_y
        self.bottom_pillar_height = screen_height - game_height - self.game_offset_y

        # 캐시 초기화
        self._left_pillar_surface = None
        self._right_pillar_surface = None
        self._top_pillar_surface = None
        self._bottom_pillar_surface = None

        # 바로크 액자 리사이즈
        if self._baroque_bg is not None:
            self._baroque_bg = BaroqueFrame(screen_width, screen_height, game_width, game_height)

        # 스타디움 배경 리사이즈 (offset 및 원본 크기 전달)
        if self._stadium_bg is not None:
            self._stadium_bg.resize(screen_width, screen_height, game_width, game_height,
                                    self.game_offset_x, self.game_offset_y,
                                    self.original_game_width, self.original_game_height)

        # 정글 배경 리사이즈 (원숭이 이벤트 매니저도 재초기화)
        if self._jungle_bg is not None:
            self._jungle_bg = init_jungle_background(screen_width, screen_height, game_width, game_height)

        # 멘헤라 배경 리사이즈
        if self._menhera_bg is not None:
            # MenheraPlushFrame은 resize 메서드가 없으면 재생성
            self._menhera_bg = MenheraPlushFrame(screen_width, screen_height, game_width, game_height)

        # 사원 배경 리사이즈
        if self._temple_bg is not None:
            self._temple_bg.resize(screen_width, screen_height, game_width, game_height)

        # 홍련 중국 전통 배경 리사이즈
        if self._hongryeon_bg is not None:
            self._hongryeon_bg.resize(screen_width, screen_height, game_width, game_height)

        # 네메시스 해상전투 배경 리사이즈
        if self._nemesis_ocean_bg is not None:
            self._nemesis_ocean_bg.resize(screen_width, screen_height, game_width, game_height)

        # 테트리서 배경 리사이즈
        if self._tetriser_bg is not None:
            self._tetriser_bg.resize(screen_width, screen_height, game_width, game_height)

        # 닌자 저택 배경 리사이즈
        if self._ninja_bg is not None:
            self._ninja_bg.resize(screen_width, screen_height, game_width, game_height)

    def trigger_stadium_excitement(self, level: float = 1.5):
        """스타디움 관중 흥분도 트리거 (점수 획득 시 호출)"""
        if self._stadium_bg is not None:
            self._stadium_bg.trigger_excitement(level)

    def trigger_jungle_excitement(self, level: float = 1.5):
        """정글 환경 반응 트리거 (점수 획득 시 호출)"""
        if self._jungle_bg is not None:
            self._jungle_bg.trigger_excitement(level)

    def trigger_menhera_excitement(self, level: float = 1.5):
        """멘헤라 인형 반응 트리거 (점수 획득 시 호출)"""
        if self._menhera_bg is not None:
            self._menhera_bg.trigger_excitement(level)

    def trigger_temple_excitement(self, level: float = 1.5):
        """사원 배경 반응 트리거 (점수 획득 시 호출)"""
        if self._temple_bg is not None:
            self._temple_bg.trigger_excitement(level)

    def trigger_hongryeon_excitement(self, level: float = 1.5):
        """홍련 중국 전통 배경 반응 트리거 (점수 획득 시 호출)"""
        if self._hongryeon_bg is not None:
            self._hongryeon_bg.trigger_excitement(level)

    # ===== Stage 5(코드=실제6 홍련) 광폭화 뱀 공격 시스템 =====

    def set_hongryeon_enraged(self, active: bool):
        """홍련 필러 광폭화 모드 설정 (뱀 공격 시스템 활성화)"""
        # 배경이 아직 초기화되지 않은 경우 대기 상태로 저장
        self._pending_hongryeon_enraged = active
        if self._hongryeon_bg is not None:
            self._hongryeon_bg.set_enraged_mode(active)
        else:
            print(f"[PillarBG] 홍련 배경 미초기화 - 광폭화 상태 대기: {active}")

    def set_hongryeon_fire_callback(self, callback, fireball_image=None):
        """홍련 필러 화염탄 발사 콜백 설정
        callback(start_x, start_y, target_x, target_y): 화염탄 발사 함수
        fireball_image: 인게임 화염탄 이미지 (필러 화염탄에 사용)
        """
        # 배경이 아직 초기화되지 않은 경우 대기 상태로 저장
        self._pending_hongryeon_fire_callback = callback
        self._pending_hongryeon_fireball_image = fireball_image
        if self._hongryeon_bg is not None:
            self._hongryeon_bg.set_fire_callback(callback, fireball_image)
        else:
            print(f"[PillarBG] 홍련 배경 미초기화 - 화염 콜백 대기")

    def update_hongryeon_player_position(self, player_x: int, player_y: int,
                                          internal_x: int = None, internal_y: int = None):
        """홍련 필러 플레이어 위치 업데이트 (뱀 조준용)

        Args:
            player_x, player_y: REAL_SCREEN 좌표 (시각적 조준용)
            internal_x, internal_y: 내부 게임 좌표 (화염탄 생성용)
        """
        if self._hongryeon_bg is not None:
            self._hongryeon_bg.update_player_position(player_x, player_y,
                                                       internal_x, internal_y)

    def get_hongryeon_background(self):
        """홍련 배경 인스턴스 반환"""
        return self._hongryeon_bg

    def trigger_nemesis_excitement(self, level: float = 1.5):
        """네메시스 해상전투 배경 반응 트리거 (점수 획득 시 호출)"""
        if self._nemesis_ocean_bg is not None:
            self._nemesis_ocean_bg.trigger_excitement(level)

    def trigger_tetriser_excitement(self, level: float = 1.5):
        """테트리서 배경 반응 트리거 (점수 획득 시 호출)"""
        if self._tetriser_bg is not None:
            self._tetriser_bg.trigger_excitement(level)

    def trigger_ninja_excitement(self, level: float = 1.5):
        """닌자 저택 배경 반응 트리거 (점수 획득 시 호출)"""
        if self._ninja_bg is not None:
            self._ninja_bg.trigger_excitement(level)

    def trigger_colosseum_excitement(self, intensity: float = 1.0, duration: float = 2.0):
        """투기장 관중 흥분 트리거 (득점/공 충돌 시 호출)"""
        if self._colosseum_bg is not None:
            self._colosseum_bg.trigger_excitement(intensity, duration)

    def get_colosseum_bg(self):
        """투기장 배경 인스턴스 반환 (직접 조작용)"""
        return self._colosseum_bg

    # ===== Stage 7 크리스탈 실드 시스템 =====

    def activate_crystal_shield(self, boss_x: float, boss_y: float) -> bool:
        """크리스탈 실드 활성화 (플레이어 4점 획득 시 호출)"""
        if self._tetriser_bg is not None:
            return self._tetriser_bg.activate_crystal_shield(boss_x, boss_y)
        return False

    def update_tetriser_with_boss(self, dt: float, boss_x: float, boss_y: float):
        """테트리서 배경 업데이트 (보스 위치 포함)"""
        if self._tetriser_bg is not None:
            self._tetriser_bg.update(dt, boss_x, boss_y)

    def is_crystal_shield_frozen(self) -> bool:
        """크리스탈 실드 화면 정지 상태"""
        if self._tetriser_bg is not None:
            return self._tetriser_bg.is_screen_frozen()
        return False

    def check_crystal_shield_collision(self, ball_rect, is_player_ball: bool):
        """크리스탈 실드 블록과 공 충돌 체크"""
        if self._tetriser_bg is not None:
            return self._tetriser_bg.check_ball_collision(ball_rect, is_player_ball)
        return None

    def draw_crystal_shield(self, screen):
        """크리스탈 실드 그리기 (게임 화면 위에)"""
        if self._tetriser_bg is not None:
            self._tetriser_bg.draw_shield(screen)

    def get_crystal_shield_count(self) -> int:
        """활성 크리스탈 실드 블록 수"""
        if self._tetriser_bg is not None:
            return self._tetriser_bg.get_shield_block_count()
        return 0

    def is_crystal_shield_active(self) -> bool:
        """크리스탈 실드가 활성 상태인지"""
        if self._tetriser_bg is not None:
            return self._tetriser_bg.is_shield_active()
        return False

    def reset_crystal_shield(self):
        """크리스탈 실드 리셋"""
        if self._tetriser_bg is not None:
            self._tetriser_bg.reset_shield()

    def is_crystal_shield_pending(self) -> bool:
        """크리스탈 실드 활성화가 예약되어 있는지"""
        if self._tetriser_bg is not None:
            return self._tetriser_bg.is_shield_pending()
        return False

    def start_crystal_shield_animation(self, boss_x: float, boss_y: float) -> bool:
        """크리스탈 실드 애니메이션 시작 (다음 라운드 시작 시 호출)"""
        if self._tetriser_bg is not None:
            return self._tetriser_bg.start_shield_animation(boss_x, boss_y)
        return False

    def clear_tetriser_boards(self):
        """테트리서 보드 클리어"""
        if self._tetriser_bg is not None:
            self._tetriser_bg.clear_tetris_boards()

    def set_player_rect(self, player_rect):
        """플레이어 위치 설정 (원숭이-바나나 이벤트용 + 스테이지1 나비 흡수용)"""
        self._player_rect = player_rect
        # 스테이지 1: 스타디움 배경에도 플레이어 위치 전달 (나비 흡수용)
        if self.current_stage == 1 and self._stadium_bg is not None:
            self._stadium_bg.set_player_rect(player_rect)

    def set_boss_rect(self, boss_rect):
        """보스 위치 설정 (원숭이-바나나 이벤트용)"""
        self._boss_rect = boss_rect

    def set_player_dash_dir(self, dash_dir):
        """플레이어 대쉬 방향 설정 (원숭이-바나나 이벤트용)

        Args:
            dash_dir: 대쉬 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        """
        self._player_dash_dir = dash_dir

    def set_boss_move_dir(self, move_dir):
        """보스 이동 방향 설정 (원숭이-바나나 이벤트용)

        Args:
            move_dir: 이동 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        """
        self._boss_move_dir = move_dir

    def set_player_in_smoke(self, in_smoke):
        """플레이어 연막 상태 설정 (바나나 미끄러짐 면역)

        Args:
            in_smoke: 연막 안에 있는지 여부
        """
        self._player_in_smoke = in_smoke

    def get_monkey_slip_offset(self):
        """원숭이 바나나 미끄러짐 오프셋 반환 (플레이어)"""
        if self.current_stage == 2:
            monkey_mgr = get_monkey_event_manager()
            if monkey_mgr:
                return monkey_mgr.get_slip_offset()
        return 0

    def get_boss_slip_offset(self):
        """원숭이 바나나 미끄러짐 오프셋 반환 (보스)"""
        if self.current_stage == 2:
            monkey_mgr = get_monkey_event_manager()
            if monkey_mgr:
                return monkey_mgr.get_boss_slip_offset()
        return 0

    def is_player_slipping(self):
        """플레이어가 바나나에 미끄러지고 있는지"""
        if self.current_stage == 2:
            monkey_mgr = get_monkey_event_manager()
            if monkey_mgr:
                return monkey_mgr.is_player_slipping()
        return False

    def is_boss_slipping(self):
        """보스가 바나나에 미끄러지고 있는지"""
        if self.current_stage == 2:
            monkey_mgr = get_monkey_event_manager()
            if monkey_mgr:
                return monkey_mgr.is_boss_slipping()
        return False

    def draw_bananas_ingame(self, screen):
        """인게임 화면에 바나나 그리기 (인게임 좌표계)"""
        if self.current_stage == 2:
            monkey_mgr = get_monkey_event_manager()
            if monkey_mgr:
                monkey_mgr.draw_ingame(screen)

    def check_butterfly_gauge_recovery(self) -> bool:
        """스테이지 1 나비 흡수로 인한 게이지 회복 여부 확인

        Returns:
            bool: 게이지 회복이 필요하면 True, 아니면 False (한 번 호출하면 리셋됨)
        """
        if self.current_stage == 1 and self._stadium_bg is not None:
            return self._stadium_bg.check_gauge_recovered()
        return False

    def draw_butterfly_ingame(self, screen, game_width, game_height):
        """스테이지 1에서 날아가는 나비를 게임 화면에 그리기

        Args:
            screen: 게임 화면 surface
            game_width: 게임 영역 너비
            game_height: 게임 영역 높이
        """
        if self.current_stage == 1 and self._stadium_bg is not None:
            self._stadium_bg.draw_flying_butterfly_ingame(screen, game_width, game_height)
            self._stadium_bg.draw_absorbing_butterfly_ingame(screen, game_width, game_height)
            self._stadium_bg.draw_absorption_particles_ingame(screen)

    # ===== 필러 UI 박스 시스템 =====

    def draw_pillar_ui_box(self, screen, x, y, width, height, alpha=180):
        """반투명 어두운 UI 박스 그리기

        Args:
            screen: 그릴 surface
            x, y: 박스 위치
            width, height: 박스 크기
            alpha: 투명도 (0-255)
        """
        # 반투명 서피스 생성
        box_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 배경 (반투명 어두운색)
        bg_color = (20, 20, 30, alpha)
        pygame.draw.rect(box_surface, bg_color, (0, 0, width, height), border_radius=6)

        # 테두리 (약간 밝은 색)
        border_color = (60, 60, 80, alpha)
        pygame.draw.rect(box_surface, border_color, (0, 0, width, height), 2, border_radius=6)

        screen.blit(box_surface, (x, y))

    def draw_top_pillar_score(self, screen, player_score=0, boss_score=0):
        """상단 필러 중앙에 고급스러운 스코어 표시 (듀스 시 화염 버전)

        Args:
            screen: 그릴 surface
            player_score: 플레이어 점수
            boss_score: 보스 점수
        """
        # 상단 필러가 없으면 그리지 않음
        if self.top_pillar_height < 20:
            return

        # 듀스 상태 확인 - pingfighter의 전역 deuce_mode 변수를 참조
        # 기존 로컬 조건 대신 전역 상태를 사용하여 일관성 유지
        try:
            import pingfighter
            is_deuce = getattr(pingfighter, 'deuce_mode', False)
        except (ImportError, AttributeError):
            # fallback: 4:4 이상 동점일 때만 듀스로 처리
            is_deuce = player_score >= 4 and boss_score >= 4 and player_score == boss_score

        # 스코어 박스 크기 (game_scale 비례)
        _s = self.game_width / self.original_game_width if self.original_game_width > 0 else 1.0
        box_width = max(80, int(140 * _s))
        box_height = max(28, int(44 * _s))

        # 게임 화면 상단 중앙에 배치
        box_x = self.game_offset_x + (self.game_width - box_width) // 2
        box_y = (self.game_offset_y - box_height) // 2

        # 박스가 화면 밖으로 나가지 않도록
        if box_y < 2:
            box_y = 2

        time_ms = pygame.time.get_ticks()

        # === 점수 변경 감지 및 반짝임 트리거 ===
        if not hasattr(self, '_prev_player_score'):
            self._prev_player_score = player_score
            self._prev_boss_score = boss_score
            self._score_sparkle_start = 0

        if player_score != self._prev_player_score or boss_score != self._prev_boss_score:
            self._score_sparkle_start = time_ms
            self._prev_player_score = player_score
            self._prev_boss_score = boss_score

        sparkle_duration = 1000
        time_since_sparkle = time_ms - self._score_sparkle_start
        sparkle_intensity = 0
        cycle_progress = 0

        if time_since_sparkle < sparkle_duration:
            cycle_progress = time_since_sparkle
            sparkle_progress = time_since_sparkle / sparkle_duration
            sparkle_intensity = math.sin(sparkle_progress * math.pi)

        if is_deuce:
            # ==================== 듀스 화염 버전 ====================
            self._draw_deuce_fire_score(screen, box_x, box_y, box_width, box_height,
                                        player_score, boss_score, time_ms, sparkle_intensity,
                                        _scale=_s)
        else:
            # ==================== 일반 버전 ====================
            self._draw_normal_score(screen, box_x, box_y, box_width, box_height,
                                    player_score, boss_score, time_ms, sparkle_intensity,
                                    cycle_progress, sparkle_duration,
                                    _scale=_s)

    def _draw_deuce_fire_score(self, screen, box_x, box_y, box_width, box_height,
                                player_score, boss_score, time_ms, sparkle_intensity,
                                _scale=1.0):
        """듀스 상태의 이글이글 타오르는 화염 점수판 (Raging Inferno 스타일)"""
        import random

        # === 외곽 열기 글로우 (강렬하게, 5단계) ===
        pulse = math.sin(time_ms * 0.008) * 0.3 + 0.7
        for glow_layer in range(5):
            glow_margin = 20 - glow_layer * 3
            glow_surface = pygame.Surface(
                (box_width + glow_margin * 2, box_height + glow_margin * 2),
                pygame.SRCALPHA
            )
            glow_alpha = int((40 - glow_layer * 7) * pulse)
            pygame.draw.rect(glow_surface, (255, 50 + glow_layer * 20, 0, glow_alpha),
                            glow_surface.get_rect(), border_radius=12)
            screen.blit(glow_surface, (box_x - glow_margin, box_y - glow_margin))

        # === 메인 박스 (격렬한 화염 그라데이션) ===
        box_surface = pygame.Surface((box_width, box_height), pygame.SRCALPHA)

        for i in range(box_height):
            ratio = i / box_height
            # 빠르고 불규칙한 파동
            wave1 = math.sin(time_ms * 0.012 + ratio * 8) * 0.15
            wave2 = math.sin(time_ms * 0.018 + ratio * 12 + 2) * 0.1
            wave3 = math.sin(time_ms * 0.025 + ratio * 20) * 0.08
            combined = wave1 + wave2 + wave3

            # 강렬한 화염 색상
            if ratio < 0.3:
                r, g, b = 255, int(255 - 55 * ratio / 0.3), int(200 - 150 * ratio / 0.3)
            elif ratio < 0.6:
                r, g, b = 255, int(200 - 100 * (ratio - 0.3) / 0.3), int(50 - 30 * (ratio - 0.3) / 0.3)
            else:
                r, g, b = int(255 - 80 * (ratio - 0.6) / 0.4), int(100 - 70 * (ratio - 0.6) / 0.4), 10

            r = int(min(255, max(0, r + 60 * combined)))
            g = int(min(255, max(0, g + 80 * combined)))
            b = int(min(255, max(0, b + 30 * combined)))

            pygame.draw.line(box_surface, (r, g, b, 245), (0, i), (box_width, i))

        # 테두리
        pygame.draw.rect(box_surface, (180, 60, 20), (0, 0, box_width, box_height), 3, border_radius=8)
        screen.blit(box_surface, (box_x, box_y))

        # === 맹렬한 상단 화염 (다중 레이어) ===
        flame_surface = pygame.Surface((box_width + 20, 45), pygame.SRCALPHA)

        for layer in range(4):
            layer_height = 35 - layer * 6
            layer_alpha = 200 - layer * 40

            points = [(0, 45)]
            for fx in range(0, box_width + 21, 2):
                h = layer_height * 0.4
                h += math.sin(time_ms * (0.015 + layer * 0.003) + fx * 0.18) * layer_height * 0.3
                h += math.sin(time_ms * (0.022 + layer * 0.005) + fx * 0.28) * layer_height * 0.2
                h += math.sin(time_ms * (0.035 + layer * 0.008) + fx * 0.45) * layer_height * 0.15
                points.append((fx, 45 - max(0, h)))
            points.append((box_width + 20, 45))

            # 화염 색상 (레이어별)
            if layer == 0:
                color = (255, 255, 220, layer_alpha)  # 밝은 중심
            elif layer == 1:
                color = (255, 200, 80, layer_alpha)   # 노랑
            elif layer == 2:
                color = (255, 120, 30, layer_alpha)   # 주황
            else:
                color = (200, 60, 10, layer_alpha)    # 빨강

            pygame.draw.polygon(flame_surface, color, points)

        screen.blit(flame_surface, (box_x - 10, box_y - 38))

        # === 떠오르는 불씨 파티클 ===
        for j in range(10):
            particle_speed = 0.004 + j * 0.0008
            particle_phase = (time_ms * particle_speed + j * 0.7) % 1.0

            # 위로 올라가는 효과
            particle_y_base = box_y - 5
            particle_y_offset = -particle_phase * 35
            particle_x = box_x + 5 + j * (box_width - 10) / 9

            # 좌우 흔들림
            sway = math.sin(time_ms * 0.01 + j * 1.2) * 5
            particle_x += sway

            particle_y = particle_y_base + particle_y_offset

            # 크기와 투명도 (위로 갈수록 작아지고 투명해짐)
            size_factor = 1 - particle_phase * 0.7
            particle_size = int((2 + j % 3) * size_factor)
            particle_alpha = int(255 * (1 - particle_phase) ** 1.2)

            if particle_size > 0 and particle_alpha > 20:
                particle_surface = pygame.Surface((particle_size * 4, particle_size * 4), pygame.SRCALPHA)

                # 화염 색상 (수명에 따라 노랑 → 주황 → 빨강)
                life_ratio = 1 - particle_phase
                if life_ratio > 0.6:
                    p_r, p_g, p_b = 255, 255, int(150 * (life_ratio - 0.6) / 0.4)
                elif life_ratio > 0.3:
                    p_r, p_g, p_b = 255, int(150 + 105 * (life_ratio - 0.3) / 0.3), 0
                else:
                    p_r, p_g, p_b = int(255 * life_ratio / 0.3), int(80 * life_ratio / 0.3), 0

                # 글로우
                pygame.draw.circle(particle_surface, (p_r, p_g, 0, particle_alpha // 4),
                                 (particle_size * 2, particle_size * 2), particle_size * 2)
                pygame.draw.circle(particle_surface, (p_r, p_g, p_b, particle_alpha // 2),
                                 (particle_size * 2, particle_size * 2), particle_size + 1)
                # 밝은 코어
                pygame.draw.circle(particle_surface, (255, 255, 200, particle_alpha),
                                 (particle_size * 2, particle_size * 2), particle_size)

                screen.blit(particle_surface,
                          (int(particle_x - particle_size * 2), int(particle_y - particle_size * 2)))

        # === "DEUCE!" 텍스트 (화염 스타일) ===
        try:
            font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
            deuce_font = pygame.font.Font(font_path, 11)

            deuce_center_x = box_x + box_width // 2
            deuce_center_y = box_y - 12

            # 글로우 레이어
            for gw in range(3, 0, -1):
                glow_text = deuce_font.render("DEUCE!", True, (255, 100, 0))
                glow_text.set_alpha(int(50 * (4 - gw) * pulse))
                glow_rect = glow_text.get_rect(center=(deuce_center_x, deuce_center_y))
                for ox, oy in [(-gw, 0), (gw, 0), (0, -gw), (0, gw)]:
                    screen.blit(glow_text, (glow_rect.x + ox, glow_rect.y + oy))

            # 메인 텍스트 (밝은 노랑)
            deuce_text = deuce_font.render("DEUCE!", True, (255, 255, 230))
            deuce_rect = deuce_text.get_rect(center=(deuce_center_x, deuce_center_y))
            # 그림자
            shadow_text = deuce_font.render("DEUCE!", True, (100, 30, 5))
            screen.blit(shadow_text, (deuce_rect.x + 1, deuce_rect.y + 1))
            screen.blit(deuce_text, deuce_rect)

        except:
            pass

        # === 스코어 텍스트 (화염 색상 + 글로우 + 미세 떨림) ===
        try:
            _font_size = max(20, int(42 * _scale))
            score_font = pygame.font.Font(None, _font_size)

            # 열기로 인한 미세한 떨림
            shake_x = math.sin(time_ms * 0.02) * 1
            shake_y = math.cos(time_ms * 0.025) * 0.5

            center_x = box_x + box_width // 2 + shake_x
            center_y = box_y + box_height // 2 + shake_y
            score_offset = max(16, int(28 * _scale))

            # 글로우 효과
            for gw in range(4, 0, -1):
                glow_color = (255, 100, 0)
                p_glow = score_font.render(str(player_score), True, glow_color)
                b_glow = score_font.render(str(boss_score), True, glow_color)
                p_glow.set_alpha(int(50 * (5 - gw)))
                b_glow.set_alpha(int(50 * (5 - gw)))

                p_glow_rect = p_glow.get_rect(center=(center_x - score_offset, center_y))
                b_glow_rect = b_glow.get_rect(center=(center_x + score_offset, center_y))

                for ox, oy in [(-gw, 0), (gw, 0), (0, -gw), (0, gw)]:
                    screen.blit(p_glow, (p_glow_rect.x + ox, p_glow_rect.y + oy))
                    screen.blit(b_glow, (b_glow_rect.x + ox, b_glow_rect.y + oy))

            # 그림자
            shadow_color = (100, 30, 5)
            p_shadow = score_font.render(str(player_score), True, shadow_color)
            b_shadow = score_font.render(str(boss_score), True, shadow_color)
            colon_shadow = score_font.render(":", True, shadow_color)

            # 메인 점수 (밝은 흰색-노랑)
            score_color = (255, 255, 230)
            colon_color = (255, 220, 150)

            p_text = score_font.render(str(player_score), True, score_color)
            b_text = score_font.render(str(boss_score), True, score_color)
            colon_text = score_font.render(":", True, colon_color)

            colon_rect = colon_text.get_rect(center=(center_x, center_y))
            p_rect = p_text.get_rect(center=(center_x - score_offset, center_y))
            b_rect = b_text.get_rect(center=(center_x + score_offset, center_y))

            # 그림자 그리기
            screen.blit(p_shadow, (p_rect.x + 2, p_rect.y + 2))
            screen.blit(b_shadow, (b_rect.x + 2, b_rect.y + 2))
            screen.blit(colon_shadow, (colon_rect.x + 2, colon_rect.y + 2))

            # 메인 텍스트 그리기
            screen.blit(p_text, p_rect)
            screen.blit(colon_text, colon_rect)
            screen.blit(b_text, b_rect)

        except:
            pass

    def _draw_normal_score(self, screen, box_x, box_y, box_width, box_height,
                           player_score, boss_score, time_ms, sparkle_intensity,
                           cycle_progress, sparkle_duration, _scale=1.0):
        """일반 점수판"""
        # === 외곽 글로우 효과 ===
        glow_margin = 6
        glow_surface = pygame.Surface(
            (box_width + glow_margin * 2, box_height + glow_margin * 2),
            pygame.SRCALPHA
        )
        base_glow_alpha = 40 + int(60 * sparkle_intensity)
        glow_color = (255, 215, 100, base_glow_alpha)
        pygame.draw.rect(glow_surface, glow_color, glow_surface.get_rect(), border_radius=12)
        screen.blit(glow_surface, (box_x - glow_margin, box_y - glow_margin))

        # === 메인 박스 ===
        box_surface = pygame.Surface((box_width, box_height), pygame.SRCALPHA)

        for i in range(box_height):
            ratio = i / box_height
            r = int(35 - 15 * ratio)
            g = int(30 - 10 * ratio)
            b = int(50 - 20 * ratio)
            if sparkle_intensity > 0:
                r = min(255, r + int(30 * sparkle_intensity))
                g = min(255, g + int(25 * sparkle_intensity))
                b = min(255, b + int(20 * sparkle_intensity))
            pygame.draw.line(box_surface, (r, g, b, 230), (0, i), (box_width, i))

        highlight_color = (255, 255, 255, 30 + int(40 * sparkle_intensity))
        pygame.draw.line(box_surface, highlight_color, (4, 2), (box_width - 4, 2), 1)

        border_brightness = 180 + int(75 * sparkle_intensity)
        border_color = (border_brightness, int(border_brightness * 0.75), 50)
        pygame.draw.rect(box_surface, border_color, (0, 0, box_width, box_height), 2, border_radius=8)

        inner_border = (100, 80, 30, 150)
        pygame.draw.rect(box_surface, inner_border, (2, 2, box_width - 4, box_height - 4), 1, border_radius=6)

        screen.blit(box_surface, (box_x, box_y))

        # === 장식 다이아몬드 ===
        diamond_size = 6
        diamond_color = (255, 220, 100, 200 + int(55 * sparkle_intensity))
        left_diamond = [
            (box_x + 10, box_y + box_height // 2),
            (box_x + 10 + diamond_size, box_y + box_height // 2 - diamond_size),
            (box_x + 10 + diamond_size * 2, box_y + box_height // 2),
            (box_x + 10 + diamond_size, box_y + box_height // 2 + diamond_size)
        ]
        pygame.draw.polygon(screen, diamond_color[:3], left_diamond)
        right_diamond = [
            (box_x + box_width - 10 - diamond_size * 2, box_y + box_height // 2),
            (box_x + box_width - 10 - diamond_size, box_y + box_height // 2 - diamond_size),
            (box_x + box_width - 10, box_y + box_height // 2),
            (box_x + box_width - 10 - diamond_size, box_y + box_height // 2 + diamond_size)
        ]
        pygame.draw.polygon(screen, diamond_color[:3], right_diamond)

        # === 스코어 텍스트 ===
        try:
            _font_size = max(18, int(36 * _scale))
            score_font = pygame.font.Font(None, _font_size)

            p_color = (100, 180, 255)
            p_text = score_font.render(str(player_score), True, p_color)
            p_shadow = score_font.render(str(player_score), True, (0, 0, 0))

            colon_color = (255, 255, 255)
            colon_text = score_font.render(":", True, colon_color)

            b_color = (255, 100, 100)
            b_text = score_font.render(str(boss_score), True, b_color)
            b_shadow = score_font.render(str(boss_score), True, (0, 0, 0))

            center_x = box_x + box_width // 2
            center_y = box_y + box_height // 2
            score_offset = max(16, int(28 * _scale))

            colon_rect = colon_text.get_rect(center=(center_x, center_y))
            p_rect = p_text.get_rect(center=(center_x - score_offset, center_y))
            b_rect = b_text.get_rect(center=(center_x + score_offset, center_y))

            screen.blit(p_shadow, (p_rect.x + 2, p_rect.y + 2))
            screen.blit(b_shadow, (b_rect.x + 2, b_rect.y + 2))

            screen.blit(p_text, p_rect)
            screen.blit(colon_text, colon_rect)
            screen.blit(b_text, b_rect)

            # 반짝임 효과
            if sparkle_intensity > 0.1:
                sweep_progress = cycle_progress / sparkle_duration
                sweep_x = int(box_width * 1.5 * sweep_progress) - box_width // 4

                sweep_surface = pygame.Surface((box_width, box_height), pygame.SRCALPHA)
                sweep_width = 25
                sweep_alpha = int(120 * sparkle_intensity)

                for i in range(sweep_width):
                    line_alpha = int(sweep_alpha * (1 - abs(i - sweep_width // 2) / (sweep_width // 2)))
                    line_x = sweep_x + i
                    if 0 <= line_x < box_width:
                        pygame.draw.line(sweep_surface, (255, 255, 220, line_alpha),
                                       (line_x, 0), (line_x - 15, box_height))
                screen.blit(sweep_surface, (box_x, box_y))

                if sparkle_intensity > 0.5:
                    star_positions = [
                        (box_x + 6, box_y + 6),
                        (box_x + box_width - 6, box_y + 6),
                        (box_x + 6, box_y + box_height - 6),
                        (box_x + box_width - 6, box_y + box_height - 6),
                    ]
                    star_alpha = int(255 * sparkle_intensity)
                    star_size = int(3 + 2 * sparkle_intensity)

                    for sx, sy in star_positions:
                        pygame.draw.line(screen, (255, 255, 200, star_alpha),
                                       (sx - star_size, sy), (sx + star_size, sy), 1)
                        pygame.draw.line(screen, (255, 255, 200, star_alpha),
                                       (sx, sy - star_size), (sx, sy + star_size), 1)
                        diag = star_size * 0.7
                        pygame.draw.line(screen, (255, 255, 150, star_alpha // 2),
                                       (int(sx - diag), int(sy - diag)), (int(sx + diag), int(sy + diag)), 1)
                        pygame.draw.line(screen, (255, 255, 150, star_alpha // 2),
                                       (int(sx + diag), int(sy - diag)), (int(sx - diag), int(sy + diag)), 1)
        except:
            pass

    def draw_left_pillar_ui(self, screen, active_items=None, icon_size=(28, 28),
                             selected_index=0, cooldown_ms=10000, round_start_time=None,
                             alchemy_notices=None, max_slots=3):
        """게임 화면 하단 필러 영역에 가로 배치되는 액티브 아이템 슬롯 (max_slots에 따라 동적 크기)

        Args:
            screen: 그릴 surface
            active_items: 액티브 아이템 리스트
            icon_size: 아이콘 크기 튜플
            selected_index: 선택된 아이템 인덱스
            cooldown_ms: 쿨다운 시간 (ms)
            round_start_time: 라운드 시작 시간
            alchemy_notices: 연금술 알림 리스트
            max_slots: 최대 슬롯 수
        """
        # game_scale 비례 크기
        _s = self.game_width / self.original_game_width if self.original_game_width > 0 else 1.0
        SLOT_W = max(16, int(icon_size[0] * _s))
        SLOT_H = max(16, int(icon_size[1] * _s))
        slot_margin = max(1, int(2 * _s))   # 슬롯 간 여백
        box_padding = max(2, int(4 * _s))   # 박스 내부 패딩

        # 실제 아이템 수
        actual_item_count = len(active_items) if active_items else 0
        # 초과 아이템 수
        overflow_count = max(0, actual_item_count - max_slots)

        # === 메인 박스 (max_slots 기준) ===
        box_inner_width = max_slots * SLOT_W + (max_slots - 1) * slot_margin
        box_width = box_inner_width + box_padding * 2
        box_height = SLOT_H + box_padding * 2

        # === 오버플로우 박스 크기 미리 계산 ===
        overflow_box_width = 0
        if overflow_count > 0:
            overflow_inner_width = overflow_count * SLOT_W + (overflow_count - 1) * slot_margin
            overflow_box_width = overflow_inner_width + box_padding * 2 - 1  # -1은 메인 박스와 겹치는 부분

        # === 전체 너비 (메인 + 오버플로우) 기준 가운데 정렬 ===
        total_width = box_width + overflow_box_width
        # 하단 필러 영역 내 세로 중앙 배치 (잘림 방지)
        _bottom_pillar_y = self.game_offset_y + self.game_height
        _bottom_pillar_h = self.screen_height - _bottom_pillar_y
        box_y = _bottom_pillar_y + max(2, (_bottom_pillar_h - box_height) // 2)

        # 게임 영역 내 가운데 정렬
        game_area_right = self.game_offset_x + self.game_width
        total_start_x = self.game_offset_x + (self.game_width - total_width) // 2

        # 게임 영역 경계 체크
        if total_start_x < self.game_offset_x:
            total_start_x = self.game_offset_x
        if total_start_x + total_width > game_area_right:
            total_start_x = game_area_right - total_width

        box_x = total_start_x

        # 메인 박스 배경 그리기
        box_surface = pygame.Surface((box_width, box_height), pygame.SRCALPHA)
        box_surface.fill((15, 15, 25, 180))
        pygame.draw.rect(box_surface, (70, 70, 90), (0, 0, box_width, box_height), 1, border_radius=3)
        screen.blit(box_surface, (box_x, box_y))

        # === 초과 아이템용 임시 박스 (오버플로우) ===
        overflow_box_x = box_x + box_width - 1  # 메인 박스에 자연스럽게 붙임

        if overflow_count > 0 and overflow_box_width > 0:
            # 게임 영역을 벗어나지 않도록 클리핑
            actual_overflow_width = min(overflow_box_width + 1, game_area_right - overflow_box_x)

            if actual_overflow_width > 0:
                overflow_surface = pygame.Surface((actual_overflow_width, box_height), pygame.SRCALPHA)
                # 임시 박스 - 연하고 투명한 느낌
                overflow_surface.fill((15, 15, 25, 80))
                pygame.draw.rect(overflow_surface, (60, 60, 80, 100), (0, 0, actual_overflow_width, box_height), 1, border_radius=3)
                screen.blit(overflow_surface, (overflow_box_x, box_y))

        # 슬롯 시작 좌표
        slot_start_x = box_x + box_padding
        slot_start_y = box_y + box_padding

        current_time = pygame.time.get_ticks()

        if round_start_time is None:
            time_since_round_start = 10000
        else:
            time_since_round_start = current_time - round_start_time

        throwing_items = {"molotov", "grenade", "flare", "spider_mine", "banana", "dynamite"}

        # 슬롯 rect 리스트 (클릭/호버 감지용으로 반환)
        slot_rects = []

        # 전체 슬롯 그리기 (메인 + 오버플로우)
        total_slots = max(max_slots, actual_item_count)
        for i in range(total_slots):
            # 좌표 계산 (메인 박스 또는 오버플로우 박스)
            if i < max_slots:
                x = slot_start_x + i * (SLOT_W + slot_margin)
            else:
                # 오버플로우 박스 내 좌표
                overflow_idx = i - max_slots
                overflow_box_x_calc = box_x + box_width - 1  # 메인 박스에 붙음
                x = overflow_box_x_calc + box_padding + overflow_idx * (SLOT_W + slot_margin)
            y = slot_start_y

            # 슬롯이 게임 영역을 벗어나면 건너뛰기
            if x + SLOT_W > game_area_right:
                continue

            # 슬롯 rect 저장 (클릭/호버 감지용)
            slot_rects.append(pygame.Rect(x, y, SLOT_W, SLOT_H))

            # 🔧 최적화: 빈 슬롯 배경 캐시 사용
            slot_alpha = 120 if i < max_slots else 60
            slot_bg_key = (SLOT_W, SLOT_H, slot_alpha)
            if slot_bg_key not in self._slot_bg_cache:
                slot_bg = pygame.Surface((SLOT_W, SLOT_H), pygame.SRCALPHA)
                slot_bg.fill((0, 0, 0, slot_alpha))
                self._slot_bg_cache[slot_bg_key] = slot_bg
            screen.blit(self._slot_bg_cache[slot_bg_key], (x, y))

            # 아이템이 있는 경우
            item = active_items[i] if active_items and i < len(active_items) else None

            if item is None:
                # 빈 슬롯 테두리
                pygame.draw.rect(screen, (40, 40, 50), (x, y, SLOT_W, SLOT_H), 1)
                continue

            # 아이콘 표시
            item_name = item.get("name") or item.get("effect")

            # 전설 아이템 처리
            _LEGENDARY_ICON_NAMES = {"ragnarok_hammer", "hermes_shoes", "poseidon_trident",
                                     "odins_eye", "sacred_laurel", "angel_blessing", "transcendent_crown"}
            if item_name in _LEGENDARY_ICON_NAMES:
                try:
                    from legendary_items import get_legendary_manager
                    legendary_manager = get_legendary_manager()
                    legendary_item = legendary_manager.get_item(item_name) if legendary_manager else None
                except Exception:
                    legendary_item = None

                if legendary_item:
                    legendary_item.update(1 / 60.0, ui_mode=True)
                    legend_surface = pygame.Surface((SLOT_W, SLOT_H), pygame.SRCALPHA)
                    legendary_item.draw_icon(legend_surface, 0, 0, SLOT_W)
                    screen.blit(legend_surface, (x, y))
                elif item.get("icon"):
                    # 🔧 최적화: 스케일된 아이콘 캐시 사용 (슬롯 크기에 맞춤)
                    scaled_icon = self._get_scaled_icon(item, (SLOT_W, SLOT_H))
                    if scaled_icon:
                        screen.blit(scaled_icon, (x, y))
            elif "icon" in item and item["icon"]:
                # 🔧 최적화: 스케일된 아이콘 캐시 사용 (슬롯 크기에 맞춤)
                scaled_icon = self._get_scaled_icon(item, (SLOT_W, SLOT_H))
                if scaled_icon:
                    screen.blit(scaled_icon, (x, y))
            else:
                radius = int(SLOT_W * 0.28)
                center_x = x + SLOT_W // 2
                center_y = y + SLOT_H // 2
                color = item.get("color", (200, 200, 200))
                pygame.draw.circle(screen, color, (center_x, center_y), radius)

            # 쿨타임 표시
            if "last_use" in item:
                last_use = item["last_use"]
                elapsed = current_time - last_use
                if elapsed < cooldown_ms:
                    cooldown_ratio = elapsed / cooldown_ms
                    overlay_height = int(SLOT_H * (1 - cooldown_ratio))
                    if overlay_height > 0:
                        overlay = pygame.Surface((SLOT_W, overlay_height), pygame.SRCALPHA)
                        overlay.fill((0, 0, 0, 210))  # 더 짙은 쿨타임 오버레이
                        screen.blit(overlay, (x, y))
                    # 쿨타임 진행 중이면 반짝임 추적에서 제거
                    if i in self._cooldown_complete_flash:
                        del self._cooldown_complete_flash[i]
                else:
                    # 쿨타임 완료! 반짝임 효과 시작
                    if i not in self._cooldown_complete_flash:
                        self._cooldown_complete_flash[i] = current_time

                    # 반짝임 효과 (400ms 동안)
                    flash_start = self._cooldown_complete_flash[i]
                    flash_elapsed = current_time - flash_start
                    flash_duration = 400  # 0.4초

                    if flash_elapsed < flash_duration:
                        # 한 번 크게 반짝이고 사라지는 효과
                        progress = flash_elapsed / flash_duration
                        # 초반에 빠르게 최대 밝기, 이후 서서히 사라짐
                        if progress < 0.2:
                            # 처음 20%: 빠르게 최대 밝기로
                            pulse = progress / 0.2
                        else:
                            # 나머지 80%: 서서히 사라짐
                            pulse = 1.0 - ((progress - 0.2) / 0.8)

                        flash_alpha = int(pulse * 255)
                        # 내부 밝은 플래시
                        flash_surface = pygame.Surface((SLOT_W, SLOT_H), pygame.SRCALPHA)
                        flash_surface.fill((255, 255, 220, flash_alpha))
                        screen.blit(flash_surface, (x, y))

                        # 외곽 글로우 테두리 (더 눈에 띄게)
                        glow_alpha = int(pulse * 200)
                        pygame.draw.rect(screen, (255, 230, 100, glow_alpha),
                                       (x - 2, y - 2, SLOT_W + 4, SLOT_H + 4), 3)

            # 투척류 카운트다운 (3초 제한)
            if item_name in throwing_items and time_since_round_start < 3000:
                remaining_seconds = int((3000 - time_since_round_start) / 1000) + 1
                # 🔧 최적화: 오버레이 캐시 사용
                overlay_key = (SLOT_W, SLOT_H, 150)
                if overlay_key not in self._overlay_cache:
                    overlay = pygame.Surface((SLOT_W, SLOT_H), pygame.SRCALPHA)
                    overlay.fill((0, 0, 0, 150))
                    self._overlay_cache[overlay_key] = overlay
                screen.blit(self._overlay_cache[overlay_key], (x, y))
                try:
                    # 🔧 최적화: 캐시된 폰트 사용
                    if self._slot_font_small:
                        text = self._slot_font_small.render(str(remaining_seconds), True, (255, 100, 100))
                        text_rect = text.get_rect(center=(x + SLOT_W // 2, y + SLOT_H // 2))
                        screen.blit(text, text_rect)
                except:
                    pass

            # 선택된 아이템 테두리
            if i == selected_index:
                pygame.draw.rect(screen, (255, 220, 80), (x - 1, y - 1, SLOT_W + 2, SLOT_H + 2), 2)
            elif i >= max_slots:
                # 오버플로우 아이템 테두리 (연하고 투명한 느낌)
                pygame.draw.rect(screen, (50, 50, 65), (x, y, SLOT_W, SLOT_H), 1)
            else:
                pygame.draw.rect(screen, (60, 60, 80), (x, y, SLOT_W, SLOT_H), 1)

            # 슬롯 번호 표시 (좌측 상단 모서리)
            # 🔧 최적화: 캐시된 폰트 사용
            if self._slot_font_num:
                try:
                    slot_num = i + 1  # 1부터 시작
                    # 숫자 텍스트 (흰색, 검은 테두리)
                    num_text = self._slot_font_num.render(str(slot_num), True, (255, 255, 255))
                    # 테두리 효과
                    num_outline = self._slot_font_num.render(str(slot_num), True, (0, 0, 0))
                    num_x = x + 3
                    num_y = y + 2
                    # 테두리 그리기 (더 두꺼운 테두리)
                    for ox in [-1, 0, 1]:
                        for oy in [-1, 0, 1]:
                            if ox != 0 or oy != 0:
                                screen.blit(num_outline, (num_x + ox, num_y + oy))
                    # 메인 텍스트
                    screen.blit(num_text, (num_x, num_y))
                except:
                    pass

            # 연금술 발동 효과 (화려한 무지개 글로우 + 텍스트)
            if alchemy_notices:
                for notice in alchemy_notices:
                    if notice.get("slot_index") == i and notice.get("timer", 0) > 0:
                        remaining = notice.get("timer", 0)
                        duration = max(1, notice.get("duration", 60))
                        ratio = remaining / duration
                        progress = 1.0 - ratio

                        time_ms = pygame.time.get_ticks()
                        pulse = math.sin(time_ms * 0.05) * 0.5 + 0.5  # 0~1 진동

                        # 무지개 색상 변화
                        hue_shift = (time_ms * 0.3) % 360
                        h = hue_shift / 60.0
                        c = 1.0
                        x_c = c * (1 - abs(h % 2 - 1))
                        if h < 1:
                            r, g, b = c, x_c, 0
                        elif h < 2:
                            r, g, b = x_c, c, 0
                        elif h < 3:
                            r, g, b = 0, c, x_c
                        elif h < 4:
                            r, g, b = 0, x_c, c
                        elif h < 5:
                            r, g, b = x_c, 0, c
                        else:
                            r, g, b = c, 0, x_c
                        base_color = (int(r * 255), int(g * 255), int(b * 255))

                        glow_intensity = pulse * ratio

                        # 바깥쪽 글로우
                        glow_margin = 4
                        glow_surface = pygame.Surface(
                            (SLOT_W + glow_margin * 2, SLOT_H + glow_margin * 2),
                            pygame.SRCALPHA
                        )
                        glow_alpha = int(150 * glow_intensity)
                        glow_color = (*base_color, glow_alpha)
                        pygame.draw.rect(glow_surface, glow_color, glow_surface.get_rect(), border_radius=4)
                        screen.blit(glow_surface, (x - glow_margin, y - glow_margin))

                        # 화려한 테두리
                        border_width = int(2 + pulse * 2)
                        bright_color = (
                            min(255, base_color[0] + int(pulse * 100)),
                            min(255, base_color[1] + int(pulse * 100)),
                            min(255, base_color[2] + int(pulse * 100))
                        )
                        pygame.draw.rect(screen, bright_color,
                                       (x - 2, y - 2, SLOT_W + 4, SLOT_H + 4), border_width)

                        # "연금술!" 텍스트 (위로 떠오르며 페이드아웃)
                        # 🔧 최적화: 캐시된 한글 폰트 사용
                        if self._slot_font_notice:
                            try:
                                alpha = int(220 * (ratio ** 0.9))
                                y_offset = -12 - progress * 20
                                text = "연금술!"
                                text_surface = self._slot_font_notice.render(text, True, (200, 150, 255))
                                text_surface.set_alpha(alpha)
                                text_rect = text_surface.get_rect(center=(x + SLOT_W // 2, y + y_offset))
                                # 그림자
                                shadow = self._slot_font_notice.render(text, True, (0, 0, 0))
                                shadow.set_alpha(int(alpha * 0.5))
                                screen.blit(shadow, (text_rect.x + 1, text_rect.y + 1))
                                screen.blit(text_surface, text_rect)
                            except:
                                pass
                        break

        # 슬롯 rect 리스트 반환 (클릭/호버 감지용)
        return slot_rects

    def draw_arena_skill_slots(self, screen, skills, hero_color, icon_size=(42, 42)):
        """투기장 모드: 하단 영웅 스킬 아이콘 2개를 필러 하단에 표시

        Args:
            screen: 그릴 Surface (REAL_SCREEN)
            skills: list of HeroSkill 인스턴스 (2개)
            hero_color: 영웅 색상 tuple (R, G, B)
            icon_size: 아이콘 크기 (기본 42x42, active item과 동일)

        Returns:
            list of (pygame.Rect, HeroSkill): 슬롯 rect + 스킬 인스턴스 쌍 (호버/툴팁 감지용)
        """
        import math
        from downtown.hero_skill_icons import get_skill_icon

        # game_scale 비례 크기
        _s = self.game_width / self.original_game_width if self.original_game_width > 0 else 1.0
        SLOT_W = max(16, int(icon_size[0] * _s))
        SLOT_H = max(16, int(icon_size[1] * _s))
        slot_margin = max(2, int(4 * _s))   # 슬롯 간 여백 (스킬 2개라 좀 더 넓게)
        box_padding = max(2, int(4 * _s))

        max_slots = min(len(skills), 2)
        if max_slots == 0:
            return []

        # 박스 크기 계산
        box_inner_width = max_slots * SLOT_W + (max_slots - 1) * slot_margin
        box_width = box_inner_width + box_padding * 2
        box_height = SLOT_H + box_padding * 2

        # 위치: draw_left_pillar_ui()와 동일 - 하단 필러 영역 내 세로 중앙 배치
        _bottom_pillar_y = self.game_offset_y + self.game_height
        _bottom_pillar_h = self.screen_height - _bottom_pillar_y
        box_y = _bottom_pillar_y + max(2, (_bottom_pillar_h - box_height) // 2)
        game_area_right = self.game_offset_x + self.game_width
        box_x = self.game_offset_x + (self.game_width - box_width) // 2

        # 경계 체크
        if box_x < self.game_offset_x:
            box_x = self.game_offset_x
        if box_x + box_width > game_area_right:
            box_x = game_area_right - box_width

        # 박스 배경 (draw_left_pillar_ui와 동일 스타일)
        box_surface = pygame.Surface((box_width, box_height), pygame.SRCALPHA)
        box_surface.fill((15, 15, 25, 180))
        pygame.draw.rect(box_surface, (70, 70, 90), (0, 0, box_width, box_height), 1, border_radius=3)
        screen.blit(box_surface, (box_x, box_y))

        slot_start_x = box_x + box_padding
        slot_start_y = box_y + box_padding
        current_time = pygame.time.get_ticks()

        slot_results = []

        for i in range(max_slots):
            skill = skills[i]
            x = slot_start_x + i * (SLOT_W + slot_margin)
            y = slot_start_y

            # 슬롯 배경
            slot_bg_key = (SLOT_W, SLOT_H, 120)
            if slot_bg_key not in self._slot_bg_cache:
                slot_bg = pygame.Surface((SLOT_W, SLOT_H), pygame.SRCALPHA)
                slot_bg.fill((0, 0, 0, 120))
                self._slot_bg_cache[slot_bg_key] = slot_bg
            screen.blit(self._slot_bg_cache[slot_bg_key], (x, y))

            # 스킬 아이콘 그리기
            icon_cache_key = (skill.skill_id, SLOT_W, SLOT_H)
            if icon_cache_key not in self._arena_skill_icon_cache:
                base_icon = get_skill_icon(skill.skill_id, 32)
                if base_icon:
                    scaled = pygame.transform.smoothscale(base_icon, (SLOT_W, SLOT_H))
                    self._arena_skill_icon_cache[icon_cache_key] = scaled
                else:
                    self._arena_skill_icon_cache[icon_cache_key] = None

            cached_icon = self._arena_skill_icon_cache[icon_cache_key]
            if cached_icon:
                screen.blit(cached_icon, (x, y))

            # 쿨타임 오버레이
            prev_cd = self._arena_prev_cooldowns.get(i, 0)

            if skill.current_cooldown > 0 and skill.cooldown > 0:
                cooldown_ratio = min(1.0, skill.current_cooldown / skill.cooldown)
                overlay_height = int(SLOT_H * cooldown_ratio)
                if overlay_height > 0:
                    overlay_key = (SLOT_W, overlay_height, 180)
                    if overlay_key not in self._overlay_cache:
                        ov = pygame.Surface((SLOT_W, overlay_height), pygame.SRCALPHA)
                        ov.fill((0, 0, 0, 180))
                        self._overlay_cache[overlay_key] = ov
                    screen.blit(self._overlay_cache[overlay_key], (x, y))

                # 남은 초 표시
                cd_text = str(int(skill.current_cooldown) + 1)
                if self._slot_font_small:
                    text_surf = self._slot_font_small.render(cd_text, True, (255, 255, 255))
                    text_rect = text_surf.get_rect(center=(x + SLOT_W // 2, y + SLOT_H // 2))
                    screen.blit(text_surf, text_rect)

                # 쿨다운 중이면 플래시 추적 제거
                if i in self._arena_cooldown_flash:
                    del self._arena_cooldown_flash[i]

            else:
                # 쿨다운 완료 감지 (이전 > 0 → 현재 ≤ 0)
                if prev_cd > 0:
                    self._arena_cooldown_flash[i] = current_time

                # 쿨다운 완료 플래시 (400ms)
                if i in self._arena_cooldown_flash:
                    flash_start = self._arena_cooldown_flash[i]
                    flash_elapsed = current_time - flash_start
                    if flash_elapsed < 400:
                        progress = flash_elapsed / 400.0
                        if progress < 0.2:
                            pulse = progress / 0.2
                        else:
                            pulse = 1.0 - ((progress - 0.2) / 0.8)
                        flash_alpha = int(max(0, min(255, pulse * 255)))
                        flash_surface = pygame.Surface((SLOT_W, SLOT_H), pygame.SRCALPHA)
                        flash_surface.fill((255, 255, 220, flash_alpha))
                        screen.blit(flash_surface, (x, y))
                        # 글로우 테두리
                        glow_alpha = int(max(0, min(255, pulse * 200)))
                        glow_rect = (x - 2, y - 2, SLOT_W + 4, SLOT_H + 4)
                        glow_surf = pygame.Surface((SLOT_W + 4, SLOT_H + 4), pygame.SRCALPHA)
                        pygame.draw.rect(glow_surf, (255, 230, 100, glow_alpha),
                                         (0, 0, SLOT_W + 4, SLOT_H + 4), 3, border_radius=4)
                        screen.blit(glow_surf, (x - 2, y - 2))
                    else:
                        del self._arena_cooldown_flash[i]

            # 쿨다운 상태 저장 (다음 프레임 비교용)
            self._arena_prev_cooldowns[i] = skill.current_cooldown

            # 스킬 활성 중 표시 (금색 글로우 펄스)
            if skill.is_active:
                anim_time = current_time / 1000.0
                pulse = math.sin(anim_time * 4) * 0.3 + 0.7
                alpha = int(150 * pulse)
                glow_surf = pygame.Surface((SLOT_W + 4, SLOT_H + 4), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (255, 255, 100, alpha),
                                 (0, 0, SLOT_W + 4, SLOT_H + 4), 3, border_radius=4)
                screen.blit(glow_surf, (x - 2, y - 2))
            elif skill.can_use():
                # 사용 가능 - 영웅 색상 테두리
                border_surf = pygame.Surface((SLOT_W + 4, SLOT_H + 4), pygame.SRCALPHA)
                r, g, b = hero_color[:3]
                pygame.draw.rect(border_surf, (r, g, b, 180),
                                 (0, 0, SLOT_W + 4, SLOT_H + 4), 2, border_radius=3)
                screen.blit(border_surf, (x - 2, y - 2))
            else:
                # 쿨다운 중 - 어두운 테두리
                pygame.draw.rect(screen, (60, 60, 80),
                                 (x, y, SLOT_W, SLOT_H), 1, border_radius=2)

            # rect + skill 쌍 저장
            slot_results.append((pygame.Rect(x, y, SLOT_W, SLOT_H), skill))

        return slot_results

    def draw_guard_stance_toggle(self, screen, stance_mode, game_scale=1.0):
        """투기장 호위무사 공격/수비 모드 토글 버튼 (하단 필러 영역)

        Args:
            screen: REAL_SCREEN
            stance_mode: "attack" or "defense"
            game_scale: 게임 스케일 팩터
        Returns:
            pygame.Rect: 버튼 히트박스 (클릭 감지용), None if 그릴 수 없음
        """
        import math

        _s = game_scale if game_scale > 0 else 1.0
        btn_w = max(20, int(54 * _s))
        btn_h = max(20, int(54 * _s))

        # 위치: 하단 필러 영역, 스킬 슬롯 오른쪽
        _bottom_pillar_y = self.game_offset_y + self.game_height
        _bottom_pillar_h = self.screen_height - _bottom_pillar_y
        if _bottom_pillar_h < btn_h + 4:
            return None

        btn_y = _bottom_pillar_y + max(2, (_bottom_pillar_h - btn_h) // 2)
        # 게임 영역 오른쪽 끝 근처에 배치
        game_area_right = self.game_offset_x + self.game_width
        btn_x = game_area_right - btn_w - max(4, int(8 * _s))

        is_defense = (stance_mode == "defense")

        # 아이콘 서피스 (SRCALPHA로 고품질 렌더링)
        _icon_surf = pygame.Surface((btn_w, btn_h), pygame.SRCALPHA)
        cx = btn_w // 2
        cy = btn_h // 2
        icon_s = max(5, int(18 * _s))

        if is_defense:
            # ──── 고퀄리티 방패 아이콘 ────
            # 배경 그라데이션 (진한 남색, 불투명)
            for _gi in range(btn_h):
                _gr = int(20 + 15 * (_gi / btn_h))
                _gg = int(35 + 20 * (_gi / btn_h))
                _gb = int(70 + 30 * (_gi / btn_h))
                pygame.draw.line(_icon_surf, (_gr, _gg, _gb, 255), (0, _gi), (btn_w, _gi))

            # 방패 본체 - 넓은 육각 실드 형태
            _sw = icon_s  # 방패 반너비
            _sh = int(icon_s * 1.3)  # 방패 반높이
            _shield_body = [
                (cx, cy - _sh),                           # 상단 꼭지
                (cx + _sw, cy - int(_sh * 0.55)),         # 우상단
                (cx + _sw, cy + int(_sh * 0.15)),         # 우중단
                (cx + int(_sw * 0.6), cy + int(_sh * 0.65)),  # 우하단
                (cx, cy + _sh),                           # 하단 꼭지
                (cx - int(_sw * 0.6), cy + int(_sh * 0.65)),  # 좌하단
                (cx - _sw, cy + int(_sh * 0.15)),         # 좌중단
                (cx - _sw, cy - int(_sh * 0.55)),         # 좌상단
            ]
            # 방패 그림자
            _shadow_pts = [(px + 1, py + 1) for px, py in _shield_body]
            pygame.draw.polygon(_icon_surf, (10, 15, 35, 255), _shadow_pts)
            # 방패 몸체 (진한 파란색)
            pygame.draw.polygon(_icon_surf, (50, 100, 180, 255), _shield_body)
            # 방패 상단 하이라이트 (밝은 영역)
            _highlight_body = [
                (cx, cy - _sh + 2),
                (cx + _sw - 2, cy - int(_sh * 0.55) + 1),
                (cx + _sw - 2, cy - int(_sh * 0.2)),
                (cx - _sw + 2, cy - int(_sh * 0.2)),
                (cx - _sw + 2, cy - int(_sh * 0.55) + 1),
            ]
            pygame.draw.polygon(_icon_surf, (80, 150, 230, 255), _highlight_body)
            # 방패 테두리 (밝은 금속)
            pygame.draw.polygon(_icon_surf, (140, 200, 255, 255), _shield_body, max(1, int(1.5 * _s)))
            # 방패 내부 십자 문양
            _cross_w = max(1, int(1.2 * _s))
            _cross_len = int(_sh * 0.55)
            _cross_c = (180, 220, 255, 255)
            pygame.draw.line(_icon_surf, _cross_c, (cx, cy - _cross_len), (cx, cy + _cross_len), _cross_w)
            pygame.draw.line(_icon_surf, _cross_c, (cx - int(_cross_len * 0.6), cy), (cx + int(_cross_len * 0.6), cy), _cross_w)
            # 방패 중앙 보석 (작은 원)
            pygame.draw.circle(_icon_surf, (120, 200, 255, 255), (cx, cy), max(2, int(2.5 * _s)))
            pygame.draw.circle(_icon_surf, (200, 240, 255, 255), (cx, cy), max(1, int(1.5 * _s)))
        else:
            # ──── 고퀄리티 검 아이콘 ────
            # 배경 그라데이션 (진한 적색, 불투명)
            for _gi in range(btn_h):
                _gr = int(65 + 25 * (_gi / btn_h))
                _gg = int(20 + 15 * (_gi / btn_h))
                _gb = int(20 + 15 * (_gi / btn_h))
                pygame.draw.line(_icon_surf, (_gr, _gg, _gb, 255), (0, _gi), (btn_w, _gi))

            # 칼날 (위→아래, 폴리곤으로 두께 표현)
            _bl = int(icon_s * 1.3)  # 칼날 길이
            _bw = max(2, int(2.5 * _s))  # 칼날 반너비
            _tip_y = cy - _bl  # 칼끝
            _guard_y = cy + int(_bl * 0.15)  # 가드 위치
            _blade_pts = [
                (cx, _tip_y),                    # 칼끝
                (cx + _bw + 1, _guard_y - 2),    # 우측 날
                (cx + _bw, _guard_y),             # 우측 가드접점
                (cx - _bw, _guard_y),             # 좌측 가드접점
                (cx - _bw - 1, _guard_y - 2),    # 좌측 날
            ]
            # 칼날 그림자
            _bs_pts = [(px + 1, py + 1) for px, py in _blade_pts]
            pygame.draw.polygon(_icon_surf, (30, 10, 10, 255), _bs_pts)
            # 칼날 본체 (은색 그라데이션)
            pygame.draw.polygon(_icon_surf, (200, 210, 220, 255), _blade_pts)
            # 칼날 좌측 어두운면
            pygame.draw.line(_icon_surf, (140, 145, 155, 255),
                           (cx, _tip_y), (cx - _bw - 1, _guard_y - 2), 1)
            # 칼날 중앙 하이라이트 (날 반사광)
            pygame.draw.line(_icon_surf, (240, 245, 255, 255),
                           (cx, _tip_y + 2), (cx, _guard_y - 1), max(1, int(1 * _s)))
            # 칼날 테두리
            pygame.draw.polygon(_icon_surf, (160, 170, 190, 255), _blade_pts, 1)

            # 가드 (크로스가드 - 가로 직사각형)
            _gw = int(icon_s * 0.9)  # 가드 반너비
            _gh = max(2, int(2.5 * _s))  # 가드 반높이
            _guard_pts = [
                (cx - _gw, _guard_y - _gh),
                (cx + _gw, _guard_y - _gh),
                (cx + _gw + 1, _guard_y),
                (cx + _gw, _guard_y + _gh),
                (cx - _gw, _guard_y + _gh),
                (cx - _gw - 1, _guard_y),
            ]
            pygame.draw.polygon(_icon_surf, (180, 150, 80, 255), _guard_pts)  # 금색 가드
            pygame.draw.polygon(_icon_surf, (230, 200, 120, 255), _guard_pts, 1)  # 테두리
            # 가드 하이라이트
            pygame.draw.line(_icon_surf, (255, 230, 150, 255),
                           (cx - _gw + 2, _guard_y - _gh + 1), (cx + _gw - 2, _guard_y - _gh + 1), 1)

            # 손잡이 (그립)
            _handle_top = _guard_y + _gh
            _handle_len = max(3, int(4 * _s))
            _hw = max(1, int(1.5 * _s))
            # 그립 가죽 (갈색)
            pygame.draw.line(_icon_surf, (120, 80, 40, 255),
                           (cx, _handle_top), (cx, _handle_top + _handle_len), max(2, int(3 * _s)))
            # 그립 감김 패턴
            for _wi in range(_handle_len):
                if _wi % 2 == 0:
                    pygame.draw.line(_icon_surf, (160, 110, 60, 255),
                                   (cx - _hw, _handle_top + _wi), (cx + _hw, _handle_top + _wi), 1)

            # 폼멜 (손잡이 끝 장식)
            _pommel_y = _handle_top + _handle_len + 1
            pygame.draw.circle(_icon_surf, (200, 160, 60, 255), (cx, _pommel_y), max(2, int(2 * _s)))
            pygame.draw.circle(_icon_surf, (255, 220, 100, 255), (cx, _pommel_y), max(1, int(1.2 * _s)))

        # 테두리 (둥근 프레임)
        border_color = (80, 150, 255) if is_defense else (255, 100, 80)
        pygame.draw.rect(_icon_surf, border_color,
                         (0, 0, btn_w, btn_h), 2, border_radius=4)
        # 내부 글로우 테두리
        _inner_glow = (60, 120, 220, 255) if is_defense else (220, 80, 60, 255)
        pygame.draw.rect(_icon_surf, _inner_glow,
                         (2, 2, btn_w - 4, btn_h - 4), 1, border_radius=3)

        screen.blit(_icon_surf, (btn_x, btn_y))

        # 모드 텍스트
        try:
            font_size = max(8, int(9 * _s))
            font = self._get_font(font_size)
            label = "수비" if is_defense else "공격"
            text_color = (150, 200, 255) if is_defense else (255, 180, 150)
            text_surf = font.render(label, True, text_color)
            text_rect = text_surf.get_rect(centerx=cx, top=btn_y + btn_h + max(1, int(2 * _s)))
            screen.blit(text_surf, text_rect)
        except Exception:
            pass

        return pygame.Rect(btn_x, btn_y, btn_w, btn_h)

    def draw_right_pillar_ui(self, screen, player_score=0, boss_score=0,
                             boss_gauge=0, boss_gauge_max=500,
                             player_gauge=0, player_gauge_max=100,
                             player_tokens=1, player_max_tokens=3):
        """오른쪽 필러 UI 그리기 (스코어 + 보스게이지 상단, 플레이어 게이지 하단)

        Args:
            screen: 그릴 surface
            player_score: 플레이어 점수
            boss_score: 보스 점수
            boss_gauge: 보스 게이지 현재값
            boss_gauge_max: 보스 게이지 최대값
            player_gauge: 플레이어 게이지 현재값
            player_gauge_max: 플레이어 게이지 최대값
            player_tokens: 플레이어 토큰 수
            player_max_tokens: 플레이어 최대 토큰 수
        """
        if self.right_pillar_width < 60:
            return  # 필러가 너무 좁으면 그리지 않음

        right_x = self.game_offset_x + self.game_width

        # === 상단: 스코어 + 보스 게이지 박스 ===
        top_box_width = 60
        top_box_height = 140
        top_box_x = right_x + (self.right_pillar_width - top_box_width) // 2
        top_box_y = 20

        self.draw_pillar_ui_box(screen, top_box_x, top_box_y, top_box_width, top_box_height)

        # 스코어 표시 (상단)
        self._draw_score_in_box(screen, top_box_x, top_box_y, top_box_width,
                                player_score, boss_score)

        # 보스 게이지 표시 (스코어 아래)
        gauge_y = top_box_y + 50
        self._draw_boss_gauge_in_box(screen, top_box_x, gauge_y, top_box_width,
                                     boss_gauge, boss_gauge_max)

        # === 하단: 플레이어 게이지 박스 ===
        bottom_box_width = 60
        bottom_box_height = 160
        bottom_box_x = right_x + (self.right_pillar_width - bottom_box_width) // 2
        bottom_box_y = self.screen_height - bottom_box_height - 20

        self.draw_pillar_ui_box(screen, bottom_box_x, bottom_box_y, bottom_box_width, bottom_box_height)

        # 플레이어 게이지 표시
        self._draw_player_gauge_in_box(screen, bottom_box_x, bottom_box_y,
                                       bottom_box_width, bottom_box_height,
                                       player_gauge, player_gauge_max,
                                       player_tokens, player_max_tokens)

    def _draw_score_in_box(self, screen, box_x, box_y, box_width, player_score, boss_score):
        """박스 내부에 스코어 표시"""
        try:
            # 스코어 폰트
            score_font = pygame.font.Font(None, 28)

            # "SCORE" 레이블
            label_font = pygame.font.Font(None, 12)
            label = label_font.render("SCORE", True, (150, 150, 180))
            label_x = box_x + (box_width - label.get_width()) // 2
            screen.blit(label, (label_x, box_y + 5))

            # 점수 (플레이어 : 보스)
            score_text = f"{player_score}:{boss_score}"
            score_surface = score_font.render(score_text, True, (255, 255, 255))
            score_x = box_x + (box_width - score_surface.get_width()) // 2
            screen.blit(score_surface, (score_x, box_y + 20))
        except:
            pass

    def _draw_boss_gauge_in_box(self, screen, box_x, gauge_y, box_width,
                                 boss_gauge, boss_gauge_max):
        """박스 내부에 보스 게이지 표시"""
        try:
            # "BOSS" 레이블
            label_font = pygame.font.Font(None, 12)
            label = label_font.render("BOSS", True, (150, 150, 180))
            label_x = box_x + (box_width - label.get_width()) // 2
            screen.blit(label, (label_x, gauge_y))

            # 게이지 바 (세로)
            bar_width = 14
            bar_height = 70
            bar_x = box_x + (box_width - bar_width) // 2
            bar_y = gauge_y + 15

            # 배경
            pygame.draw.rect(screen, (40, 40, 50),
                           (bar_x, bar_y, bar_width, bar_height), border_radius=3)

            # 게이지 채우기
            if boss_gauge_max > 0:
                fill_ratio = min(boss_gauge / boss_gauge_max, 1.0)
                fill_height = int(bar_height * fill_ratio)
                if fill_height > 0:
                    # 게이지 색상 (빨간색 계열)
                    gauge_color = (200, 60, 60) if boss_gauge < boss_gauge_max else (255, 100, 100)
                    pygame.draw.rect(screen, gauge_color,
                                   (bar_x, bar_y + bar_height - fill_height,
                                    bar_width, fill_height), border_radius=3)

            # 테두리
            pygame.draw.rect(screen, (80, 80, 100),
                           (bar_x, bar_y, bar_width, bar_height), 1, border_radius=3)
        except:
            pass

    def _draw_player_gauge_in_box(self, screen, box_x, box_y, box_width, box_height,
                                   player_gauge, player_gauge_max,
                                   player_tokens, player_max_tokens):
        """박스 내부에 플레이어 게이지 표시"""
        try:
            # "PLAYER" 레이블
            label_font = pygame.font.Font(None, 12)
            label = label_font.render("PLAYER", True, (150, 150, 180))
            label_x = box_x + (box_width - label.get_width()) // 2
            screen.blit(label, (label_x, box_y + 5))

            # 게이지 바 (세로)
            bar_width = 14
            bar_height = 100
            bar_x = box_x + (box_width - bar_width) // 2
            bar_y = box_y + 20

            # 배경
            pygame.draw.rect(screen, (40, 40, 50),
                           (bar_x, bar_y, bar_width, bar_height), border_radius=3)

            # 게이지 채우기
            if player_gauge_max > 0:
                fill_ratio = min(player_gauge / player_gauge_max, 1.0)
                fill_height = int(bar_height * fill_ratio)
                if fill_height > 0:
                    # 게이지 색상 (파란색/녹색 계열)
                    gauge_color = (60, 150, 200) if player_gauge < player_gauge_max else (100, 200, 255)
                    pygame.draw.rect(screen, gauge_color,
                                   (bar_x, bar_y + bar_height - fill_height,
                                    bar_width, fill_height), border_radius=3)

            # 테두리
            pygame.draw.rect(screen, (80, 80, 100),
                           (bar_x, bar_y, bar_width, bar_height), 1, border_radius=3)

            # 토큰 표시 (게이지 바 아래)
            token_y = bar_y + bar_height + 10
            token_radius = 5
            token_spacing = 14
            total_width = player_max_tokens * token_spacing
            token_start_x = box_x + (box_width - total_width) // 2 + token_spacing // 2

            for i in range(player_max_tokens):
                tx = token_start_x + i * token_spacing
                if i < player_tokens:
                    # 활성 토큰 (빨간색)
                    pygame.draw.circle(screen, (255, 80, 80), (tx, token_y), token_radius)
                    pygame.draw.circle(screen, (255, 150, 150), (tx, token_y), token_radius, 1)
                else:
                    # 비활성 토큰 (어두운 색)
                    pygame.draw.circle(screen, (60, 40, 40), (tx, token_y), token_radius)
                    pygame.draw.circle(screen, (100, 80, 80), (tx, token_y), token_radius, 1)
        except:
            pass

    def _create_rage_indicator_icon(self):
        """광폭화 인디케이터 아이콘 생성 (공포스러운 악마 - 세로가 긴 비율)"""
        try:
            # 세로가 더 긴 비율
            icon_w, icon_h = 52, 68
            self._rage_icon_w = icon_w
            self._rage_icon_h = icon_h
            self._rage_icon_surface = pygame.Surface((icon_w, icon_h), pygame.SRCALPHA)

            cx = icon_w // 2
            cy = icon_h // 2

            # === 1. 어둠의 배경 (검은 연기/그림자) ===
            for i in range(6):
                alpha = 50 - i * 8
                shrink = i * 3
                pygame.draw.ellipse(self._rage_icon_surface, (10, 0, 0, alpha),
                    (shrink, shrink + 4, icon_w - shrink * 2, icon_h - shrink * 2 - 4))

            # === 2. 얼굴 베이스 (어두운 붉은 피부 - 공포스러운 질감) ===
            face_w, face_h = 40, 54
            face_x, face_y = (icon_w - face_w) // 2, 8

            # 깊은 그림자
            pygame.draw.ellipse(self._rage_icon_surface, (25, 5, 5),
                (face_x - 2, face_y + 3, face_w + 4, face_h))
            # 어두운 피부 베이스
            pygame.draw.ellipse(self._rage_icon_surface, (90, 15, 10),
                (face_x, face_y, face_w, face_h))
            # 중간 톤 (붉은 피부)
            pygame.draw.ellipse(self._rage_icon_surface, (140, 25, 18),
                (face_x + 2, face_y + 2, face_w - 4, face_h - 6))
            # 미세한 하이라이트 (이마)
            pygame.draw.ellipse(self._rage_icon_surface, (180, 40, 30, 180),
                (face_x + 6, face_y + 4, face_w - 12, 16))

            # === 3. 깊은 균열/주름 (공포 효과) ===
            crack_dark = (40, 8, 5)
            crack_glow = (120, 40, 20)
            # 이마 세로 균열
            pygame.draw.line(self._rage_icon_surface, crack_dark, (cx, face_y + 8), (cx - 2, face_y + 18), 2)
            pygame.draw.line(self._rage_icon_surface, crack_glow, (cx + 1, face_y + 8), (cx - 1, face_y + 18), 1)
            # 왼쪽 볼 균열
            pygame.draw.line(self._rage_icon_surface, crack_dark, (face_x + 6, face_y + 20), (face_x + 10, face_y + 38), 1)
            pygame.draw.line(self._rage_icon_surface, crack_dark, (face_x + 8, face_y + 28), (face_x + 4, face_y + 34), 1)
            # 오른쪽 볼 균열
            pygame.draw.line(self._rage_icon_surface, crack_dark, (face_x + face_w - 6, face_y + 20), (face_x + face_w - 10, face_y + 38), 1)
            pygame.draw.line(self._rage_icon_surface, crack_dark, (face_x + face_w - 8, face_y + 28), (face_x + face_w - 4, face_y + 34), 1)

            # === 4. 뿔 (더 크고 날카롭고 위협적) ===
            # 왼쪽 뿔 - 그림자
            pygame.draw.polygon(self._rage_icon_surface, (30, 25, 10),
                [(10, 20), (2, -2), (20, 16)])
            # 왼쪽 뿔 - 베이스 (어두운 금색)
            pygame.draw.polygon(self._rage_icon_surface, (150, 120, 45),
                [(9, 18), (3, 0), (18, 14)])
            # 왼쪽 뿔 - 중간 하이라이트
            pygame.draw.polygon(self._rage_icon_surface, (200, 170, 80),
                [(8, 14), (4, 2), (14, 12)])
            # 왼쪽 뿔 - 밝은 하이라이트
            pygame.draw.polygon(self._rage_icon_surface, (240, 215, 140),
                [(6, 10), (4, 3), (10, 9)])
            # 왼쪽 뿔 - 끝 광택
            pygame.draw.polygon(self._rage_icon_surface, (255, 250, 210),
                [(5, 5), (4, 1), (7, 5)])

            # 오른쪽 뿔
            pygame.draw.polygon(self._rage_icon_surface, (30, 25, 10),
                [(icon_w - 10, 20), (icon_w - 2, -2), (icon_w - 20, 16)])
            pygame.draw.polygon(self._rage_icon_surface, (150, 120, 45),
                [(icon_w - 9, 18), (icon_w - 3, 0), (icon_w - 18, 14)])
            pygame.draw.polygon(self._rage_icon_surface, (200, 170, 80),
                [(icon_w - 8, 14), (icon_w - 4, 2), (icon_w - 14, 12)])
            pygame.draw.polygon(self._rage_icon_surface, (240, 215, 140),
                [(icon_w - 6, 10), (icon_w - 4, 3), (icon_w - 10, 9)])
            pygame.draw.polygon(self._rage_icon_surface, (255, 250, 210),
                [(icon_w - 5, 5), (icon_w - 4, 1), (icon_w - 7, 5)])

            # === 5. 눈 (공포스러운 빛나는 눈) ===
            eye_y = 28
            eye_w_size, eye_h_size = 11, 8

            for side in [-1, 1]:
                eye_cx = cx + side * 10
                # 깊은 눈구멍 (검은 구멍)
                pygame.draw.ellipse(self._rage_icon_surface, (5, 0, 0),
                    (eye_cx - eye_w_size//2 - 2, eye_y - 2, eye_w_size + 4, eye_h_size + 4))
                # 눈 외곽 글로우 (주황)
                pygame.draw.ellipse(self._rage_icon_surface, (255, 120, 30, 200),
                    (eye_cx - eye_w_size//2 - 1, eye_y - 1, eye_w_size + 2, eye_h_size + 2))
                # 눈 베이스 (밝은 주황)
                pygame.draw.ellipse(self._rage_icon_surface, (255, 170, 50),
                    (eye_cx - eye_w_size//2, eye_y, eye_w_size, eye_h_size))
                # 눈 중심 (노랑)
                pygame.draw.ellipse(self._rage_icon_surface, (255, 220, 80),
                    (eye_cx - eye_w_size//2 + 2, eye_y + 2, eye_w_size - 4, eye_h_size - 4))
                # 눈 코어 (밝은 흰노랑 - 불타는 느낌)
                pygame.draw.ellipse(self._rage_icon_surface, (255, 255, 180),
                    (eye_cx - 2, eye_y + 2, 4, 4))
                # 광채 점
                pygame.draw.circle(self._rage_icon_surface, (255, 255, 255), (eye_cx, eye_y + 3), 1)

            # === 6. 눈썹 (더 사악하게) ===
            brow_color = (60, 10, 8)
            # 왼쪽 - 더 각지게
            pygame.draw.polygon(self._rage_icon_surface, brow_color,
                [(12, eye_y - 6), (27, eye_y - 1), (27, eye_y + 1), (12, eye_y - 3)])
            # 오른쪽
            pygame.draw.polygon(self._rage_icon_surface, brow_color,
                [(icon_w - 12, eye_y - 6), (icon_w - 27, eye_y - 1), (icon_w - 27, eye_y + 1), (icon_w - 12, eye_y - 3)])

            # === 7. 코 (납작하고 짐승같은) ===
            nose_y = 40
            pygame.draw.ellipse(self._rage_icon_surface, (80, 15, 12), (cx - 5, nose_y, 10, 7))
            # 콧구멍 (검고 깊은)
            pygame.draw.ellipse(self._rage_icon_surface, (15, 0, 0), (cx - 4, nose_y + 3, 3, 3))
            pygame.draw.ellipse(self._rage_icon_surface, (15, 0, 0), (cx + 1, nose_y + 3, 3, 3))

            # === 8. 입 (불타는 지옥의 입) ===
            mouth_y = 48
            mouth_w_size, mouth_h_size = 30, 16

            # 입 배경 (검은 심연)
            pygame.draw.ellipse(self._rage_icon_surface, (8, 0, 0),
                (cx - mouth_w_size//2, mouth_y, mouth_w_size, mouth_h_size))
            # 입 안쪽 불꽃 (용암 느낌)
            pygame.draw.ellipse(self._rage_icon_surface, (180, 60, 20, 150),
                (cx - mouth_w_size//2 + 3, mouth_y + 4, mouth_w_size - 6, mouth_h_size - 6))
            pygame.draw.ellipse(self._rage_icon_surface, (255, 120, 40, 100),
                (cx - mouth_w_size//2 + 6, mouth_y + 6, mouth_w_size - 12, mouth_h_size - 10))
            pygame.draw.ellipse(self._rage_icon_surface, (255, 180, 80, 80),
                (cx - mouth_w_size//2 + 9, mouth_y + 8, mouth_w_size - 18, mouth_h_size - 14))

            # === 9. 이빨 (날카로운 금색) ===
            teeth_color = (230, 200, 110)
            teeth_highlight = (255, 245, 195)

            # 윗니 (더 날카롭고 불규칙하게)
            teeth_positions = [(-12, 7), (-8, 5), (-4, 6), (0, 5), (4, 6), (8, 5), (12, 7)]
            for i, (offset, height) in enumerate(teeth_positions):
                tx = cx + offset - 2
                # 이빨 그림자
                pygame.draw.polygon(self._rage_icon_surface, (100, 80, 40),
                    [(tx, mouth_y + 1), (tx + 2, mouth_y + height + 1), (tx + 4, mouth_y + 1)])
                # 이빨 본체
                pygame.draw.polygon(self._rage_icon_surface, teeth_color,
                    [(tx + 1, mouth_y), (tx + 2, mouth_y + height), (tx + 3, mouth_y)])
                # 하이라이트
                pygame.draw.line(self._rage_icon_surface, teeth_highlight,
                    (tx + 2, mouth_y + 1), (tx + 2, mouth_y + height - 1), 1)

            # === 10. 큰 송곳니 (더 길고 무섭게) ===
            fang_shadow = (70, 55, 25)
            fang_color = (240, 210, 120)
            fang_highlight = (255, 250, 210)

            # 왼쪽 송곳니
            pygame.draw.polygon(self._rage_icon_surface, fang_shadow,
                [(cx - 14, mouth_y + 2), (cx - 10, mouth_y + 18), (cx - 16, mouth_y + 16)])
            pygame.draw.polygon(self._rage_icon_surface, fang_color,
                [(cx - 13, mouth_y + 1), (cx - 10, mouth_y + 16), (cx - 15, mouth_y + 14)])
            pygame.draw.polygon(self._rage_icon_surface, fang_highlight,
                [(cx - 12, mouth_y + 2), (cx - 11, mouth_y + 10), (cx - 13, mouth_y + 8)])

            # 오른쪽 송곳니
            pygame.draw.polygon(self._rage_icon_surface, fang_shadow,
                [(cx + 14, mouth_y + 2), (cx + 10, mouth_y + 18), (cx + 16, mouth_y + 16)])
            pygame.draw.polygon(self._rage_icon_surface, fang_color,
                [(cx + 13, mouth_y + 1), (cx + 10, mouth_y + 16), (cx + 15, mouth_y + 14)])
            pygame.draw.polygon(self._rage_icon_surface, fang_highlight,
                [(cx + 12, mouth_y + 2), (cx + 11, mouth_y + 10), (cx + 13, mouth_y + 8)])

            # === 11. 이마 제3의 눈/문양 ===
            third_eye_y = 18
            # 외곽 글로우
            pygame.draw.circle(self._rage_icon_surface, (255, 100, 50, 100), (cx, third_eye_y), 6)
            # 문양 베이스
            pygame.draw.circle(self._rage_icon_surface, (200, 60, 30), (cx, third_eye_y), 4)
            # 내부 빛
            pygame.draw.circle(self._rage_icon_surface, (255, 180, 80), (cx, third_eye_y), 2)
            # 중앙 광점
            pygame.draw.circle(self._rage_icon_surface, (255, 255, 200), (cx, third_eye_y), 1)

            # === 12. 얼굴 테두리 불꽃 효과 ===
            flame_points_left = [(4, 25), (2, 35), (5, 45), (3, 55)]
            flame_points_right = [(icon_w - 4, 25), (icon_w - 2, 35), (icon_w - 5, 45), (icon_w - 3, 55)]
            pygame.draw.lines(self._rage_icon_surface, (255, 100, 30, 120), False, flame_points_left, 2)
            pygame.draw.lines(self._rage_icon_surface, (255, 100, 30, 120), False, flame_points_right, 2)

            print("[PillarBG] 광폭화 인디케이터 아이콘 생성 완료 (공포 버전)")
        except Exception as e:
            print(f"[PillarBG] 광폭화 아이콘 생성 실패: {e}")
            self._rage_icon_surface = None
            self._rage_icon_w = 52
            self._rage_icon_h = 68

    def set_rage_indicator(self, active: bool):
        """광폭화 인디케이터 활성화/비활성화"""
        self._rage_indicator_active = active

    def draw_rage_indicator(self, screen, dt: float = 0.016):
        """광폭화 인디케이터 그리기 (우측 필러 상단 - X축은 대쉬토큰구슬 중앙, Y축은 골드HUD 높이)

        Args:
            screen: 그릴 surface
            dt: 프레임 시간 (애니메이션용)

        Returns:
            pygame.Rect or None: 인디케이터 영역 (호버 감지용)
        """
        if not self._rage_indicator_active or self._rage_icon_surface is None:
            self._rage_indicator_rect = None
            return None

        if self.right_pillar_width < 50:
            self._rage_indicator_rect = None
            return None

        try:
            # 애니메이션 업데이트
            self._rage_animation_time += dt

            # 위치 계산
            right_x = self.game_offset_x + self.game_width
            icon_w = self._rage_icon_w  # 가로
            icon_h = self._rage_icon_h  # 세로 (더 김)

            # X축: 대쉬토큰구슬 박스의 중앙
            bottom_box_width = 60
            bottom_box_x = right_x + (self.right_pillar_width - bottom_box_width) // 2
            dash_token_center_x = bottom_box_x + bottom_box_width // 2

            # Y축: 골드 HUD와 같은 높이 (상단), X축: 대쉬토큰구슬 중앙 기준
            base_x = dash_token_center_x - icon_w // 2 - 110  # 왼쪽으로 110px
            base_y = 75  # 상단에서 75px 아래

            # 펄스/흔들림 애니메이션
            pulse = 1.0 + 0.06 * math.sin(self._rage_animation_time * 4)
            shake_x = int(1 * math.sin(self._rage_animation_time * 10))
            shake_y = int(0.5 * math.cos(self._rage_animation_time * 8))

            x = base_x + shake_x
            y = base_y + shake_y

            # === 배경 효과 (타원형 글로우) ===
            glow_w = int(icon_w * 1.6)
            glow_h = int(icon_h * 1.4)
            glow_surface = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
            glow_pulse = 0.6 + 0.4 * math.sin(self._rage_animation_time * 3)

            # 외곽 글로우 (타원형)
            for i in range(8):
                shrink = i * 4
                alpha = int(40 * glow_pulse * (8 - i) / 8)
                pygame.draw.ellipse(glow_surface, (255, 50 + i * 10, 20, alpha),
                    (shrink, shrink, glow_w - shrink * 2, glow_h - shrink * 2))

            screen.blit(glow_surface, (x + icon_w // 2 - glow_w // 2,
                                       y + icon_h // 2 - glow_h // 2))

            # === 아이콘 그리기 (펄스 스케일) ===
            scaled_w = int(self._rage_icon_w * pulse)
            scaled_h = int(self._rage_icon_h * pulse)
            scaled_icon = pygame.transform.scale(self._rage_icon_surface,
                                                (scaled_w, scaled_h))
            draw_x = x + (self._rage_icon_w - scaled_w) // 2
            draw_y = y + (self._rage_icon_h - scaled_h) // 2
            screen.blit(scaled_icon, (draw_x, draw_y))

            # 호버 영역 저장 (테두리 없이 아이콘 영역만)
            self._rage_indicator_rect = pygame.Rect(x, y, self._rage_icon_w, self._rage_icon_h)
            return self._rage_indicator_rect

        except Exception as e:
            print(f"[PillarBG] 광폭화 인디케이터 그리기 실패: {e}")
            self._rage_indicator_rect = None
            return None

    def get_rage_indicator_rect(self):
        """광폭화 인디케이터 영역 반환 (호버 감지용)"""
        return self._rage_indicator_rect

    def check_rage_indicator_hover(self, mouse_pos):
        """마우스가 광폭화 인디케이터 위에 있는지 확인

        Args:
            mouse_pos: 마우스 위치 (x, y)

        Returns:
            bool: 호버 중이면 True
        """
        if self._rage_indicator_rect and self._rage_indicator_active:
            return self._rage_indicator_rect.collidepoint(mouse_pos)
        return False

    def draw_rage_tooltip(self, screen, mouse_pos):
        """광폭화 모드 툴팁 그리기

        Args:
            screen: 그릴 surface
            mouse_pos: 마우스 위치 (x, y)
        """
        if not self.check_rage_indicator_hover(mouse_pos):
            return

        try:
            # 툴팁 텍스트
            tooltip_text = "광폭화보스"

            # 폰트 로드 (한글 렌더링을 위해 freetype 사용)
            import pygame.freetype as freetype_module
            try:
                font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
                tooltip_font = freetype_module.Font(font_path, 14)
            except:
                tooltip_font = freetype_module.SysFont("malgun gothic", 14)

            # 텍스트 렌더링
            text_surface, text_rect = tooltip_font.render(tooltip_text, (255, 255, 255))

            # 툴팁 배경 크기
            padding = 6
            bg_width = text_rect.width + padding * 2
            bg_height = text_rect.height + padding * 2

            # 위치 (마우스 옆에 표시, 화면 밖으로 나가지 않게)
            tooltip_x = mouse_pos[0] + 15
            tooltip_y = mouse_pos[1] - bg_height // 2

            # 화면 경계 체크
            if tooltip_x + bg_width > self.screen_width:
                tooltip_x = mouse_pos[0] - bg_width - 10
            if tooltip_y < 5:
                tooltip_y = 5
            if tooltip_y + bg_height > self.screen_height - 5:
                tooltip_y = self.screen_height - bg_height - 5

            # 배경 (반투명 검정 + 빨간 테두리)
            bg_surface = pygame.Surface((bg_width, bg_height), pygame.SRCALPHA)
            pygame.draw.rect(bg_surface, (40, 10, 10, 230), (0, 0, bg_width, bg_height), border_radius=4)
            pygame.draw.rect(bg_surface, (200, 50, 50), (0, 0, bg_width, bg_height), 1, border_radius=4)

            screen.blit(bg_surface, (tooltip_x, tooltip_y))
            screen.blit(text_surface, (tooltip_x + padding, tooltip_y + padding))

        except Exception as e:
            print(f"[PillarBG] 광폭화 툴팁 그리기 실패: {e}")

    # ============================================================
    # 퀘스트 양피지 엠블럼 시스템
    # ============================================================

    def _create_quest_parchment_icon(self):
        """퀘스트 양피지 엠블럼 아이콘 생성 (프로그래밍 방식)"""
        try:
            icon_w, icon_h = self._quest_emblem_w, self._quest_emblem_h
            self._quest_emblem_surface = pygame.Surface((icon_w, icon_h), pygame.SRCALPHA)
            surf = self._quest_emblem_surface

            cx = icon_w // 2
            # === 양피지 본체 ===
            # 양피지 배경 (베이지/크림색)
            parchment_color = (210, 185, 140)
            parchment_dark = (180, 155, 110)
            parchment_light = (230, 210, 170)

            # 메인 양피지 사각형 (약간 둥근 모서리)
            body_rect = pygame.Rect(4, 6, icon_w - 8, icon_h - 12)
            pygame.draw.rect(surf, parchment_color, body_rect, border_radius=3)

            # 양피지 테두리 (갈색)
            border_color = (140, 110, 70)
            pygame.draw.rect(surf, border_color, body_rect, 1, border_radius=3)

            # 양피지 상단/하단 말림 효과 (롤 부분)
            roll_color = (190, 165, 120)
            roll_highlight = (220, 200, 160)
            # 상단 말림
            pygame.draw.ellipse(surf, roll_color, (3, 2, icon_w - 6, 10))
            pygame.draw.ellipse(surf, roll_highlight, (5, 3, icon_w - 10, 6))
            pygame.draw.ellipse(surf, border_color, (3, 2, icon_w - 6, 10), 1)
            # 하단 말림
            pygame.draw.ellipse(surf, roll_color, (3, icon_h - 10, icon_w - 6, 10))
            pygame.draw.ellipse(surf, roll_highlight, (5, icon_h - 9, icon_w - 10, 6))
            pygame.draw.ellipse(surf, border_color, (3, icon_h - 10, icon_w - 6, 10), 1)

            # === 텍스트 라인 장식 (가로 줄) ===
            line_color = (160, 135, 100, 120)
            line_y_start = 14
            line_spacing = 6
            for i in range(4):
                ly = line_y_start + i * line_spacing
                lx_start = 10
                lx_end = icon_w - 10 - (i % 2) * 6  # 줄마다 약간 다른 길이
                line_surf = pygame.Surface((lx_end - lx_start, 1), pygame.SRCALPHA)
                line_surf.fill(line_color)
                surf.blit(line_surf, (lx_start, ly))

            # === 밀봉 인장 (빨간 원) ===
            seal_cx = cx
            seal_cy = icon_h - 16
            seal_r = 5
            # 어두운 빨강 (왁스 느낌)
            pygame.draw.circle(surf, (160, 40, 40), (seal_cx, seal_cy), seal_r)
            pygame.draw.circle(surf, (200, 60, 50), (seal_cx, seal_cy), seal_r - 1)
            # 인장 하이라이트
            pygame.draw.circle(surf, (220, 100, 80), (seal_cx - 1, seal_cy - 1), 2)
            # 인장 테두리
            pygame.draw.circle(surf, (120, 30, 30), (seal_cx, seal_cy), seal_r, 1)

            print(f"[PillarBG] 퀘스트 양피지 엠블럼 생성 완료 ({icon_w}x{icon_h})")

        except Exception as e:
            print(f"[PillarBG] 퀘스트 양피지 엠블럼 생성 실패: {e}")
            self._quest_emblem_surface = None

    def set_quest_emblem(self, active: bool, glow: bool = False):
        """퀘스트 엠블럼 활성화/비활성화 설정

        Args:
            active: 진행 중인 퀘스트가 있으면 True
            glow: 퀘스트 완료 빛 효과 활성화
        """
        self._quest_emblem_active = active
        self._quest_completion_glow = glow

    def set_quest_tablet_counter(self, count: int, target: int, active: bool):
        """석판 퀘스트 카운터 설정"""
        self._quest_tablet_count = count
        self._quest_tablet_target = target
        self._quest_has_tablet_quest = active

    def draw_quest_emblem(self, screen, dt: float = 0.016):
        """퀘스트 양피지 엠블럼 그리기 (우측 필러 상단 박스 아래)

        Args:
            screen: 그릴 surface
            dt: 프레임 시간 (애니메이션용)

        Returns:
            pygame.Rect or None: 엠블럼 영역 (호버 감지용)
        """
        if not self._quest_emblem_active and not self._quest_completion_glow:
            self._quest_emblem_rect = None
            return None

        if self._quest_emblem_surface is None:
            self._quest_emblem_rect = None
            return None

        if self.right_pillar_width < 50:
            self._quest_emblem_rect = None
            return None

        try:
            # 애니메이션 타이머 업데이트
            self._quest_animation_time += dt

            # 위치 계산 (광폭화 아이콘과 같은 X축, 그 아래에 배치)
            right_x = self.game_offset_x + self.game_width
            icon_w = self._quest_emblem_w
            icon_h = self._quest_emblem_h

            # X: 광폭화 아이콘과 동일한 X축 계산 (대쉬토큰 중앙 기준 왼쪽 110px)
            bottom_box_width = 60
            bottom_box_x = right_x + (self.right_pillar_width - bottom_box_width) // 2
            dash_token_center_x = bottom_box_x + bottom_box_width // 2
            base_x = dash_token_center_x - icon_w // 2 - 110
            # Y: 광폭화 아이콘(Y=75, H=68) 아래에 배치
            base_y = 155

            # 미세한 떠다니는 애니메이션 (상하로 살짝 흔들림)
            float_offset = int(2.0 * math.sin(self._quest_animation_time * 1.5))
            x = base_x
            y = base_y + float_offset

            # === 퀘스트 완료 빛 효과 ===
            if self._quest_completion_glow:
                self._quest_completion_glow_timer += dt
                glow_progress = self._quest_completion_glow_timer

                # 빛 방사 효과 (금색 글로우)
                glow_intensity = max(0, 1.0 - glow_progress / 3.0)  # 3초에 걸쳐 페이드아웃
                if glow_intensity > 0:
                    # 펄싱 글로우
                    pulse = 0.6 + 0.4 * math.sin(glow_progress * 6)
                    glow_alpha = int(120 * glow_intensity * pulse)

                    # 외곽 글로우 (여러 레이어)
                    for layer in range(6):
                        expand = layer * 5
                        layer_alpha = int(glow_alpha * (6 - layer) / 6)
                        if layer_alpha > 0:
                            glow_w = icon_w + expand * 2
                            glow_h = icon_h + expand * 2
                            glow_surf = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
                            pygame.draw.ellipse(glow_surf,
                                (255, 215, 80, layer_alpha),
                                (0, 0, glow_w, glow_h))
                            screen.blit(glow_surf,
                                (x + icon_w // 2 - glow_w // 2,
                                 y + icon_h // 2 - glow_h // 2))

                    # 빛 입자 효과
                    for i in range(8):
                        angle = (self._quest_animation_time * 2 + i * 0.785)  # 45도 간격
                        dist = 15 + 10 * math.sin(glow_progress * 3 + i)
                        px = int(x + icon_w // 2 + math.cos(angle) * dist)
                        py = int(y + icon_h // 2 + math.sin(angle) * dist)
                        p_alpha = int(180 * glow_intensity * pulse)
                        if p_alpha > 0:
                            p_surf = pygame.Surface((4, 4), pygame.SRCALPHA)
                            pygame.draw.circle(p_surf, (255, 230, 120, p_alpha), (2, 2), 2)
                            screen.blit(p_surf, (px - 2, py - 2))
            else:
                # 평상시 미세한 글로우 (따뜻한 베이지)
                ambient_pulse = 0.3 + 0.2 * math.sin(self._quest_animation_time * 2)
                ambient_alpha = int(40 * ambient_pulse)
                if ambient_alpha > 0:
                    glow_w = icon_w + 12
                    glow_h = icon_h + 12
                    glow_surf = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
                    pygame.draw.ellipse(glow_surf,
                        (210, 185, 100, ambient_alpha),
                        (0, 0, glow_w, glow_h))
                    screen.blit(glow_surf,
                        (x + icon_w // 2 - glow_w // 2,
                         y + icon_h // 2 - glow_h // 2))

            # === 아이콘 그리기 ===
            screen.blit(self._quest_emblem_surface, (x, y))

            # === 석판 카운터 표시 (엠블럼 아래) ===
            if self._quest_has_tablet_quest:
                try:
                    counter_text = f"{self._quest_tablet_count}/{self._quest_tablet_target}"
                    counter_font = pygame.font.Font(None, 18)
                    counter_surf = counter_font.render(counter_text, True, (200, 210, 230))
                    counter_x = x + icon_w // 2 - counter_surf.get_width() // 2
                    counter_y = y + icon_h + 4
                    # 배경 박스
                    bg_w = counter_surf.get_width() + 8
                    bg_h = counter_surf.get_height() + 4
                    bg_surf = pygame.Surface((bg_w, bg_h), pygame.SRCALPHA)
                    pygame.draw.rect(bg_surf, (30, 30, 40, 160), (0, 0, bg_w, bg_h), border_radius=3)
                    pygame.draw.rect(bg_surf, (120, 130, 160, 100), (0, 0, bg_w, bg_h), 1, border_radius=3)
                    screen.blit(bg_surf, (counter_x - 4, counter_y - 2))
                    screen.blit(counter_surf, (counter_x, counter_y))
                except:
                    pass

            # 호버 영역 저장
            self._quest_emblem_rect = pygame.Rect(x, y, icon_w, icon_h)
            return self._quest_emblem_rect

        except Exception as e:
            print(f"[PillarBG] 퀘스트 엠블럼 그리기 실패: {e}")
            self._quest_emblem_rect = None
            return None

    def get_quest_emblem_rect(self):
        """퀘스트 엠블럼 영역 반환 (호버 감지용)"""
        return self._quest_emblem_rect

    def check_quest_emblem_hover(self, mouse_pos):
        """마우스가 퀘스트 엠블럼 위에 있는지 확인

        Args:
            mouse_pos: 마우스 위치 (x, y)

        Returns:
            bool: 호버 중이면 True
        """
        if self._quest_emblem_rect and self._quest_emblem_active:
            return self._quest_emblem_rect.collidepoint(mouse_pos)
        return False

    def draw_quest_tooltip(self, screen, mouse_pos, quest_info_list):
        """퀘스트 정보 툴팁 그리기

        Args:
            screen: 그릴 surface
            mouse_pos: 마우스 위치 (x, y)
            quest_info_list: 퀘스트 정보 딕셔너리 리스트
                [{"name": "...", "description": "...", "condition_desc": "...", "reward_gold": 1000}, ...]
        """
        if not self.check_quest_emblem_hover(mouse_pos):
            return

        if not quest_info_list:
            return

        try:
            import pygame.freetype as freetype_module
            try:
                font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
                title_font = freetype_module.Font(font_path, 13)
                body_font = freetype_module.Font(font_path, 11)
            except:
                title_font = freetype_module.SysFont("malgun gothic", 13)
                body_font = freetype_module.SysFont("malgun gothic", 11)

            # 툴팁 내용 구성
            lines = []
            # 헤더
            header_surf, header_rect = title_font.render("진행 중인 퀘스트", (255, 220, 150))
            lines.append(("header", header_surf, header_rect))

            for i, quest in enumerate(quest_info_list):
                if i > 0:
                    lines.append(("spacer", None, None))

                # 퀘스트명
                name_surf, name_rect = title_font.render(
                    quest.get("name", "???"), (255, 255, 255))
                lines.append(("name", name_surf, name_rect))

                # 조건
                cond_surf, cond_rect = body_font.render(
                    quest.get("condition_desc", ""), (200, 200, 200))
                lines.append(("cond", cond_surf, cond_rect))

                # 보상
                reward_gold = quest.get("reward_gold", 0)
                reward_surf, reward_rect = body_font.render(
                    f"보상: {reward_gold}G", (255, 215, 80))
                lines.append(("reward", reward_surf, reward_rect))

            # 툴팁 크기 계산
            padding = 8
            line_height = 18
            spacer_height = 6
            max_w = 0
            total_h = padding * 2

            for line_type, surf, rect in lines:
                if line_type == "spacer":
                    total_h += spacer_height
                else:
                    total_h += line_height
                    if rect:
                        max_w = max(max_w, rect.width)

            bg_width = max_w + padding * 2 + 4
            bg_height = total_h

            # 최소 너비 보장
            bg_width = max(bg_width, 140)

            # 위치 (마우스 왼쪽에 표시 - 우측 필러에 있으므로)
            tooltip_x = mouse_pos[0] - bg_width - 10
            tooltip_y = mouse_pos[1] - bg_height // 2

            # 화면 경계 체크
            if tooltip_x < 5:
                tooltip_x = mouse_pos[0] + 15
            if tooltip_y < 5:
                tooltip_y = 5
            if tooltip_y + bg_height > self.screen_height - 5:
                tooltip_y = self.screen_height - bg_height - 5

            # 배경 (양피지 느낌의 반투명 박스)
            bg_surface = pygame.Surface((bg_width, bg_height), pygame.SRCALPHA)
            pygame.draw.rect(bg_surface, (45, 35, 20, 235),
                (0, 0, bg_width, bg_height), border_radius=5)
            pygame.draw.rect(bg_surface, (180, 150, 80),
                (0, 0, bg_width, bg_height), 1, border_radius=5)
            # 내부 테두리 (이중선 효과)
            pygame.draw.rect(bg_surface, (120, 100, 50, 80),
                (2, 2, bg_width - 4, bg_height - 4), 1, border_radius=4)

            screen.blit(bg_surface, (tooltip_x, tooltip_y))

            # 텍스트 렌더링
            current_y = tooltip_y + padding
            for line_type, surf, rect in lines:
                if line_type == "spacer":
                    # 구분선
                    sep_y = current_y + spacer_height // 2
                    pygame.draw.line(screen, (120, 100, 60),
                        (tooltip_x + padding, sep_y),
                        (tooltip_x + bg_width - padding, sep_y), 1)
                    current_y += spacer_height
                elif line_type == "header":
                    # 헤더 중앙 정렬
                    tx = tooltip_x + (bg_width - rect.width) // 2
                    screen.blit(surf, (tx, current_y))
                    current_y += line_height
                else:
                    screen.blit(surf, (tooltip_x + padding + 2, current_y))
                    current_y += line_height

        except Exception as e:
            print(f"[PillarBG] 퀘스트 툴팁 그리기 실패: {e}")

# 전역 인스턴스
_pillar_renderer = None


def init_pillar_background(screen_width: int, screen_height: int,
                           game_width: int, game_height: int,
                           offset_x: int = None, offset_y: int = None,
                           original_game_width: int = None, original_game_height: int = None) -> PillarBackgroundRenderer:
    """필러 배경 렌더러 초기화"""
    global _pillar_renderer
    _pillar_renderer = PillarBackgroundRenderer(
        screen_width, screen_height, game_width, game_height,
        offset_x, offset_y, original_game_width, original_game_height
    )
    return _pillar_renderer


def get_pillar_renderer() -> PillarBackgroundRenderer:
    """필러 배경 렌더러 인스턴스 반환"""
    return _pillar_renderer