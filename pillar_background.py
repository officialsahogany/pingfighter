# -*- coding: utf-8 -*-
"""
필러(Pillar) 배경 렌더러
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
                 offset_x: int = None, offset_y: int = None):
        """
        Args:
            screen_width: 전체화면 너비
            screen_height: 전체화면 높이
            game_width: 게임 영역 너비 (스케일링된 크기)
            game_height: 게임 영역 높이 (스케일링된 크기)
            offset_x: 게임 영역 X 오프셋 (None이면 자동 계산)
            offset_y: 게임 영역 Y 오프셋 (None이면 자동 계산)
        """
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

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

        # 플레이어/보스 위치 (원숭이-바나나 이벤트용)
        self._player_rect = None
        self._boss_rect = None
        self._player_dash_dir = 0  # 플레이어 대쉬 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        self._boss_move_dir = 0  # 보스 이동 방향 (-1: 왼쪽, 0: 없음, 1: 오른쪽)
        self._player_in_smoke = False  # 플레이어가 연막 안에 있는지 (바나나 미끄러짐 면역)

        # 불타는 태양 효과 강도 (0.0 ~ 1.0)
        self._blazing_intensity = 0.8

        # 아트워크 로드
        self._load_artwork()

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
        # macOS에서는 smoothscale이 깨질 수 있으므로 scale 사용
        if _is_macos:
            scaled_artwork = pygame.transform.scale(
                self._artwork_surface, (scaled_w, scaled_h)
            )
        else:
            scaled_artwork = pygame.transform.smoothscale(
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

        # 상단 필러
        if self.top_pillar_height > 0:
            self._top_pillar_surface = pygame.Surface(
                (self.game_width, self.top_pillar_height)
            )
            self._top_pillar_surface.fill(self.bg_color)
            if _is_macos:
                self._top_pillar_surface = self._top_pillar_surface.convert()

        # 하단 필러
        if self.bottom_pillar_height > 0:
            self._bottom_pillar_surface = pygame.Surface(
                (self.game_width, self.bottom_pillar_height)
            )
            self._bottom_pillar_surface.fill(self.bg_color)
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
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 1 스타디움 배경 초기화 완료")

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

        # 스테이지 6(코드): 네메시스 해상전투 배경 초기화 (게임 내 실제 스테이지 5 = 코드 상 stage 6)
        if stage == 6 and self._nemesis_ocean_bg is None:
            self._nemesis_ocean_bg = NemesisOceanFrame(
                self.screen_width, self.screen_height,
                self.game_width, self.game_height
            )
            print(f"[PillarBG] 스테이지 6(실제 5 네메시스) 해상전투 배경 초기화 완료")

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

    def set_blazing_intensity(self, intensity: float):
        """불타는 태양 효과 강도 설정 (0.0 ~ 1.0)"""
        self._blazing_intensity = max(0.0, min(1.0, intensity))
        if self._blazing_sun_bg is not None:
            self._blazing_sun_bg.set_intensity(self._blazing_intensity)

    def update(self, dt: float):
        """애니메이션 업데이트"""
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
        if self.current_stage == 5 and self._hongryeon_bg is not None:
            self._hongryeon_bg.update(dt)

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

        # 스타디움 배경 리사이즈
        if self._stadium_bg is not None:
            self._stadium_bg.resize(screen_width, screen_height, game_width, game_height)

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

    def draw_left_pillar_ui(self, screen, active_items=None, icon_size=(28, 28)):
        """왼쪽 필러 UI 그리기 (액티브 아이템 슬롯)

        Args:
            screen: 그릴 surface
            active_items: 액티브 아이템 리스트
            icon_size: 아이콘 크기 튜플
        """
        if self.left_pillar_width < 60:
            return  # 필러가 너무 좁으면 그리지 않음

        # 왼쪽 하단에 액티브 아이템 박스
        box_width = 60
        box_height = 120  # 최대 3슬롯 세로 배치
        box_x = (self.left_pillar_width - box_width) // 2
        box_y = self.screen_height - box_height - 20

        self.draw_pillar_ui_box(screen, box_x, box_y, box_width, box_height)

        # "ITEMS" 레이블
        try:
            font = pygame.font.Font(None, 14)
            label = font.render("ITEMS", True, (150, 150, 180))
            label_x = box_x + (box_width - label.get_width()) // 2
            screen.blit(label, (label_x, box_y + 5))
        except:
            pass

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

# 전역 인스턴스
_pillar_renderer = None


def init_pillar_background(screen_width: int, screen_height: int,
                           game_width: int, game_height: int,
                           offset_x: int = None, offset_y: int = None) -> PillarBackgroundRenderer:
    """필러 배경 렌더러 초기화"""
    global _pillar_renderer
    _pillar_renderer = PillarBackgroundRenderer(
        screen_width, screen_height, game_width, game_height,
        offset_x, offset_y
    )
    return _pillar_renderer


def get_pillar_renderer() -> PillarBackgroundRenderer:
    """필러 배경 렌더러 인스턴스 반환"""
    return _pillar_renderer